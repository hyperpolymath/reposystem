// SPDX-License-Identifier: PMPL-1.0-or-later
//
// ReconForth types - Core value and document types

use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use thiserror::Error;

/// ReconForth runtime errors
#[derive(Error, Debug, Clone, Serialize, Deserialize)]
pub enum Error {
    #[error("Stack underflow: {0}")]
    StackUnderflow(String),

    #[error("Type error: expected {expected}, got {got}")]
    TypeError { expected: String, got: String },

    #[error("Undefined word: {0}")]
    UndefinedWord(String),

    #[error("Parse error: {0}")]
    ParseError(String),

    #[error("Validation error: {0}")]
    ValidationError(String),

    #[error("Runtime error: {0}")]
    RuntimeError(String),
}

/// Document metadata
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DocumentMetadata {
    pub path: String,
    pub document_type: String,
    pub last_modified: f64,
    pub version: Option<String>,
    pub canonical_source: String,
    pub repository: String,
    pub branch: String,
}

/// A document in the reconciliation system
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Document {
    pub hash: String,
    pub content: String,
    pub metadata: DocumentMetadata,
    pub created_at: f64,
}

impl Document {
    /// Get document type as string
    pub fn doc_type(&self) -> &str {
        &self.metadata.document_type
    }

    /// Check if document is from a canonical source
    pub fn is_canonical(&self) -> bool {
        self.metadata.canonical_source != "Inferred"
    }
}

/// A bundle of documents
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct Bundle {
    pub documents: Vec<Document>,
}

impl Bundle {
    /// Create new empty bundle
    pub fn new() -> Self {
        Bundle { documents: Vec::new() }
    }

    /// Add document to bundle
    pub fn add(&mut self, doc: Document) {
        self.documents.push(doc);
    }

    /// Count documents
    pub fn count(&self) -> usize {
        self.documents.len()
    }

    /// Check if bundle has document type
    pub fn has_type(&self, doc_type: &str) -> bool {
        self.documents.iter().any(|d| d.doc_type() == doc_type)
    }

    /// Get document by type
    pub fn get_type(&self, doc_type: &str) -> Option<&Document> {
        self.documents.iter().find(|d| d.doc_type() == doc_type)
    }
}

/// Validation rule for pack specification
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Rule {
    pub name: String,
    pub body: Vec<Token>,
}

/// Pack specification for document bundles
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PackSpec {
    pub name: String,
    pub required: Vec<String>,
    pub optional: Vec<String>,
    pub rules: Vec<Rule>,
}

impl PackSpec {
    /// Create new pack specification
    pub fn new(name: String) -> Self {
        PackSpec {
            name,
            required: Vec::new(),
            optional: Vec::new(),
            rules: Vec::new(),
        }
    }

    /// Add required document type
    pub fn require(&mut self, doc_type: String) {
        self.required.push(doc_type);
    }

    /// Add optional document type
    pub fn optional(&mut self, doc_type: String) {
        self.optional.push(doc_type);
    }

    /// Add validation rule
    pub fn add_rule(&mut self, name: String, body: Vec<Token>) {
        self.rules.push(Rule { name, body });
    }
}

/// Validation result from pack shipping
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ValidationResult {
    pub success: bool,
    pub errors: Vec<ValidationMessage>,
    pub warnings: Vec<ValidationMessage>,
    pub suggestions: Vec<ValidationMessage>,
}

impl Default for ValidationResult {
    fn default() -> Self {
        ValidationResult {
            success: true,
            errors: Vec::new(),
            warnings: Vec::new(),
            suggestions: Vec::new(),
        }
    }
}

/// A validation message (error, warning, or suggestion)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ValidationMessage {
    pub message: String,
    pub path: Option<String>,
    pub rule: Option<String>,
}

impl ValidationMessage {
    pub fn new(message: String) -> Self {
        ValidationMessage {
            message,
            path: None,
            rule: None,
        }
    }

    pub fn with_path(mut self, path: String) -> Self {
        self.path = Some(path);
        self
    }

    pub fn with_rule(mut self, rule: String) -> Self {
        self.rule = Some(rule);
        self
    }
}

