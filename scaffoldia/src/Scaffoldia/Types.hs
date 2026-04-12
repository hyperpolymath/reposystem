{- SPDX-License-Identifier: MPL-2.0 -}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

{- |
Module      : Scaffoldia.Types
Description : Core types for Scaffoldia
Copyright   : (c) Hyperpolymath, 2026
License     : MPL-2.0
-}

module Scaffoldia.Types
  ( -- * Template Types
    Template(..)
  , TemplateMetadata(..)
  , TemplateFile(..)
  , FileType(..)
    -- * Project Types
  , Project(..)
  , ProjectConfig(..)
  , Language(..)
    -- * Validation Types
  , ValidationResult(..)
  , ValidationError(..)
  , Severity(..)
    -- * Registry Types
  , Registry(..)
  , RegistryEntry(..)
    -- * Repo Kind Taxonomy
  , RepoKind(..)
  , repoKindId
    -- * Layers (what a repo is made of)
  , Layer(..)
  , layerId
    -- * Estate Connections (what a repo wires into)
  , IntegrationTarget(..)
  , Integration(..)
    -- * Provision Steps (post-mint estate wiring)
  , ProvisionStep(..)
  , ProvisionKind(..)
    -- * Minting Prompts (what to ask the user)
  , MintPrompt(..)
  , PromptKind(..)
  ) where

import Data.Aeson (FromJSON, ToJSON)
import Data.Text (Text)
import GHC.Generics (Generic)

-- | A template definition
data Template = Template
  { templateId          :: Text
  , templateMetadata    :: TemplateMetadata
  , templateFiles       :: [TemplateFile]
  , templateDependencies :: [Text]
  } deriving (Show, Eq, Generic)

instance FromJSON Template
instance ToJSON Template

-- | Template metadata
data TemplateMetadata = TemplateMetadata
  { metaName        :: Text
  , metaDescription :: Text
  , metaVersion     :: Text
  , metaAuthor      :: Text
  , metaLicense     :: Text
  , metaLanguages   :: [Language]
  , metaCategory    :: Text
  , metaTags        :: [Text]
  } deriving (Show, Eq, Generic)

instance FromJSON TemplateMetadata
instance ToJSON TemplateMetadata

-- | A file within a template
data TemplateFile = TemplateFile
  { filePath     :: FilePath
  , fileType     :: FileType
  , fileTemplate :: Text  -- Nickel template content
  , fileRequired :: Bool
  } deriving (Show, Eq, Generic)

instance FromJSON TemplateFile
instance ToJSON TemplateFile

-- | File type classification
data FileType
  = SourceFile
  | ConfigFile
  | DocumentationFile
  | BuildFile
  | CIFile
  | LicenseFile
  | OtherFile
  deriving (Show, Eq, Generic, Enum, Bounded)

instance FromJSON FileType
instance ToJSON FileType

-- | A project being scaffolded
data Project = Project
  { projectName     :: Text
  , projectPath     :: FilePath
  , projectConfig   :: ProjectConfig
  , projectTemplate :: Text  -- Template ID
  } deriving (Show, Eq, Generic)

instance FromJSON Project
instance ToJSON Project

-- | Project configuration
data ProjectConfig = ProjectConfig
  { configLanguage    :: Language
  , configLicense     :: Text
  , configAuthor      :: Text
  , configDescription :: Text
  , configFeatures    :: [Text]
  } deriving (Show, Eq, Generic)

instance FromJSON ProjectConfig
instance ToJSON ProjectConfig

-- | Supported languages
data Language
  = Rust
  | Haskell
  | ReScript
  | Nickel
  | Gleam
  | OCaml
  | Ada
  | Julia
  | Scheme
  | Bash
  deriving (Show, Eq, Generic, Enum, Bounded)

instance FromJSON Language
instance ToJSON Language

-- | Validation result
data ValidationResult
  = ValidationSuccess
  | ValidationFailure [ValidationError]
  deriving (Show, Eq)

-- | A validation error
data ValidationError = ValidationError
  { errorSeverity :: Severity
  , errorMessage  :: Text
  , errorLocation :: Maybe FilePath
  , errorSuggestion :: Maybe Text
  } deriving (Show, Eq, Generic)

instance FromJSON ValidationError
instance ToJSON ValidationError

-- | Error severity levels
data Severity
  = Info
  | Warning
  | Error
  | Critical
  deriving (Show, Eq, Ord, Generic, Enum, Bounded)

instance FromJSON Severity
instance ToJSON Severity

-- | Template registry
data Registry = Registry
  { registryVersion :: Text
  , registryEntries :: [RegistryEntry]
  } deriving (Show, Eq, Generic)

