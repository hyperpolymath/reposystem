// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell
//
//! Fuzz JSON deserialization of all core store types.
//! Ensures malformed JSON never causes panics or UB.

#![no_main]
use libfuzzer_sys::fuzz_target;
use reposystem::types::{AspectStore, AuditStore, GraphStore, PlanStore, SlotStore};

fuzz_target!(|data: &[u8]| {
    if data.len() > 256_000 {
        return;
    }

    // Fuzz all five JSON store types — any parse failure is fine,
    // but panics or memory corruption are bugs.
    let _ = serde_json::from_slice::<GraphStore>(data);
    let _ = serde_json::from_slice::<AspectStore>(data);
    let _ = serde_json::from_slice::<SlotStore>(data);
    let _ = serde_json::from_slice::<PlanStore>(data);
    let _ = serde_json::from_slice::<AuditStore>(data);
});