/// ReconForth token types
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum Token {
    /// Word (identifier)
    Word(String),
    /// Integer literal
    Int(i64),
    /// Float literal
    Float(f64),
    /// String literal
    Str(String),
    /// Start of quotation
    QuoteStart,
    /// End of quotation
    QuoteEnd,
    /// Start of definition
    DefStart,
    /// End of definition
    DefEnd,
    /// Stack effect comment start
    StackEffectStart,
    /// Stack effect comment end
    StackEffectEnd,
    /// Comment
    Comment(String),
}

/// ReconForth values on the stack
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum Value {
    /// Integer
    Int(i64),
    /// Float
    Float(f64),
    /// Boolean
    Bool(bool),
    /// String
    Str(String),
    /// Content hash
    Hash(String),
    /// Document reference
    Doc(Document),
    /// Document bundle
    Bundle(Bundle),
    /// Pack specification
    Pack(PackSpec),
    /// List of values
    List(Vec<Value>),
    /// Quotation (code block)
    Quotation(Vec<Token>),
    /// Nil/None value
    Nil,
    /// Validation result
    ValidationResult(ValidationResult),
    /// Document format
    Format(String),
    /// Parsed document structure
    Structure(Box<super::formats::DocumentStructure>),
}

impl Value {
    /// Get type name as string
    pub fn type_name(&self) -> &'static str {
        match self {
            Value::Int(_) => "Int",
            Value::Float(_) => "Float",
            Value::Bool(_) => "Bool",
            Value::Str(_) => "Str",
            Value::Hash(_) => "Hash",
            Value::Doc(_) => "Doc",
            Value::Bundle(_) => "Bundle",
            Value::Pack(_) => "Pack",
            Value::List(_) => "List",
            Value::Quotation(_) => "Quotation",
            Value::Nil => "Nil",
            Value::ValidationResult(_) => "ValidationResult",
            Value::Format(_) => "Format",
            Value::Structure(_) => "Structure",
        }
    }

    /// Try to convert to bool
    pub fn as_bool(&self) -> Option<bool> {
        match self {
            Value::Bool(b) => Some(*b),
            Value::Int(i) => Some(*i != 0),
            Value::Nil => Some(false),
            _ => None,
        }
    }

    /// Try to convert to int
    pub fn as_int(&self) -> Option<i64> {
        match self {
            Value::Int(i) => Some(*i),
            Value::Float(f) => Some(*f as i64),
            Value::Bool(b) => Some(if *b { 1 } else { 0 }),
            _ => None,
        }
    }

    /// Try to convert to string
    pub fn as_str(&self) -> Option<&str> {
        match self {
            Value::Str(s) => Some(s),
            Value::Hash(s) => Some(s),
            _ => None,
        }
    }

    /// Try to get as document
    pub fn as_doc(&self) -> Option<&Document> {
        match self {
            Value::Doc(d) => Some(d),
            _ => None,
        }
    }

    /// Try to get as bundle
    pub fn as_bundle(&self) -> Option<&Bundle> {
        match self {
            Value::Bundle(b) => Some(b),
            _ => None,
        }
    }

    /// Try to get as mutable bundle
    pub fn as_bundle_mut(&mut self) -> Option<&mut Bundle> {
        match self {
            Value::Bundle(b) => Some(b),
            _ => None,
        }
    }

    /// Try to get as pack
    pub fn as_pack(&self) -> Option<&PackSpec> {
        match self {
            Value::Pack(p) => Some(p),
            _ => None,
        }
    }

    /// Try to get as mutable pack
    pub fn as_pack_mut(&mut self) -> Option<&mut PackSpec> {
        match self {
            Value::Pack(p) => Some(p),
            _ => None,
        }
    }

    /// Try to get as list
    pub fn as_list(&self) -> Option<&Vec<Value>> {
        match self {
            Value::List(l) => Some(l),
            _ => None,
        }
    }

    /// Try to get as quotation
    pub fn as_quotation(&self) -> Option<&Vec<Token>> {
        match self {
            Value::Quotation(q) => Some(q),
            _ => None,
        }
    }
}

/// Word definition in the dictionary
#[derive(Debug, Clone)]
pub enum WordDef {
    /// Built-in native word
    Native(fn(&mut crate::reconforth::vm::VM) -> Result<(), Error>),
    /// User-defined word (sequence of tokens)
    User(Vec<Token>),
}

/// The word dictionary
pub type Dictionary = HashMap<String, WordDef>;
