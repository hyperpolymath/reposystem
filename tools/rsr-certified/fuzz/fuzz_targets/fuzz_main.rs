#![no_main]
use libfuzzer_sys::fuzz_target;

fuzz_target!(|data: &[u8]| {
    // Fuzz string processing functions
    if let Ok(input) = std::str::from_utf8(data) {
        if input.is_empty() || input.len() > 10000 {
            return;
        }

        // Test various string operations
        let _lower = input.to_lowercase();
        let _upper = input.to_uppercase();
        let _trimmed = input.trim();
        let _lines: Vec<&str> = input.lines().collect();
        let _words: Vec<&str> = input.split_whitespace().collect();
    }
});
