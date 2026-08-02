# SPDX-License-Identifier: MPL-2.0
# Owner: Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
# total-upgrade: Stub & Technical Debt Map

## 🛠 Stage-by-Stage Wiring Status

| Stage | Component | Status | Type | Notes |
| :--- | :--- | :--- | :--- | :--- |
| **Stage 2** | UI Navigation | ✅ DONE | Layout | Basic state-machine and screens exist. |
| **Stage 3** | System PM Updates | ✅ DONE | External Call | `Detector` now runs `which` and `--version`. |
| **Stage 4** | asdf/mise/opsm Logic | ✅ DONE | File I/O | `.tool-versions` parsing implemented. |
| **Stage 5** | Ecosystem Discovery | ✅ DONE | Logic | Runtime-to-PM mapping is live. |
| **Stage 6** | Association Search | ✅ DONE | Logic | File extension scan with `.v` disambiguation. |
| **Stage 7** | Cross-Platform | 🟡 PARTIAL | Logic | Icons exist, but platform-specific builds are pending. |

## 📍 Specific Code Stubs

| File/Line | Category | Description |
| :--- | :--- | :--- |
| `scanner.rs:32` | **Associations** | Certainty for `.v` drops to 0.5 if both Coq and V are installed. Needs project file check. |
| `main.rs:188` | **Feedback** | 'F' key placeholder for `feedback-o-tron` integration. |
| `manifest.rs:24` | **Manifests** | `mise.toml` (TOML) parsing is still a TODO. |

## ⚠️ Unresolved Questions
* **FIXME (Sync):** The "Transfer" screen is still descriptive text. Needs logic to write to `.tool-versions`.
* **FIXME (Feedback):** Integration with `feedback-o-tron` needs the `opsm` feedback protocol.
