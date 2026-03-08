{- |
Module      : Main
Description : Gnosis - The Stateful Artefacts Rendering Engine
Copyright   : (c) 2025-2026 Jonathan D.A. Jewell
License     : PMPL-1.0-or-later
Maintainer  : hyperpolymath

Gnosis reads Guile Scheme metadata (6scm files) and renders template
documents into static output suitable for Git forges.

Usage: gnosis [OPTIONS] <template> <output>
       gnosis --plain  README.template.md README.md
       gnosis --badges README.template.md README.md
       gnosis --scm-path /path/to/.machine_readable --plain tpl.md out.md
       gnosis --dump-context --scm-path .machine_readable
       gnosis --fetch-npm lodash
       gnosis --npm-pkg lodash --plain tpl.md out.md
-}

module Main (main) where

import System.Environment (getArgs)
import System.Directory (doesFileExist, getCurrentDirectory)
import System.FilePath ((</>), takeDirectory, isAbsolute)
import qualified Data.Map.Strict as Map

import Types (FlexiText(..), Context)
import Render (render, renderWithBadges)
import SixSCMEnhanced (loadAll6SCMEnhanced, SCMContext(..))
import DataSources (fetchNPM, fetchCrate, fetchPyPI, DataSourceResult(..))
import qualified DAX

-- | A data source to fetch and merge into context during rendering.
data DataSource
    = DSNpm String
    | DSCrate String
    | DSPyPI String
    deriving (Show)

-- | CLI options parsed from arguments.
data Options = Options
    { optRenderMode   :: RenderMode
    , optSCMPath      :: Maybe FilePath
    , optDataSources  :: [DataSource]      -- ^ Data sources to merge into context
    , optCommand      :: Command
    } deriving (Show)

data RenderMode = Plain | Badges deriving (Show, Eq)

data Command
    = RenderTemplate FilePath FilePath  -- ^ template output
    | DumpContext                       -- ^ print all resolved keys
    | FetchNPM String                   -- ^ fetch npm package metadata (standalone)
    | FetchCrate String                 -- ^ fetch crates.io crate metadata (standalone)
    | FetchPyPI String                  -- ^ fetch PyPI package metadata (standalone)
    | ShowVersion
    | ShowHelp
    deriving (Show)

-- | Parse CLI arguments into Options.
parseArgs :: [String] -> Options
parseArgs = go (Options Plain Nothing [] ShowHelp)
  where
    go opts [] = opts
    go opts ("--version":_) = opts { optCommand = ShowVersion }
    go opts ("--help":_) = opts { optCommand = ShowHelp }
    go opts ("--plain":rest) = go (opts { optRenderMode = Plain }) rest
    go opts ("--badges":rest) = go (opts { optRenderMode = Badges }) rest
    go opts ("--scm-path":p:rest) = go (opts { optSCMPath = Just p }) rest
    go opts ("--dump-context":rest) = go (opts { optCommand = DumpContext }) rest
    -- Standalone fetch commands (print and exit)
    go opts ("--fetch-npm":pkg:_) = opts { optCommand = FetchNPM pkg }
    go opts ("--fetch-crate":pkg:_) = opts { optCommand = FetchCrate pkg }
    go opts ("--fetch-pypi":pkg:_) = opts { optCommand = FetchPyPI pkg }
    -- Data sources to merge into rendering context
    go opts ("--npm-pkg":pkg:rest) =
        go (opts { optDataSources = optDataSources opts ++ [DSNpm pkg] }) rest
    go opts ("--crate-pkg":pkg:rest) =
        go (opts { optDataSources = optDataSources opts ++ [DSCrate pkg] }) rest
    go opts ("--pypi-pkg":pkg:rest) =
        go (opts { optDataSources = optDataSources opts ++ [DSPyPI pkg] }) rest
    go opts [tpl, out] = opts { optCommand = RenderTemplate tpl out }
    go opts (_:rest) = go opts rest  -- skip unknown flags

-- | Resolve SCM path: explicit flag > template's parent dir > cwd.
resolveSCMPath :: Options -> FilePath -> IO FilePath
resolveSCMPath opts templatePath = do
    case optSCMPath opts of
        Just p | isAbsolute p -> return p
        Just p -> do
            cwd <- getCurrentDirectory
            return (cwd </> p)
        Nothing -> do
            -- Look relative to template's parent directory first
            let templateDir = takeDirectory templatePath
            let candidate = templateDir </> ".machine_readable"
            exists <- doesFileExist (candidate </> "STATE.scm")
            if exists
                then return candidate
                else do
                    -- Fall back to cwd
                    cwd <- getCurrentDirectory
                    return (cwd </> ".machine_readable")

-- | Fetch all data sources and merge into a context map.
fetchDataSources :: [DataSource] -> IO Context
fetchDataSources sources = do
    results <- mapM fetchOne sources
    let allKeys = concatMap dsKeys results
    return $ Map.fromList
        [ (k, FlexiText v k) | (k, v) <- allKeys, not (null v) ]
  where
    fetchOne (DSNpm pkg)   = fetchNPM pkg
    fetchOne (DSCrate pkg) = fetchCrate pkg
    fetchOne (DSPyPI pkg)  = fetchPyPI pkg

-- | Print data source results as key-value pairs.
printDataSourceResult :: DataSourceResult -> IO ()
printDataSourceResult dsr = do
    putStrLn $ "Source: " ++ dsSource dsr
    mapM_ (\(k, v) -> putStrLn $ "  " ++ k ++ " = " ++ v) (dsKeys dsr)

