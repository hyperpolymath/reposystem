// SPDX-License-Identifier: PMPL-1.0-or-later
//
// Watch Folder Monitor
// Monitors folder for operation files and executes automatically

module watcher

import os
import time
import toml

// OperationFile represents a TOML operation definition
pub struct OperationFile {
pub mut:
	path           string
	operation_type string
	params         map[string]string
	targets        string
	dry_run        bool
	backup         bool
}

// WatchMonitor monitors folder for operation files
pub struct WatchMonitor {
pub mut:
	watch_folder    string
	check_interval  int // seconds
	auto_delete     bool
	processed_files map[string]i64 // path -> timestamp
}

// Creates new watch monitor
pub fn new_watch_monitor(watch_folder string, check_interval int, auto_delete bool) WatchMonitor {
	// Create watch folder if needed
	os.mkdir_all(watch_folder) or {}

	return WatchMonitor{
		watch_folder: watch_folder
		check_interval: check_interval
		auto_delete: auto_delete
		processed_files: map[string]i64{}
	}
}

// Starts monitoring loop
pub fn (mut monitor WatchMonitor) start() {
	println('Starting watch monitor...')
	println('  Watch folder: ${monitor.watch_folder}')
	println('  Check interval: ${monitor.check_interval}s')
	println('  Auto-delete: ${monitor.auto_delete}')
	println('')
	println('Watching for operation files (*.toml)...')
	println('Press Ctrl+C to stop')
	println('')

	for {
		// Scan for new operation files
		monitor.scan_and_process()

		// Wait before next check
		time.sleep(monitor.check_interval * time.second)
	}
}

// Scans folder and processes new files
fn (mut monitor WatchMonitor) scan_and_process() {
	// List TOML files in watch folder
	entries := os.ls(monitor.watch_folder) or { return }

	for entry in entries {
		// Only process .toml files
		if !entry.ends_with('.toml') {
			continue
		}

		full_path := os.join_path(monitor.watch_folder, entry)

		// Skip if already processed
		if monitor.is_processed(full_path) {
			continue
		}

		// Parse and execute operation
		println('[${time.now().format()}] Found: ${entry}')
		monitor.process_operation_file(full_path)

		// Mark as processed
		monitor.mark_processed(full_path)

		// Delete if auto-delete enabled
		if monitor.auto_delete {
			os.rm(full_path) or {}
		}
	}
}

// Checks if file already processed
fn (monitor WatchMonitor) is_processed(path string) bool {
	// Get file modification time
	stat := os.stat(path) or { return true }
	mtime := stat.mtime

	// Check if we've processed this version
	if processed_time := monitor.processed_files[path] {
		return mtime <= processed_time
	}

	return false
}

// Marks file as processed
fn (mut monitor WatchMonitor) mark_processed(path string) {
	stat := os.stat(path) or { return }
	monitor.processed_files[path] = stat.mtime
}

// Processes operation file
fn (mut monitor WatchMonitor) process_operation_file(path string) {
	// Parse TOML file
	op_file := monitor.parse_operation_file(path) or {
		println('  ✗ Failed to parse: ${err}')
		return
	}

	// Execute operation
	println('  Operation: ${op_file.operation_type}')
	println('  Targets: ${op_file.targets}')
	println('  Dry run: ${op_file.dry_run}')
	println('')

	// NOTE: This would call the actual operation execution
	// For now, just print what would happen
	match op_file.operation_type {
		'license-update' {
			old := op_file.params['old_license'] or { 'unknown' }
			new := op_file.params['new_license'] or { 'unknown' }
			println('  Would update licenses: ${old} -> ${new}')
		}
		'git-sync' {
			parallel := op_file.params['parallel_jobs'] or { '4' }
			println('  Would sync repositories (parallel: ${parallel})')
		}
		'file-replace' {
			pattern := op_file.params['pattern'] or { 'unknown' }
			println('  Would replace files matching: ${pattern}')
		}
		else {
			println('  Unknown operation type: ${op_file.operation_type}')
		}
	}

	println('  ✓ Operation queued')
	println('')
}

// Parses TOML operation file
fn (monitor WatchMonitor) parse_operation_file(path string) !OperationFile {
	content := os.read_file(path) or {
		return error('Failed to read file: ${err}')
	}

	doc := toml.parse_text(content) or {
		return error('Failed to parse TOML: ${err}')
	}

	// Extract operation type
	op_type := doc.value('operation.type').string() or {
		return error('Missing operation.type')
	}

	// Extract parameters
	mut params := map[string]string{}

	// Try to extract common parameters
	if val := doc.value('parameters.old_license') {
		params['old_license'] = val.string()
	}
	if val := doc.value('parameters.new_license') {
		params['new_license'] = val.string()
	}
	if val := doc.value('parameters.pattern') {
		params['pattern'] = val.string()
	}
	if val := doc.value('parameters.replacement') {
		params['replacement'] = val.string()
	}
	if val := doc.value('parameters.commit_message') {
		params['commit_message'] = val.string()
	}
	if val := doc.value('parameters.parallel_jobs') {
		params['parallel_jobs'] = val.string()
	}

	// Extract targets
	targets := doc.value('targets.selection').default_to('').string()

	// Extract options
	dry_run := doc.value('options.dry_run').default_to(false).bool()
	backup := doc.value('options.backup').default_to(true).bool()

	return OperationFile{
		path: path
		operation_type: op_type
		params: params
		targets: targets
		dry_run: dry_run
		backup: backup
	}
}
