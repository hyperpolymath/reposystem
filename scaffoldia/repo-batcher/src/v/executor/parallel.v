// SPDX-License-Identifier: PMPL-1.0-or-later
//
// Parallel Executor
// V coroutines for parallel repository processing

module executor

import time
import sync
import ffi

// WorkerPool manages parallel execution of operations across repositories
pub struct WorkerPool {
pub mut:
	workers       int
	repos         []string
	progress      int
	total         int
	results       []ffi.BatchResult
	errors        []string
	mtx           &sync.Mutex
	completed_ch  chan int
}

// TaskResult represents result of a single repository operation
struct TaskResult {
	repo_path string
	result    ffi.BatchResult
	err       string
}

// Creates new worker pool for parallel execution
pub fn new_worker_pool(repos []string, workers int) &WorkerPool {
	return &WorkerPool{
		workers: workers
		repos: repos
		progress: 0
		total: repos.len
		results: []ffi.BatchResult{}
		errors: []string{}
		mtx: sync.new_mutex()
		completed_ch: chan int{cap: repos.len}
	}
}

// Executes git-sync operation across all repositories in parallel
pub fn (mut pool WorkerPool) execute_git_sync(commit_msg string, dry_run bool) ffi.BatchResult {
	println('Executing git-sync with ${pool.workers} workers on ${pool.total} repositories...')
	println('')

	// Spawn worker coroutines
	for i in 0 .. pool.workers {
		spawn pool.git_sync_worker(i, commit_msg, dry_run)
	}

	// Wait for all workers to complete
	pool.wait_for_completion()

	// Aggregate results
	return pool.aggregate_results()
}

// Worker coroutine for git-sync operations
fn (mut pool WorkerPool) git_sync_worker(worker_id int, commit_msg string, dry_run bool) {
	for {
		// Get next repository to process
		repo := pool.get_next_repo() or { break }

		// Call ATS2 formally verified git-sync for single repo
		params := ffi.GitSyncParams{
			base_dir: repo
			max_depth: 0 // Already at repo level
			commit_msg: commit_msg
			parallel_jobs: 1 // Single repo at a time
			dry_run: dry_run
		}

		result := ffi.git_sync(params)

		// Record result
		pool.record_result(repo, result)
		pool.update_progress()

		// Show progress
		if !dry_run || result.has_failures() {
			pool.mtx.@lock()
			status := if result.is_success() { '✓' } else { '✗' }
			println('[${worker_id}] ${status} ${repo} (${pool.progress}/${pool.total})')
			pool.mtx.unlock()
		}
	}

	// Signal completion
	pool.completed_ch <- worker_id
}

// Gets next repository to process (thread-safe)
fn (mut pool WorkerPool) get_next_repo() ?string {
	pool.mtx.@lock()
	defer {
		pool.mtx.unlock()
	}

	if pool.repos.len == 0 {
		return none
	}

	repo := pool.repos[0]
	pool.repos = pool.repos[1..]
	return repo
}

// Records operation result (thread-safe)
fn (mut pool WorkerPool) record_result(repo string, result ffi.BatchResult) {
	pool.mtx.@lock()
	defer {
		pool.mtx.unlock()
	}

	pool.results << result
	if result.has_failures() {
		pool.errors << '${repo}: ${result.message}'
	}
}

// Updates progress counter (thread-safe)
fn (mut pool WorkerPool) update_progress() {
	pool.mtx.@lock()
	defer {
		pool.mtx.unlock()
	}

	pool.progress++
}

// Waits for all workers to complete
fn (mut pool WorkerPool) wait_for_completion() {
	completed := 0
	for completed < pool.workers {
		<-pool.completed_ch
		completed++
	}
}

