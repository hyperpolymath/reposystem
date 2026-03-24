// SPDX-License-Identifier: PMPL-1.0-or-later

/// ForgeOps Gossamer Command Wrappers — TEA commands for forge API operations.
///
/// Each function wraps a Gossamer IPC handler from the Rust backend,
/// using `Tea_Cmd.call` to bridge async Gossamer invocations into the TEA loop.
///
/// Supports three forges: GitHub (gh API), GitLab (REST v4), Bitbucket (REST 2.0).
/// Local-first: all config is cached in ~/.config/forgeops/

/// Gossamer IPC bridge — replaces Tauri's @tauri-apps/api/core invoke.
let invoke = RuntimeBridge.invoke

// ============================================================================
// Connection / token verification
// ============================================================================

/// Verify API tokens for all three forges. Returns connection status JSON.
let verifyTokens = (tagger: result<string, string> => 'msg): Tea_Cmd.t<'msg> => {
  Tea_Cmd.call(callbacks => {
    invoke("forgeops_verify_tokens", ())
    ->Promise.then(result => {
      callbacks.enqueue(tagger(Ok(result)))
      Promise.resolve()
    })
    ->Promise.catch(_err => {
      callbacks.enqueue(tagger(Error("Forge token verification failed")))
      Promise.resolve()
    })
    ->ignore
  })
}

/// Verify a single forge's API token.
let verifyForgeToken = (forge: string, tagger: result<string, string> => 'msg): Tea_Cmd.t<'msg> => {
  Tea_Cmd.call(callbacks => {
    invoke("forgeops_verify_forge_token", {"forge": forge})
    ->Promise.then(result => {
      callbacks.enqueue(tagger(Ok(result)))
      Promise.resolve()
    })
    ->Promise.catch(_err => {
      callbacks.enqueue(tagger(Error(`${forge} token verification failed`)))
      Promise.resolve()
    })
    ->ignore
  })
}

// ============================================================================
// Repository listing
// ============================================================================

/// List all repos from a specific forge.
let listRepos = (forge: string, tagger: result<string, string> => 'msg): Tea_Cmd.t<'msg> => {
  Tea_Cmd.call(callbacks => {
    invoke("forgeops_list_repos", {"forge": forge})
    ->Promise.then(result => {
      callbacks.enqueue(tagger(Ok(result)))
      Promise.resolve()
    })
    ->Promise.catch(_err => {
      callbacks.enqueue(tagger(Error(`Failed to list ${forge} repos`)))
      Promise.resolve()
    })
    ->ignore
  })
}

/// List all repos from all forges and merge by name.
let listAllRepos = (tagger: result<string, string> => 'msg): Tea_Cmd.t<'msg> => {
  Tea_Cmd.call(callbacks => {
    invoke("forgeops_list_all_repos", ())
    ->Promise.then(result => {
      callbacks.enqueue(tagger(Ok(result)))
      Promise.resolve()
    })
    ->Promise.catch(_err => {
      callbacks.enqueue(tagger(Error("Failed to list repos from all forges")))
      Promise.resolve()
    })
    ->ignore
  })
}

// ============================================================================
// Repo settings
// ============================================================================

/// Get settings for a specific repo on a specific forge.
let getRepoSettings = (
  forge: string,
  repoName: string,
  tagger: result<string, string> => 'msg,
): Tea_Cmd.t<'msg> => {
  Tea_Cmd.call(callbacks => {
    invoke("forgeops_get_repo_settings", {"forge": forge, "repo_name": repoName})
    ->Promise.then(result => {
      callbacks.enqueue(tagger(Ok(result)))
      Promise.resolve()
    })
    ->Promise.catch(_err => {
      callbacks.enqueue(tagger(Error(`Failed to get ${forge} settings for ${repoName}`)))
      Promise.resolve()
    })
    ->ignore
  })
}

/// Update a single repo setting.
let updateSetting = (
  forge: string,
  repoName: string,
  settingId: string,
  value: string,
  tagger: result<string, string> => 'msg,
): Tea_Cmd.t<'msg> => {
  Tea_Cmd.call(callbacks => {
    invoke(
      "forgeops_update_setting",
      {"forge": forge, "repo_name": repoName, "setting_id": settingId, "value": value},
    )
    ->Promise.then(result => {
      callbacks.enqueue(tagger(Ok(result)))
      Promise.resolve()
    })
    ->Promise.catch(_err => {
      callbacks.enqueue(tagger(Error(`Failed to update ${settingId} on ${forge}/${repoName}`)))
      Promise.resolve()
    })
    ->ignore
  })
}

// ============================================================================
// Mirror operations
// ============================================================================

/// Get mirror status for all repos.
let getMirrorStatus = (tagger: result<string, string> => 'msg): Tea_Cmd.t<'msg> => {
  Tea_Cmd.call(callbacks => {
    invoke("forgeops_get_mirror_status", ())
    ->Promise.then(result => {
      callbacks.enqueue(tagger(Ok(result)))
      Promise.resolve()
    })
    ->Promise.catch(_err => {
      callbacks.enqueue(tagger(Error("Failed to get mirror status")))
      Promise.resolve()
    })
    ->ignore
  })
}

/// Force sync a mirror for a specific repo to a specific target forge.
let forceSyncMirror = (
  repoName: string,
  targetForge: string,
  tagger: result<string, string> => 'msg,
): Tea_Cmd.t<'msg> => {
  Tea_Cmd.call(callbacks => {
    invoke("forgeops_force_sync_mirror", {"repo_name": repoName, "target_forge": targetForge})
    ->Promise.then(result => {
      callbacks.enqueue(tagger(Ok(result)))
      Promise.resolve()
    })
    ->Promise.catch(_err => {
      callbacks.enqueue(tagger(Error(`Failed to sync ${repoName} to ${targetForge}`)))
      Promise.resolve()
    })
    ->ignore
  })
}

// ============================================================================
// Branch protection
// ============================================================================

/// Get branch protection rules for a repo on a specific forge.
let getProtectionRules = (
  forge: string,
  repoName: string,
  tagger: result<string, string> => 'msg,
): Tea_Cmd.t<'msg> => {
  Tea_Cmd.call(callbacks => {
    invoke("forgeops_get_protection", {"forge": forge, "repo_name": repoName})
    ->Promise.then(result => {
      callbacks.enqueue(tagger(Ok(result)))
      Promise.resolve()
    })
    ->Promise.catch(_err => {
      callbacks.enqueue(tagger(Error(`Failed to get protection rules for ${forge}/${repoName}`)))
      Promise.resolve()
    })
    ->ignore
  })
}

/// Update branch protection for a repo on a specific forge.
let updateProtection = (
  forge: string,
  repoName: string,
  rulesJson: string,
  tagger: result<string, string> => 'msg,
): Tea_Cmd.t<'msg> => {
  Tea_Cmd.call(callbacks => {
    invoke(
      "forgeops_update_protection",
      {"forge": forge, "repo_name": repoName, "rules_json": rulesJson},
    )
    ->Promise.then(result => {
      callbacks.enqueue(tagger(Ok(result)))
      Promise.resolve()
    })
    ->Promise.catch(_err => {
      callbacks.enqueue(tagger(Error(`Failed to update protection on ${forge}/${repoName}`)))
      Promise.resolve()
    })
    ->ignore
  })
}

