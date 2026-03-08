{- |
Module      : Types
Description : Core types for the Gnosis rendering engine
Copyright   : (c) 2025-2026 Jonathan D.A. Jewell
License     : PMPL-1.0-or-later
Maintainer  : hyperpolymath

This module defines the FlexiText type which ensures every visual
element has accompanying alt-text for accessibility compliance.
-}

module Types
    ( FlexiText(..)
    , Context
    , mkFlexiText
    , renderFlexiText
    , renderFlexiTextBadge
    ) where

import Data.Map.Strict (Map)

-- | FlexiText ensures accessibility by pairing visual and semantic content.
-- The Tri-Guard system requires this for all dynamic output.
data FlexiText = FlexiText
    { visual  :: !String  -- ^ What is displayed (emoji, text, badge URL)
    , altText :: !String  -- ^ What screen readers announce (cannot be empty)
    } deriving (Show, Eq)

-- | The rendering context: a map from placeholder keys to FlexiText values.
type Context = Map String FlexiText

-- | Smart constructor that validates non-empty alt-text.
-- Proof obligation: alt-text-non-empty
mkFlexiText :: String -> String -> Either String FlexiText
mkFlexiText v a
    | null a    = Left "Alt-text cannot be empty (Tri-Guard violation)"
    | otherwise = Right $ FlexiText v a

-- | Render FlexiText as plain text (for inline use).
renderFlexiText :: FlexiText -> String
renderFlexiText (FlexiText v _) = v

-- | Render FlexiText as a Shields.io badge (for visual emphasis).
-- Format: ![alt-text](badge-url)
renderFlexiTextBadge :: String -> FlexiText -> String
renderFlexiTextBadge key (FlexiText v a) =
    "![" ++ sanitizeAlt a ++ "](https://img.shields.io/badge/"
    ++ sanitizeUrl v ++ "-grey?label=" ++ sanitizeUrl key ++ ")"
  where
    -- Sanitize for Markdown image alt-text (Guard 1: Sanitization)
    sanitizeAlt = filter (\c -> c /= '[' && c /= ']' && c /= '"')
    -- Sanitize for URL (spaces become underscores, special chars removed)
    sanitizeUrl = map (\c -> if c == ' ' then '_' else c) . filter urlSafe
    urlSafe c = c `elem` (['a'..'z'] ++ ['A'..'Z'] ++ ['0'..'9'] ++ "-_.")
