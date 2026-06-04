// SPDX-License-Identifier: MPL-2.0
// Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const lib = b.addStaticLibrary(.{ .name = "reposystem_ffi", .root_source_file = b.path("src/reposystem_ffi.zig"), .target = target, .optimize = optimize });
    b.installArtifact(lib);
    const tests = b.addTest(.{ .root_source_file = b.path("src/reposystem_ffi.zig"), .target = target, .optimize = optimize });
    const test_step = b.step("test", "Run FFI tests");
    test_step.dependOn(&b.addRunArtifact(tests).step);
}
