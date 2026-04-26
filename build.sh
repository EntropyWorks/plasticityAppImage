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

#TARGET_DEB_URL=https://github.com/nkallen/plasticity/releases/download/v24.1.5/plasticity_24.1.5_amd64.deb
TARGET_DEB_URL=https://github.com/nkallen/plasticity/releases/download/v26.1.3/plasticity_26.1.3_amd64.deb
APPIMAGE_RUNTIME_URL=https://github.com/AppImage/AppImageKit/releases/download/continuous/runtime-x86_64
TEMP_DIR=/tmp/build-plasticity

###############

set -e
# set -x # for debug

if [[ ! -d "${TEMP_DIR}" ]] ; then
  mkdir "${TEMP_DIR}"
fi

sudo apt -y install\
    desktop-file-utils\
    fuse\
    file\
    squashfs-tools

# get plasticity deb
wget "${TARGET_DEB_URL}" -O "${TEMP_DIR}/plasticity.deb"
sudo apt install "${TEMP_DIR}/plasticity.deb"

# extract deb files
dpkg -x "${TEMP_DIR}/plasticity.deb" "${TEMP_DIR}/DebFiles"

# get AppImage runtime (plain ELF, not an AppImage itself)
wget "${APPIMAGE_RUNTIME_URL}" -O "${TEMP_DIR}/runtime-x86_64"

# create the App directory
mkdir -p "${TEMP_DIR}/AppDir"

# get all the library objects
for objlink in $(ldd /usr/bin/plasticity | cut -d '>' -f 2 | awk '{print $1}')
do
	[ -f "${objlink}" ] && cp --verbose --parents "${objlink}" "${TEMP_DIR}/AppDir/"
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

#create the destop file
cat << 'EOF' > "${TEMP_DIR}/AppDir/plasticity.desktop"
[Desktop Entry]
Name=Plasticity
Exec=plasticity
Type=Application
Icon=icon
Categories=Utility
EOF
chmod +x "${TEMP_DIR}/AppDir/plasticity.desktop"

#copy the icon
cp icon.png "${TEMP_DIR}/AppDir/"
cp icon.png "${TEMP_DIR}/AppDir/.DirIcon"

# build AppImage manually (avoids appimagetool, which is itself an AppImage and
# fails in containers where binfmt_misc routes AppImages through a missing handler)
mksquashfs "${TEMP_DIR}/AppDir" "${TEMP_DIR}/plasticity.squashfs" -root-owned -noappend -comp gzip

cat "${TEMP_DIR}/runtime-x86_64" "${TEMP_DIR}/plasticity.squashfs" > Plasticity-x86_64.AppImage
chmod +x Plasticity-x86_64.AppImage
echo "AppImage built: $(pwd)/Plasticity-x86_64.AppImage"

#ask about files
while true; do
    read -p "Do you want to cleaup ${TEMP_DIR}? (yes/no): " yn
    case $yn in
        [Yy]* ) 
            rm -r "${TEMP_DIR}"
            echo "Directory ${TEMP_DIR} deleted."
            break
            ;;
        [Nn]* ) 
            echo "Keeping directory ${TEMP_DIR}"
            break
            ;;
        * ) 
            echo "Please answer yes or no."
            ;;
    esac
done
