{
  description = "Plasticity 3D CAD — NixOS AppImage package";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; config.allowUnfree = true; };
    in {
      # Run directly without installing:
      #   nix run github:EntropyWorks/plasticityAppImage
      #
      # Install into your profile:
      #   nix profile install github:EntropyWorks/plasticityAppImage
      packages.${system} = {
        plasticity = pkgs.callPackage ./nix/plasticity.nix {};
        default = self.packages.${system}.plasticity;
      };

      # Use in your NixOS flake as an overlay:
      #   nixpkgs.overlays = [ inputs.plasticityAppImage.overlays.default ];
      overlays.default = _: prev: {
        plasticity = prev.callPackage ./nix/plasticity.nix {};
      };
    };
}