instance FromJSON Registry
instance ToJSON Registry

-- | A registry entry
data RegistryEntry = RegistryEntry
  { entryId       :: Text
  , entryMetadata :: TemplateMetadata
  , entryPath     :: FilePath
  , entryChecksum :: Text  -- SHA256
  } deriving (Show, Eq, Generic)

instance FromJSON RegistryEntry
instance ToJSON RegistryEntry

-- ═══════════════════════════════════════════════════════════════════════════
-- Repo Kind Taxonomy
--
-- A RepoKind is not a template — it is a *category* of repository that
-- implies a specific combination of layers, estate connections, and
-- provisioning steps.  Templates are the file-level building blocks;
-- RepoKind is the architectural level above.
--
-- Example: RepoKind 'BojCartridge' implies layers [Idris2Abi, ZigFfi,
-- NickelManifest, DenoAdapter, PanllPanels] and connections to the BoJ
-- catalogue, TOPOLOGY port map, and MCP bridge.
-- ═══════════════════════════════════════════════════════════════════════════

-- | The kinds of repository in the hyperpolymath estate.
--
-- Each constructor represents a distinct architectural pattern with its own
-- required layers, connections, and provisioning sequence.  Adding a new
-- repo kind means defining what it needs in 'Scaffoldia.RepoKind'.
data RepoKind
  = BojCartridge         -- ^ BoJ server cartridge (Idris2 ABI + Zig FFI + Nickel manifest + Deno adapter)
  | EcosystemFfi         -- ^ Cross-language FFI package (Idris2 ABI + Zig FFI + per-language bindings)
  | ProvenServer         -- ^ Formally verified server (proven-agentic protocol + Groove + deploy)
  | LanguageTool          -- ^ Language tooling (tree-sitter + LSP/DAP adapter)
  | PanllPanel           -- ^ PanLL panel module (ReScript TEA + panel manifest + Gossamer IPC)
  | GleamService         -- ^ Gleam BEAM service (Groove client + BoJ registration + Fly deploy)
  | ElixirService        -- ^ Elixir/Phoenix service (Groove client + BoJ registration + Fly deploy)
  | TauriApp             -- ^ Tauri 2.0 desktop/mobile app (Rust + ReScript + launcher + .desktop)
  | DioxusApp            -- ^ Dioxus native app (pure Rust + launcher)
  | JuliaPackage         -- ^ Julia package (Project.toml + registry + ecosystem position)
  | RustCli              -- ^ Rust/SPARK CLI tool (Cargo workspace + launcher + OPSM integration)
  | StandardsExtension   -- ^ Standards monorepo extension (A2ML schema + prose spec)
  | GameProject          -- ^ Game (AGPL, co-dev with son — IDApTIK/ASS pattern)
  | NickelConfig         -- ^ Nickel configuration package (contracts + exports)
  | MonorepoMember       -- ^ Subdirectory within an existing monorepo (not a standalone repo)
  | GenericRsr           -- ^ Generic RSR-compliant repo (baseline template only)
  deriving (Show, Eq, Generic, Enum, Bounded)

instance FromJSON RepoKind
instance ToJSON RepoKind

-- | Machine-readable identifier for a repo kind (used in registry lookups).
repoKindId :: RepoKind -> Text
repoKindId BojCartridge       = "boj-cartridge"
repoKindId EcosystemFfi       = "ecosystem-ffi"
repoKindId ProvenServer       = "proven-server"
repoKindId LanguageTool       = "language-tool"
repoKindId PanllPanel         = "panll-panel"
repoKindId GleamService       = "gleam-service"
repoKindId ElixirService      = "elixir-service"
repoKindId TauriApp           = "tauri-app"
repoKindId DioxusApp          = "dioxus-app"
repoKindId JuliaPackage       = "julia-package"
repoKindId RustCli            = "rust-cli"
repoKindId StandardsExtension = "standards-extension"
repoKindId GameProject        = "game-project"
repoKindId NickelConfig       = "nickel-config"
repoKindId MonorepoMember     = "monorepo-member"
repoKindId GenericRsr         = "generic-rsr"

-- ═══════════════════════════════════════════════════════════════════════════
-- Layers — the building blocks a repo is made of
-- ═══════════════════════════════════════════════════════════════════════════

