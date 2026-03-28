// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// Reposystem V-lang API — Repository management client.
module reposystem

pub enum Forge {
	github
	gitlab
	bitbucket
	codeberg
}

pub enum ComplianceLevel {
	non_compliant
	partial
	full
}

pub struct RepoHealth {
pub:
	name       string
	forge      Forge
	score      int  // 0-100, clamped by ABI
	compliance ComplianceLevel
}

fn C.reposystem_clamp_health(score int) int
fn C.reposystem_valid_forge(forge int) int

// clamp_health ensures a health score is within bounds [0, 100].
pub fn clamp_health(score int) int {
	return C.reposystem_clamp_health(score)
}

// is_valid_forge checks if a forge identifier is known.
pub fn is_valid_forge(forge Forge) bool {
	return C.reposystem_valid_forge(int(forge)) == 1
}
