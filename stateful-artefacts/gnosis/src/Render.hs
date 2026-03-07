{- |
Module      : Render
Description : Template rendering engine with Tri-Guard safety
Copyright   : (c) 2025-2026 Jonathan D.A. Jewell
License     : PMPL-1.0-or-later
Maintainer  : hyperpolymath

This module implements the core rendering logic that transforms
templates with (:placeholder) syntax into final output.
-}

module Render
    ( render
    , renderWithBadges
    , sanitize
    , RenderMode(..)
    ) where

import qualified Data.Map.Strict as Map
import Types (FlexiText(..), Context, renderFlexiText, renderFlexiTextBadge)
import qualified DAX

-- | Rendering mode determines how FlexiText values are output.
data RenderMode
    = PlainText      -- ^ Output visual text only
    | ShieldsIOBadge -- ^ Output as Shields.io badge with alt-text
    deriving (Show, Eq)

-- | Render a template string, replacing (:key) placeholders with values.
-- Uses PlainText mode by default.
render :: Context -> String -> String
render = renderWithMode PlainText

-- | Render a template with Shields.io badges for visual elements.
renderWithBadges :: Context -> String -> String
renderWithBadges = renderWithMode ShieldsIOBadge

-- | Internal render function with configurable mode.
renderWithMode :: RenderMode -> Context -> String -> String
renderWithMode _ _ [] = []
renderWithMode mode ctx ('(':':':rest) =
    let (placeholder, remaining) = span (/= ')') rest
        tailStr = drop 1 remaining  -- Drop closing ')'

        -- Parse key and optional filters: "key | filter1 | filter2"
        (key, filters) = parseKeyAndFilters placeholder

        -- Look up base value and apply filters BEFORE rendering
        replacement = case Map.lookup key ctx of
            Just ft ->
                -- Apply filters to the visual component
                let filteredVisual = applyFilters filters (visual ft)
                    filteredFt = FlexiText filteredVisual (altText ft)
                in case mode of
                    PlainText -> renderFlexiText filteredFt
                    ShieldsIOBadge -> renderFlexiTextBadge key filteredFt
            Nothing -> "(:MISSING:" ++ key ++ ")"

    in replacement ++ renderWithMode mode ctx tailStr
renderWithMode mode ctx (c:cs) = c : renderWithMode mode ctx cs

-- | Parse "key | filter1 | filter2" into (key, [filter1, filter2])
parseKeyAndFilters :: String -> (String, [String])
parseKeyAndFilters placeholder =
    let parts = splitOn '|' placeholder
        trimmedParts = map trim parts
    in case trimmedParts of
        [] -> ("", [])
        (k:fs) -> (k, fs)

-- | Apply a list of filters in sequence
applyFilters :: [String] -> String -> String
applyFilters [] value = value
applyFilters (f:fs) value = applyFilters fs (DAX.applyFilter f value)

-- | Split string on delimiter
splitOn :: Char -> String -> [String]
splitOn _ [] = []
splitOn delim s =
    let (chunk, rest) = break (== delim) s
    in chunk : case rest of
        [] -> []
        (_:xs) -> splitOn delim xs

-- | Trim whitespace from string
trim :: String -> String
trim = reverse . dropWhile isSpace . reverse . dropWhile isSpace
  where
    isSpace c = c == ' ' || c == '\t' || c == '\n' || c == '\r'

-- | Sanitize a string for safe inclusion in various contexts.
-- Guard 1 of the Tri-Guard system.
sanitize :: SanitizeContext -> String -> String
sanitize ctx = filter (allowed ctx)
  where
    allowed TableCell c = c /= '|' && c /= '\n'
    allowed AltText c = c /= '[' && c /= ']' && c /= '"'
    allowed Url c = c `elem` (['a'..'z'] ++ ['A'..'Z'] ++ ['0'..'9'] ++ "-_./:")
    allowed PlainTextCtx _ = True

-- | Context for sanitization determines which characters are allowed.
data SanitizeContext
    = TableCell    -- ^ Inside a Markdown table cell
    | AltText      -- ^ Inside image alt-text brackets
    | Url          -- ^ Inside a URL
    | PlainTextCtx -- ^ No restrictions
    deriving (Show, Eq)
