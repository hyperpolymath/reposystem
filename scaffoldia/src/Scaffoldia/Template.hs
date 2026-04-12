{- SPDX-License-Identifier: MPL-2.0 -}
{-# LANGUAGE OverloadedStrings #-}

{- |
Module      : Scaffoldia.Template
Description : Template loading and management
Copyright   : (c) Hyperpolymath, 2026
License     : MPL-2.0
-}

module Scaffoldia.Template
  ( -- * Template Operations
    loadTemplate
  , saveTemplate
  , validateTemplate
  , renderTemplate
    -- * Template Discovery
  , findTemplates
  , getTemplateInfo
  ) where

import Scaffoldia.Types

import Control.Monad (forM, forM_)
import Data.Aeson (decode, encode)
import qualified Data.ByteString.Lazy as BL
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import System.Directory (createDirectoryIfMissing, doesDirectoryExist,
                         doesFileExist, listDirectory)
import System.FilePath ((</>), takeDirectory, takeExtension)

-- | Load a template from disk
loadTemplate :: FilePath -> IO (Either Text Template)
loadTemplate path = do
  exists <- doesDirectoryExist path
  if not exists
    then return $ Left $ "Template directory not found: " <> T.pack path
    else do
      let metaPath = path </> "metadata.json"
      metaExists <- doesFileExist metaPath
      if not metaExists
        then return $ Left "Missing metadata.json"
        else do
          content <- BL.readFile metaPath
          case decode content of
            Nothing -> return $ Left "Invalid metadata.json format"
            Just meta -> do
              files <- loadTemplateFiles path
              return $ Right Template
                { templateId = metaName meta
                , templateMetadata = meta
                , templateFiles = files
                , templateDependencies = []
                }

-- | Load template files from directory
loadTemplateFiles :: FilePath -> IO [TemplateFile]
loadTemplateFiles basePath = do
  let templatesDir = basePath </> "templates"
  exists <- doesDirectoryExist templatesDir
  if not exists
    then return []
    else do
      files <- listDirectory templatesDir
      forM files $ \f -> do
        content <- TIO.readFile (templatesDir </> f)
        return TemplateFile
          { filePath = f
          , fileType = classifyFile f
          , fileTemplate = content
          , fileRequired = True
          }

-- | Classify a file by extension
classifyFile :: FilePath -> FileType
classifyFile path = case takeExtension path of
  ".rs"     -> SourceFile
  ".hs"     -> SourceFile
  ".res"    -> SourceFile
  ".ncl"    -> ConfigFile
  ".toml"   -> ConfigFile
  ".yaml"   -> ConfigFile
  ".yml"    -> ConfigFile
  ".json"   -> ConfigFile
  ".md"     -> DocumentationFile
  ".adoc"   -> DocumentationFile
  ".txt"    -> DocumentationFile
  _         -> OtherFile

-- | Save a template to disk.
--
-- Creates the template directory (and parents) if it does not exist, writes
-- @metadata.json@ from the template metadata, then creates a @templates/@
-- subdirectory and writes each 'TemplateFile' into it.
saveTemplate :: FilePath -> Template -> IO (Either Text ())
saveTemplate path template = do
  -- Create the template root directory
  createDirectoryIfMissing True path

  -- Write metadata.json
  let metaPath = path </> "metadata.json"
  BL.writeFile metaPath (encode (templateMetadata template))

  -- Create templates/ subdirectory and write each file
  let templatesDir = path </> "templates"
  createDirectoryIfMissing True templatesDir
  forM_ (templateFiles template) $ \tf -> do
    let fullPath = templatesDir </> filePath tf
    createDirectoryIfMissing True (takeDirectory fullPath)
    TIO.writeFile fullPath (fileTemplate tf)

  return $ Right ()

-- | Validate a template definition
validateTemplate :: Template -> ValidationResult
validateTemplate template =
  let errors = validateMetadata (templateMetadata template)
            ++ validateFiles (templateFiles template)
  in if null errors
     then ValidationSuccess
     else ValidationFailure errors

-- | Validate template metadata
validateMetadata :: TemplateMetadata -> [ValidationError]
validateMetadata meta =
  [ ValidationError Warning "Description is empty" Nothing (Just "Add a description")
  | T.null (metaDescription meta)
  ] ++
  [ ValidationError Warning "No languages specified" Nothing (Just "Specify target languages")
  | null (metaLanguages meta)
  ]

-- | Validate template files
validateFiles :: [TemplateFile] -> [ValidationError]
validateFiles files =
  [ ValidationError Error "No template files defined" Nothing (Just "Add at least one template file")
  | null files
  ]

-- | Render a template with configuration.
--
-- Performs @{{var}}@ substitution on each template file using values from
-- the 'ProjectConfig'.  Supported variables: @{{project_name}}@,
-- @{{author}}@, @{{license}}@, @{{description}}@, @{{language}}@.
renderTemplate :: Template -> ProjectConfig -> Either Text [(FilePath, Text)]
renderTemplate template config =
  Right $ map renderFile (templateFiles template)
  where
    renderFile tf = (filePath tf, substituteVars (fileTemplate tf))
    substituteVars content =
      T.replace "{{project_name}}" (configDescription config) $
      T.replace "{{author}}" (configAuthor config) $
      T.replace "{{license}}" (configLicense config) $
      T.replace "{{description}}" (configDescription config) $
      T.replace "{{language}}" (T.pack $ show $ configLanguage config) $
      content

-- | Find all templates in a directory
findTemplates :: FilePath -> IO [FilePath]
findTemplates basePath = do
  exists <- doesDirectoryExist basePath
  if not exists
    then return []
    else do
      dirs <- listDirectory basePath
      filterM isTemplateDir (map (basePath </>) dirs)
  where
    filterM p = foldr (\x acc -> do
      b <- p x
      xs <- acc
      return $ if b then x:xs else xs) (return [])

-- | Check if directory is a valid template
isTemplateDir :: FilePath -> IO Bool
isTemplateDir path = do
  isDir <- doesDirectoryExist path
  if not isDir
    then return False
    else doesFileExist (path </> "metadata.json")

-- | Get template info without loading full template
getTemplateInfo :: FilePath -> IO (Maybe TemplateMetadata)
getTemplateInfo path = do
  let metaPath = path </> "metadata.json"
  exists <- doesFileExist metaPath
  if not exists
    then return Nothing
    else do
      content <- BL.readFile metaPath
      return $ decode content
