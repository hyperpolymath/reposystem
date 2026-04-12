{- SPDX-License-Identifier: MPL-2.0 -}
{-# LANGUAGE OverloadedStrings #-}

{- |
Module      : Scaffoldia.RepoKind
Description : Repo kind taxonomy — layers, connections, and minting prompts
Copyright   : (c) Jonathan D.A. Jewell, 2026
License     : MPL-2.0

The knowledge graph for Scaffoldia.  Each 'RepoKind' carries:

  1. __Layers__ — the structural components the repo is made of (ABI, FFI,
     adapters, manifests, panels, etc.)

  2. __Connections__ — which estate systems ('IntegrationTarget') the repo
     wires into.  This is the trainyard model: Scaffoldia knows where this
     repo sits in the network of ~300 repos and what junctions it touches.

  3. __Prompts__ — what to ask the user during minting (name, port, domain,
     target languages, social image, etc.)

  4. __Provision steps__ �� the ordered sequence of post-mint actions that
     wire the repo into the estate (create GitHub repo, apply rulesets,
     register in catalogues, provision databases, set up mirroring, etc.)

When the user says "I want to make a BoJ cartridge", Scaffoldia looks up
'BojCartridge' here and knows: you need Idris2 ABI + Zig FFI + Nickel
manifest + Deno adapter + PanLL panels, you'll wire into the BoJ catalogue
+ MCP bridge + TOPOLOGY port map, and I need to ask you for a cartridge
name, domain, port number, and protocol list.
-}

module Scaffoldia.RepoKind
  ( -- * Layer queries
    repoKindLayers
  , repoKindOptionalLayers
    -- * Connection queries
  , repoKindConnections
    -- * Prompts
  , repoKindPrompts
    -- * Provision steps
  , repoKindProvisionSteps
    -- * Metadata
  , repoKindDescription
  , repoKindPrimaryLanguages
  , repoKindLicense
  ) where

import Scaffoldia.Types

import Data.Text (Text)

-- ═══════════════════════════════════════════════════════════════════════════
-- Layers — what structural components does this repo kind require?
-- ═══════════════════════════════════════════════════════════════════════════

-- | Required layers for a repo kind.  These are non-negotiable — if you
-- pick this kind, Scaffoldia will scaffold all of these.
repoKindLayers :: RepoKind -> [Layer]

repoKindLayers BojCartridge =
  [ Idris2Abi, ZigFfi, ZigAdapter, NickelManifest, DenoAdapter
  , PanllPanels, A2mlData, ReadmeAdoc, ExplainmeAdoc, TechnicalReport
  , SecurityMd, RsrWorkflows
  ]

repoKindLayers EcosystemFfi =
  [ Idris2Abi, ZigFfi, CHeaders, LanguageBindings
  , A2mlData, ReadmeAdoc, ExplainmeAdoc, TechnicalReport
  , SecurityMd, RsrWorkflows
  ]

repoKindLayers ProvenServer =
  [ Idris2Abi, ZigFfi, ProvenProtocol, GrooveEndpoint, DenoAdapter
  , NickelManifest, A2mlData, Containerfile, FlyDeploy
  , ReadmeAdoc, ExplainmeAdoc, TechnicalReport, SecurityMd, RsrWorkflows
  ]

repoKindLayers LanguageTool =
  [ TreeSitterGrammar, LspAdapter, DapAdapter
  , CargoWorkspace, A2mlData
  , ReadmeAdoc, ExplainmeAdoc, SecurityMd, RsrWorkflows
  ]

repoKindLayers PanllPanel =
  [ ReScriptTea, PanllPanels, GossamerIpc, DenoJson
  , A2mlData, ReadmeAdoc, ExplainmeAdoc, SecurityMd, RsrWorkflows
  ]

repoKindLayers GleamService =
  [ GleamToml, GrooveClient, Containerfile, FlyDeploy
  , A2mlData, ReadmeAdoc, ExplainmeAdoc, SecurityMd, RsrWorkflows
  ]

repoKindLayers ElixirService =
  [ MixProject, GrooveClient, Containerfile, FlyDeploy
  , A2mlData, ReadmeAdoc, ExplainmeAdoc, SecurityMd, RsrWorkflows
  ]

repoKindLayers TauriApp =
  [ CargoWorkspace, TauriConfig, ReScriptTea, DenoJson, LauncherScript
  , A2mlData, ReadmeAdoc, ExplainmeAdoc, SecurityMd, RsrWorkflows
  ]

repoKindLayers DioxusApp =
  [ CargoWorkspace, LauncherScript
  , A2mlData, ReadmeAdoc, ExplainmeAdoc, SecurityMd, RsrWorkflows
  ]

repoKindLayers JuliaPackage =
  [ JuliaProject
  , A2mlData, ReadmeAdoc, ExplainmeAdoc, SecurityMd, RsrWorkflows
  ]

repoKindLayers RustCli =
  [ CargoWorkspace, LauncherScript
  , A2mlData, ReadmeAdoc, ExplainmeAdoc, SecurityMd, RsrWorkflows
  ]

repoKindLayers StandardsExtension =
  [ A2mlData, NickelContracts
  , ReadmeAdoc, ExplainmeAdoc, SecurityMd, RsrWorkflows
  ]

repoKindLayers GameProject =
  [ CargoWorkspace, TauriConfig, ReScriptTea, PanllPanels, DenoJson
  , A2mlData, ReadmeAdoc, ExplainmeAdoc, SecurityMd, RsrWorkflows
  ]

repoKindLayers NickelConfig =
  [ NickelContracts, NickelManifest
  , A2mlData, ReadmeAdoc, ExplainmeAdoc, SecurityMd, RsrWorkflows
  ]

repoKindLayers MonorepoMember =
  [ A2mlData, ReadmeAdoc ]

repoKindLayers GenericRsr =
  [ A2mlData, ReadmeAdoc, ExplainmeAdoc, SecurityMd, RsrWorkflows ]

-- | Optional layers the user can add during minting.
repoKindOptionalLayers :: RepoKind -> [Layer]
repoKindOptionalLayers BojCartridge     = [GrooveEndpoint, ProvenProtocol]
repoKindOptionalLayers EcosystemFfi     = [NickelContracts, PanllPanels]
repoKindOptionalLayers ProvenServer     = [PanllPanels, LauncherScript]
repoKindOptionalLayers LanguageTool     = [NickelContracts, PanllPanels]
repoKindOptionalLayers GleamService     = [PanllPanels, LauncherScript]
repoKindOptionalLayers ElixirService    = [PanllPanels, LauncherScript]
repoKindOptionalLayers TauriApp         = [Idris2Abi, ZigFfi, GrooveClient]
repoKindOptionalLayers DioxusApp        = [Idris2Abi, ZigFfi, GrooveClient]
repoKindOptionalLayers RustCli          = [Idris2Abi, ZigFfi, Containerfile]
repoKindOptionalLayers JuliaPackage     = [NickelContracts]
repoKindOptionalLayers GameProject      = [GrooveClient, Containerfile, FlyDeploy]
repoKindOptionalLayers _                = []

-- ═══════════════════════════════════════════════════════════════════════════
-- Connections — what estate junctions does this repo kind touch?
--
-- This is the trainyard model.  Each repo kind sits on certain tracks and
-- connects at certain junctions.  Scaffoldia uses this to know what post-
-- mint wiring is needed.
-- ═══════════════════════════════════════════════════════════════════════════

-- | Estate integrations for a repo kind.  Required integrations are wired
-- automatically; optional ones are offered to the user during minting.
repoKindConnections :: RepoKind -> [Integration]

repoKindConnections BojCartridge =
  [ Integration BojCatalogue    True  "Register in BoJ catalogue (Catalogue.idr + TOPOLOGY.md)" True
  , Integration BojMcpBridge    True  "Wire into MCP bridge tool discovery" True
  , Integration GitHubRepo      True  "Create GitHub repo with rulesets" True
  , Integration GitHubMirroring True  "Set up forge mirroring" True
  , Integration PanllRegistry   False "Register panels in PanLL workspace" True
  , Integration HypatiaRules    False "Add project-specific Hypatia CI rules" False
  , Integration SocialImage     False "Generate social/OG image for GitHub" False
  ]

repoKindConnections EcosystemFfi =
  [ Integration GitHubRepo       True  "Create GitHub repo with rulesets" True
  , Integration GitHubMirroring  True  "Set up forge mirroring" True
  , Integration EcosystemRegistry True "Register in developer-ecosystem" True
  , Integration VeriSimDbInstance False "Provision VeriSimDB for integration tests" False
  , Integration SocialImage      False "Generate social/OG image" False
  ]

repoKindConnections ProvenServer =
  [ Integration GitHubRepo       True  "Create GitHub repo with rulesets" True
  , Integration GitHubMirroring  True  "Set up forge mirroring" True
  , Integration ProvenServersWiring True "Wire proven-agentic protocol" True
  , Integration GrooveNetwork    True  "Join Groove protocol mesh" True
  , Integration BojCatalogue     False "Register as BoJ cartridge (if dual-use)" False
  , Integration VeriSimDbInstance True  "Provision VeriSimDB instance" True
  , Integration HypatiaRules     True  "Register Hypatia CI rules" True
  , Integration SocialImage      False "Generate social/OG image" False
  ]

repoKindConnections LanguageTool =
  [ Integration GitHubRepo       True  "Create GitHub repo with rulesets" True
  , Integration GitHubMirroring  True  "Set up forge mirroring" True
  , Integration EcosystemRegistry True "Register in developer-ecosystem" True
  , Integration BojCatalogue     False "Register as BoJ LSP/DAP cartridge" False
  , Integration SocialImage      False "Generate social/OG image" False
  ]

repoKindConnections PanllPanel =
  [ Integration GitHubRepo       True  "Create GitHub repo with rulesets" True
  , Integration GitHubMirroring  True  "Set up forge mirroring" True
  , Integration PanllRegistry    True  "Register in PanLL workspace" True
  , Integration GrooveNetwork    True  "Wire Gossamer IPC handlers (via Groove)" True
  , Integration SocialImage      False "Generate social/OG image" False
  ]

repoKindConnections GleamService =
  [ Integration GitHubRepo       True  "Create GitHub repo with rulesets" True
  , Integration GitHubMirroring  True  "Set up forge mirroring" True
  , Integration GrooveNetwork    True  "Join Groove protocol mesh" True
  , Integration BojCatalogue     False "Register as BoJ cartridge" False
  , Integration VeriSimDbInstance True  "Provision VeriSimDB instance" True
  , Integration HypatiaRules     True  "Register Hypatia CI rules" True
  , Integration SocialImage      False "Generate social/OG image" False
  ]

repoKindConnections ElixirService =
  [ Integration GitHubRepo       True  "Create GitHub repo with rulesets" True
  , Integration GitHubMirroring  True  "Set up forge mirroring" True
  , Integration GrooveNetwork    True  "Join Groove protocol mesh" True
  , Integration BojCatalogue     False "Register as BoJ cartridge" False
  , Integration VeriSimDbInstance True  "Provision VeriSimDB instance" True
  , Integration HypatiaRules     True  "Register Hypatia CI rules" True
  , Integration SocialImage      False "Generate social/OG image" False
  ]

repoKindConnections TauriApp =
  [ Integration GitHubRepo       True  "Create GitHub repo with rulesets" True
  , Integration GitHubMirroring  True  "Set up forge mirroring" True
  , Integration LauncherScaffolder True "Generate launcher via launch-scaffolder" True
  , Integration OpsManager       False "Register in OPSM" False
  , Integration SocialImage      False "Generate social/OG image" False
  ]

repoKindConnections DioxusApp =
  [ Integration GitHubRepo       True  "Create GitHub repo with rulesets" True
  , Integration GitHubMirroring  True  "Set up forge mirroring" True
  , Integration LauncherScaffolder True "Generate launcher via launch-scaffolder" True
  , Integration OpsManager       False "Register in OPSM" False
  , Integration SocialImage      False "Generate social/OG image" False
  ]

repoKindConnections JuliaPackage =
  [ Integration GitHubRepo       True  "Create GitHub repo with rulesets" True
  , Integration GitHubMirroring  True  "Set up forge mirroring" True
  , Integration EcosystemRegistry True "Register in julia-ecosystem" True
  , Integration SocialImage      False "Generate social/OG image" False
  ]

repoKindConnections RustCli =
  [ Integration GitHubRepo       True  "Create GitHub repo with rulesets" True
  , Integration GitHubMirroring  True  "Set up forge mirroring" True
  , Integration LauncherScaffolder True "Generate launcher via launch-scaffolder" True
  , Integration OpsManager       False "Register in OPSM" False
  , Integration SocialImage      False "Generate social/OG image" False
  ]

repoKindConnections StandardsExtension =
  [ Integration GitHubRepo       True  "Create GitHub repo with rulesets" True
  , Integration GitHubMirroring  True  "Set up forge mirroring" True
  , Integration EcosystemRegistry True "Register in standards ecosystem" True
  , Integration SocialImage      False "Generate social/OG image" False
  ]

repoKindConnections GameProject =
  [ Integration GitHubRepo       True  "Create PRIVATE GitHub repo (AGPL, co-dev)" True
  , Integration LauncherScaffolder True "Generate launcher" True
  , Integration VeriSimDbInstance False "Provision VeriSimDB for game state" False
  , Integration SocialImage      False "Generate social/OG image" False
  -- NOTE: No mirroring — games may be private
  ]

repoKindConnections NickelConfig =
  [ Integration GitHubRepo       True  "Create GitHub repo with rulesets" True
  , Integration GitHubMirroring  True  "Set up forge mirroring" True
  , Integration SocialImage      False "Generate social/OG image" False
  ]

repoKindConnections MonorepoMember =
  -- No GitHub repo creation — it lives inside an existing monorepo
  [ Integration EcosystemRegistry False "Register position in parent monorepo's ecosystem" True
  ]

repoKindConnections GenericRsr =
  [ Integration GitHubRepo       True  "Create GitHub repo with rulesets" True
  , Integration GitHubMirroring  True  "Set up forge mirroring" True
  , Integration SocialImage      False "Generate social/OG image" False
  ]

-- ═══════════════════════════════════════════════════════════════════════════
-- Prompts — what does Scaffoldia ask during minting?
-- ═══════════════════════════════════════════════════════════════════════════

-- | Universal prompts asked for every repo kind.
universalPrompts :: [MintPrompt]
universalPrompts =
  [ MintPrompt "name" "Repository name" (FreeText) Nothing Nothing
  , MintPrompt "description" "One-line description" (FreeText) Nothing Nothing
  , MintPrompt "social_image" "Would you like to set a social/OG image now?"
      YesNo (Just "no") Nothing
  ]

-- | Kind-specific prompts.
repoKindPrompts :: RepoKind -> [MintPrompt]

repoKindPrompts BojCartridge = universalPrompts ++
  [ MintPrompt "domain" "Capability domain"
      (SingleChoice [ "Cloud", "Container", "Database", "K8s", "Git"
                    , "Secrets", "Queues", "IaC", "Observe", "SSG"
                    , "Proof", "FleetDom", "NeSyDom", "Agent"
                    , "Lsp", "Dap", "Bsp", "CodeIntel" ])
      (Just "Agent") (Nothing)
  , MintPrompt "port" "Backend port (next available: check TOPOLOGY.md)"
      PortNumber Nothing Nothing
  , MintPrompt "protocols" "Wire protocols"
      (MultiChoice ["MCP", "LSP", "DAP", "BSP", "NeSy", "Agentic", "Fleet", "gRPC", "REST"])
      (Just "MCP") Nothing
  , MintPrompt "tier" "Cartridge tier"
      (SingleChoice ["Teranga", "Shield", "Ayo"])
      (Just "Ayo") Nothing
  ]

repoKindPrompts EcosystemFfi = universalPrompts ++
  [ MintPrompt "target_languages" "Target language bindings"
      (MultiChoice ["Rust", "Haskell", "ReScript", "Gleam", "OCaml", "Julia", "Ada", "Elixir"])
      Nothing (Just LanguageBindings)
  ]

repoKindPrompts ProvenServer = universalPrompts ++
  [ MintPrompt "protocol_name" "Protocol name (e.g. proven-agentic)" FreeText Nothing Nothing
  , MintPrompt "groove_service" "Groove service identifier" FreeText Nothing (Just GrooveEndpoint)
  , MintPrompt "fly_app" "Fly.io app name" FreeText Nothing (Just FlyDeploy)
  ]

repoKindPrompts LanguageTool = universalPrompts ++
  [ MintPrompt "language_name" "Language being tooled" FreeText Nothing Nothing
  , MintPrompt "grammar_repo" "Tree-sitter grammar repo (if separate)" FreeText
      Nothing (Just TreeSitterGrammar)
  ]

repoKindPrompts PanllPanel = universalPrompts ++
  [ MintPrompt "panel_count" "How many panels to scaffold?" FreeText (Just "1") Nothing
  ]

repoKindPrompts GleamService = universalPrompts ++
  [ MintPrompt "groove_service" "Groove service identifier" FreeText Nothing (Just GrooveClient)
  , MintPrompt "fly_app" "Fly.io app name" FreeText Nothing (Just FlyDeploy)
  ]

repoKindPrompts ElixirService = universalPrompts ++
  [ MintPrompt "groove_service" "Groove service identifier" FreeText Nothing (Just GrooveClient)
  , MintPrompt "fly_app" "Fly.io app name" FreeText Nothing (Just FlyDeploy)
  , MintPrompt "phoenix" "Use Phoenix framework?" YesNo (Just "yes") Nothing
  ]

repoKindPrompts TauriApp = universalPrompts ++
  [ MintPrompt "app_name" "Application display name" FreeText Nothing Nothing
  , MintPrompt "mobile" "Include mobile targets (iOS/Android)?" YesNo (Just "yes") Nothing
  ]

repoKindPrompts DioxusApp = universalPrompts ++
  [ MintPrompt "app_name" "Application display name" FreeText Nothing Nothing
  ]

repoKindPrompts JuliaPackage = universalPrompts ++
  [ MintPrompt "uuid" "Package UUID (auto-generate?)" YesNo (Just "yes") Nothing
  ]

repoKindPrompts RustCli = universalPrompts ++
  [ MintPrompt "spark_integration" "Design for SPARK/Ada module integration?"
      YesNo (Just "yes") Nothing
  ]

repoKindPrompts GameProject = universalPrompts ++
  [ MintPrompt "game_name" "Game title" FreeText Nothing Nothing
  , MintPrompt "private" "Private repo?" YesNo (Just "yes") Nothing
  , MintPrompt "codev" "Co-developed with son (AGPL)?" YesNo (Just "yes") Nothing
  ]

repoKindPrompts _ = universalPrompts

-- ═══════════════════════════════════════════════════════════════════════════
-- Provision Steps — the ordered post-mint sequence
-- ═══════════════════════════════════════════════════════════════════════════

-- | Default provision steps for kinds that just need GitHub + mirroring.
defaultProvisionSteps :: [ProvisionStep]
defaultProvisionSteps =
  [ ProvisionStep CreateRemote "Create GitHub repo" (Just GitHubRepo)
      (Just "gh repo create hyperpolymath/{{name}} --public --source . --push") True
  , ProvisionStep ApplyRulesets "Apply branch protection rulesets" (Just GitHubRepo)
      Nothing True
  , ProvisionStep ConfigureMirroring "Set up forge mirroring" (Just GitHubMirroring)
      Nothing True
  , ProvisionStep SetSocialImage "Generate and upload social image" (Just SocialImage)
      Nothing True
  ]

-- | Ordered list of provision steps for a repo kind.
-- Steps run in order; idempotent steps can be safely re-run.
repoKindProvisionSteps :: RepoKind -> [ProvisionStep]

repoKindProvisionSteps BojCartridge =
  [ ProvisionStep CreateRemote "Create GitHub repo" (Just GitHubRepo)
      (Just "gh repo create hyperpolymath/{{name}} --public --source . --push") True
  , ProvisionStep ApplyRulesets "Apply branch protection rulesets" (Just GitHubRepo)
      Nothing True
  , ProvisionStep ConfigureMirroring "Set up forge mirroring" (Just GitHubMirroring)
      Nothing True
  , ProvisionStep RegisterCatalogue "Register in BoJ Catalogue.idr" (Just BojCatalogue)
      Nothing False  -- Requires editing Idris2 source — not idempotent
  , ProvisionStep RegisterCatalogue "Add port to TOPOLOGY.md" (Just BojCatalogue)
      Nothing True
  , ProvisionStep WireProtocol "Wire into MCP bridge tool discovery" (Just BojMcpBridge)
      Nothing False
  , ProvisionStep RegisterCi "Register Hypatia CI rules" (Just HypatiaRules)
      Nothing True
  , ProvisionStep SetSocialImage "Generate and upload social image" (Just SocialImage)
      Nothing True
  ]

repoKindProvisionSteps ProvenServer =
  [ ProvisionStep CreateRemote "Create GitHub repo" (Just GitHubRepo)
      (Just "gh repo create hyperpolymath/{{name}} --public --source . --push") True
  , ProvisionStep ApplyRulesets "Apply branch protection rulesets" (Just GitHubRepo)
      Nothing True
  , ProvisionStep ConfigureMirroring "Set up forge mirroring" (Just GitHubMirroring)
      Nothing True
  , ProvisionStep WireProtocol "Wire proven-agentic protocol" (Just ProvenServersWiring)
      Nothing False
  , ProvisionStep WireProtocol "Join Groove protocol mesh" (Just GrooveNetwork)
      Nothing False
  , ProvisionStep ProvisionDatabase "Create VeriSimDB instance" (Just VeriSimDbInstance)
      Nothing True
  , ProvisionStep RegisterCi "Register Hypatia CI rules" (Just HypatiaRules)
      Nothing True
  , ProvisionStep SetSocialImage "Generate and upload social image" (Just SocialImage)
      Nothing True
  ]

repoKindProvisionSteps EcosystemFfi      = defaultProvisionSteps
repoKindProvisionSteps LanguageTool       = defaultProvisionSteps
repoKindProvisionSteps PanllPanel         = defaultProvisionSteps
repoKindProvisionSteps NickelConfig       = defaultProvisionSteps
repoKindProvisionSteps StandardsExtension = defaultProvisionSteps
repoKindProvisionSteps GenericRsr         = defaultProvisionSteps
repoKindProvisionSteps JuliaPackage       = defaultProvisionSteps

repoKindProvisionSteps GleamService  = defaultProvisionSteps ++
  [ ProvisionStep WireProtocol "Join Groove protocol mesh" (Just GrooveNetwork) Nothing False
  , ProvisionStep ProvisionDatabase "Create VeriSimDB instance" (Just VeriSimDbInstance) Nothing True
  ]

repoKindProvisionSteps ElixirService = defaultProvisionSteps ++
  [ ProvisionStep WireProtocol "Join Groove protocol mesh" (Just GrooveNetwork) Nothing False
  , ProvisionStep ProvisionDatabase "Create VeriSimDB instance" (Just VeriSimDbInstance) Nothing True
  ]

repoKindProvisionSteps TauriApp = defaultProvisionSteps ++
  [ ProvisionStep GenerateLauncher "Generate launcher via launch-scaffolder" (Just LauncherScaffolder)
      (Just "launch-scaffolder mint --shape server-with-url --target {{path}}") True
  ]

repoKindProvisionSteps DioxusApp = defaultProvisionSteps ++
  [ ProvisionStep GenerateLauncher "Generate launcher via launch-scaffolder" (Just LauncherScaffolder)
      (Just "launch-scaffolder mint --shape background-process --target {{path}}") True
  ]

repoKindProvisionSteps RustCli = defaultProvisionSteps ++
  [ ProvisionStep GenerateLauncher "Generate launcher via launch-scaffolder" (Just LauncherScaffolder)
      (Just "launch-scaffolder mint --shape one-shot-cli --target {{path}}") True
  ]

repoKindProvisionSteps GameProject =
  [ ProvisionStep CreateRemote "Create PRIVATE GitHub repo" (Just GitHubRepo)
      (Just "gh repo create hyperpolymath/{{name}} --private --source . --push") True
  , ProvisionStep ApplyRulesets "Apply branch protection rulesets" (Just GitHubRepo)
      Nothing True
  -- No mirroring for private game repos
  , ProvisionStep GenerateLauncher "Generate launcher" (Just LauncherScaffolder)
      Nothing True
  , ProvisionStep SetSocialImage "Generate and upload social image" (Just SocialImage)
      Nothing True
  ]

repoKindProvisionSteps MonorepoMember = []  -- No standalone repo creation

-- ═══════════════════════════════════════════════════════════════════════════
-- Metadata — descriptive information for each repo kind
-- ═══════════════════════════════════════════════════════════════════════════

-- | Human-readable description of a repo kind.
repoKindDescription :: RepoKind -> Text
repoKindDescription BojCartridge       = "BoJ server cartridge — MCP tool with formally verified ABI"
repoKindDescription EcosystemFfi       = "Cross-language FFI package — Idris2 ABI + Zig FFI + per-language bindings"
repoKindDescription ProvenServer       = "Formally verified server — proven-agentic protocol + Groove + deploy"
repoKindDescription LanguageTool       = "Language tooling — tree-sitter grammar + LSP/DAP adapters"
repoKindDescription PanllPanel         = "PanLL panel module — ReScript TEA + Gossamer IPC"
repoKindDescription GleamService       = "Gleam BEAM backend service"
repoKindDescription ElixirService      = "Elixir/Phoenix backend service"
repoKindDescription TauriApp           = "Tauri 2.0 desktop/mobile app �� Rust backend + ReScript frontend"
repoKindDescription DioxusApp          = "Dioxus native app ��� pure Rust UI"
repoKindDescription JuliaPackage       = "Julia package"
repoKindDescription RustCli            = "Rust/SPARK CLI tool"
repoKindDescription StandardsExtension = "Standards monorepo extension — A2ML schema + prose spec"
repoKindDescription GameProject        = "Game (AGPL, co-developed with son)"
repoKindDescription NickelConfig       = "Nickel configuration package — contracts + exports"
repoKindDescription MonorepoMember     = "Subdirectory within an existing monorepo"
repoKindDescription GenericRsr         = "Generic RSR-compliant repository"

-- | Primary languages for a repo kind (used for template selection).
repoKindPrimaryLanguages :: RepoKind -> [Language]
repoKindPrimaryLanguages BojCartridge       = []  -- Idris2 + Zig (not in Language enum yet)
repoKindPrimaryLanguages EcosystemFfi       = []  -- Idris2 + Zig
repoKindPrimaryLanguages ProvenServer       = []  -- Idris2 + Zig
repoKindPrimaryLanguages LanguageTool       = [Rust]
repoKindPrimaryLanguages PanllPanel         = [ReScript]
repoKindPrimaryLanguages GleamService       = [Gleam]
repoKindPrimaryLanguages ElixirService      = []  -- Elixir not in Language enum yet
repoKindPrimaryLanguages TauriApp           = [Rust, ReScript]
repoKindPrimaryLanguages DioxusApp          = [Rust]
repoKindPrimaryLanguages JuliaPackage       = [Julia]
repoKindPrimaryLanguages RustCli            = [Rust]
repoKindPrimaryLanguages StandardsExtension = [Nickel]
repoKindPrimaryLanguages GameProject        = [Rust, ReScript]
repoKindPrimaryLanguages NickelConfig       = [Nickel]
repoKindPrimaryLanguages MonorepoMember     = []
repoKindPrimaryLanguages GenericRsr         = []

-- | Default license for a repo kind.
repoKindLicense :: RepoKind -> Text
repoKindLicense GameProject = "AGPL-3.0-or-later"  -- Co-dev with son
repoKindLicense _           = "PMPL-1.0-or-later"   -- Estate default