-- | A layer is a structural component that a repo kind requires.
-- Multiple repo kinds can share the same layer (e.g. many kinds need
-- Idris2Abi + ZigFfi).
data Layer
  -- ABI / FFI
  = Idris2Abi            -- ^ src/abi/*.idr — formal interface definitions
  | ZigFfi               -- ^ ffi/zig/ — C-ABI compatible implementation
  | CHeaders             -- ^ generated/abi/*.h — auto-generated C bridge
  | LanguageBindings      -- ^ bindings/<lang>/ — per-language wrappers
  -- Manifest / Config
  | NickelManifest       -- ^ *.ncl source-of-truth config (exported to JSON)
  | A2mlData             -- ^ .machine_readable/ A2ML checkpoint files
  | NickelContracts      -- ^ Nickel type contracts for validation
  -- Adapters / Handlers
  | DenoAdapter          -- ^ mod.js — Deno/JS tool handler
  | ZigAdapter           -- ^ adapter/*.zig — REST/gRPC/GraphQL adapter
  -- UI / Panels
  | PanllPanels          -- ^ panels/ — PanLL panel definitions + manifest.json
  | ReScriptTea          -- ^ ReScript TEA module (model/update/view)
  | GossamerIpc          -- ^ Gossamer IPC handler registration
  -- Protocol / Comms
  | GrooveEndpoint       -- ^ Groove protocol endpoint definition
  | GrooveClient         -- ^ Groove client integration
  | ProvenProtocol       -- ^ proven-agentic protocol definition
  -- Build / Deploy
  | CargoWorkspace       -- ^ Cargo.toml workspace (Rust/SPARK)
  | CabalPackage         -- ^ *.cabal (Haskell)
  | GleamToml            -- ^ gleam.toml
  | MixProject           -- ^ mix.exs (Elixir)
  | JuliaProject         -- ^ Project.toml (Julia)
  | DenoJson             -- ^ deno.json imports
  | TauriConfig          -- ^ tauri.conf.json + Cargo workspace
  -- CI / Infra
  | RsrWorkflows         -- ^ .github/workflows/ (17 standard workflows)
  | Containerfile        -- ^ Containerfile (Chainguard base, Podman)
  | FlyDeploy            -- ^ fly.toml deployment config
  | LauncherScript       -- ^ launcher.sh + .desktop file (via launch-scaffolder)
  -- Docs
  | ReadmeAdoc           -- ^ README.adoc
  | ExplainmeAdoc        -- ^ EXPLAINME.adoc
  | TechnicalReport      -- ^ *-REPORT.adoc
  | SecurityMd           -- ^ SECURITY.md
  -- Grammar / Language
  | TreeSitterGrammar    -- ^ tree-sitter grammar definition
  | LspAdapter           -- ^ LSP server/adapter
  | DapAdapter           -- ^ DAP debug adapter
  deriving (Show, Eq, Generic, Enum, Bounded)

instance FromJSON Layer
instance ToJSON Layer

-- | Machine-readable identifier for a layer.
layerId :: Layer -> Text
layerId Idris2Abi         = "idris2-abi"
layerId ZigFfi            = "zig-ffi"
layerId CHeaders          = "c-headers"
layerId LanguageBindings  = "language-bindings"
layerId NickelManifest    = "nickel-manifest"
layerId A2mlData          = "a2ml-data"
layerId NickelContracts   = "nickel-contracts"
layerId DenoAdapter       = "deno-adapter"
layerId ZigAdapter        = "zig-adapter"
layerId PanllPanels       = "panll-panels"
layerId ReScriptTea       = "rescript-tea"
layerId GossamerIpc       = "gossamer-ipc"
layerId GrooveEndpoint    = "groove-endpoint"
layerId GrooveClient      = "groove-client"
layerId ProvenProtocol    = "proven-protocol"
layerId CargoWorkspace    = "cargo-workspace"
layerId CabalPackage      = "cabal-package"
layerId GleamToml         = "gleam-toml"
layerId MixProject        = "mix-project"
layerId JuliaProject      = "julia-project"
layerId DenoJson          = "deno-json"
layerId TauriConfig       = "tauri-config"
layerId RsrWorkflows      = "rsr-workflows"
layerId Containerfile     = "containerfile"
layerId FlyDeploy         = "fly-deploy"
layerId LauncherScript    = "launcher-script"
layerId ReadmeAdoc        = "readme-adoc"
layerId ExplainmeAdoc     = "explainme-adoc"
layerId TechnicalReport   = "technical-report"
layerId SecurityMd        = "security-md"
layerId TreeSitterGrammar = "tree-sitter-grammar"
layerId LspAdapter        = "lsp-adapter"
layerId DapAdapter        = "dap-adapter"

-- ═══════════════════════════════════════════════════════════════════════════
-- Estate Connections — what external systems a repo wires into
-- ═══════════════════════════════════════════════════════════════════════════

-- | An estate system that a repo can integrate with.
data IntegrationTarget
  = BojCatalogue         -- ^ Register as a BoJ cartridge (Catalogue.idr + TOPOLOGY.md)
  | BojMcpBridge         -- ^ Wire into the MCP bridge tool discovery
  | PanllRegistry        -- ^ Register panels in PanLL workspace
  | GrooveNetwork        -- ^ Join the Groove protocol mesh
  | ProvenServersWiring  -- ^ Wire a proven-agentic protocol
  | LauncherScaffolder   -- ^ Generate a launcher via launch-scaffolder
  | EcosystemRegistry    -- ^ Register in ecosystem position (developer-ecosystem)
  | GitHubRepo           -- ^ Create GitHub repo, apply rulesets, configure mirroring
  | GitHubMirroring      -- ^ Set up hub-and-spoke mirror to GitLab/Bitbucket/etc.
  | VeriSimDbInstance     -- ^ Provision a per-project VeriSimDB instance
  | HypatiaRules         -- ^ Register project-specific Hypatia CI rules
  | SocialImage          -- ^ Generate and set the GitHub social/Open Graph image
  | OpsManager           -- ^ Register in OPSM for runtime management
  deriving (Show, Eq, Generic, Enum, Bounded)

instance FromJSON IntegrationTarget
instance ToJSON IntegrationTarget

-- | A concrete integration: a target + configuration for how to wire it.
data Integration = Integration
  { integTarget      :: IntegrationTarget
  , integRequired    :: Bool       -- ^ True = mandatory for this repo kind, False = optional
  , integDescription :: Text       -- ^ Human-readable explanation for the minting prompt
  , integAutomatic   :: Bool       -- ^ True = Scaffoldia can do this unattended
  } deriving (Show, Eq, Generic)

instance FromJSON Integration
instance ToJSON Integration

-- ═══════════════════════════════════════════════════════════════════════════
-- Provision Steps — what happens after minting
-- ═══════════════════════════════════════════════════════════════════════════

-- | What kind of provisioning action this is.
data ProvisionKind
  = CreateRemote        -- ^ Create the GitHub repo
  | ApplyRulesets       -- ^ Apply branch protection + rulesets
  | ConfigureMirroring  -- ^ Set up forge mirroring
  | RegisterCatalogue   -- ^ Register in a catalogue (BoJ, PanLL, ecosystem)
  | WireProtocol        -- ^ Connect a Groove/proven-agentic endpoint
  | GenerateLauncher    -- ^ Run launch-scaffolder mint
  | SetSocialImage      -- ^ Upload social/OG image to GitHub
  | ProvisionDatabase   -- ^ Create a VeriSimDB instance
  | RegisterCi          -- ^ Wire Hypatia rules or custom CI
  | CustomStep          -- ^ Arbitrary user-defined step
  deriving (Show, Eq, Generic, Enum, Bounded)

instance FromJSON ProvisionKind
instance ToJSON ProvisionKind

-- | A single post-mint provisioning step.
data ProvisionStep = ProvisionStep
  { provKind        :: ProvisionKind
  , provDescription :: Text         -- ^ Human-readable description
  , provTarget      :: Maybe IntegrationTarget  -- ^ Which integration this serves
  , provCommand     :: Maybe Text   -- ^ Shell command to execute (Nothing = interactive)
  , provIdempotent  :: Bool         -- ^ Safe to re-run?
  } deriving (Show, Eq, Generic)

instance FromJSON ProvisionStep
instance ToJSON ProvisionStep

-- ═══════════════════════════════════════════════════════════════════════════
-- Minting Prompts — what Scaffoldia asks the user during repo creation
-- ═══════════════════════════════════════════════════════════════════════════

-- | What kind of answer a prompt expects.
data PromptKind
  = FreeText             -- ^ Open text input (e.g. repo name, description)
  | SingleChoice [Text]  -- ^ Pick one from a list (e.g. domain, license)
  | MultiChoice [Text]   -- ^ Pick many from a list (e.g. target languages for bindings)
  | YesNo                -- ^ Boolean (e.g. "would you like a social image now?")
  | PortNumber           -- ^ Numeric port (validated against TOPOLOGY.md)
  deriving (Show, Eq, Generic)

instance FromJSON PromptKind
instance ToJSON PromptKind

-- | A question Scaffoldia asks during minting.
data MintPrompt = MintPrompt
  { promptId       :: Text         -- ^ Machine-readable key (e.g. "port", "domain")
  , promptQuestion :: Text         -- ^ Human-readable question
  , promptKind     :: PromptKind   -- ^ What kind of answer
  , promptDefault  :: Maybe Text   -- ^ Default value (Nothing = required)
  , promptLayer    :: Maybe Layer  -- ^ Which layer this configures (Nothing = general)
  } deriving (Show, Eq, Generic)

instance FromJSON MintPrompt
instance ToJSON MintPrompt
