{- |
Module      : SExp
Description : S-expression parser for Guile Scheme metadata files
Copyright   : (c) 2025-2026 Jonathan D.A. Jewell
License     : PMPL-1.0-or-later
Maintainer  : hyperpolymath

This module provides a recursive descent parser for S-expressions,
enabling Gnosis to read STATE.scm and other Guile metadata files.
-}

module SExp
    ( SExp(..)
    , parseSExp
    , findInTree
    , findPair
    ) where

import Data.Char (isSpace)

-- | An S-Expression is either an Atom or a List of S-Expressions.
-- This is the universal representation of Lisp data.
data SExp
    = Atom String
    | List [SExp]
    deriving (Show, Eq)

-- | Parse a string into an S-Expression tree.
-- Returns Nothing if parsing fails.
parseSExp :: String -> Maybe SExp
parseSExp input =
    case runParser sexp (stripComments input) of
        Just (result, _) -> Just result
        Nothing -> Nothing

-- | Find a value by key in the S-Expression tree.
-- Looks for patterns like (key . "value") or (key "value")
findInTree :: String -> SExp -> Maybe String
findInTree target (List items) =
    case findPair target items of
        Just val -> Just val
        Nothing -> firstJust (map (findInTree target) items)
findInTree _ (Atom _) = Nothing

-- | Find a dotted pair or simple pair in a list of S-expressions.
-- Handles: (key . "value") and (key "value")
findPair :: String -> [SExp] -> Maybe String
findPair target items =
    case items of
        [Atom k, Atom ".", Atom v] | k == target -> Just v
        [Atom k, Atom v] | k == target -> Just v
        _ -> Nothing

-- | Return the first Just value from a list, or Nothing.
firstJust :: [Maybe a] -> Maybe a
firstJust = foldr (<|>) Nothing
  where
    Just x <|> _ = Just x
    Nothing <|> y = y

-- Simple parser combinator implementation
type Parser a = String -> Maybe (a, String)

runParser :: Parser a -> String -> Maybe (a, String)
runParser = id

-- | Strip Scheme comments (lines starting with ;)
stripComments :: String -> String
stripComments = unlines . filter (not . isComment) . lines
  where
    isComment s = case dropWhile isSpace s of
        (';':_) -> True
        _ -> False

-- | Parse whitespace
spaces :: Parser ()
spaces input = Just ((), dropWhile isSpace input)

-- | Parse a quoted string
quotedString :: Parser String
quotedString ('"':rest) =
    let (str, remaining) = span (/= '"') rest
    in case remaining of
        ('"':xs) -> Just (str, xs)
        _ -> Nothing
quotedString _ = Nothing

-- | Parse an atom (unquoted identifier or number)
atom :: Parser String
atom input =
    let (str, remaining) = span isAtomChar input
    in if null str then Nothing else Just (str, remaining)
  where
    isAtomChar c = not (isSpace c) && c /= '(' && c /= ')' && c /= '"'

-- | Parse a single S-expression
sexp :: Parser SExp
sexp input = do
    (_, input1) <- spaces input
    case input1 of
        ('(':rest) -> do
            (items, rest2) <- parseList rest
            (_, rest3) <- spaces rest2
            case rest3 of
                (')':rest4) -> Just (List items, rest4)
                _ -> Nothing
        ('"':_) -> do
            (str, rest2) <- quotedString input1
            Just (Atom str, rest2)
        _ -> do
            (str, rest2) <- atom input1
            Just (Atom str, rest2)

-- | Parse a list of S-expressions (inside parentheses)
parseList :: Parser [SExp]
parseList input = do
    (_, input1) <- spaces input
    case input1 of
        (')':_) -> Just ([], input1)
        _ -> do
            (item, rest) <- sexp input1
            (items, rest2) <- parseList rest
            Just (item:items, rest2)
