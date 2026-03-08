# SPDX-License-Identifier: MIT OR AGPL-3.0-or-later WITH Palimpsest-0.8
# SPDX-FileCopyrightText: 2025 hyperpolymath
{
  description = "Gitvisor - Repository intelligence platform";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        # Elixir/Erlang versions
        elixir = pkgs.elixir_1_16;
        erlang = pkgs.erlang_26;

        # Ada toolchain
        gnat = pkgs.gnat13;

        # Development tools
        devTools = with pkgs; [
          # Elixir/Erlang
          elixir
          erlang
          elixir-ls
          hex

          # Frontend
          deno
          nodejs_20

          # Ada
          gnat
          gprbuild

          # General
          just
          jq
          git
        ];

      in {
        # Development shell
        devShells.default = pkgs.mkShell {
          buildInputs = devTools;

          shellHook = ''
            export MIX_HOME=$PWD/.mix
            export HEX_HOME=$PWD/.hex
            export ERL_AFLAGS="-kernel shell_history enabled"

            # Ensure hex and rebar are installed
            mix local.hex --force --if-missing
            mix local.rebar --force --if-missing

            echo "Gitvisor development environment"
            echo ""
            echo "Components:"
            echo "  backend/   - Elixir Phoenix (mix phx.server)"
            echo "  frontend/  - ReScript (deno task build)"
            echo "  tui/       - Ada terminal UI (gprbuild)"
            echo ""
            echo "Commands:"
            echo "  cd backend && mix deps.get && mix phx.server"
            echo "  cd frontend && npm install && npx rescript build"
            echo "  cd tui && gprbuild -P gitvisor_tui.gpr"
          '';

          # For Ada/GNAT
          LIBRARY_PATH = "${pkgs.glibc}/lib";
        };

        # Backend-only dev shell
        devShells.backend = pkgs.mkShell {
          buildInputs = with pkgs; [ elixir erlang elixir-ls hex postgresql ];

          shellHook = ''
            export MIX_HOME=$PWD/.mix
            export HEX_HOME=$PWD/.hex
            mix local.hex --force --if-missing
            mix local.rebar --force --if-missing
            echo "Backend development (Elixir/Phoenix)"
          '';
        };

        # Frontend-only dev shell
        devShells.frontend = pkgs.mkShell {
          buildInputs = with pkgs; [ deno nodejs_20 ];

          shellHook = ''
            export DENO_DIR=$PWD/.deno
            echo "Frontend development (ReScript/Deno)"
          '';
        };

        # TUI-only dev shell
        devShells.tui = pkgs.mkShell {
          buildInputs = with pkgs; [ gnat gprbuild ];

          shellHook = ''
            echo "TUI development (Ada)"
          '';
        };

        # Backend package (Elixir release)
        packages.backend = pkgs.beamPackages.mixRelease {
          pname = "gitvisor";
          version = "0.1.0";

          src = ./backend;

          mixNixDeps = import ./backend/mix.nix { inherit pkgs; };

          meta = with pkgs.lib; {
            description = "Gitvisor backend (Phoenix)";
            license = licenses.mit;
          };
        };

        # TUI package (Ada binary)
        packages.tui = pkgs.stdenv.mkDerivation {
          pname = "gitvisor-tui";
          version = "0.1.0";

          src = ./tui;

          nativeBuildInputs = [ pkgs.gnat pkgs.gprbuild ];

          buildPhase = ''
            gprbuild -P gitvisor_tui.gpr -XMODE=release
          '';

          installPhase = ''
            mkdir -p $out/bin
            cp bin/gitvisor_tui $out/bin/
          '';

          meta = with pkgs.lib; {
            description = "Gitvisor terminal UI (Ada)";
            license = licenses.mit;
            mainProgram = "gitvisor_tui";
          };
        };

        # Container image
        packages.container = pkgs.dockerTools.buildLayeredImage {
          name = "gitvisor";
          tag = "latest";

          contents = [
            self.packages.${system}.backend
            self.packages.${system}.tui
            pkgs.cacert
          ];

          config = {
            Cmd = [ "/bin/gitvisor" "start" ];
            Env = [
              "MIX_ENV=prod"
              "PHX_HOST=localhost"
            ];
            ExposedPorts = {
              "4000/tcp" = {};
            };
          };
        };
      }
    );
}
