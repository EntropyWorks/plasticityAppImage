## Plasticity AppImage

This is a simple script to build an AppImage pacakge for Plasticity ( https://www.plasticity.xyz/ ).  
Unfortunately Plasticity only releases deb packages for debian-like distributions and I am a nixOS user.  
I made this simple script so I could run plasticity in my machine and creating this repo in case anyone else can benefit.   

### If you just want to run the app
download the AppImage from the release and run it in your machine (in nixOS you need appimage-run)  

### If you would like to build the AppImage yourself
Use the build.sh script.  
I used distrobox ( https://github.com/89luca89/distrobox ) to build the release binary in a Debian image  
Once you are into your distro clone this repo and run it.  

The script will automatically fetch the latest Plasticity release from GitHub so you don't need to edit anything to stay up to date.  

#### Tested on

- [ ] Debian 12 (Bookworm)
- [ ] Debian 13 (Trixie)
- [x] Debian forky/sid (unstable)


#### Environment variables

A couple of variables you can pass to the script if needed:

| Variable | Description |
|---|---|
| `DEBUG=true` | Enables verbose output — shows full apt, wget and mksquashfs output, and turns on `set -x` tracing. Useful if something goes wrong and you want to see exactly what happened. |
| `CI=true` | Intended for running in a CI/CD pipeline (GitHub Actions sets this automatically). Implies `DEBUG=true`, skips all interactive prompts, auto-cleans up the temp directory, and exits with a non-zero code on failure so the pipeline knows the build failed. |

Example:
```bash
DEBUG=true ./build.sh
```

## Disclaimer

This script and binary are provided as-is, without any guarantees or warranty. Although it was created for personal use, it is being shared in good faith for others who may find it useful. The author is not responsible for any issues, errors, or damages that may arise from the use of this script. Users are advised to test and evaluate the script in their own environment and use it at their own risk.
