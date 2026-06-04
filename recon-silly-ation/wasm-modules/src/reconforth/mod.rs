// SPDX-License-Identifier: MPL-2.0
// Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
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