-- | Main entry point.
main :: IO ()
main = do
    args <- getArgs
    let opts = parseArgs args

    case optCommand opts of
        ShowVersion ->
            putStrLn "Gnosis v1.6.0 - Stateful Artefacts Engine (6scm + DAX + Paxos-Lite)"

        ShowHelp -> do
            putStrLn "Gnosis - The Stateful Artefacts Rendering Engine"
            putStrLn ""
            putStrLn "Usage: gnosis [OPTIONS] <template> <output>"
            putStrLn "       gnosis --dump-context [--scm-path PATH]"
            putStrLn "       gnosis --fetch-npm <pkg>"
            putStrLn ""
            putStrLn "Options:"
            putStrLn "  --plain        Render placeholders as plain text (default)"
            putStrLn "  --badges       Render placeholders as Shields.io badges"
            putStrLn "  --scm-path P   Path to .machine_readable/ directory"
            putStrLn "  --dump-context Print all resolved context keys and values"
            putStrLn "  --version      Show version"
            putStrLn "  --help         Show this help"
            putStrLn ""
            putStrLn "Template syntax:"
            putStrLn "  (:key)                 Simple placeholder"
            putStrLn "  (:key | uppercase)     Placeholder with filter"
            putStrLn "  {{#if key == val}}     Conditional (==, !=, >, <, >=, <=)"
            putStrLn "  {{#else}}              Else branch in conditional"
            putStrLn "  {{#for x in list}}     Loop block"
            putStrLn "  {{@index}}             Loop iteration index (0-based)"
            putStrLn ""
            putStrLn "Filters:"
            putStrLn "  uppercase, lowercase, capitalize, thousands-separator"
            putStrLn "  relativeTime, round, emojify, slug, truncate"
            putStrLn "  strip-html, count-words, reverse"
            putStrLn ""
            putStrLn "Data source commands (standalone):"
            putStrLn "  --fetch-npm <pkg>    Fetch and display npm package metadata"
            putStrLn "  --fetch-crate <pkg>  Fetch and display crates.io crate metadata"
            putStrLn "  --fetch-pypi <pkg>   Fetch and display PyPI package metadata"
            putStrLn ""
            putStrLn "Data sources (merge into template context):"
            putStrLn "  --npm-pkg <pkg>      Add npm package data to context"
            putStrLn "  --crate-pkg <pkg>    Add crates.io crate data to context"
            putStrLn "  --pypi-pkg <pkg>     Add PyPI package data to context"
            putStrLn ""
            putStrLn "Example: gnosis --npm-pkg lodash --plain tpl.md out.md"

        DumpContext -> do
            scmPath <- case optSCMPath opts of
                Just p -> return p
                Nothing -> do
                    cwd <- getCurrentDirectory
                    return (cwd </> ".machine_readable")
            putStrLn $ "Loading 6scm from: " ++ scmPath
            scmCtx <- loadAll6SCMEnhanced scmPath
            let ctx = mergedContext scmCtx
            -- Also fetch any data sources
            dsCtx <- fetchDataSources (optDataSources opts)
            let fullCtx = Map.union dsCtx ctx  -- data sources override SCM keys
            putStrLn $ "Resolved " ++ show (Map.size fullCtx) ++ " keys:"
            putStrLn ""
            mapM_ (\(k, FlexiText v _) ->
                putStrLn $ "  " ++ k ++ " = " ++ show v
                ) (Map.toAscList fullCtx)

        FetchNPM pkg -> do
            result <- fetchNPM pkg
            printDataSourceResult result

        FetchCrate pkg -> do
            result <- fetchCrate pkg
            printDataSourceResult result

        FetchPyPI pkg -> do
            result <- fetchPyPI pkg
            printDataSourceResult result

        RenderTemplate templatePath outputPath -> do
            putStrLn "Gnosis: Stateful Artefacts Engine v1.6.0"
            putStrLn $ "  Template: " ++ templatePath
            putStrLn $ "  Output:   " ++ outputPath
            putStrLn $ "  Mode:     " ++ show (optRenderMode opts)

            -- Resolve SCM path
            scmPath <- resolveSCMPath opts templatePath
            putStrLn $ "  SCM path: " ++ scmPath

            -- Load all 6scm files with enhanced deep extraction
            scmCtx <- loadAll6SCMEnhanced scmPath
            let ctx = mergedContext scmCtx

            -- Fetch and merge data sources into context
            dsCtx <- fetchDataSources (optDataSources opts)
            let fullCtx = Map.union dsCtx ctx  -- data sources override SCM keys
            let dsCount = Map.size dsCtx
            putStrLn $ "  Keys:     " ++ show (Map.size fullCtx) ++ " resolved"
                ++ (if dsCount > 0
                    then " (" ++ show dsCount ++ " from data sources)"
                    else "")

            -- Read template
            templateExists <- doesFileExist templatePath
            if not templateExists
                then putStrLn $ "Error: Template not found: " ++ templatePath
                else do
                    template <- readFile templatePath

                    -- Pipeline: DAX conditionals/loops -> placeholder rendering
                    let withDAX = DAX.processTemplate fullCtx template
                    let result = case optRenderMode opts of
                            Plain  -> render fullCtx withDAX
                            Badges -> renderWithBadges fullCtx withDAX

                    writeFile outputPath result
                    putStrLn "Hydration complete."
