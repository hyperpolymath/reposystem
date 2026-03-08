{- |
Module      : Plugins.DataSources.PyPI
Description : Fetch PyPI package metadata for template rendering
Copyright   : (c) 2025-2026 Jonathan D.A. Jewell
License     : PMPL-1.0-or-later

Data source plugin that queries the PyPI JSON API and returns
key-value pairs suitable for injection into a Gnosis context.

Usage in templates:
  Version:   (:pypi-version)
  License:   (:pypi-license)
  Summary:   (:pypi-summary)
-}

module Plugins.DataSources.PyPI
    ( fetchPyPIStats
    , parsePyPIResponse
    , pypiPluginName
    ) where

-- | Plugin identifier
pypiPluginName :: String
pypiPluginName = "pypi-data-source"

-- | Fetch stats for a package from PyPI.
--   In a full implementation this would use http-client to call:
--     https://pypi.org/pypi/<package>/json
--
--   Returns key-value pairs for context injection:
--     pypi-name, pypi-version, pypi-license, pypi-summary,
--     pypi-author, pypi-requires-python, pypi-home-page
fetchPyPIStats :: String -> IO [(String, String)]
fetchPyPIStats packageName = do
    -- Placeholder: in production, use http-client + aeson
    -- GET https://pypi.org/pypi/{packageName}/json
    putStrLn $ "pypi-data-source: would fetch https://pypi.org/pypi/" ++ packageName ++ "/json"
    return
        [ ("pypi-name",            packageName)
        , ("pypi-version",         "0.0.0")
        , ("pypi-license",         "unknown")
        , ("pypi-summary",         "")
        , ("pypi-author",          "")
        , ("pypi-requires-python", "")
        , ("pypi-home-page",       "")
        ]

-- | Parse a JSON response string from PyPI.
--   The PyPI API returns JSON like:
--   { "info": { "name": "...", "version": "...",
--     "license": "MIT", "summary": "...",
--     "author": "...", "requires_python": ">=3.8",
--     "home_page": "..." } }
parsePyPIResponse :: String -> [(String, String)]
parsePyPIResponse json =
    let extractField key = findJsonValue key json
    in  [ ("pypi-name",            extractField "name")
        , ("pypi-version",         extractField "version")
        , ("pypi-license",         extractField "license")
        , ("pypi-summary",         extractField "summary")
        , ("pypi-author",          extractField "author")
        , ("pypi-requires-python", extractField "requires_python")
        , ("pypi-home-page",       extractField "home_page")
        ]

-- | Naive JSON string value extraction for a given key.
findJsonValue :: String -> String -> String
findJsonValue _   [] = ""
findJsonValue key str =
    case findAfter ("\"" ++ key ++ "\":\"") str of
        Just rest -> takeWhile (/= '"') rest
        Nothing   ->
            -- Try null value
            case findAfter ("\"" ++ key ++ "\":") str of
                Just rest -> takeWhile (\c -> c /= ',' && c /= '}') rest
                Nothing   -> ""

-- | Find the substring after a given prefix.
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
