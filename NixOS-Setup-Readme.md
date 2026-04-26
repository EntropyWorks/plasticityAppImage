## Running Plasticity on NixOS

Since Plasticity only ships a `.deb`, this repo also provides a Nix flake so you can install it properly on NixOS without any manual AppImage wrangling.

The package uses `appimageTools.wrapType2` which unpacks the AppImage and wraps it into a proper Nix derivation — no binfmt or FUSE tricks needed just to run Plasticity.

---

### Quickest way — run without installing

```bash
nix run github:EntropyWorks/plasticityAppImage
```

---

### Adding to your NixOS flake

**1. Add this repo as a flake input:**

```nix
inputs = {
  plasticityAppImage = {
    url = "github:EntropyWorks/plasticityAppImage";
    inputs.nixpkgs.follows = "nixpkgs";
  };
};
```

**2. Apply the overlay in your nixpkgs config:**

```nix
nixpkgs.overlays = [ inputs.plasticityAppImage.overlays.default ];
```

**3. Add `plasticity` to your `environment.systemPackages`:**

```nix
environment.systemPackages = with pkgs; [
  plasticity
];
```

---

### AppImage support for everything else (optional)

The Nix package above handles Plasticity without needing any of this. But if you want your system to run arbitrary `.AppImage` files — double-clicking one in a file manager, downloading one from a vendor, etc. — you need two things: the FUSE kernel module and a binfmt registration.

**Add to your NixOS configuration:**

```nix
{ pkgs, ... }:
let
  # Customised appimage-run with the extra libs that most Electron/Qt AppImages need.
  # Without these, apps that bundle their own Chromium or Qt will fail to start.
  appimage-run-with-pkgs = pkgs.appimage-run.override {
    extraPkgs = pkgs: with pkgs; [
      libxshmfence
      libGL
      xorg.libxcb
      xorg.libX11
      xorg.libXext
      xorg.libXi
      xorg.libXrender
      xorg.libXrandr
      xorg.libXcursor
      xorg.libXfixes
      xorg.libXScrnSaver
      xorg.libXtst
      xorg.libXcomposite
      xorg.libXdamage
      xorg.xcbutilkeysyms
      xorg.xcbutilimage
      xorg.xcbutilrenderutil
      xorg.xcbutilwm
      nss
      nspr
      alsa-lib
      cups
      dbus
      expat
      libdrm
      mesa
      pango
      cairo
      glib
      gtk3
      at-spi2-atk
      at-spi2-core
    ];
  };
in
{
  # FUSE is required for AppImages to mount their internal filesystem
  boot.kernelModules = [ "fuse" ];

  # Register the AppImage magic bytes with binfmt so the kernel hands off
  # any AppImage directly to appimage-run, making them executable like native binaries.
  boot.binfmt.registrations.appimage = {
    wrapInterpreterInShell = false;
    interpreter = "${appimage-run-with-pkgs}/bin/appimage-run";
    recognitionType = "magic";
    offset = 0;
    mask = ''\xff\xff\xff\xff\x00\x00\x00\x00\xff\xff\xff'';
    magicOrExtension = ''\x7fELF....AI\x02'';
  };

  # Make appimage-run available on the command line too
  environment.systemPackages = [ appimage-run-with-pkgs ];
}
```

The `extraPkgs` list covers what most Electron and Qt-based AppImages need at runtime. Without it, apps that bundle their own Chromium (like Plasticity) will often crash silently or fail with missing library errors.
