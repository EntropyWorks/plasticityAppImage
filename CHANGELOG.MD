## Changelog

### Latest

- The script now automatically fetches the latest Plasticity release from GitHub so there is no need to manually update the version in the script.
- Same for the AppImageKit runtime — it picks up the latest release automatically.
- The output AppImage filename now includes the version number (e.g. `Plasticity-26.1.3-x86_64.AppImage`).
- Added a `DEBUG=true` flag for verbose output when something goes wrong.
- Added a `CI=true` flag so the script can run unattended in a CI/CD pipeline.
- The temp directory cleanup is now handled automatically on exit — whether the build succeeds, fails, or is cancelled with Ctrl+C.
- Added a spinner on long-running steps (downloading, checking for updates, building the squashfs) so it is clearer that something is happening rather than the script just sitting there silently.
- Downloads are skipped if the local file already matches the remote — handy when iterating and re-running the script.
- Improved error messages — if something fails the script reports which command failed and the exit code.
- Added `wget` and `squashfs-tools` to the apt install list so the script is self-contained and does not rely on them being pre-installed.
- The custom icon is now also written as `.DirIcon` inside the AppDir, which is what desktop environments use to show the app icon on the AppImage file itself.
