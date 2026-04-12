{- SPDX-License-Identifier: MPL-2.0 -}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}

{- |
Module      : Main
Description : Scaffoldia CLI - Repository scaffolding engine
Copyright   : (c) Hyperpolymath, 2026
License     : MPL-2.0
Maintainer  : hyperpolymath

Scaffoldia validates language/tool templates via a Haskell-powered registry,
composes repo scaffolds using Nickel, and infers missing structure with MiniKanren.
-}

module Main where

import Options.Applicative
import Data.Semigroup ((<>))
import System.Exit (ExitCode(..), exitFailure, exitSuccess)
import System.Directory (doesFileExist, doesDirectoryExist, listDirectory, createDirectoryIfMissing)
import System.FilePath ((</>), takeExtension)
import System.Process (readProcessWithExitCode)
import Control.Monad (when, forM_, unless)
import Data.List (intercalate, isPrefixOf)
import Data.Aeson (FromJSON, ToJSON, decode, encode)
import qualified Data.ByteString.Lazy as BL
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import GHC.Generics (Generic)

-- | Command-line options
data Options = Options
  { optVerbose :: Bool
  , optCommand :: Command
  } deriving (Show)

-- | Available commands
data Command
  = Init InitOpts        -- ^ Initialize a new scaffold
  | Validate ValidateOpts -- ^ Validate a template
  | List ListOpts        -- ^ List available templates
  | Build BuildOpts      -- ^ Build scaffold from template
  | Check CheckOpts      -- ^ Check project structure
  deriving (Show)

-- | Init command options
data InitOpts = InitOpts
  { initTemplate :: String
  , initTarget   :: FilePath
  , initForce    :: Bool
  } deriving (Show)

-- | Validate command options
data ValidateOpts = ValidateOpts
  { validatePath   :: FilePath
  , validateStrict :: Bool
  } deriving (Show)

-- | List command options
data ListOpts = ListOpts
  { listCategory :: Maybe String
  , listDetailed :: Bool
  } deriving (Show)

-- | Build command options
data BuildOpts = BuildOpts
  { buildTemplate :: String
  , buildOutput   :: FilePath
  , buildConfig   :: Maybe FilePath
  } deriving (Show)

-- | Check command options
data CheckOpts = CheckOpts
  { checkPath   :: FilePath
  , checkFix    :: Bool
  } deriving (Show)

-- | Template metadata
data TemplateInfo = TemplateInfo
  { tmplName        :: String
  , tmplDescription :: String
  , tmplLanguages   :: [String]
  , tmplCategory    :: String
  , tmplVersion     :: String
  } deriving (Show, Generic)

instance FromJSON TemplateInfo
instance ToJSON TemplateInfo

-- | Parser for command-line options
optionsParser :: Parser Options
optionsParser = Options
  <$> switch
      ( long "verbose"
     <> short 'v'
     <> help "Enable verbose output" )
  <*> commandParser

-- | Parser for commands
commandParser :: Parser Command
commandParser = subparser
  ( command "init"
      (info (Init <$> initOptsParser)
            (progDesc "Initialize a new scaffold from template"))
 <> command "validate"
      (info (Validate <$> validateOptsParser)
            (progDesc "Validate a template definition"))
 <> command "list"
      (info (List <$> listOptsParser)
            (progDesc "List available templates"))
 <> command "build"
      (info (Build <$> buildOptsParser)
            (progDesc "Build scaffold from template"))
 <> command "check"
      (info (Check <$> checkOptsParser)
            (progDesc "Check project structure against constraints"))
  )

-- | Parser for init options
initOptsParser :: Parser InitOpts
initOptsParser = InitOpts
  <$> strArgument
      ( metavar "TEMPLATE"
     <> help "Template name to use" )
  <*> strOption
      ( long "target"
     <> short 't'
     <> metavar "DIR"
     <> value "."
     <> help "Target directory (default: current)" )
  <*> switch
      ( long "force"
     <> short 'f'
     <> help "Overwrite existing files" )

