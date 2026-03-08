{- |
Module      : PluginAPI
Description : Core plugin system API definitions
Copyright   : (c) 2025-2026 Jonathan D.A. Jewell
License     : PMPL-1.0-or-later
Maintainer  : hyperpolymath

Defines the interfaces for all plugin types:
- FilterPlugin: Transform values during rendering
- DataSourcePlugin: Fetch external data
- RendererPlugin: Custom output formats
- AIAgentPlugin: Analyze and suggest updates
-}

module PluginAPI
    ( -- * Plugin Types
      FilterPlugin(..)
    , DataSourcePlugin(..)
    , RendererPlugin(..)
    , AIAgentPlugin(..)
      -- * AI Suggestion Types
    , Suggestion(..)
    , SuggestionType(..)
    , RepoData(..)
      -- * Plugin Metadata
    , PluginMetadata(..)
    , PluginType(..)
    ) where

import qualified Data.Map.Strict as Map
import Data.Time (UTCTime)

-- | Plugin metadata shared by all plugin types
data PluginMetadata = PluginMetadata
    { pluginName        :: !String
    , pluginVersion     :: !String
    , pluginDescription :: !String
    , pluginAuthor      :: !String
    , pluginLicense     :: !String
    } deriving (Show, Eq)

-- | Types of plugins supported
data PluginType
    = FilterType
    | DataSourceType
    | RendererType
    | AIAgentType
    deriving (Show, Eq)

-- | Filter plugin: transforms string values
data FilterPlugin = FilterPlugin
    { filterMetadata :: !PluginMetadata
    , filterFunction :: !(String -> String)
    }

-- | Data source plugin: fetches external data
data DataSourcePlugin = DataSourcePlugin
    { dataSourceMetadata :: !PluginMetadata
    , dataSourceName     :: !String  -- Name of the data source (npm, github, etc.)
    , fetchData          :: !(Map.Map String String -> IO [(String, String)])
      -- ^ Takes config parameters, returns key-value pairs
    }

-- | Renderer plugin: custom output formats
data RendererPlugin = RendererPlugin
    { rendererMetadata :: !PluginMetadata
    , rendererFormat   :: !String  -- Output format name (json, yaml, etc.)
    , renderFunction   :: !(Map.Map String String -> String)
      -- ^ Takes context, returns formatted output
    }

-- | AI Agent plugin: analyzes data and suggests updates
data AIAgentPlugin = AIAgentPlugin
    { agentMetadata     :: !PluginMetadata
    , agentName         :: !String
    , analyzeFunction   :: !(RepoData -> [Suggestion])
      -- ^ Analyzes repository data and returns suggestions
    }

-- | Repository data for AI analysis
data RepoData = RepoData
    { repoName          :: !String
    , repoOwner         :: !String
    , repoStars         :: !Int
    , repoForks         :: !Int
    , repoOpenIssues    :: !Int
    , repoOpenPRs       :: !Int
    , repoLastCommit    :: !(Maybe UTCTime)
    , repoCreatedAt     :: !UTCTime
    , repoUpdatedAt     :: !UTCTime
    , repoPrimaryLang   :: !String
    , repoLicense       :: !(Maybe String)
    , repoTopics        :: ![String]
    , repoHasWiki       :: !Bool
    , repoHasIssues     :: !Bool
    , currentPhase      :: !String  -- Current phase from STATE.scm
    , currentHealth     :: !Int     -- Current health score
    } deriving (Show, Eq)

-- | Type of suggestion
data SuggestionType
    = PhaseTransition      -- Suggest phase change
    | HealthWarning        -- Warn about health issues
    | MetadataUpdate       -- Suggest metadata update
    | FieldAddition        -- Suggest new field
    | FieldRemoval         -- Suggest field removal
    deriving (Show, Eq)

-- | Suggestion from AI agent
data Suggestion = Suggestion
    { suggestionType   :: !SuggestionType
    , suggestionKey    :: !String      -- Field to update (e.g., "phase")
    , suggestionValue  :: !String      -- New value
    , suggestionReason :: !String      -- Human-readable explanation
    , suggestionScore  :: !Int         -- Confidence score (0-100)
    } deriving (Show, Eq)
