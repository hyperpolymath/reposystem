{-# LANGUAGE OverloadedStrings #-}

-- Main entry point for Haskell validator
-- Accepts JSON input, validates, returns JSON output

module Main where

import Data.Aeson (encode, decode, eitherDecode)
import qualified Data.ByteString.Lazy as BL
import qualified Data.Text as T
import System.Environment (getArgs)
import System.Exit (exitFailure, exitSuccess)
import DocumentValidator

-- CLI input format
data ValidatorInput = ValidatorInput
  { inputDocType :: DocumentType
  , inputContent :: T.Text
  } deriving (Show)

-- Parse command line and validate
main :: IO ()
main = do
  args <- getArgs
  case args of
    [docTypeStr, filePath] -> do
      content <- T.pack <$> readFile filePath
      let docType = parseDocType docTypeStr
      let result = validateDocument docType content
      BL.putStr (encode result)
      if isValid result
        then exitSuccess
        else exitFailure
    ["--stdin"] -> do
      input <- BL.getContents
      case eitherDecode input of
        Left err -> do
          putStrLn $ "JSON parse error: " ++ err
          exitFailure
        Right (docType, content) -> do
          let result = validateDocument docType (T.pack content)
          BL.putStr (encode result)
          if isValid result
            then exitSuccess
            else exitFailure
    _ -> do
      putStrLn "Usage: validator-bridge <doctype> <file>"
      putStrLn "   or: validator-bridge --stdin"
      putStrLn ""
      putStrLn "Document types: LICENSE, SECURITY, CONTRIBUTING, README, etc."
      exitFailure

parseDocType :: String -> DocumentType
parseDocType "LICENSE" = LICENSE
parseDocType "SECURITY" = SECURITY
parseDocType "CONTRIBUTING" = CONTRIBUTING
parseDocType "README" = README
parseDocType "FUNDING" = FUNDING
parseDocType "CITATION" = CITATION
parseDocType "CHANGELOG" = CHANGELOG
parseDocType _ = README
