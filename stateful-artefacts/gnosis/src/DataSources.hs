{- |
Module      : DataSources
Description : Fetch package metadata from external registries
Copyright   : (c) 2025-2026 Jonathan D.A. Jewell
License     : PMPL-1.0-or-later
Maintainer  : hyperpolymath

Data source plugins that fetch metadata from npm, crates.io, and PyPI
using curl. Returns key-value pairs suitable for merging into a Gnosis
rendering context.
-}

module DataSources
    ( fetchNPM
    , fetchCrate
    , fetchPyPI
    , DataSourceResult(..)
    ) where

import System.Process (readProcess)
import System.IO (hPutStrLn, stderr)
import Control.Exception (try, SomeException)

-- | Result of a data source fetch
data DataSourceResult = DataSourceResult
    { dsKeys   :: [(String, String)]  -- ^ Key-value pairs for context
    , dsSource :: String              -- ^ Source identifier (npm, crates.io, pypi)
    } deriving (Show)

-- | Fetch package metadata from the npm registry.
--   GET https://registry.npmjs.org/<package>
fetchNPM :: String -> IO DataSourceResult
fetchNPM pkg = do
    let url = "https://registry.npmjs.org/" ++ sanitizePackageName pkg
    hPutStrLn stderr $ "Fetching npm: " ++ url
    result <- safeReadProcess "curl" ["-sL", "--max-time", "10", url] ""
    case result of
        Left err -> do
            hPutStrLn stderr $ "npm fetch failed: " ++ err
            return $ DataSourceResult [("npm-name", pkg)] "npm"
        Right json -> return $ DataSourceResult (parseNPMJson pkg json) "npm"

-- | Fetch crate metadata from crates.io.
--   GET https://crates.io/api/v1/crates/<crate>
--   Requires User-Agent header (crates.io policy).
fetchCrate :: String -> IO DataSourceResult
fetchCrate pkg = do
    let url = "https://crates.io/api/v1/crates/" ++ sanitizePackageName pkg
    hPutStrLn stderr $ "Fetching crate: " ++ url
    result <- safeReadProcess "curl"
        ["-sL", "--max-time", "10", "-H", "User-Agent: gnosis/1.0", url] ""
    case result of
        Left err -> do
            hPutStrLn stderr $ "crates.io fetch failed: " ++ err
            return $ DataSourceResult [("crate-name", pkg)] "crates.io"
        Right json -> return $ DataSourceResult (parseCrateJson pkg json) "crates.io"

-- | Fetch package metadata from PyPI.
--   GET https://pypi.org/pypi/<package>/json
fetchPyPI :: String -> IO DataSourceResult
fetchPyPI pkg = do
    let url = "https://pypi.org/pypi/" ++ sanitizePackageName pkg ++ "/json"
    hPutStrLn stderr $ "Fetching PyPI: " ++ url
    result <- safeReadProcess "curl" ["-sL", "--max-time", "10", url] ""
    case result of
        Left err -> do
            hPutStrLn stderr $ "PyPI fetch failed: " ++ err
            return $ DataSourceResult [("pypi-name", pkg)] "pypi"
        Right json -> return $ DataSourceResult (parsePyPIJson pkg json) "pypi"

-- | Safely run a process, catching exceptions
safeReadProcess :: FilePath -> [String] -> String -> IO (Either String String)
safeReadProcess cmd args input = do
    result <- try (readProcess cmd args input) :: IO (Either SomeException String)
    case result of
        Left e  -> return $ Left (show e)
        Right s -> return $ Right s

-- | Parse npm registry JSON response.
--   npm returns: {"name":"...", "dist-tags":{"latest":"..."}, "license":"...", "description":"..."}
--   Downloads require separate API: https://api.npmjs.org/downloads/point/last-month/<pkg>
parseNPMJson :: String -> String -> [(String, String)]
parseNPMJson pkg json =
    [ ("npm-name",        pkg)
    , ("npm-version",     extractJsonString "latest" json)
    , ("npm-license",     extractJsonString "license" json)
    , ("npm-description", extractJsonString "description" json)
    ]

-- | Parse crates.io JSON response.
--   crates.io returns: {"crate":{"name":"...", "max_version":"...", "downloads":N, ...}}
parseCrateJson :: String -> String -> [(String, String)]
parseCrateJson pkg json =
    [ ("crate-name",        pkg)
    , ("crate-version",     extractJsonString "max_version" json)
    , ("crate-downloads",   extractJsonNumber "downloads" json)
    , ("crate-license",     extractJsonString "license" json)
    , ("crate-description", extractJsonString "description" json)
    , ("crate-repository",  extractJsonString "repository" json)
    ]

-- | Parse PyPI JSON response.
--   PyPI returns: {"info":{"name":"...", "version":"...", "license":"...", ...}}
parsePyPIJson :: String -> String -> [(String, String)]
parsePyPIJson pkg json =
    [ ("pypi-name",            pkg)
    , ("pypi-version",         extractJsonString "version" json)
    , ("pypi-license",         extractJsonString "license" json)
    , ("pypi-summary",         extractJsonString "summary" json)
    , ("pypi-author",          extractJsonString "author" json)
    , ("pypi-requires-python", extractJsonString "requires_python" json)
    , ("pypi-home-page",       extractJsonString "home_page" json)
    ]

-- | Extract a JSON string value for a given key.
--   Looks for "key":"value" pattern. Returns empty string if not found.
extractJsonString :: String -> String -> String
extractJsonString key = findValue ("\"" ++ key ++ "\":\"")
  where
    findValue _      [] = ""
    findValue prefix str
        | prefix `isPrefixOfStr` str =
            takeWhile (/= '"') (drop (length prefix) str)
        | otherwise = findValue prefix (tail str)

-- | Extract a JSON numeric value for a given key.
--   Looks for "key":123 pattern. Returns "0" if not found.
extractJsonNumber :: String -> String -> String
extractJsonNumber key = findValue ("\"" ++ key ++ "\":")
  where
    findValue _      [] = "0"
    findValue prefix str
        | prefix `isPrefixOfStr` str =
            let rest = drop (length prefix) str
            in takeWhile (\c -> c >= '0' && c <= '9') rest
        | otherwise = findValue prefix (tail str)

-- | Check if one string is a prefix of another
isPrefixOfStr :: String -> String -> Bool
isPrefixOfStr [] _ = True
isPrefixOfStr _ [] = False
isPrefixOfStr (x:xs) (y:ys) = x == y && isPrefixOfStr xs ys

-- | Sanitize package name for URL safety (prevent injection)
sanitizePackageName :: String -> String
sanitizePackageName = filter isSafeChar
  where
    isSafeChar c = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
                || (c >= '0' && c <= '9') || c `elem` "-_.@/"
