// SPDX-License-Identifier: MPL-2.0
// Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
//
// repo-batcher Zig FFI build (Layer 7), Zig 0.15.2.
//
// HONEST SCOPE: this build script only compiles the Zig CLI front-end
// to a PIC relocatable object (`rb_cli.o`). It deliberately does NOT
// produce the final executable, because patscc must own the final
// link: the ATS2 core needs the Postiats prelude/libats/runtime/dynload
// bootstrap that only `patscc` injects. The Justfile `cli` recipe takes
// this object and patscc-links it with the ATS2 core + libatslib into
// the real `repo-batcher` binary. `addSharedLibrary` (removed in Zig
// 0.15) is not used.
//
//   zig build         -> build/rb_cli.o  (this script)
//   just cli          -> build/repo-batcher (patscc final link)
//   just e2e          -> fixture-backed integration gate

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const obj = b.addObject(.{
        .name = "rb_cli",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            // PIC: gcc/patscc links PIE by default; a non-PIC object
            // triggers R_X86_64_32-against-PIE link failure.
            .pic = true,
        }),
    });

    // Emit to ../../build/rb_cli.o so the Justfile patscc link finds it
    // next to librepobatcher.a.
    const install = b.addInstallFile(obj.getEmittedBin(), "../../../build/rb_cli.o");
    b.getInstallStep().dependOn(&install.step);
}
