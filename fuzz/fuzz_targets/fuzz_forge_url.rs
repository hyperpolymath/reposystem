// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell
//
//! Fuzz the Forge::from_url parser with arbitrary strings.

#![no_main]
use libfuzzer_sys::fuzz_target;
use reposystem::types::Forge;

fuzz_target!(|data: &[u8]| {
    if data.len() > 4096 {
        return;
    }

    if let Ok(url) = std::str::from_utf8(data) {
        let _ = Forge::from_url(url);
    }
});
