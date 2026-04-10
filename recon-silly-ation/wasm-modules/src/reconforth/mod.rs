// SPDX-License-Identifier: PMPL-1.0-or-later
//
// ReconForth - Stack-based DSL for document reconciliation
// This module provides the interpreter and VM for ReconForth programs.

mod lexer;
mod types;
mod vm;
mod builtins;
pub mod formats;

pub use lexer::Lexer;
pub use types::{Value, Error, Document, DocumentMetadata, Bundle, PackSpec, Rule, Token, ValidationResult};
pub use vm::VM;
pub use builtins::register_builtins;
pub use formats::{Format, DocumentStructure, Element, detect_format, parse_content};
