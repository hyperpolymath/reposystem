// SPDX-License-Identifier: PMPL-1.0-or-later
//
// Backup Manager
// Tracks and manages backups for rollback support

module rollback

import os
import time
import json

// BackupEntry represents a single backed up file
struct BackupEntry {
pub mut:
	original_path string
	backup_path   string
	timestamp     i64
	checksum      string
}

// OperationBackup tracks all backups for an operation
pub struct OperationBackup {
pub mut:
	operation_id   string
	operation_type string
	timestamp      i64
	repos          []string
	entries        []BackupEntry
	metadata       map[string]string
}

// BackupManager handles backup creation and restoration
pub struct BackupManager {
pub mut:
	backup_dir string
	log_file   string
}

// Creates new backup manager
pub fn new_backup_manager() BackupManager {
	home := os.home_dir()
	backup_dir := os.join_path(home, '.local', 'share', 'repo-batcher', 'backups')
	log_file := os.join_path(home, '.local', 'share', 'repo-batcher', 'backup-log.json')

	// Create backup directory if needed
	os.mkdir_all(backup_dir) or {}

	return BackupManager{
		backup_dir: backup_dir
		log_file: log_file
	}
}

// Starts new operation backup
pub fn (mut mgr BackupManager) start_operation(op_type string, repos []string) OperationBackup {
	timestamp := time.now().unix
	op_id := '${op_type}-${timestamp}'

	return OperationBackup{
		operation_id: op_id
		operation_type: op_type
		timestamp: timestamp
		repos: repos
		entries: []BackupEntry{}
		metadata: map[string]string{}
	}
}

// Backs up a file before modification
pub fn (mut mgr BackupManager) backup_file(mut op_backup OperationBackup, file_path string) !string {
	// Check file exists
	if !os.exists(file_path) {
		return error('File does not exist: ${file_path}')
	}

	// Create backup path
	timestamp := time.now().unix
	file_name := os.file_name(file_path)
	backup_name := '${file_name}.${timestamp}.backup'
	backup_path := os.join_path(mgr.backup_dir, op_backup.operation_id, backup_name)

	// Ensure backup directory exists
	backup_subdir := os.join_path(mgr.backup_dir, op_backup.operation_id)
	os.mkdir_all(backup_subdir) or {
		return error('Failed to create backup directory: ${err}')
	}

	// Copy file to backup location
	os.cp(file_path, backup_path) or {
		return error('Failed to backup file: ${err}')
	}

	// Calculate checksum
	content := os.read_file(backup_path) or { '' }
	checksum := calculate_checksum(content)

	// Record backup entry
	entry := BackupEntry{
		original_path: file_path
		backup_path: backup_path
		timestamp: timestamp
		checksum: checksum
	}

	op_backup.entries << entry

	return backup_path
}

// Completes operation backup and saves log
pub fn (mut mgr BackupManager) complete_operation(op_backup OperationBackup) ! {
	// Save operation backup to log
	mgr.append_to_log(op_backup) or {
		return error('Failed to save backup log: ${err}')
	}
}

// Appends operation to backup log
fn (mut mgr BackupManager) append_to_log(op_backup OperationBackup) ! {
	// Read existing log
	mut operations := []OperationBackup{}
	if os.exists(mgr.log_file) {
		content := os.read_file(mgr.log_file) or { '[]' }
		operations = json.decode([]OperationBackup, content) or { []OperationBackup{} }
	}

	// Append new operation
	operations << op_backup

	// Write back
	json_data := json.encode(operations)
	os.write_file(mgr.log_file, json_data) or {
		return error('Failed to write log: ${err}')
	}
}

// Lists recent operations
pub fn (mgr BackupManager) list_operations(limit int) []OperationBackup {
	if !os.exists(mgr.log_file) {
		return []OperationBackup{}
	}

	content := os.read_file(mgr.log_file) or { return []OperationBackup{} }
	operations := json.decode([]OperationBackup, content) or { return []OperationBackup{} }

	// Return last N operations
	start := if operations.len > limit { operations.len - limit } else { 0 }
	return operations[start..]
}

// Gets operation by ID
pub fn (mgr BackupManager) get_operation(op_id string) ?OperationBackup {
	if !os.exists(mgr.log_file) {
		return none
	}

	content := os.read_file(mgr.log_file) or { return none }
	operations := json.decode([]OperationBackup, content) or { return none }

	for op in operations {
		if op.operation_id == op_id {
			return op
		}
	}

	return none
}

// Restores files from operation backup
pub fn (mut mgr BackupManager) restore_operation(op_id string) ! {
	op_backup := mgr.get_operation(op_id) or {
		return error('Operation not found: ${op_id}')
	}

	println('Restoring operation: ${op_backup.operation_type} (${op_backup.operation_id})')
	println('Backed up files: ${op_backup.entries.len}')
	println('')

	mut restored := 0
	mut failed := 0

	for entry in op_backup.entries {
		// Verify backup exists
		if !os.exists(entry.backup_path) {
			println('✗ Backup missing: ${entry.original_path}')
			failed++
			continue
		}

		// Verify checksum
		content := os.read_file(entry.backup_path) or {
			println('✗ Failed to read backup: ${entry.original_path}')
			failed++
			continue
		}

		checksum := calculate_checksum(content)
		if checksum != entry.checksum {
			println('✗ Checksum mismatch: ${entry.original_path}')
			failed++
			continue
		}

		// Restore file
		os.cp(entry.backup_path, entry.original_path) or {
			println('✗ Failed to restore: ${entry.original_path}')
			failed++
			continue
		}

		println('✓ Restored: ${entry.original_path}')
		restored++
	}

	println('')
	println('Restored: ${restored}')
	println('Failed: ${failed}')
	println('Total: ${op_backup.entries.len}')

	if failed > 0 {
		return error('Rollback completed with ${failed} failures')
	}
}

// Restores last operation
pub fn (mut mgr BackupManager) restore_last() ! {
	operations := mgr.list_operations(1)
	if operations.len == 0 {
		return error('No operations to restore')
	}

	last_op := operations[0]
	mgr.restore_operation(last_op.operation_id)!
}

// Simple checksum calculation (FNV-1a hash)
fn calculate_checksum(data string) string {
	mut hash := u32(2166136261)
	for c in data {
		hash ^= u32(c)
		hash *= 16777619
	}
	return hash.hex()
}

// Cleans up old backups (older than days)
pub fn (mut mgr BackupManager) cleanup_old_backups(days int) ! {
	cutoff := time.now().unix - i64(days * 86400)

	operations := mgr.list_operations(1000)
	mut cleaned := 0

	for op in operations {
		if op.timestamp < cutoff {
			// Remove backup directory
			backup_dir := os.join_path(mgr.backup_dir, op.operation_id)
			if os.exists(backup_dir) {
				os.rmdir_all(backup_dir) or {}
				cleaned++
			}
		}
	}

	println('Cleaned up ${cleaned} old backup(s)')
}
