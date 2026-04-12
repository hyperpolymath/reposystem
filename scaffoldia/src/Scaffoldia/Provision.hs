{- SPDX-License-Identifier: MPL-2.0 -}
{-# LANGUAGE OverloadedStrings #-}

{- |
Module      : Scaffoldia.Provision
Description : Post-mint estate wiring — the provisioner
Copyright   : (c) Jonathan D.A. Jewell, 2026
License     : MPL-2.0

After Scaffoldia mints the files (the minter's job), the provisioner wires
the new repo into the estate.  This is the trainyard junction work:

  * Create the GitHub repo, apply rulesets, set up forge mirroring
  * Register in catalogues (BoJ, PanLL, ecosystem)
  * Provision databases (VeriSimDB)
  * Wire protocols (Groove, proven-agentic)
  * Generate launchers (via launch-scaffolder)
  * Set social images

Each 'ProvisionStep' is either automatic (has a shell command) or
interactive (requires human/AI input).  Steps are ordered and can be
re-run if idempotent.

The provisioner does not own the implementation of each integration — it
delegates to the existing tools (gh CLI, launch-scaffolder, etc.).  It is
the orchestrator that knows the sequence and dependencies.
-}

module Scaffoldia.Provision
  ( -- * Provision execution
    runProvision
  , runProvisionStep
    -- * Provision planning
  , planProvision
  , filterRequired
  , filterAutomatic
    -- * Step utilities
  , substituteVars
  , isStepApplicable
  ) where

import Scaffoldia.Types
import Scaffoldia.RepoKind (repoKindProvisionSteps, repoKindConnections)

import Data.Text (Text)
import qualified Data.Text as T
import System.Process (readProcessWithExitCode)
import System.Exit (ExitCode(..))

-- | Variable context for template substitution in provision commands.
type VarContext = [(Text, Text)]

-- | Plan the provision steps for a repo kind, filtering by the user's
-- chosen integrations.
planProvision :: RepoKind -> [IntegrationTarget] -> [ProvisionStep]
planProvision kind enabledTargets =
  filter (isStepApplicable enabledTargets) (repoKindProvisionSteps kind)

-- | Check if a provision step applies given the enabled integrations.
isStepApplicable :: [IntegrationTarget] -> ProvisionStep -> Bool
isStepApplicable _ (ProvisionStep { provTarget = Nothing }) = True  -- Always applies
isStepApplicable enabled (ProvisionStep { provTarget = Just t }) = t `elem` enabled

-- | Filter to only required integrations for a repo kind.
filterRequired :: RepoKind -> [Integration]
filterRequired kind = filter integRequired (repoKindConnections kind)

-- | Filter to only automatic integrations (no human input needed).
filterAutomatic :: RepoKind -> [Integration]
filterAutomatic kind = filter integAutomatic (repoKindConnections kind)

-- | Substitute @{{var}}@ placeholders in a command string.
substituteVars :: VarContext -> Text -> Text
substituteVars [] cmd = cmd
substituteVars ((k, v) : rest) cmd =
  substituteVars rest (T.replace ("{{" <> k <> "}}") v cmd)

-- | Execute a single provision step.
--
-- Returns Right () on success, Left errorMessage on failure.
-- Steps without a command are skipped (they need interactive handling).
runProvisionStep :: VarContext -> ProvisionStep -> IO (Either Text ())
runProvisionStep vars step = case provCommand step of
  Nothing -> return $ Left $
    "Interactive step — needs manual handling: " <> provDescription step
  Just cmdTemplate -> do
    let cmd = T.unpack $ substituteVars vars cmdTemplate
    (exitCode, _stdout, stderr) <- readProcessWithExitCode "sh" ["-c", cmd] ""
    case exitCode of
      ExitSuccess   -> return $ Right ()
      ExitFailure n -> return $ Left $
        provDescription step <> " failed (exit " <> T.pack (show n) <> "): "
        <> T.pack stderr

-- | Run all applicable provision steps for a repo kind.
--
-- Stops at the first non-automatic step and returns it along with the
-- remaining steps, so the caller can handle interactive steps.
--
-- Returns: (completed steps, Maybe (blocked step, remaining steps))
runProvision
  :: VarContext
  -> [ProvisionStep]
  -> IO ([Text], Maybe (ProvisionStep, [ProvisionStep]))
runProvision _ [] = return ([], Nothing)
runProvision vars (step : rest) = case provCommand step of
  Nothing ->
    -- Interactive step — pause and return it
    return ([], Just (step, rest))
  Just _ -> do
    result <- runProvisionStep vars step
    case result of
      Left err -> do
        -- Log the error but continue (the step may be non-critical)
        (completed, blocked) <- runProvision vars rest
        return (("WARN: " <> err) : completed, blocked)
      Right () -> do
        (completed, blocked) <- runProvision vars rest
        return (("OK: " <> provDescription step) : completed, blocked)