// Aggregates all results into single BatchResult
fn (pool WorkerPool) aggregate_results() ffi.BatchResult {
	mut total_success := 0
	mut total_failure := 0
	mut total_skipped := 0

	for result in pool.results {
		total_success += result.success_count
		total_failure += result.failure_count
		total_skipped += result.skipped_count
	}

	msg := if pool.errors.len > 0 {
		'Completed with ${pool.errors.len} repository failures'
	} else {
		'All repositories processed successfully'
	}

	return ffi.BatchResult{
		success_count: total_success
		failure_count: total_failure
		skipped_count: total_skipped
		message: msg
	}
}

// Executes license-update operation across all repositories in parallel
pub fn (mut pool WorkerPool) execute_license_update(old_license string, new_license string, backup bool, dry_run bool) ffi.BatchResult {
	println('Executing license-update with ${pool.workers} workers on ${pool.total} repositories...')
	println('')

	// Spawn worker coroutines
	for i in 0 .. pool.workers {
		spawn pool.license_update_worker(i, old_license, new_license, backup, dry_run)
	}

	// Wait for all workers to complete
	pool.wait_for_completion()

	// Aggregate results
	return pool.aggregate_results()
}

// Worker coroutine for license-update operations
fn (mut pool WorkerPool) license_update_worker(worker_id int, old_license string, new_license string, backup bool, dry_run bool) {
	for {
		// Get next repository to process
		repo := pool.get_next_repo() or { break }

		// Call ATS2 formally verified license-update for single repo
		params := ffi.LicenseUpdateParams{
			old_license: old_license
			new_license: new_license
			base_dir: repo
			max_depth: 5 // Deep scan within repo
			dry_run: dry_run
			backup: backup
		}

		result := ffi.license_update(params)

		// Record result
		pool.record_result(repo, result)
		pool.update_progress()

		// Show progress
		pool.mtx.@lock()
		status := if result.is_success() { '✓' } else { '✗' }
		println('[${worker_id}] ${status} ${repo} (${pool.progress}/${pool.total})')
		pool.mtx.unlock()
	}

	// Signal completion
	pool.completed_ch <- worker_id
}

// Executes file-replace operation across all repositories in parallel
pub fn (mut pool WorkerPool) execute_file_replace(pattern string, replacement string, backup bool, dry_run bool) ffi.BatchResult {
	println('Executing file-replace with ${pool.workers} workers on ${pool.total} repositories...')
	println('')

	// Spawn worker coroutines
	for i in 0 .. pool.workers {
		spawn pool.file_replace_worker(i, pattern, replacement, backup, dry_run)
	}

	// Wait for all workers to complete
	pool.wait_for_completion()

	// Aggregate results
	return pool.aggregate_results()
}

// Worker coroutine for file-replace operations
fn (mut pool WorkerPool) file_replace_worker(worker_id int, pattern string, replacement string, backup bool, dry_run bool) {
	for {
		// Get next repository to process
		repo := pool.get_next_repo() or { break }

		// Call ATS2 formally verified file-replace for single repo
		params := ffi.FileReplaceParams{
			pattern: pattern
			replacement: replacement
			base_dir: repo
			max_depth: 5
			dry_run: dry_run
			backup: backup
		}

		result := ffi.file_replace(params)

		// Record result
		pool.record_result(repo, result)
		pool.update_progress()

		// Show progress
		pool.mtx.@lock()
		status := if result.is_success() { '✓' } else { '✗' }
		println('[${worker_id}] ${status} ${repo} (${pool.progress}/${pool.total})')
		pool.mtx.unlock()
	}

	// Signal completion
	pool.completed_ch <- worker_id
}

// Displays progress bar during execution
pub fn show_progress(current int, total int, width int) {
	percent := f32(current) / f32(total) * 100.0
	filled := int(f32(current) / f32(total) * f32(width))

	mut bar := '['
	for i in 0 .. width {
		if i < filled {
			bar += '='
		} else if i == filled {
			bar += '>'
		} else {
			bar += ' '
		}
	}
	bar += '] ${percent:5.1f}% (${current}/${total})'

	print('\r${bar}')
	if current == total {
		println('')
	}
}
