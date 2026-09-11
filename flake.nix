{
  description = "SG2000 / CV181x secure-boot disclosure site";

  # Based on the Zola flake output of github:NixVegas/nix.vegas (flake-parts +
  # a `zola build` derivation), with all of the Nix Vegas theming stripped: no
  # overlay, no onsite/kiosk variant, no onboarding-artifact plumbing -- just the
  # static-site build. `nix build` -> $out/public.
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      perSystem =
        { pkgs, ... }:
        {
          packages.default = pkgs.stdenv.mkDerivation {
            name = "sg2000-disclosure-site";
            src = ./.;
            nativeBuildInputs = [ pkgs.zola ];
            buildPhase = ''
              runHook preBuild
              zola build --output-dir public
              runHook postBuild
            '';
            installPhase = ''
              runHook preInstall
              mkdir -p $out
              mv public $out/
              runHook postInstall
            '';
          };

          devShells.default = pkgs.mkShell {
            packages = with pkgs; [
              zola
              nixfmt-rfc-style
            ];
          };
        };
    };
}
