{
  appimageTools,
  fetchurl,
  makeDesktopItem,
  lib,
}:
let
  pname = "plasticity";
  version = "26.1.3";

  src = fetchurl {
    url = "https://github.com/EntropyWorks/plasticityAppImage/releases/download/v${version}/Plasticity-${version}-x86_64.AppImage";
    hash = "sha256-SQmGrUkBmAq9RZeje7+MwVC2R6wpOd5R9CvOqtpR9io=";
  };

  desktopItem = makeDesktopItem {
    name = "plasticity";
    desktopName = "Plasticity";
    genericName = "3D CAD Modeler";
    comment = "Professional 3D CAD software for artists";
    exec = "plasticity %U";
    icon = "plasticity";
    terminal = false;
    mimeTypes = [ "model/step" "model/stl" ];
    categories = [ "Graphics" "3DGraphics" ];
    keywords = [ "CAD" "3D" "Modeling" ];
  };

in
appimageTools.wrapType2 {
  inherit pname version src;

  extraInstallCommands = ''
    install -Dm444 -t $out/share/applications ${desktopItem}/share/applications/*
  '';

  meta = {
    description = "Professional 3D CAD software for artists";
    homepage = "https://www.plasticity.xyz/";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "plasticity";
  };
}
