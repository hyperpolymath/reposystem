{- SPDX-License-Identifier: MPL-2.0 -}
{-# LANGUAGE OverloadedStrings #-}

{- |
Module      : Main
Description : Test suite for Scaffoldia
Copyright   : (c) Hyperpolymath, 2026
License     : MPL-2.0
-}

module Main where

import Test.Hspec

import Scaffoldia.Template
import Scaffoldia.Types

import Data.Aeson (encode)
import qualified Data.ByteString.Lazy as BL
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import System.Directory (createDirectoryIfMissing, doesFileExist)
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)

-- | Sample metadata for tests
sampleMetadata :: TemplateMetadata
sampleMetadata = TemplateMetadata
  { metaName        = "test-template"
  , metaDescription = "A test template"
  , metaVersion     = "1.0.0"
  , metaAuthor      = "Test Author"
  , metaLicense     = "MPL-2.0"
  , metaLanguages   = [Haskell]
  , metaCategory    = "library"
  , metaTags        = ["test"]
  }

-- | Sample template file for tests
sampleTemplateFile :: TemplateFile
sampleTemplateFile = TemplateFile
  { filePath     = "README.md"
  , fileType     = DocumentationFile
  , fileTemplate = "# {{project_name}}\n\nAuthor: {{author}}\nLicense: {{license}}\n"
  , fileRequired = True
  }

-- | Sample template
sampleTemplate :: Template
sampleTemplate = Template
  { templateId           = "test-template"
  , templateMetadata     = sampleMetadata
  , templateFiles        = [sampleTemplateFile]
  , templateDependencies = []
  }

-- | Sample project config for rendering
sampleConfig :: ProjectConfig
sampleConfig = ProjectConfig
  { configLanguage    = Haskell
  , configLicense     = "MPL-2.0"
  , configAuthor      = "Jonathan D.A. Jewell"
  , configDescription = "My Test Project"
  , configFeatures    = []
  }

main :: IO ()
main = hspec $ do

  -- ----------------------------------------------------------------
  -- Template loading
  -- ----------------------------------------------------------------
  describe "loadTemplate" $ do

    it "loads a valid template from a temp directory" $
      withSystemTempDirectory "scaffoldia-test" $ \tmpDir -> do
        -- Set up template directory with metadata.json
        BL.writeFile (tmpDir </> "metadata.json") (encode sampleMetadata)
        let templatesDir = tmpDir </> "templates"
        createDirectoryIfMissing True templatesDir
        TIO.writeFile (templatesDir </> "README.md") "# Hello"

        result <- loadTemplate tmpDir
        case result of
          Left err -> expectationFailure $ "loadTemplate failed: " ++ T.unpack err
          Right tmpl -> do
            templateId tmpl `shouldBe` "test-template"
            length (templateFiles tmpl) `shouldBe` 1

    it "returns an error for a non-existent directory" $ do
      result <- loadTemplate "/tmp/scaffoldia-nonexistent-dir-abc123"
      case result of
        Left _  -> return ()
        Right _ -> expectationFailure "Expected error for missing directory"

    it "returns an error when metadata.json is missing" $
      withSystemTempDirectory "scaffoldia-test" $ \tmpDir -> do
        -- Directory exists but no metadata.json
        result <- loadTemplate tmpDir
        case result of
          Left err -> err `shouldBe` "Missing metadata.json"
          Right _  -> expectationFailure "Expected error for missing metadata.json"

  -- ----------------------------------------------------------------
  -- Template validation
  -- ----------------------------------------------------------------
  describe "validateTemplate" $ do

    it "fails validation when files list is empty" $ do
      let emptyTemplate = sampleTemplate { templateFiles = [] }
      case validateTemplate emptyTemplate of
        ValidationSuccess   -> expectationFailure "Expected validation failure for empty files"
        ValidationFailure errs ->
          any (\e -> "No template files" `T.isInfixOf` errorMessage e) errs
            `shouldBe` True

    it "warns when description is empty" $ do
      let emptyDescMeta = sampleMetadata { metaDescription = "" }
          tmpl = sampleTemplate { templateMetadata = emptyDescMeta }
      case validateTemplate tmpl of
        ValidationSuccess -> expectationFailure "Expected warning for empty description"
        ValidationFailure errs ->
          any (\e -> errorSeverity e == Warning
                  && "Description" `T.isInfixOf` errorMessage e) errs
            `shouldBe` True

    it "passes validation for a well-formed template" $ do
      validateTemplate sampleTemplate `shouldBe` ValidationSuccess

  -- ----------------------------------------------------------------
  -- Template rendering with variable substitution
  -- ----------------------------------------------------------------
  describe "renderTemplate" $ do

    it "substitutes {{project_name}} in template files" $ do
      case renderTemplate sampleTemplate sampleConfig of
        Left err -> expectationFailure $ "renderTemplate failed: " ++ T.unpack err
        Right rendered -> do
          let (_, content) = head rendered
          T.isInfixOf "My Test Project" content `shouldBe` True

    it "substitutes {{author}} in template files" $ do
      case renderTemplate sampleTemplate sampleConfig of
        Left err -> expectationFailure $ "renderTemplate failed: " ++ T.unpack err
        Right rendered -> do
          let (_, content) = head rendered
          T.isInfixOf "Jonathan D.A. Jewell" content `shouldBe` True

    it "substitutes {{license}} in template files" $ do
      case renderTemplate sampleTemplate sampleConfig of
        Left err -> expectationFailure $ "renderTemplate failed: " ++ T.unpack err
        Right rendered -> do
          let (_, content) = head rendered
          T.isInfixOf "MPL-2.0" content `shouldBe` True

    it "does not leave {{var}} markers in output" $ do
      case renderTemplate sampleTemplate sampleConfig of
        Left err -> expectationFailure $ "renderTemplate failed: " ++ T.unpack err
        Right rendered -> do
          let (_, content) = head rendered
          T.isInfixOf "{{" content `shouldBe` False

  -- ----------------------------------------------------------------
  -- Template saving (round-trip)
  -- ----------------------------------------------------------------
  describe "saveTemplate" $ do

    it "writes metadata.json and template files to disk" $
      withSystemTempDirectory "scaffoldia-save" $ \tmpDir -> do
        let outDir = tmpDir </> "my-template"
        result <- saveTemplate outDir sampleTemplate
        result `shouldBe` Right ()

        -- Check metadata.json was created
        doesFileExist (outDir </> "metadata.json") >>= (`shouldBe` True)

        -- Check templates/ subdirectory and file
        doesFileExist (outDir </> "templates" </> "README.md") >>= (`shouldBe` True)
