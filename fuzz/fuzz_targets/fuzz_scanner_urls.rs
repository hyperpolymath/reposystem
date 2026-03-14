// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell
//! Fuzz target for the scanner's URL parsing functions.
//!
//! Exercises `parse_owner_name`, `extract_from_path`, and `Forge::from_url`
//! with arbitrary byte sequences converted to UTF-8 strings.

#![no_main]

use libfuzzer_sys::fuzz_target;
use reposystem::scanner::{extract_from_path, parse_owner_name};
use reposystem::types::Forge;

fuzz_target!(|data: &[u8]| {
    // Convert arbitrary bytes to a UTF-8 string (lossy — replaces invalid
    // sequences with U+FFFD so we never panic on encoding).
    let input = String::from_utf8_lossy(data);

    // Exercise forge detection from URL string
    let _ = Forge::from_url(&input);

    // Exercise owner/name parsing from full URL
    let _ = parse_owner_name(&input);

    // Exercise path-only extraction (the inner helper)
    let _ = extract_from_path(&input);
});
