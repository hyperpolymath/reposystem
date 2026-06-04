// SPDX-License-Identifier: MPL-2.0
// Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
// src/rollback.rs
use std::fs;

pub fn rollback(task_name: &str, mustfile: &MustFile) -> Result<(), String> {
    if let Some(task) = mustfile.tasks.get(task_name) {
        for rule in &task.must_have {
            let _ = fs::remove_file(&rule.path);  // Simple rollback
        }
    }
    Ok(())
}
