{- SPDX-License-Identifier: MPL-2.0 -}
{-# LANGUAGE OverloadedStrings #-}

{- |
Module      : Scaffoldia.Registry
Description : Template registry management
Copyright   : (c) Hyperpolymath, 2026
License     : MPL-2.0
-}

module Scaffoldia.Registry
  ( -- * Registry Operations
    loadRegistry
  , saveRegistry
  , addToRegistry
  , removeFromRegistry
    -- * Registry Queries
  , findInRegistry
  , searchRegistry
  , listRegistry
  ) where

import Scaffoldia.Types

import Data.Aeson (decode, encode)
import qualified Data.ByteString.Lazy as BL
import Data.List (isInfixOf)
import Data.Text (Text)
import qualified Data.Text as T
import System.Directory (doesFileExist)
import System.FilePath ((</>))

-- | Default registry path
defaultRegistryPath :: FilePath
defaultRegistryPath = "registry" </> "index.json"

-- | Load registry from disk
loadRegistry :: FilePath -> IO (Either Text Registry)
loadRegistry path = do
  exists <- doesFileExist path
  if not exists
    then return $ Right emptyRegistry
    else do
      content <- BL.readFile path
      case decode content of
        Nothing  -> return $ Left "Invalid registry format"
        Just reg -> return $ Right reg

-- | Save registry to disk
saveRegistry :: FilePath -> Registry -> IO (Either Text ())
saveRegistry path registry = do
  BL.writeFile path (encode registry)
  return $ Right ()

-- | Add entry to registry
addToRegistry :: Registry -> RegistryEntry -> Registry
addToRegistry registry entry = registry
  { registryEntries = entry : filter ((/= entryId entry) . entryId) (registryEntries registry)
  }

-- | Remove entry from registry
removeFromRegistry :: Registry -> Text -> Registry
removeFromRegistry registry templateId = registry
  { registryEntries = filter ((/= templateId) . entryId) (registryEntries registry)
  }

-- | Find entry by ID
findInRegistry :: Registry -> Text -> Maybe RegistryEntry
findInRegistry registry templateId =
  lookup templateId [(entryId e, e) | e <- registryEntries registry]

-- | Search registry by query
searchRegistry :: Registry -> Text -> [RegistryEntry]
searchRegistry registry query =
  let q = T.toLower query
      matches entry =
        q `T.isInfixOf` T.toLower (entryId entry) ||
        q `T.isInfixOf` T.toLower (metaDescription (entryMetadata entry)) ||
        any (T.isInfixOf q . T.toLower) (metaTags (entryMetadata entry))
  in filter matches (registryEntries registry)

-- | List all registry entries
listRegistry :: Registry -> [RegistryEntry]
listRegistry = registryEntries

-- | Empty registry
emptyRegistry :: Registry
emptyRegistry = Registry
  { registryVersion = "1.0.0"
  , registryEntries = defaultEntries
  }

-- | Default built-in templates
defaultEntries :: [RegistryEntry]
defaultEntries =
  [ RegistryEntry
      { entryId = "rust-cli"
      , entryMetadata = TemplateMetadata
          { metaName = "rust-cli"
          , metaDescription = "Rust command-line application with clap"
          , metaVersion = "1.0.0"
          , metaAuthor = "Scaffoldia"
          , metaLicense = "MPL-2.0"
          , metaLanguages = [Rust]
          , metaCategory = "cli"
          , metaTags = ["rust", "cli", "command-line"]
          }
      , entryPath = "registry/rust-cli"
      , entryChecksum = ""
      }
  , RegistryEntry
      { entryId = "haskell-lib"
      , entryMetadata = TemplateMetadata
          { metaName = "haskell-lib"
          , metaDescription = "Haskell library package with cabal"
          , metaVersion = "1.0.0"
          , metaAuthor = "Scaffoldia"
          , metaLicense = "MPL-2.0"
          , metaLanguages = [Haskell]
          , metaCategory = "library"
          , metaTags = ["haskell", "library", "cabal"]
          }
      , entryPath = "registry/haskell-lib"
      , entryChecksum = ""
      }
  , RegistryEntry
      { entryId = "rescript-app"
      , entryMetadata = TemplateMetadata
          { metaName = "rescript-app"
          , metaDescription = "ReScript web application with Deno"
          , metaVersion = "1.0.0"
          , metaAuthor = "Scaffoldia"
          , metaLicense = "MPL-2.0"
          , metaLanguages = [ReScript]
          , metaCategory = "webapp"
          , metaTags = ["rescript", "web", "deno"]
          }
      , entryPath = "registry/rescript-app"
      , entryChecksum = ""
      }
  , RegistryEntry
      { entryId = "gleam-service"
      , entryMetadata = TemplateMetadata
          { metaName = "gleam-service"
          , metaDescription = "Gleam backend service"
          , metaVersion = "1.0.0"
          , metaAuthor = "Scaffoldia"
          , metaLicense = "MPL-2.0"
          , metaLanguages = [Gleam]
          , metaCategory = "service"
          , metaTags = ["gleam", "backend", "beam"]
          }
      , entryPath = "registry/gleam-service"
      , entryChecksum = ""
      }
  , RegistryEntry
      { entryId = "tauri-mobile"
      , entryMetadata = TemplateMetadata
          { metaName = "tauri-mobile"
          , metaDescription = "Tauri 2.0 mobile application"
          , metaVersion = "1.0.0"
          , metaAuthor = "Scaffoldia"
          , metaLicense = "MPL-2.0"
          , metaLanguages = [Rust, ReScript]
          , metaCategory = "mobile"
          , metaTags = ["tauri", "mobile", "rust", "rescript"]
          }
      , entryPath = "registry/tauri-mobile"
      , entryChecksum = ""
      }
  ]
