{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

-- Haskell validator bridge for schema enforcement
-- Provides type-safe validation of documentation schemas

module DocumentValidator
  ( DocumentType(..)
  , ValidationResult(..)
  , SchemaViolation(..)
  , validateDocument
  , validateLicense
  , validateSecurity
  , validateContributing
  ) where

import Data.Aeson (FromJSON, ToJSON)
import Data.Text (Text)
import qualified Data.Text as T
import GHC.Generics (Generic)
import Data.Maybe (isJust, catMaybes)
import Data.List (isInfixOf)

-- Document types
data DocumentType
  = README
  | LICENSE
  | SECURITY
  | CONTRIBUTING
  | CODE_OF_CONDUCT
  | FUNDING
  | CITATION
  | CHANGELOG
  deriving (Eq, Show, Generic)

instance FromJSON DocumentType
instance ToJSON DocumentType

-- Schema violation
data SchemaViolation = SchemaViolation
  { violationField :: Text
  , violationMessage :: Text
  , violationSeverity :: Text  -- "error" | "warning"
  , violationLine :: Maybe Int
  } deriving (Eq, Show, Generic)

instance FromJSON SchemaViolation
instance ToJSON SchemaViolation

-- Validation result
data ValidationResult = ValidationResult
  { isValid :: Bool
  , violations :: [SchemaViolation]
  , confidence :: Double
  } deriving (Eq, Show, Generic)

instance FromJSON ValidationResult
instance ToJSON ValidationResult

-- Validate document based on type
validateDocument :: DocumentType -> Text -> ValidationResult
validateDocument docType content =
  case docType of
    LICENSE -> validateLicense content
    SECURITY -> validateSecurity content
    CONTRIBUTING -> validateContributing content
    README -> validateReadme content
    FUNDING -> validateFunding content
    CITATION -> validateCitation content
    _ -> ValidationResult True [] 1.0

-- LICENSE validation
validateLicense :: Text -> ValidationResult
validateLicense content =
  let violations = catMaybes
        [ checkNotEmpty content
        , checkLicenseKeywords content
        , checkCopyrightNotice content
        ]
      valid = null violations
      conf = if valid then 1.0 else 0.5
  in ValidationResult valid violations conf

checkNotEmpty :: Text -> Maybe SchemaViolation
checkNotEmpty content
  | T.null (T.strip content) = Just $ SchemaViolation
      "content"
      "License file cannot be empty"
      "error"
      Nothing
  | otherwise = Nothing

checkLicenseKeywords :: Text -> Maybe SchemaViolation
checkLicenseKeywords content
  | not (anyInfix ["license", "License", "LICENSE"] content) = Just $ SchemaViolation
      "content"
      "License file should contain the word 'license'"
      "warning"
      Nothing
  | otherwise = Nothing

checkCopyrightNotice :: Text -> Maybe SchemaViolation
checkCopyrightNotice content
  | not (anyInfix ["Copyright", "copyright", "©"] content) = Just $ SchemaViolation
      "copyright"
      "License should include a copyright notice"
      "warning"
      Nothing
  | otherwise = Nothing

-- SECURITY.md validation
validateSecurity :: Text -> ValidationResult
validateSecurity content =
  let violations = catMaybes
        [ checkNotEmpty content
        , checkSecuritySections content
        , checkContactInfo content
        , checkReportingInstructions content
        ]
      valid = null violations
      conf = if valid then 1.0 else 0.6
  in ValidationResult valid violations conf

checkSecuritySections :: Text -> Maybe SchemaViolation
checkSecuritySections content
  | not (anyInfix ["Reporting", "reporting", "Report"] content) = Just $ SchemaViolation
      "structure"
      "SECURITY.md should include reporting instructions"
      "error"
      Nothing
  | otherwise = Nothing

checkContactInfo :: Text -> Maybe SchemaViolation
checkContactInfo content
  | not (anyInfix ["email", "Email", "contact", "Contact"] content) = Just $ SchemaViolation
      "contact"
      "SECURITY.md should include contact information"
      "warning"
      Nothing
  | otherwise = Nothing

checkReportingInstructions :: Text -> Maybe SchemaViolation
checkReportingInstructions content
  | not (anyInfix ["vulnerability", "Vulnerability", "security issue"] content) = Just $ SchemaViolation
      "content"
      "SECURITY.md should mention vulnerabilities or security issues"
      "warning"
      Nothing
  | otherwise = Nothing

-- CONTRIBUTING.md validation
validateContributing :: Text -> ValidationResult
validateContributing content =
  let violations = catMaybes
        [ checkNotEmpty content
        , checkContributingSections content
        , checkPullRequestInfo content
        ]
      valid = null violations
      conf = if valid then 1.0 else 0.7
  in ValidationResult valid violations conf

checkContributingSections :: Text -> Maybe SchemaViolation
checkContributingSections content
  | not (anyInfix ["contribute", "Contribute", "Contributing"] content) = Just $ SchemaViolation
      "structure"
      "CONTRIBUTING.md should mention how to contribute"
      "error"
      Nothing
  | otherwise = Nothing

checkPullRequestInfo :: Text -> Maybe SchemaViolation
checkPullRequestInfo content
  | not (anyInfix ["pull request", "Pull Request", "PR"] content) = Just $ SchemaViolation
      "content"
      "CONTRIBUTING.md should include pull request guidelines"
      "warning"
      Nothing
  | otherwise = Nothing

-- README.md validation
validateReadme :: Text -> ValidationResult
validateReadme content =
  let violations = catMaybes
        [ checkNotEmpty content
        , checkReadmeTitle content
        , checkInstallationInfo content
        ]
      valid = null violations
      conf = if valid then 1.0 else 0.8
  in ValidationResult valid violations conf

checkReadmeTitle :: Text -> Maybe SchemaViolation
checkReadmeTitle content
  | not (anyInfix ["#", "Title"] (T.take 100 content)) = Just $ SchemaViolation
      "structure"
      "README.md should start with a title (# heading)"
      "warning"
      Nothing
  | otherwise = Nothing

checkInstallationInfo :: Text -> Maybe SchemaViolation
checkInstallationInfo content
  | not (anyInfix ["install", "Install", "Installation", "Setup", "setup"] content) = Just $ SchemaViolation
      "content"
      "README.md should include installation or setup instructions"
      "warning"
      Nothing
  | otherwise = Nothing

-- FUNDING.yml validation
validateFunding :: Text -> ValidationResult
validateFunding content =
  let violations = catMaybes
        [ checkNotEmpty content
        , checkFundingPlatforms content
        ]
      valid = null violations
      conf = if valid then 1.0 else 0.9
  in ValidationResult valid violations conf

checkFundingPlatforms :: Text -> Maybe SchemaViolation
checkFundingPlatforms content
  | not (anyInfix ["github", "patreon", "open_collective", "custom"] content) = Just $ SchemaViolation
      "platforms"
      "FUNDING.yml should specify at least one funding platform"
      "error"
      Nothing
  | otherwise = Nothing

-- CITATION.cff validation
validateCitation :: Text -> ValidationResult
validateCitation content =
  let violations = catMaybes
        [ checkNotEmpty content
        , checkCitationFormat content
        ]
      valid = null violations
      conf = if valid then 1.0 else 0.85
  in ValidationResult valid violations conf

checkCitationFormat :: Text -> Maybe SchemaViolation
checkCitationFormat content
  | not (anyInfix ["cff-version", "title", "authors"] content) = Just $ SchemaViolation
      "format"
      "CITATION.cff should include required fields (cff-version, title, authors)"
      "error"
      Nothing
  | otherwise = Nothing

-- Helper: Check if any of the strings is an infix of the text
anyInfix :: [String] -> Text -> Bool
anyInfix patterns text =
  let textStr = T.unpack text
  in any (`isInfixOf` textStr) patterns

-- JSON interface for ReScript bridge
-- These would be called via FFI from ReScript
