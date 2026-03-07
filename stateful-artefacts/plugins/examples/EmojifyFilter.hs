{- |
Module      : Plugins.Filters.Emojify
Description : Example filter plugin that adds emoji to values
Copyright   : (c) 2025-2026 Jonathan D.A. Jewell
License     : PMPL-1.0-or-later
Maintainer  : hyperpolymath

Adds emoji prefixes to common phase and status values.
-}

module Plugins.Filters.Emojify
    ( plugin
    , emojify
    ) where

import PluginAPI

-- | The emojify filter function
emojify :: String -> String
emojify "alpha"       = "🔬 alpha"
emojify "beta"        = "🧪 beta"
emojify "stable"      = "✅ stable"
emojify "production"  = "🚀 production"
emojify "deprecated"  = "⚠️  deprecated"
emojify "archived"    = "📦 archived"
emojify "testing"     = "🧪 testing"
emojify "development" = "🔨 development"
emojify "active"      = "✨ active"
emojify "inactive"    = "💤 inactive"
emojify s             = s  -- Pass through unknown values

-- | Plugin definition
plugin :: FilterPlugin
plugin = FilterPlugin
    { filterMetadata = PluginMetadata
        { pluginName = "emojify"
        , pluginVersion = "1.0.0"
        , pluginDescription = "Adds emoji prefixes to phase and status values"
        , pluginAuthor = "Gnosis Team"
        , pluginLicense = "PMPL-1.0-or-later"
        }
    , filterFunction = emojify
    }
