// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// Reposystem FFI — C-compatible bridge for repo management.

const std = @import("std");

pub const Forge = enum(i32) { github = 0, gitlab = 1, bitbucket = 2, codeberg = 3 };
pub const ComplianceLevel = enum(i32) { non_compliant = 0, partial = 1, full = 2 };

/// Clamp health score to [0, 100].
pub export fn reposystem_clamp_health(score: i32) callconv(.C) i32 {
    if (score < 0) return 0;
    if (score > 100) return 100;
    return score;
}

/// Check if a forge ID is valid.
pub export fn reposystem_valid_forge(forge: i32) callconv(.C) i32 {
    return if (forge >= 0 and forge <= 3) 1 else 0;
}

test "health clamping" {
    try std.testing.expectEqual(@as(i32, 0), reposystem_clamp_health(-5));
    try std.testing.expectEqual(@as(i32, 50), reposystem_clamp_health(50));
    try std.testing.expectEqual(@as(i32, 100), reposystem_clamp_health(200));
}

test "forge validation" {
    try std.testing.expectEqual(@as(i32, 1), reposystem_valid_forge(0));
    try std.testing.expectEqual(@as(i32, 1), reposystem_valid_forge(3));
    try std.testing.expectEqual(@as(i32, 0), reposystem_valid_forge(4));
}
