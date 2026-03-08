{- |
Module      : Plugins.DataSources.NPM
Description : Fetch npm package metadata for template rendering
Copyright   : (c) 2025-2026 Jonathan D.A. Jewell
License     : PMPL-1.0-or-later

Data source plugin that queries the npm registry API and returns
key-value pairs suitable for injection into a Gnosis context.

Usage in templates:
  Downloads: (:npm-downloads | thousands-separator)
  Version:   (:npm-version)
  License:   (:npm-license)
-}

module Plugins.DataSources.NPM
    ( fetchNPMStats
    , parseNPMResponse
    , npmPluginName
    ) where

-- | Plugin identifier
npmPluginName :: String
npmPluginName = "npm-data-source"

-- | Fetch stats for an npm package.
--   In a full implementation this would use http-client to call:
--     https://registry.npmjs.org/<package>
--   and parse the JSON response.
--
--   Returns key-value pairs for context injection:
--     npm-name, npm-version, npm-license, npm-description,
--     npm-downloads (requires separate API call to npm download counts)
fetchNPMStats :: String -> IO [(String, String)]
fetchNPMStats packageName = do
    -- Placeholder: in production, use http-client + aeson
    -- GET https://registry.npmjs.org/{packageName}
    -- GET https://api.npmjs.org/downloads/point/last-month/{packageName}
    putStrLn $ "npm-data-source: would fetch https://registry.npmjs.org/" ++ packageName
    return
        [ ("npm-name",        packageName)
        , ("npm-version",     "0.0.0")
        , ("npm-license",     "unknown")
        , ("npm-description", "")
        , ("npm-downloads",   "0")
        ]

-- | Parse a JSON response string from the npm registry.
--   Extracts: name, version, license, description from
--   the dist-tags.latest version entry.
parseNPMResponse :: String -> [(String, String)]
parseNPMResponse json =
    -- Simple extraction for common fields.
    -- Production version would use aeson for proper JSON parsing.
    let extractField key = findJsonValue key json
    in  [ ("npm-name",        extractField "name")
        , ("npm-version",     extractField "version")
        , ("npm-license",     extractField "license")
        , ("npm-description", extractField "description")
        ]

-- | Naive JSON string value extraction for a given key.
--   Looks for "key":"value" pattern. Not suitable for nested objects.
findJsonValue :: String -> String -> String
findJsonValue _   [] = ""
findJsonValue key str =
    case findAfter ("\"" ++ key ++ "\":\"") str of
        Just rest -> takeWhile (/= '"') rest
        Nothing   -> ""

-- | Find the substring after a given prefix in a string.
findAfter :: String -> String -> Maybe String
findAfter _      [] = Nothing
findAfter prefix str
    | prefix `isPrefixOfList` str = Just (drop (length prefix) str)
    | otherwise                   = findAfter prefix (tail str)

-- | Check if one list is a prefix of another.
isPrefixOfList :: Eq a => [a] -> [a] -> Bool
isPrefixOfList []     _      = True
isPrefixOfList _      []     = False
isPrefixOfList (x:xs) (y:ys) = x == y && isPrefixOfList xs ys
