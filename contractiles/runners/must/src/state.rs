// src/state.rs
use sha2::{Sha512, Digest};
use std::path::Path;
use std::fs;

#[derive(Debug, serde::Deserialize)]
pub struct FileRule {
    pub path: String,
    pub hash: Option<String>,  // SHA-512 or SHAKE256
    pub contains: Option<Vec<String>>,
}

#[derive(Debug, serde::Deserialize)]
pub struct MustFile {
    pub must_have: Vec<FileRule>,
    pub must_not_have: Vec<String>,
    pub tasks: std::collections::HashMap<String, Task>,
}

#[derive(Debug, serde::Deserialize)]
pub struct Task {
    pub steps: Vec<String>,
    pub must_have: Vec<FileRule>,
}

pub fn validate_state(mustfile: &MustFile) -> Result<(), String> {
    // Check must_have
    for rule in &mustfile.must_have {
        let path = Path::new(&rule.path);
        if !path.exists() {
            return Err(format!("❌ Missing required file: {}", rule.path));
        }
        if let Some(hash) = &rule.hash {
            let actual_hash = compute_hash(&rule.path)?;
            if actual_hash != hash {
                return Err(format!("❌ Hash mismatch for {} (expected {}, got {})", rule.path, hash, actual_hash));
            }
        }
        if let Some(strings) = &rule.contains {
            let content = fs::read_to_string(&rule.path).map_err(|e| e.to_string())?;
            for s in strings {
                if !content.contains(s) {
                    return Err(format!("❌ File {} missing required string: {}", rule.path, s));
                }
            }
        }
    }

    // Check must_not_have
    for path in &mustfile.must_not_have {
        if Path::new(path).exists() {
            return Err(format!("❌ Forbidden file present: {}", path));
        }
    }

    Ok(())
}

pub fn compute_hash(path: &str) -> Result<String, String> {
    let mut file = fs::File::open(path).map_err(|e| e.to_string())?;
    let mut hasher = Sha512::new();
    std::io::copy(&mut file, &mut hasher).map_err(|e| e.to_string())?;
    Ok(format!("{:x}", hasher.finalize()))
}
