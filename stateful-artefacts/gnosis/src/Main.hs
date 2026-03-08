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
-}

module Main (main) where

import System.Environment (getArgs)
import System.Directory (doesFileExist, getCurrentDirectory)
import System.FilePath ((</>), takeDirectory, isAbsolute)
import qualified Data.Map.Strict as Map

import Types (FlexiText(..))
import Render (render, renderWithBadges)
import SixSCMEnhanced (loadAll6SCMEnhanced, SCMContext(..))
import qualified DAX

-- | CLI options parsed from arguments.
data Options = Options
    { optRenderMode :: RenderMode
    , optSCMPath    :: Maybe FilePath
    , optCommand    :: Command
    } deriving (Show)

data RenderMode = Plain | Badges deriving (Show, Eq)

data Command
    = RenderTemplate FilePath FilePath  -- ^ template output
    | DumpContext                       -- ^ print all resolved keys
    | FetchNPM String                   -- ^ fetch npm package metadata
    | FetchCrate String                 -- ^ fetch crates.io crate metadata
    | FetchPyPI String                  -- ^ fetch PyPI package metadata
    | ShowVersion
    | ShowHelp
    deriving (Show)

-- | Parse CLI arguments into Options.
parseArgs :: [String] -> Options
parseArgs = go (Options Plain Nothing ShowHelp)
  where
    go opts [] = opts
    go opts ("--version":_) = opts { optCommand = ShowVersion }
    go opts ("--help":_) = opts { optCommand = ShowHelp }
    go opts ("--plain":rest) = go (opts { optRenderMode = Plain }) rest
    go opts ("--badges":rest) = go (opts { optRenderMode = Badges }) rest
    go opts ("--scm-path":p:rest) = go (opts { optSCMPath = Just p }) rest
    go opts ("--dump-context":rest) = go (opts { optCommand = DumpContext }) rest
    go opts ("--fetch-npm":pkg:_) = opts { optCommand = FetchNPM pkg }
    go opts ("--fetch-crate":pkg:_) = opts { optCommand = FetchCrate pkg }
    go opts ("--fetch-pypi":pkg:_) = opts { optCommand = FetchPyPI pkg }
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

-- | Main entry point.
main :: IO ()
main = do
    args <- getArgs
    let opts = parseArgs args

    case optCommand opts of
        ShowVersion ->
            putStrLn "Gnosis v1.2.0 - Stateful Artefacts Engine (6scm + DAX + Paxos-Lite)"

        ShowHelp -> do
            putStrLn "Gnosis - The Stateful Artefacts Rendering Engine"
            putStrLn ""
            putStrLn "Usage: gnosis [OPTIONS] <template> <output>"
            putStrLn "       gnosis --dump-context [--scm-path PATH]"
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
            putStrLn "Data source commands:"
            putStrLn "  --fetch-npm <pkg>    Fetch metadata from npm registry"
            putStrLn "  --fetch-crate <pkg>  Fetch metadata from crates.io"
            putStrLn "  --fetch-pypi <pkg>   Fetch metadata from PyPI"

        DumpContext -> do
            scmPath <- case optSCMPath opts of
                Just p -> return p
                Nothing -> do
                    cwd <- getCurrentDirectory
                    return (cwd </> ".machine_readable")
            putStrLn $ "Loading 6scm from: " ++ scmPath
            scmCtx <- loadAll6SCMEnhanced scmPath
            let ctx = mergedContext scmCtx
            putStrLn $ "Resolved " ++ show (Map.size ctx) ++ " keys:"
            putStrLn ""
            mapM_ (\(k, FlexiText v _) ->
                putStrLn $ "  " ++ k ++ " = " ++ show v
                ) (Map.toAscList ctx)

        FetchNPM pkg -> do
            putStrLn $ "Fetching npm metadata for: " ++ pkg
            putStrLn $ "  API: https://registry.npmjs.org/" ++ pkg
            putStrLn "  (Data source plugins require http-client; showing placeholder output)"
            putStrLn $ "  npm-name = " ++ pkg
            putStrLn "  npm-version = (requires network fetch)"
            putStrLn "  npm-license = (requires network fetch)"
            putStrLn "  npm-downloads = (requires network fetch)"

        FetchCrate pkg -> do
            putStrLn $ "Fetching crates.io metadata for: " ++ pkg
            putStrLn $ "  API: https://crates.io/api/v1/crates/" ++ pkg
            putStrLn "  (Data source plugins require http-client; showing placeholder output)"
            putStrLn $ "  crate-name = " ++ pkg
            putStrLn "  crate-version = (requires network fetch)"
            putStrLn "  crate-license = (requires network fetch)"
            putStrLn "  crate-downloads = (requires network fetch)"

        FetchPyPI pkg -> do
            putStrLn $ "Fetching PyPI metadata for: " ++ pkg
            putStrLn $ "  API: https://pypi.org/pypi/" ++ pkg ++ "/json"
            putStrLn "  (Data source plugins require http-client; showing placeholder output)"
            putStrLn $ "  pypi-name = " ++ pkg
            putStrLn "  pypi-version = (requires network fetch)"
            putStrLn "  pypi-license = (requires network fetch)"
            putStrLn "  pypi-author = (requires network fetch)"

        RenderTemplate templatePath outputPath -> do
            putStrLn "Gnosis: Stateful Artefacts Engine v1.2.0"
            putStrLn $ "  Template: " ++ templatePath
            putStrLn $ "  Output:   " ++ outputPath
            putStrLn $ "  Mode:     " ++ show (optRenderMode opts)

            -- Resolve SCM path
            scmPath <- resolveSCMPath opts templatePath
            putStrLn $ "  SCM path: " ++ scmPath

            -- Load all 6scm files with enhanced deep extraction
            scmCtx <- loadAll6SCMEnhanced scmPath
            let ctx = mergedContext scmCtx
            putStrLn $ "  Keys:     " ++ show (Map.size ctx) ++ " resolved"

            -- Read template
            templateExists <- doesFileExist templatePath
            if not templateExists
                then putStrLn $ "Error: Template not found: " ++ templatePath
                else do
                    template <- readFile templatePath

                    -- Pipeline: DAX conditionals/loops -> placeholder rendering
                    let withDAX = DAX.processTemplate ctx template
                    let result = case optRenderMode opts of
                            Plain  -> render ctx withDAX
                            Badges -> renderWithBadges ctx withDAX

                    writeFile outputPath result
                    putStrLn "Hydration complete."