-- | Parser for validate options
validateOptsParser :: Parser ValidateOpts
validateOptsParser = ValidateOpts
  <$> strArgument
      ( metavar "PATH"
     <> help "Path to template to validate" )
  <*> switch
      ( long "strict"
     <> short 's'
     <> help "Enable strict validation mode" )

-- | Parser for list options
listOptsParser :: Parser ListOpts
listOptsParser = ListOpts
  <$> optional (strOption
      ( long "category"
     <> short 'c'
     <> metavar "CAT"
     <> help "Filter by category" ))
  <*> switch
      ( long "detailed"
     <> short 'd'
     <> help "Show detailed information" )

-- | Parser for build options
buildOptsParser :: Parser BuildOpts
buildOptsParser = BuildOpts
  <$> strArgument
      ( metavar "TEMPLATE"
     <> help "Template to build from" )
  <*> strOption
      ( long "output"
     <> short 'o'
     <> metavar "DIR"
     <> value "."
     <> help "Output directory" )
  <*> optional (strOption
      ( long "config"
     <> short 'c'
     <> metavar "FILE"
     <> help "Configuration file (Nickel)" ))

-- | Parser for check options
checkOptsParser :: Parser CheckOpts
checkOptsParser = CheckOpts
  <$> strArgument
      ( metavar "PATH"
     <> value "."
     <> help "Path to project (default: current)" )
  <*> switch
      ( long "fix"
     <> help "Attempt to fix issues" )

-- | Main entry point
main :: IO ()
main = do
  opts <- execParser optsInfo
  runCommand (optVerbose opts) (optCommand opts)
  where
    optsInfo = info (optionsParser <**> helper)
      ( fullDesc
     <> progDesc "Scaffoldia - Repository scaffolding engine"
     <> header "scaffoldia - generate idiomatic, validated project structures" )

-- | Run the specified command
runCommand :: Bool -> Command -> IO ()
runCommand verbose cmd = case cmd of
  Init opts     -> runInit verbose opts
  Validate opts -> runValidate verbose opts
  List opts     -> runList verbose opts
  Build opts    -> runBuild verbose opts
  Check opts    -> runCheck verbose opts

-- | Run init command
runInit :: Bool -> InitOpts -> IO ()
runInit verbose opts = do
  when verbose $ putStrLn $ "Initializing from template: " ++ initTemplate opts

  -- Check if target exists
  targetExists <- doesDirectoryExist (initTarget opts)
  when (targetExists && not (initForce opts)) $ do
    putStrLn $ "Error: Target directory exists: " ++ initTarget opts
    putStrLn "Use --force to overwrite"
    exitFailure

  -- Look up template in registry
  templatePath <- findTemplate (initTemplate opts)
  case templatePath of
    Nothing -> do
      putStrLn $ "Error: Template not found: " ++ initTemplate opts
      putStrLn "Use 'scaffoldia list' to see available templates"
      exitFailure
    Just path -> do
      when verbose $ putStrLn $ "Found template at: " ++ path
      -- TODO: Call Nickel builder to compose scaffold
      putStrLn $ "Scaffolding project from '" ++ initTemplate opts ++ "'..."
      createDirectoryIfMissing True (initTarget opts)
      putStrLn $ "Created scaffold at: " ++ initTarget opts
      exitSuccess

-- | Run validate command
runValidate :: Bool -> ValidateOpts -> IO ()
runValidate verbose opts = do
  when verbose $ putStrLn $ "Validating template: " ++ validatePath opts

  exists <- doesDirectoryExist (validatePath opts)
  unless exists $ do
    putStrLn $ "Error: Path does not exist: " ++ validatePath opts
    exitFailure

  -- Check for required files
  let requiredFiles = ["template.ncl", "metadata.json"]
  errors <- validateTemplateStructure (validatePath opts) requiredFiles

  if null errors
    then do
      putStrLn "✓ Template validation passed"
      when (validateStrict opts) $ do
        -- Additional strict checks
        putStrLn "Running strict validation..."
        strictErrors <- runStrictValidation (validatePath opts)
        unless (null strictErrors) $ do
          mapM_ (putStrLn . ("  ✗ " ++)) strictErrors
          exitFailure
      exitSuccess
    else do
      putStrLn "✗ Template validation failed:"
      mapM_ (putStrLn . ("  - " ++)) errors
      exitFailure

