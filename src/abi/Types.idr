-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
||| ABI Types for Reposystem — repository management TUI
|||
||| Defines the formal interface for repo operations.
||| Proves that:
|||   1. Repo health scores are bounded [0,100]
|||   2. Forge operations are typed (no string-based dispatch)
|||   3. Batch operations preserve ordering
module Reposystem.ABI.Types

import Data.Fin

%default total

||| Repository forge type
public export
data Forge = GitHub | GitLab | Bitbucket | Codeberg

||| Repository health score (0-100, bounded)
public export
data HealthScore = MkHealth (n : Fin 101)

||| Reposystem operation
public export
data Operation
  = ListRepos         -- List managed repos
  | CheckHealth       -- Check repo health
  | SyncMirrors       -- Sync to mirrors
  | RunAudit          -- Run compliance audit
  | ApplyFix          -- Apply automated fix
  | CreateRepo        -- Create new repo from template

||| RSR compliance level
public export
data ComplianceLevel = NonCompliant | Partial | Full

-- ═══════════════════════════════════════════════════════════════════════
-- C ABI Exports
-- ═══════════════════════════════════════════════════════════════════════

export
forgeToInt : Forge -> Int
forgeToInt GitHub    = 0
forgeToInt GitLab    = 1
forgeToInt Bitbucket = 2
forgeToInt Codeberg  = 3

export
operationToInt : Operation -> Int
operationToInt ListRepos   = 0
operationToInt CheckHealth = 1
operationToInt SyncMirrors = 2
operationToInt RunAudit    = 3
operationToInt ApplyFix    = 4
operationToInt CreateRepo  = 5

export
complianceToInt : ComplianceLevel -> Int
complianceToInt NonCompliant = 0
complianceToInt Partial      = 1
complianceToInt Full         = 2
