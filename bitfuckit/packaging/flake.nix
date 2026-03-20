# SPDX-License-Identifier: PMPL-1.0
{
  description = "Bitbucket CLI tool written in Ada";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        packages.default = pkgs.stdenv.mkDerivation {
          pname = "bitfuckit";
          version = "0.1.0";

          src = ./.;

          nativeBuildInputs = with pkgs; [
            gnat
            gprbuild
          ];

          buildInputs = with pkgs; [
            curl
          ];

          buildPhase = ''
            gprbuild -P bitfuckit.gpr -XBUILD_MODE=release
          '';

          installPhase = ''
            mkdir -p $out/bin
            cp bin/bitfuckit $out/bin/

            mkdir -p $out/share/man/man1
            cp doc/bitfuckit.1 $out/share/man/man1/

            mkdir -p $out/share/bash-completion/completions
            cp completions/bitfuckit.bash $out/share/bash-completion/completions/bitfuckit

            mkdir -p $out/share/zsh/site-functions
            cp completions/bitfuckit.zsh $out/share/zsh/site-functions/_bitfuckit

            mkdir -p $out/share/fish/vendor_completions.d
            cp completions/bitfuckit.fish $out/share/fish/vendor_completions.d/bitfuckit.fish
          '';

          meta = with pkgs.lib; {
            description = "Bitbucket CLI tool written in Ada";
            homepage = "https://github.com/hyperpolymath/bitfuckit";
            license = licenses.agpl3Plus;
            maintainers = [];
            platforms = platforms.linux;
          };
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            gnat
            gprbuild
            curl
          ];
        };
      }
    );
}