// ============================================================================
// Webhooks
// ============================================================================

/// List webhooks for a repo on a specific forge.
let listWebhooks = (
  forge: string,
  repoName: string,
  tagger: result<string, string> => 'msg,
): Tea_Cmd.t<'msg> => {
  Tea_Cmd.call(callbacks => {
    invoke("forgeops_list_webhooks", {"forge": forge, "repo_name": repoName})
    ->Promise.then(result => {
      callbacks.enqueue(tagger(Ok(result)))
      Promise.resolve()
    })
    ->Promise.catch(_err => {
      callbacks.enqueue(tagger(Error(`Failed to list webhooks for ${forge}/${repoName}`)))
      Promise.resolve()
    })
    ->ignore
  })
}

/// Delete a webhook.
let deleteWebhook = (
  forge: string,
  repoName: string,
  webhookId: string,
  tagger: result<string, string> => 'msg,
): Tea_Cmd.t<'msg> => {
  Tea_Cmd.call(callbacks => {
    invoke(
      "forgeops_delete_webhook",
      {"forge": forge, "repo_name": repoName, "webhook_id": webhookId},
    )
    ->Promise.then(result => {
      callbacks.enqueue(tagger(Ok(result)))
      Promise.resolve()
    })
    ->Promise.catch(_err => {
      callbacks.enqueue(tagger(Error(`Failed to delete webhook ${webhookId}`)))
      Promise.resolve()
    })
    ->ignore
  })
}

