#!/bin/bash
#####
# Disclaimer
# This script and binary are provided as-is, without any guarantees or warranty.
# Although it was created for personal use, it is being shared in
# good faith for others who may find it useful. The author is not
# responsible for any issues, errors, or damages that may arise from
# the use of this script. Users are advised to test and evaluate
# the script in their own environment and use it at their own risk.
#

##### EDIT #####

PLASTICITY_REPO=nkallen/plasticity
APPIMAGE_REPO=AppImage/AppImageKit
TEMP_DIR=/tmp/build-plasticity

###############

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # no color

# GitHub Actions and most CI systems set CI=true automatically
[[ "${CI}" == "true" ]] && DEBUG=true

set -e
[[ "${DEBUG}" == "true" ]] && set -x

FAILED_CMD=""
FAILED_LINE=""
SPINNER_PID=""

on_error() {
    FAILED_CMD="${BASH_COMMAND}"
    FAILED_LINE="${BASH_LINENO[0]}"
}

trap on_error ERR

start_spinner() {
    # no-op in CI: set -x would flood logs with spinner's sleep/printf trace
    [[ "${CI}" == "true" ]] && return 0
    spinner "$1" &
    SPINNER_PID=$!
}

stop_spinner() {
    if [[ -n "${SPINNER_PID}" ]]; then
        kill "${SPINNER_PID}" 2>/dev/null
        wait "${SPINNER_PID}" 2>/dev/null || true
        printf "\r\033[K"
        SPINNER_PID=""
    fi
}

cleanup() {
    local exit_status=$?
    stop_spinner
    if [[ $exit_status -ne 0 ]]; then
        echo -e "${RED}Build failed (exit status ${exit_status}): '${FAILED_CMD}' on line ${FAILED_LINE}${NC}" >&2
    fi
    if [[ "${CI}" == "true" ]]; then
        rm -rf "${TEMP_DIR}" 2>/dev/null || true
        exit $exit_status
    fi
    while true; do
        read -p "Do you want to cleanup ${TEMP_DIR}? (yes/no): " yn || { echo "Keeping directory ${TEMP_DIR}"; break; }
        case $yn in
            [Yy]* )
                rm -rf "${TEMP_DIR}"
                echo "Directory ${TEMP_DIR} deleted."
                break
                ;;
            [Nn]* )
                echo "Keeping directory ${TEMP_DIR}"
                break
                ;;
            * ) echo "Please answer yes or no."
                ;;
        esac
    done
    exit $exit_status
}

trap cleanup EXIT

spinner() {
    local msg="$1"
    local chars='/-\|'
    local i=0
    while true; do
        printf "\r${CYAN}%s %s${NC}" "${chars:$((i % 4)):1}" "$msg"
        sleep 0.1
        i=$(( i + 1 ))
    done
}

download_if_needed() {
    local url="$1"
    local dest="$2"
    if [[ -f "${dest}" ]]; then
        local remote_size local_size
        start_spinner "Checking $(basename "${dest}")..."
        remote_size=$(wget --spider --server-response "${url}" 2>&1 | awk '/Content-Length/{print $2}' | tail -1 | tr -d '\r')
        stop_spinner
        if [[ -z "${remote_size}" ]]; then
            echo -e "${YELLOW}Could not determine remote size for $(basename "${dest}"), re-downloading.${NC}"
        else
            local_size=$(stat -c%s "${dest}")
            if [[ "${remote_size}" == "${local_size}" ]]; then
                echo -e "${GREEN}Skipping $(basename "${dest}"), already up to date.${NC}"
                return 0
            fi
            echo -e "${YELLOW}Re-downloading $(basename "${dest}") (local: ${local_size} bytes, remote: ${remote_size} bytes).${NC}"
        fi
    else
        echo -e "${CYAN}Downloading $(basename "${dest}")...${NC}"
    fi
    if [[ "${DEBUG}" == "true" ]]; then
        wget "${url}" -O "${dest}"
    else
        wget -q "${url}" -O "${dest}" &
        local wget_pid=$!
        start_spinner "Downloading $(basename "${dest}")..."
        wait "${wget_pid}"
        stop_spinner
        echo -e "${GREEN}Downloaded $(basename "${dest}").${NC}"
    fi
}

# pre-flight: icon must exist before we start downloading anything
[[ -f "plasticity.png" ]] || { echo -e "${RED}plasticity.png not found in $(pwd). Run from the repo root.${NC}" >&2; exit 1; }

if [[ ! -d "${TEMP_DIR}" ]] ; then
  mkdir "${TEMP_DIR}"
fi

APT_FLAGS="-y"
[[ "${DEBUG}" != "true" ]] && APT_FLAGS="-y -qq"

sudo apt ${APT_FLAGS} install\
    desktop-file-utils\
    fuse\
    file\
    squashfs-tools\
    wget

