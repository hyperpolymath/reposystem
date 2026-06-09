// SPDX-License-Identifier: MPL-2.0
// Owner: Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
use crate::backend::types::Association;
use std::process::Command;

pub struct Scanner;

impl Scanner {
    pub fn scan_associations() -> Vec<Association> {
        let mut associations = Vec::new();

        // 6B: Extension/application association discovery
        // Logic for .v (Coq vs V-lang)
        let has_coq = Command::new("which").arg("coqtop").output().is_ok_and(|o| o.status.success());
        let has_v = Command::new("which").arg("v").output().is_ok_and(|o| o.status.success());

        if has_coq || has_v {
            let (detected_type, certainty) = if has_coq && !has_v {
                ("Coq Proof Assistant".to_string(), 0.9)
            } else if has_v && !has_coq {
                ("V Programming Language".to_string(), 0.9)
            } else {
                // Both exist, certainty drops without project file check
                ("Ambiguous (.v)".to_string(), 0.5)
            };

            associations.push(Association {
                extension: ".v".to_string(),
                tools: vec!["coqtop".to_string(), "v".to_string()],
                detected_type,
                certainty,
            });
        }

        // Logic for .rs (Rust)
        let has_cargo = Command::new("which").arg("cargo").output().is_ok_and(|o| o.status.success());
        if has_cargo {
            associations.push(Association {
                extension: ".rs".to_string(),
                tools: vec!["cargo".to_string(), "rustc".to_string()],
                detected_type: "Rust Language".to_string(),
                certainty: 1.0,
            });
        }

        associations
    }
}