// ============================================================================
// CI/CD
// ============================================================================

/// List CI/CD pipelines for a repo on a specific forge.
let listPipelines = (
  forge: string,
  repoName: string,
  tagger: result<string, string> => 'msg,
): Tea_Cmd.t<'msg> => {
  Tea_Cmd.call(callbacks => {
    invoke("forgeops_list_pipelines", {"forge": forge, "repo_name": repoName})
    ->Promise.then(result => {
      callbacks.enqueue(tagger(Ok(result)))
      Promise.resolve()
    })
    ->Promise.catch(_err => {
      callbacks.enqueue(tagger(Error(`Failed to list pipelines for ${forge}/${repoName}`)))
      Promise.resolve()
    })
    ->ignore
  })
}

// ============================================================================
// Security
// ============================================================================

/// Get security alerts for a repo.
let getSecurityAlerts = (
  forge: string,
  repoName: string,
  tagger: result<string, string> => 'msg,
): Tea_Cmd.t<'msg> => {
  Tea_Cmd.call(callbacks => {
    invoke("forgeops_get_security_alerts", {"forge": forge, "repo_name": repoName})
    ->Promise.then(result => {
      callbacks.enqueue(tagger(Ok(result)))
      Promise.resolve()
    })
    ->Promise.catch(_err => {
      callbacks.enqueue(tagger(Error(`Failed to get security alerts for ${forge}/${repoName}`)))
      Promise.resolve()
    })
    ->ignore
  })
}

// ============================================================================
// Bulk operations
// ============================================================================

/// Apply RSR compliance settings to a repo on all forges.
let applyCompliance = (
  repoName: string,
  tagger: result<string, string> => 'msg,
): Tea_Cmd.t<'msg> => {
  Tea_Cmd.call(callbacks => {
    invoke("forgeops_apply_compliance", {"repo_name": repoName})
    ->Promise.then(result => {
      callbacks.enqueue(tagger(Ok(result)))
      Promise.resolve()
    })
    ->Promise.catch(_err => {
      callbacks.enqueue(tagger(Error(`Failed to apply compliance to ${repoName}`)))
      Promise.resolve()
    })
    ->ignore
  })
}

// ============================================================================
// Offline config
// ============================================================================

/// Download offline configuration for a repo (settings + protection + mirrors).
let downloadConfig = (
  repoName: string,
  tagger: result<string, string> => 'msg,
): Tea_Cmd.t<'msg> => {
  Tea_Cmd.call(callbacks => {
    invoke("forgeops_download_config", {"repo_name": repoName})
    ->Promise.then(result => {
      callbacks.enqueue(tagger(Ok(result)))
      Promise.resolve()
    })
    ->Promise.catch(_err => {
      callbacks.enqueue(tagger(Error(`Failed to download config for ${repoName}`)))
      Promise.resolve()
    })
    ->ignore
  })
}
