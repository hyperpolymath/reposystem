{- SPDX-License-Identifier: MPL-2.0 -}
{-# LANGUAGE OverloadedStrings #-}

{- |
Module      : Scaffoldia.Constraints
Description : Project structure constraints - interfaces with MiniKanren
Copyright   : (c) Hyperpolymath, 2026
License     : MPL-2.0
-}

module Scaffoldia.Constraints
  ( -- * Constraint Checking
    checkConstraints
  , validateStructure
    -- * MiniKanren Integration
  , runMiniKanren
  , inferMissingFiles
    -- * Built-in Constraints
  , defaultConstraints
  , languageConstraints
  ) where

import Scaffoldia.Types

import Data.Text (Text)
import qualified Data.Text as T
import System.Directory (doesFileExist, doesDirectoryExist, listDirectory)
import System.FilePath ((</>), takeExtension)
import System.Process (readProcessWithExitCode)
import System.Exit (ExitCode(..))

-- | A constraint definition
data Constraint = Constraint
  { constraintName :: Text
  , constraintCheck :: FilePath -> IO Bool
  , constraintMessage :: Text
  , constraintSeverity :: Severity
  }

-- | Check all constraints on a project
checkConstraints :: FilePath -> [Constraint] -> IO [ValidationError]
checkConstraints projectPath constraints = do
  results <- mapM (checkOne projectPath) constraints
  return $ concat results
  where
    checkOne path c = do
      passed <- constraintCheck c path
      if passed
        then return []
        else return [ValidationError
          { errorSeverity = constraintSeverity c
          , errorMessage = constraintMessage c
          , errorLocation = Just path
          , errorSuggestion = Nothing
          }]

-- | Validate project structure
validateStructure :: FilePath -> Language -> IO ValidationResult
validateStructure projectPath lang = do
  let constraints = defaultConstraints ++ languageConstraints lang
  errors <- checkConstraints projectPath constraints
  return $ if null errors
    then ValidationSuccess
    else ValidationFailure errors

-- | Run MiniKanren constraints (via Guile Scheme)
runMiniKanren :: FilePath -> FilePath -> IO (Either Text [Text])
runMiniKanren constraintFile projectPath = do
  let args = [constraintFile, "--", projectPath]
  (exitCode, stdout, stderr) <- readProcessWithExitCode "guile" args ""
  case exitCode of
    ExitSuccess   -> return $ Right (T.lines $ T.pack stdout)
    ExitFailure _ -> return $ Left (T.pack stderr)

-- | Infer missing files based on constraints
inferMissingFiles :: FilePath -> Language -> IO [FilePath]
inferMissingFiles projectPath lang = do
  existingFiles <- listDirectoryRecursive projectPath
  let expectedFiles = expectedFilesFor lang
      missing = filter (`notElem` existingFiles) expectedFiles
  return missing

-- | List directory recursively
listDirectoryRecursive :: FilePath -> IO [FilePath]
listDirectoryRecursive path = do
  isDir <- doesDirectoryExist path
  if not isDir
    then return []
    else do
      entries <- listDirectory path
      let paths = map (path </>) entries
      files <- mapM listDirectoryRecursive paths
      return $ entries ++ concat files

-- | Expected files for a language
expectedFilesFor :: Language -> [FilePath]
expectedFilesFor Rust = ["Cargo.toml", "src/main.rs", "README.md", "LICENSE"]
expectedFilesFor Haskell = ["*.cabal", "src/", "README.md", "LICENSE"]
expectedFilesFor ReScript = ["rescript.json", "src/", "README.md", "LICENSE"]
expectedFilesFor Nickel = ["*.ncl", "README.md", "LICENSE"]
expectedFilesFor Gleam = ["gleam.toml", "src/", "README.md", "LICENSE"]
expectedFilesFor _ = ["README.md", "LICENSE"]

-- | Default constraints for all projects
defaultConstraints :: [Constraint]
defaultConstraints =
  [ Constraint
      { constraintName = "has-readme"
      , constraintCheck = \p -> do
          md <- doesFileExist (p </> "README.md")
          adoc <- doesFileExist (p </> "README.adoc")
          return (md || adoc)
      , constraintMessage = "Project must have README.md or README.adoc"
      , constraintSeverity = Error
      }
  , Constraint
      { constraintName = "has-license"
      , constraintCheck = \p -> do
          l1 <- doesFileExist (p </> "LICENSE")
          l2 <- doesFileExist (p </> "LICENSE.txt")
          l3 <- doesFileExist (p </> "LICENSE.md")
          return (l1 || l2 || l3)
      , constraintMessage = "Project must have a LICENSE file"
      , constraintSeverity = Error
      }
  , Constraint
      { constraintName = "has-gitignore"
      , constraintCheck = \p -> doesFileExist (p </> ".gitignore")
      , constraintMessage = "Project should have a .gitignore file"
      , constraintSeverity = Warning
      }
  , Constraint
      { constraintName = "has-security-md"
      , constraintCheck = \p -> doesFileExist (p </> "SECURITY.md")
      , constraintMessage = "Project should have SECURITY.md for vulnerability reporting"
      , constraintSeverity = Warning
      }
  ]

-- | Language-specific constraints
languageConstraints :: Language -> [Constraint]
languageConstraints Rust =
  [ Constraint
      { constraintName = "rust-has-cargo-toml"
      , constraintCheck = \p -> doesFileExist (p </> "Cargo.toml")
      , constraintMessage = "Rust project must have Cargo.toml"
      , constraintSeverity = Error
      }
  , Constraint
      { constraintName = "rust-has-src"
      , constraintCheck = \p -> doesDirectoryExist (p </> "src")
      , constraintMessage = "Rust project must have src/ directory"
      , constraintSeverity = Error
      }
  ]
languageConstraints Haskell =
  [ Constraint
      { constraintName = "haskell-has-cabal"
      , constraintCheck = \p -> do
          files <- listDirectory p
          return $ any ((== ".cabal") . takeExtension) files
      , constraintMessage = "Haskell project must have a .cabal file"
      , constraintSeverity = Error
      }
  ]
languageConstraints ReScript =
  [ Constraint
      { constraintName = "rescript-has-config"
      , constraintCheck = \p -> doesFileExist (p </> "rescript.json")
      , constraintMessage = "ReScript project must have rescript.json"
      , constraintSeverity = Error
      }
  ]
languageConstraints Gleam =
  [ Constraint
      { constraintName = "gleam-has-toml"
      , constraintCheck = \p -> doesFileExist (p </> "gleam.toml")
      , constraintMessage = "Gleam project must have gleam.toml"
      , constraintSeverity = Error
      }
  ]
languageConstraints _ = []
