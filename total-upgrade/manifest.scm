;;; SPDX-License-Identifier: MPL-2.0
;;; Owner: Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
;;; manifest.scm — Guix manifest for total-upgrade
;;;

(specifications->manifest
  '(;; Core development tools
    "git"
    "just"
    "curl"
    "bash"
    "coreutils"

    ;; Rust Toolchain
    "rust"
    "cargo"
    "rust-analyzer"

    ;; Dependencies for the binary
    "openssl"
    "zlib"
    "pkg-config"
    
    ;; TUI support
    "ncurses"))
