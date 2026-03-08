{- |
Module      : Plugins.DataSources.CratesIO
Description : Fetch crates.io package metadata for template rendering
Copyright   : (c) 2025-2026 Jonathan D.A. Jewell
License     : PMPL-1.0-or-later

Data source plugin that queries the crates.io API and returns
key-value pairs suitable for injection into a Gnosis context.

Usage in templates:
  Downloads: (:crate-downloads | thousands-separator)
  Version:   (:crate-version)
  MSRV:      (:crate-msrv)
-}

module Plugins.DataSources.CratesIO
    ( fetchCrateStats
    , parseCrateResponse
    , cratesPluginName
    ) where

-- | Plugin identifier
cratesPluginName :: String
cratesPluginName = "crates-io-data-source"

-- | Fetch stats for a crate from crates.io.
--   In a full implementation this would use http-client to call:
--     https://crates.io/api/v1/crates/<crate>
--   with User-Agent header (required by crates.io API policy).
--
--   Returns key-value pairs for context injection:
--     crate-name, crate-version, crate-downloads, crate-license,
--     crate-description, crate-msrv, crate-repository
fetchCrateStats :: String -> IO [(String, String)]
fetchCrateStats crateName = do
    -- Placeholder: in production, use http-client + aeson
    -- GET https://crates.io/api/v1/crates/{crateName}
    -- Required header: User-Agent: gnosis-data-source/1.0
    putStrLn $ "crates-io-data-source: would fetch https://crates.io/api/v1/crates/" ++ crateName
    return
        [ ("crate-name",        crateName)
        , ("crate-version",     "0.0.0")
        , ("crate-downloads",   "0")
        , ("crate-license",     "unknown")
        , ("crate-description", "")
        , ("crate-msrv",        "")
        , ("crate-repository",  "")
        ]

-- | Parse a JSON response string from crates.io.
--   The crates.io API returns JSON like:
--   { "crate": { "name": "...", "max_version": "...",
--     "downloads": 12345, "description": "...",
--     "license": "MIT/Apache-2.0", "repository": "..." } }
parseCrateResponse :: String -> [(String, String)]
parseCrateResponse json =
    let extractField key = findJsonValue key json
    in  [ ("crate-name",        extractField "name")
        , ("crate-version",     extractField "max_version")
        , ("crate-downloads",   extractField "downloads")
        , ("crate-license",     extractField "license")
        , ("crate-description", extractField "description")
        , ("crate-repository",  extractField "repository")
        ]

-- | Naive JSON string value extraction for a given key.
findJsonValue :: String -> String -> String
findJsonValue _   [] = ""
findJsonValue key str =
    case findAfter ("\"" ++ key ++ "\":\"") str of
        Just rest -> takeWhile (/= '"') rest
        Nothing   ->
            -- Try numeric value: "key":123
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
