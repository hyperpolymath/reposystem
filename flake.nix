# SPDX-License-Identifier: AGPL-3.0-or-later
# SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
#
# flake.nix - Nix flake for reproducible builds
#
# Build: nix build
# Shell: nix develop
# Run:   nix run
{
  description = "Railway yard for your repository ecosystem";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
    flake-utils.url = "github:numtide/flake-utils";
    crane = {
      url = "github:ipetkov/crane";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, rust-overlay, flake-utils, crane }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs { inherit system overlays; };

        rustToolchain = pkgs.rust-bin.stable.latest.default.override {
          extensions = [ "rust-src" "rust-analyzer" ];
        };

        craneLib = (crane.mkLib pkgs).overrideToolchain rustToolchain;

        # Common arguments for crane builds
        commonArgs = {
          src = craneLib.cleanCargoSource (craneLib.path ./.);
          strictDeps = true;

          buildInputs = with pkgs; [
            openssl
          ] ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [
            pkgs.libiconv
            pkgs.darwin.apple_sdk.frameworks.Security
          ];

          nativeBuildInputs = with pkgs; [
            pkg-config
          ];
        };

        # Build dependencies separately for caching
        cargoArtifacts = craneLib.buildDepsOnly commonArgs;

        # Build the actual package
        reposystem = craneLib.buildPackage (commonArgs // {
          inherit cargoArtifacts;

          postInstall = ''
            mkdir -p $out/share/man/man1
            cp doc/reposystem.1 $out/share/man/man1/ 2>/dev/null || true

            mkdir -p $out/share/bash-completion/completions
            $out/bin/reposystem completions bash > $out/share/bash-completion/completions/reposystem 2>/dev/null || true

            mkdir -p $out/share/zsh/site-functions
            $out/bin/reposystem completions zsh > $out/share/zsh/site-functions/_reposystem 2>/dev/null || true

            mkdir -p $out/share/fish/vendor_completions.d
            $out/bin/reposystem completions fish > $out/share/fish/vendor_completions.d/reposystem.fish 2>/dev/null || true
          '';
        });

      in {
        checks = {
          inherit reposystem;

          clippy = craneLib.cargoClippy (commonArgs // {
            inherit cargoArtifacts;
            cargoClippyExtraArgs = "--all-targets -- --deny warnings";
          });

          fmt = craneLib.cargoFmt { src = ./.; };

          audit = craneLib.cargoAudit {
            inherit (commonArgs) src;
            advisory-db = pkgs.fetchFromGitHub {
              owner = "rustsec";
              repo = "advisory-db";
              rev = "main";
              sha256 = pkgs.lib.fakeSha256;
            };
          };
        };

        packages = {
          default = reposystem;
          reposystem = reposystem;
        };

        apps.default = flake-utils.lib.mkApp {
          drv = reposystem;
        };

        devShells.default = craneLib.devShell {
          checks = self.checks.${system};

          packages = with pkgs; [
            # Rust tooling
            rustToolchain
            cargo-watch
            cargo-audit
            cargo-outdated
            cargo-tarpaulin

            # Build tools
            just

            # Documentation
            asciidoctor
            graphviz

            # Ada/SPARK (for TUI)
            gnat
            gprbuild

            # Scheme
            guile

            # Deno for ReScript
            deno

            # Git tooling
            git
            git-lfs

            # Container tools
            dive
          ];

          RUST_SRC_PATH = "${rustToolchain}/lib/rustlib/src/rust/library";
        };
      }
    ) // {
      # Overlays for use in other flakes
      overlays.default = final: prev: {
        reposystem = self.packages.${prev.system}.reposystem;
      };
    };
}