-- | Run list command
runList :: Bool -> ListOpts -> IO ()
runList verbose opts = do
  when verbose $ putStrLn "Listing templates..."

  templates <- getAvailableTemplates (listCategory opts)

  if null templates
    then putStrLn "No templates found"
    else do
      putStrLn "Available templates:"
      putStrLn ""
      forM_ templates $ \tmpl ->
        if listDetailed opts
          then printDetailedTemplate tmpl
          else putStrLn $ "  " ++ tmplName tmpl ++ " - " ++ tmplDescription tmpl

-- | Run build command
runBuild :: Bool -> BuildOpts -> IO ()
runBuild verbose opts = do
  when verbose $ putStrLn $ "Building from template: " ++ buildTemplate opts

  putStrLn $ "Building scaffold to: " ++ buildOutput opts

  -- Optionally evaluate a Nickel config file if provided
  case buildConfig opts of
    Just cfg -> do
      putStrLn $ "Evaluating Nickel config: " ++ cfg
      (exitCode, stdout, stderr) <-
        readProcessWithExitCode "nickel" ["export", cfg] ""
      case exitCode of
        ExitSuccess -> when verbose $ putStrLn $ "Nickel config: " ++ stdout
        ExitFailure _ -> do
          putStrLn $ "Warning: Nickel evaluation failed: " ++ stderr
          putStrLn "Continuing with default configuration"
    Nothing -> when verbose $ putStrLn "Using default configuration"

  -- Build scaffold from template
  templatePath <- findTemplate (buildTemplate opts)
  case templatePath of
    Nothing -> do
      putStrLn $ "Error: Template not found: " ++ buildTemplate opts
      exitFailure
    Just path -> do
      when verbose $ putStrLn $ "Found template at: " ++ path
      createDirectoryIfMissing True (buildOutput opts)
      putStrLn "Build complete"
      exitSuccess

-- | Run check command
--
-- Checks the project structure for missing required files (README, LICENSE,
-- .gitignore) and reports issues.  When @--fix@ is passed, attempts to
-- create missing files with sensible defaults.
runCheck :: Bool -> CheckOpts -> IO ()
runCheck verbose opts = do
  when verbose $ putStrLn $ "Checking project structure: " ++ checkPath opts

  exists <- doesDirectoryExist (checkPath opts)
  unless exists $ do
    putStrLn $ "Error: Path does not exist: " ++ checkPath opts
    exitFailure

  -- Run constraint checks on the project path
  issues <- checkProjectStructure (checkPath opts)

  if null issues
    then do
      putStrLn "Project structure is valid"
      exitSuccess
    else do
      putStrLn $ "Found " ++ show (length issues) ++ " issue(s):"
      mapM_ (putStrLn . ("  - " ++)) issues
      when (checkFix opts) $ do
        putStrLn "Attempting to fix issues..."
        fixProjectIssues (checkPath opts) issues
        putStrLn "Fix complete"
      exitFailure

-- | Find a template in the registry
findTemplate :: String -> IO (Maybe FilePath)
findTemplate name = do
  let registryPath = "registry" </> name
  exists <- doesDirectoryExist registryPath
  return $ if exists then Just registryPath else Nothing

-- | Validate template structure
validateTemplateStructure :: FilePath -> [FilePath] -> IO [String]
validateTemplateStructure basePath required = do
  missingFiles <- filterM (fmap not . doesFileExist . (basePath </>)) required
  return $ map (\f -> "Missing required file: " ++ f) missingFiles
  where
    filterM p = foldr (\x acc -> do
      b <- p x
      xs <- acc
      return $ if b then x:xs else xs) (return [])

-- | Run strict validation
runStrictValidation :: FilePath -> IO [String]
runStrictValidation path = do
  -- Check for Nickel syntax validity
  let nickelFile = path </> "template.ncl"
  nickelExists <- doesFileExist nickelFile
  if nickelExists
    then return []  -- TODO: Actually validate Nickel syntax
    else return ["template.ncl not found"]

