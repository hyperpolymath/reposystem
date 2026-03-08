{- |
Module      : PluginLoader
Description : Plugin discovery, loading, and registration
Copyright   : (c) 2025-2026 Jonathan D.A. Jewell
License     : PMPL-1.0-or-later
Maintainer  : hyperpolymath

Discovers plugins from the registry manifest, loads enabled plugins,
and registers their filter/renderer functions into the gnosis pipeline.
-}

module PluginLoader
    ( PluginRegistry(..)
    , loadRegistry
    , lookupFilter
    , applyPluginFilter
    , registeredFilterNames
    , emptyRegistry
    ) where

import qualified Data.Map.Strict as Map

-- | Registry of loaded plugins, indexed by name
data PluginRegistry = PluginRegistry
    { registryFilters   :: !(Map.Map String (String -> String))
    , registryRenderers :: !(Map.Map String (Map.Map String String -> String))
    }

-- | Empty registry with no plugins
emptyRegistry :: PluginRegistry
emptyRegistry = PluginRegistry
    { registryFilters = Map.empty
    , registryRenderers = Map.empty
    }

-- | Load the default plugin registry with built-in plugins
loadRegistry :: PluginRegistry
loadRegistry = PluginRegistry
    { registryFilters = Map.fromList
        [ ("emojify", emojifyFilter)
        , ("slug", slugFilter)
        , ("truncate", truncateFilter)
        , ("reverse", reverseFilter)
        , ("strip-html", stripHtmlFilter)
        , ("count-words", countWordsFilter)
        ]
    , registryRenderers = Map.fromList
        [ ("json", jsonRenderer)
        , ("csv", csvRenderer)
        ]
    }

-- | Look up a filter by name in the registry
lookupFilter :: String -> PluginRegistry -> Maybe (String -> String)
lookupFilter name reg = Map.lookup name (registryFilters reg)

-- | Apply a plugin filter, returning the original value if not found
applyPluginFilter :: String -> PluginRegistry -> String -> String
applyPluginFilter name reg value =
    case lookupFilter name reg of
        Just f  -> f value
        Nothing -> value

-- | List all registered filter names
registeredFilterNames :: PluginRegistry -> [String]
registeredFilterNames = Map.keys . registryFilters

-- ============================================================================
-- Built-in Filter Plugins
-- ============================================================================

-- | Add emoji prefixes to common phase/status values
emojifyFilter :: String -> String
emojifyFilter "alpha"       = "🔬 alpha"
emojifyFilter "beta"        = "🧪 beta"
emojifyFilter "stable"      = "✅ stable"
emojifyFilter "production"  = "🚀 production"
emojifyFilter "deprecated"  = "⚠️  deprecated"
emojifyFilter "archived"    = "📦 archived"
emojifyFilter "active"      = "✨ active"
emojifyFilter "inactive"    = "💤 inactive"
emojifyFilter "complete"    = "✅ complete"
emojifyFilter "planned"     = "📋 planned"
emojifyFilter "scaffolded"  = "🏗️  scaffolded"
emojifyFilter "designed"    = "📐 designed"
emojifyFilter s             = s

-- | Convert to URL-safe slug
slugFilter :: String -> String
slugFilter = map slugChar . filter validSlugChar
  where
    slugChar ' ' = '-'
    slugChar c   = toLowerChar c
    validSlugChar c = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
                   || (c >= '0' && c <= '9') || c == ' ' || c == '-' || c == '_'
    toLowerChar c
        | c >= 'A' && c <= 'Z' = toEnum (fromEnum c + 32)
        | otherwise = c

-- | Truncate to 50 characters with ellipsis
truncateFilter :: String -> String
truncateFilter s
    | length s <= 50 = s
    | otherwise = take 47 s ++ "..."

-- | Reverse a string
reverseFilter :: String -> String
reverseFilter = reverse

-- | Strip HTML tags (simple angle-bracket removal)
stripHtmlFilter :: String -> String
stripHtmlFilter = go False
  where
    go _ [] = []
    go True  ('>':rest)  = go False rest
    go True  (_:rest)    = go True rest
    go False ('<':rest)  = go True rest
    go False (c:rest)    = c : go False rest

-- | Count words in a string
countWordsFilter :: String -> String
countWordsFilter = show . length . words

-- ============================================================================
-- Built-in Renderer Plugins
-- ============================================================================

-- | Render context as JSON
jsonRenderer :: Map.Map String String -> String
jsonRenderer ctx =
    "{\n" ++ Map.foldlWithKey' renderPair "" ctx ++ "}"
  where
    renderPair acc k v =
        acc ++ "  " ++ show k ++ ": " ++ show v ++ ",\n"

-- | Render context as CSV
csvRenderer :: Map.Map String String -> String
csvRenderer ctx =
    "key,value\n" ++ Map.foldlWithKey' renderRow "" ctx
  where
    renderRow acc k v = acc ++ escapeCSV k ++ "," ++ escapeCSV v ++ "\n"
    escapeCSV s
        | any (\c -> c == ',' || c == '"' || c == '\n') s =
            "\"" ++ concatMap (\c -> if c == '"' then "\"\"" else [c]) s ++ "\""
        | otherwise = s
