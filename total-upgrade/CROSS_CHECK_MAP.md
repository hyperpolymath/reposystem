# SPDX-License-Identifier: MPL-2.0
# Owner: Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
# total-upgrade: Cross Check Map

| Feature | Requirement | Implementation Status | Evidence |
| :--- | :--- | :--- | :--- |
| **Detection** | Detect asdf, mise, opsm | ✅ **DONE** | `Detector` module. |
| **UI** | Show present/missing | ✅ **DONE** | `render_detection` with colors. |
| **Cross-Platform** | Indicators for Win/Mac/Linux/Minix/Mob | ✅ **DONE** | Unicode icons in headers/discovery. |
| **Categorization** | Tiered hierarchy (IDE vs Editor) | ✅ **DONE** | `ToolCategory` used in discovery. |
| **Management** | Attach/Detach/Transfer/Sync | ✅ **DONE (Structural)** | Interactive toggles (Space) for tools. |
| **Ecosystems** | hex, opam, deno, bun, etc. | ✅ **DONE** | Proactive scan for missing PMs. |
| **Associations** | .v (Coq) vs .v (V-lang) | ✅ **DONE** | `Scanner` with disambiguation logic. |
| **Feedback** | feedback-o-tron integration | 🔳 **STUBBED** | Footer hint 'F' added. |
