# SPDX-License-Identifier: MPL-2.0
# Owner: Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
# total-upgrade: Release Checklist

## ✅ Verification
- [ ] `cargo test` passes on WSL/Linux.
- [ ] `cargo build --release` produces a functional binary.
- [ ] TUI navigates all screens without crashing.
- [ ] Manifest parsing handles empty or missing `.tool-versions`.

## 📦 Packaging
- [ ] Sync `Cargo.toml` version with `README.adoc`.
- [ ] Ensure `MPL-2.0` license headers are in all files.
- [ ] Build for Windows (`x86_64-pc-windows-msvc`).
- [ ] Build for Termux/Android (if toolchain available).

## 🚀 Future Integration
- [ ] Implement `mise.toml` parsing (TOML).
- [ ] Connect 'F' key to real `feedback-o-tron` API/CLI.
- [ ] Wire 'Transfer' button to write back to manifests.
