// SPDX-License-Identifier: PMPL-1.0-or-later
//
// recon-wasm - WASM-accelerated document reconciliation
//
// This module provides:
// - Content hashing (SHA-256)
// - Content normalization
// - ReconForth interpreter for validation rules

#![forbid(unsafe_code)]
use sha2::{Digest, Sha256};
use wasm_bindgen::prelude::*;

pub mod reconforth;
pub mod security;

use reconforth::{Bundle, Document, VM};

// ============================================================================
// Original WASM functions
// ============================================================================

/// WASM-accelerated SHA-256 content hashing
/// Provides AOT-compiled performance for critical operations
#[wasm_bindgen]
pub fn hash_content(content: &str) -> String {
    let mut hasher = Sha256::new();
    hasher.update(content.as_bytes());
    let result = hasher.finalize();

    // Convert to hex string
    result.iter().map(|byte| format!("{:02x}", byte)).collect()
}

/// WASM-accelerated content normalization
/// Handles whitespace normalization faster than JS
#[wasm_bindgen]
pub fn normalize_content(content: &str) -> String {
    content
        .trim()
        .replace("\r\n", "\n")
        .lines()
        .map(|line| line.trim_end())
        .collect::<Vec<_>>()
        .join("\n")
        .split("\n\n\n")
        .collect::<Vec<_>>()
        .join("\n\n")
}

/// Batch hash multiple documents
/// Optimized for bulk operations
#[wasm_bindgen]
pub fn batch_hash(documents: &JsValue) -> Result<JsValue, JsValue> {
    // Parse JSON array of documents
    let docs: Vec<String> = serde_wasm_bindgen::from_value(documents.clone())?;

    let hashes: Vec<String> = docs.iter().map(|doc| hash_content(doc)).collect();

    serde_wasm_bindgen::to_value(&hashes).map_err(|e| JsValue::from_str(&e.to_string()))
}

// ============================================================================
// ReconForth WASM bindings
// ============================================================================

/// Evaluate a ReconForth program
///
/// # Arguments
/// * `program` - ReconForth source code
///
/// # Returns
/// * JSON-encoded result or error
#[wasm_bindgen]
pub fn reconforth_eval(program: &str) -> Result<JsValue, JsValue> {
    let mut vm = VM::new();

    vm.eval(program)
        .map_err(|e| JsValue::from_str(&format!("{}", e)))?;

    // Return validation results
    let validation = vm.get_validation();
    serde_wasm_bindgen::to_value(validation).map_err(|e| JsValue::from_str(&e.to_string()))
}

/// Evaluate a ReconForth program with a bundle
///
/// # Arguments
/// * `program` - ReconForth source code
/// * `bundle` - JSON-encoded bundle of documents
///
/// # Returns
/// * JSON-encoded validation result
#[wasm_bindgen]
pub fn reconforth_eval_bundle(program: &str, bundle: &JsValue) -> Result<JsValue, JsValue> {
    let mut vm = VM::new();

    // Parse bundle from JS
    let bundle: Bundle =
        serde_wasm_bindgen::from_value(bundle.clone()).map_err(|e| JsValue::from_str(&e.to_string()))?;

    // Load bundle into VM
    vm.load_bundle(bundle);

    // Execute program
    vm.eval(program)
        .map_err(|e| JsValue::from_str(&format!("{}", e)))?;

    // Return validation results
    let validation = vm.get_validation();
    serde_wasm_bindgen::to_value(validation).map_err(|e| JsValue::from_str(&e.to_string()))
}

/// Validate a bundle against a pack specification
///
/// # Arguments
/// * `bundle` - JSON-encoded bundle of documents
/// * `pack_spec` - ReconForth pack specification code
///
/// # Returns
/// * JSON-encoded validation result
#[wasm_bindgen]
pub fn validate_bundle(bundle: &JsValue, pack_spec: &str) -> Result<JsValue, JsValue> {
    let mut vm = VM::new();

    // Parse bundle from JS
    let bundle: Bundle =
        serde_wasm_bindgen::from_value(bundle.clone()).map_err(|e| JsValue::from_str(&e.to_string()))?;

    // Load bundle
    vm.load_bundle(bundle);

    // Execute pack spec (should define a pack and validate)
    vm.eval(pack_spec)
        .map_err(|e| JsValue::from_str(&format!("{}", e)))?;

    // Return validation results
    let validation = vm.get_validation();
    serde_wasm_bindgen::to_value(validation).map_err(|e| JsValue::from_str(&e.to_string()))
}

/// Create a document from content and metadata
///
/// # Arguments
/// * `content` - Document content
/// * `path` - File path
/// * `doc_type` - Document type (README, LICENSE, etc.)
///
/// # Returns
/// * JSON-encoded document
#[wasm_bindgen]
pub fn create_document(content: &str, path: &str, doc_type: &str) -> Result<JsValue, JsValue> {
    let hash = hash_content(content);

    let doc = Document {
        hash,
        content: content.to_string(),
        metadata: reconforth::DocumentMetadata {
            path: path.to_string(),
            document_type: doc_type.to_string(),
            last_modified: js_sys::Date::now(),
            version: None,
            canonical_source: "Inferred".to_string(),
            repository: String::new(),
            branch: String::new(),
        },
        created_at: js_sys::Date::now(),
    };

    serde_wasm_bindgen::to_value(&doc).map_err(|e| JsValue::from_str(&e.to_string()))
}

/// Create an empty bundle
#[wasm_bindgen]
pub fn create_bundle() -> Result<JsValue, JsValue> {
    let bundle = Bundle::new();
    serde_wasm_bindgen::to_value(&bundle).map_err(|e| JsValue::from_str(&e.to_string()))
}

/// Add a document to a bundle
///
/// # Arguments
/// * `bundle` - JSON-encoded bundle
/// * `doc` - JSON-encoded document
///
/// # Returns
/// * JSON-encoded updated bundle
#[wasm_bindgen]
pub fn bundle_add_document(bundle: &JsValue, doc: &JsValue) -> Result<JsValue, JsValue> {
    let mut bundle: Bundle =
        serde_wasm_bindgen::from_value(bundle.clone()).map_err(|e| JsValue::from_str(&e.to_string()))?;

    let doc: Document =
        serde_wasm_bindgen::from_value(doc.clone()).map_err(|e| JsValue::from_str(&e.to_string()))?;

    bundle.add(doc);

    serde_wasm_bindgen::to_value(&bundle).map_err(|e| JsValue::from_str(&e.to_string()))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_hash_content() {
        let content = "Hello, World!";
        let hash = hash_content(content);
        assert_eq!(hash.len(), 64); // SHA-256 = 64 hex chars
    }

    #[test]
    fn test_normalize_content() {
        let content = "  Hello  \r\n\r\n\r\nWorld  ";
        let normalized = normalize_content(content);
        assert_eq!(normalized, "Hello\n\nWorld");
    }

    #[test]
    fn test_reconforth_basic() {
        let mut vm = VM::new();
        vm.eval("5 3 +").unwrap();
    }

    #[test]
    fn test_reconforth_validation() {
        let mut vm = VM::new();
        vm.eval("\"Missing README\" error!").unwrap();
        assert!(!vm.get_validation().success);
        assert_eq!(vm.get_validation().errors.len(), 1);
    }
}