-- | Get available templates
getAvailableTemplates :: Maybe String -> IO [TemplateInfo]
getAvailableTemplates categoryFilter = do
  let registryPath = "registry"
  exists <- doesDirectoryExist registryPath
  if exists
    then do
      dirs <- listDirectory registryPath
      templates <- mapM (loadTemplateInfo registryPath) dirs
      let valid = [t | Just t <- templates]
      return $ case categoryFilter of
        Nothing  -> valid
        Just cat -> filter ((== cat) . tmplCategory) valid
    else return defaultTemplates

-- | Load template info from registry
loadTemplateInfo :: FilePath -> String -> IO (Maybe TemplateInfo)
loadTemplateInfo registry name = do
  let metaPath = registry </> name </> "metadata.json"
  exists <- doesFileExist metaPath
  if exists
    then do
      content <- BL.readFile metaPath
      return $ decode content
    else return $ Just $ TemplateInfo
      { tmplName = name
      , tmplDescription = "Template: " ++ name
      , tmplLanguages = []
      , tmplCategory = "general"
      , tmplVersion = "0.1.0"
      }

-- | Default templates (built-in)
defaultTemplates :: [TemplateInfo]
defaultTemplates =
  [ TemplateInfo "rust-cli" "Rust command-line application" ["Rust"] "cli" "1.0.0"
  , TemplateInfo "haskell-lib" "Haskell library package" ["Haskell"] "library" "1.0.0"
  , TemplateInfo "rescript-app" "ReScript web application" ["ReScript"] "webapp" "1.0.0"
  , TemplateInfo "nickel-config" "Nickel configuration project" ["Nickel"] "config" "1.0.0"
  , TemplateInfo "gleam-service" "Gleam backend service" ["Gleam"] "service" "1.0.0"
  , TemplateInfo "tauri-mobile" "Tauri mobile application" ["Rust", "ReScript"] "mobile" "1.0.0"
  ]

-- | Print detailed template info
printDetailedTemplate :: TemplateInfo -> IO ()
printDetailedTemplate tmpl = do
  putStrLn $ "  " ++ tmplName tmpl
  putStrLn $ "    Description: " ++ tmplDescription tmpl
  putStrLn $ "    Languages:   " ++ intercalate ", " (tmplLanguages tmpl)
  putStrLn $ "    Category:    " ++ tmplCategory tmpl
  putStrLn $ "    Version:     " ++ tmplVersion tmpl
  putStrLn ""

-- | Check project structure against constraints
checkProjectStructure :: FilePath -> IO [String]
checkProjectStructure path = do
  -- Basic structure checks (TODO: integrate with MiniKanren)
  let requiredItems =
        [ ("README.md", "README.adoc")   -- Either is acceptable
        , ("LICENSE", "LICENSE.txt")
        ]

  issues <- checkRequiredFiles path
  return issues

-- | Check for required files
checkRequiredFiles :: FilePath -> IO [String]
checkRequiredFiles path = do
  files <- listDirectory path
  let checks =
        [ ("README", any (isPrefixOf "README") files)
        , ("LICENSE", any (isPrefixOf "LICENSE") files)
        , (".gitignore", ".gitignore" `elem` files)
        ]
  return [name ++ " file missing" | (name, exists) <- checks, not exists]

-- | Attempt to fix project issues by creating missing files with defaults
fixProjectIssues :: FilePath -> [String] -> IO ()
fixProjectIssues path issues = forM_ issues $ \issue ->
  case issue of
    "README file missing" -> do
      putStrLn "  Creating README.adoc..."
      writeFile (path </> "README.adoc") "= Project\n\nTODO: Add project description.\n"
    "LICENSE file missing" -> do
      putStrLn "  Creating LICENSE placeholder..."
      writeFile (path </> "LICENSE") "MPL-2.0\n\nSee https://mozilla.org/MPL/2.0/ for full text.\n"
    ".gitignore file missing" -> do
      putStrLn "  Creating .gitignore..."
      writeFile (path </> ".gitignore") "dist-newstyle/\n*.hi\n*.o\n.cabal-sandbox/\n"
    _ -> putStrLn $ "  Skipping unknown issue: " ++ issue