# fetch latest release version from GitHub
start_spinner "Fetching latest Plasticity version..."
LATEST_VERSION=$(wget -qO- "https://api.github.com/repos/${PLASTICITY_REPO}/releases/latest" \
    | grep -oP '"tag_name":\s*"v\K[^"]+')
stop_spinner
[[ -z "${LATEST_VERSION}" ]] && { echo -e "${RED}Failed to fetch Plasticity version from GitHub API (rate-limited?).${NC}" >&2; exit 1; }
echo -e "${CYAN}Latest version: ${LATEST_VERSION}${NC}"
TARGET_DEB_URL="https://github.com/${PLASTICITY_REPO}/releases/download/v${LATEST_VERSION}/plasticity_${LATEST_VERSION}_amd64.deb"

# get plasticity deb
download_if_needed "${TARGET_DEB_URL}" "${TEMP_DIR}/plasticity.deb"

# apt install is required here so ldd /usr/bin/plasticity resolves libraries below
sudo apt ${APT_FLAGS} install "${TEMP_DIR}/plasticity.deb"

# extract deb files
dpkg -x "${TEMP_DIR}/plasticity.deb" "${TEMP_DIR}/DebFiles"

# fetch latest AppImageKit release version from GitHub
# uses /releases (not /releases/latest) because AppImageKit's runtime asset lives
# in their "continuous" pre-release, which /releases/latest does not return
start_spinner "Fetching latest AppImageKit version..."
APPIMAGE_VERSION=$(wget -qO- "https://api.github.com/repos/${APPIMAGE_REPO}/releases" \
    | grep -oP '"tag_name":\s*"\K[^"]+' | head -1)
stop_spinner
[[ -z "${APPIMAGE_VERSION}" ]] && { echo -e "${RED}Failed to fetch AppImageKit version from GitHub API (rate-limited?).${NC}" >&2; exit 1; }
echo -e "${CYAN}Latest AppImageKit: ${APPIMAGE_VERSION}${NC}"
APPIMAGE_RUNTIME_URL="https://github.com/${APPIMAGE_REPO}/releases/download/${APPIMAGE_VERSION}/runtime-x86_64"

# get AppImage runtime (plain ELF, not an AppImage itself)
download_if_needed "${APPIMAGE_RUNTIME_URL}" "${TEMP_DIR}/runtime-x86_64"

# create the App directory
mkdir -p "${TEMP_DIR}/AppDir"

# get all the library objects
for objlink in $(ldd /usr/bin/plasticity | cut -d '>' -f 2 | awk '{print $1}')
do
	[ -f "${objlink}" ] && cp $([[ "${DEBUG}" == "true" ]] && echo "--verbose") --parents "${objlink}" "${TEMP_DIR}/AppDir/"
done

# copy the deb files into the App directory
cp -a "${TEMP_DIR}/DebFiles/usr" "${TEMP_DIR}/AppDir/"

#create AppRun script
cat << 'EOF'> "${TEMP_DIR}/AppDir/AppRun"
#!/bin/sh
PWD="$(dirname "$(readlink -f "${0}")")"
exec "${PWD}/usr/bin/plasticity"
EOF
chmod +x "${TEMP_DIR}/AppDir/AppRun"

#create the desktop file
cat << 'EOF' > "${TEMP_DIR}/AppDir/plasticity.desktop"
[Desktop Entry]
Name=Plasticity
Exec=plasticity
Type=Application
Icon=plasticity
Categories=Utility
EOF
chmod +x "${TEMP_DIR}/AppDir/plasticity.desktop"

#copy the icon
cp plasticity.png "${TEMP_DIR}/AppDir/"
cp plasticity.png "${TEMP_DIR}/AppDir/.DirIcon"

# build AppImage manually (avoids appimagetool, which is itself an AppImage and
# fails in containers where binfmt_misc routes AppImages through a missing handler)
if [[ "${DEBUG}" == "true" ]]; then
    mksquashfs "${TEMP_DIR}/AppDir" "${TEMP_DIR}/plasticity.squashfs" -root-owned -noappend -comp gzip
else
    mksquashfs "${TEMP_DIR}/AppDir" "${TEMP_DIR}/plasticity.squashfs" -root-owned -noappend -comp gzip > /dev/null &
    local_pid=$!
    start_spinner "Building AppImage..."
    wait "${local_pid}"
    stop_spinner
fi

cat "${TEMP_DIR}/runtime-x86_64" "${TEMP_DIR}/plasticity.squashfs" > "Plasticity-${LATEST_VERSION}-x86_64.AppImage"
chmod +x "Plasticity-${LATEST_VERSION}-x86_64.AppImage"
echo -e "${GREEN}AppImage built: $(pwd)/Plasticity-${LATEST_VERSION}-x86_64.AppImage${NC}"
