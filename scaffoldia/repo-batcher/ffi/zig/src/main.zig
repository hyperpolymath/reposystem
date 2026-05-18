// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// repo-batcher CLI (Layer 7), Zig 0.15.2.
//
// This is a thin, honest front-end over the REAL ATS2 C-export surface
// (Layer 5). Every operation below is the genuine Postiats-compiled
// symbol linked from ../../build/librepobatcher.a — there is NO Zig
// reimplementation of repo-batcher logic here. The CLI only parses
// argv, calls the c_* function, and reports what the ATS2 side returned
// (faithful exit-code/count propagation, matching the L4 honesty
// model: we report what the external operation did, we do not
// reinterpret it).

const std = @import("std");

// ── ATS2 C ABI (mirrors src/ats2/ffi/c_exports.dats exactly) ──
// atstype_int = C int = c_int; atstype_string = char* = [*:0]const u8
// (verified against pats_ccomp_typedefs.h).
pub const CBatchResult = extern struct {
    success_count: c_int,
    failure_count: c_int,
    skipped_count: c_int,
    message: [*:0]const u8,
};

pub extern fn c_get_version() [*:0]const u8;
pub extern fn c_validate_spdx(license: [*:0]const u8) c_int;
pub extern fn c_git_sync(
    base_dir: [*:0]const u8,
    max_depth: c_int,
    commit_msg: [*:0]const u8,
    parallel_jobs: c_int,
    dry_run: c_int,
) CBatchResult;
pub extern fn c_license_update(
    old_license: [*:0]const u8,
    new_license: [*:0]const u8,
    base_dir: [*:0]const u8,
    max_depth: c_int,
    dry_run: c_int,
    backup: c_int,
) CBatchResult;
pub extern fn c_file_replace(
    pattern: [*:0]const u8,
    replacement: [*:0]const u8,
    base_dir: [*:0]const u8,
    max_depth: c_int,
    dry_run: c_int,
    backup: c_int,
) CBatchResult;
pub extern fn c_spdx_audit(
    base_dir: [*:0]const u8,
    max_depth: c_int,
) CBatchResult;

fn out(comptime fmt: []const u8, args: anytype) void {
    var buf: [4096]u8 = undefined;
    const s = std.fmt.bufPrint(&buf, fmt, args) catch return;
    std.fs.File.stdout().writeAll(s) catch {};
}

fn parseInt(s: [:0]const u8) c_int {
    return std.fmt.parseInt(c_int, s, 10) catch 0;
}

fn reportBatch(label: []const u8, r: CBatchResult) u8 {
    out("{s}: success={d} failure={d} skipped={d} :: {s}\n", .{
        label,
        r.success_count,
        r.failure_count,
        r.skipped_count,
        std.mem.span(r.message),
    });
    // Faithful propagation: any failure the ATS2 side counted is a
    // non-zero exit; otherwise success.
    return if (r.failure_count > 0) 1 else 0;
}

fn usage() void {
    out(
        \\repo-batcher (ATS2 core / Zig CLI)
        \\usage:
        \\  repo-batcher --version
        \\  repo-batcher validate-spdx <id>
        \\  repo-batcher file-replace <name-pattern> <replacement-file> <base_dir> <max_depth> <dry_run> <backup>
        \\  repo-batcher spdx-audit <base_dir> <max_depth>
        \\  repo-batcher git-sync <base_dir> <max_depth> <commit_msg> <parallel_jobs> <dry_run>
        \\  repo-batcher license-update <old> <new> <base_dir> <max_depth> <dry_run> <backup>
        \\
    , .{});
}

// patscc links the final binary and owns the ATS2 program bootstrap;
// the ATS `main0` root calls this. argv is recovered from the OS by
// std.process, so no parameters need crossing the ATS->Zig boundary.
export fn rb_main() c_int {
    run() catch return 1;
    return 0;
}

// patscc owns the program entry, so Zig's start code never sets
// std.os.argv. Recover argv directly from the kernel via
// /proc/self/cmdline (NUL-separated), which is start-code independent.
fn argvFromProc(a: std.mem.Allocator) ![][:0]u8 {
    const raw = try std.fs.cwd().readFileAlloc(a, "/proc/self/cmdline", 1 << 20);
    var list = std.ArrayList([:0]u8){};
    var it = std.mem.splitScalar(u8, raw, 0);
    while (it.next()) |part| {
        if (part.len == 0) continue;
        const z = try a.allocSentinel(u8, part.len, 0);
        @memcpy(z, part);
        try list.append(a, z);
    }
    return list.toOwnedSlice(a);
}

fn run() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const argv = try argvFromProc(arena.allocator());

    if (argv.len < 2) {
        usage();
        std.process.exit(2);
    }
    const cmd = argv[1];

    if (std.mem.eql(u8, cmd, "--version") or std.mem.eql(u8, cmd, "version")) {
        out("{s}\n", .{std.mem.span(c_get_version())});
        return;
    }

    if (std.mem.eql(u8, cmd, "validate-spdx")) {
        if (argv.len < 3) {
            usage();
            std.process.exit(2);
        }
        const ok = c_validate_spdx(argv[2].ptr);
        out("{s}: {s}\n", .{ std.mem.span(argv[2].ptr), if (ok == 1) "valid" else "invalid" });
        std.process.exit(if (ok == 1) 0 else 1);
    }

    if (std.mem.eql(u8, cmd, "file-replace")) {
        if (argv.len < 8) {
            usage();
            std.process.exit(2);
        }
        const r = c_file_replace(
            argv[2].ptr,
            argv[3].ptr,
            argv[4].ptr,
            parseInt(argv[5]),
            parseInt(argv[6]),
            parseInt(argv[7]),
        );
        std.process.exit(reportBatch("file-replace", r));
    }

    if (std.mem.eql(u8, cmd, "spdx-audit")) {
        if (argv.len < 4) {
            usage();
            std.process.exit(2);
        }
        const r = c_spdx_audit(argv[2].ptr, parseInt(argv[3]));
        std.process.exit(reportBatch("spdx-audit", r));
    }

    if (std.mem.eql(u8, cmd, "git-sync")) {
        if (argv.len < 7) {
            usage();
            std.process.exit(2);
        }
        const r = c_git_sync(
            argv[2].ptr,
            parseInt(argv[3]),
            argv[4].ptr,
            parseInt(argv[5]),
            parseInt(argv[6]),
        );
        std.process.exit(reportBatch("git-sync", r));
    }

    if (std.mem.eql(u8, cmd, "license-update")) {
        if (argv.len < 8) {
            usage();
            std.process.exit(2);
        }
        const r = c_license_update(
            argv[2].ptr,
            argv[3].ptr,
            argv[4].ptr,
            parseInt(argv[5]),
            parseInt(argv[6]),
            parseInt(argv[7]),
        );
        std.process.exit(reportBatch("license-update", r));
    }

    usage();
    std.process.exit(2);
}
