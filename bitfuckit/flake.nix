# SPDX-License-Identifier: PMPL-1.0
# Nix flake for bitfuckit
# Usage:
#   nix build
#   nix run
#   nix develop
{
  description = "bitfuckit - The Bitbucket CLI Atlassian never made";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        version = "0.2.0";
      in
      {
        packages = {
          default = pkgs.stdenv.mkDerivation {
            pname = "bitfuckit";
            inherit version;

            src = ./.;

            nativeBuildInputs = with pkgs; [
              gnat
              gprbuild
            ];

            buildInputs = with pkgs; [
              curl
            ];

            buildPhase = ''
              gprbuild -P bitfuckit.gpr -j$NIX_BUILD_CORES
            '';

            installPhase = ''
              mkdir -p $out/bin
              mkdir -p $out/share/man/man1
              mkdir -p $out/share/bash-completion/completions
              mkdir -p $out/share/zsh/site-functions
              mkdir -p $out/share/fish/vendor_completions.d

              cp bin/bitfuckit $out/bin/

              # Completions (if exist)
              [ -f completions/bitfuckit.bash ] && cp completions/bitfuckit.bash $out/share/bash-completion/completions/bitfuckit
              [ -f completions/bitfuckit.zsh ] && cp completions/bitfuckit.zsh $out/share/zsh/site-functions/_bitfuckit
              [ -f completions/bitfuckit.fish ] && cp completions/bitfuckit.fish $out/share/fish/vendor_completions.d/bitfuckit.fish

              # Man page (if exists)
              [ -f doc/bitfuckit.1 ] && cp doc/bitfuckit.1 $out/share/man/man1/
            '';

            meta = with pkgs.lib; {
              description = "Community-built Bitbucket CLI that Atlassian never made";
              longDescription = ''
                bitfuckit is a command-line interface for Bitbucket Cloud, written in
                Ada/SPARK for reliability. Features include authentication, repository
                management, pull request workflows, GitHub mirroring, fault tolerance,
                network awareness, and security scanning.
              '';
              homepage = "https://github.com/hyperpolymath/bitfuckit";
              license = licenses.agpl3Plus;
              maintainers = [ ];
              platforms = platforms.linux ++ platforms.darwin;
              mainProgram = "bitfuckit";
            };
          };
        };

        # Development shell
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            gnat
            gprbuild
            curl
            clamav
            syncthing
            # Development tools
            git
            lazygit
          ];

          shellHook = ''
            echo "bitfuckit development shell"
            echo "Build: gprbuild -P bitfuckit.gpr"
            echo "Run: ./bin/bitfuckit --help"
          '';
        };

        # Run directly
        apps.default = flake-utils.lib.mkApp {
          drv = self.packages.${system}.default;
        };
      }
    );
}
