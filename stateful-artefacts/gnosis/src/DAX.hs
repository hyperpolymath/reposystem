{- |
Module      : DAX
Description : DAX (Data eXpression) Era - Conditional rendering and basic logic
Copyright   : (c) 2025-2026 Jonathan D.A. Jewell
License     : PMPL-1.0-or-later
Maintainer  : hyperpolymath

DAX provides conditional rendering for templates based on metadata values.
Simplified MVP version for v1.0.
-}

module DAX
    ( evalCondition
    , processConditionals
    , processLoops
    , processTemplate
    , applyFilter
    , thousandsSeparator
    , relativeTime
    , roundValue
    , readInt
    , parseISODate
    ) where

import qualified Data.Map.Strict as Map
import Types (Context, FlexiText(..))

-- | Evaluate a simple condition like "phase == alpha"
evalCondition :: Context -> String -> Bool
evalCondition ctx condition =
    let trimmed = trim condition
    in case parseCondition trimmed of
        Just (key, op, value) ->
            case Map.lookup key ctx of
                Just (FlexiText actual _) -> compareValues op actual value
                Nothing -> False
        Nothing -> False

-- | Parse condition string into (key, operator, value)
parseCondition :: String -> Maybe (String, String, String)
parseCondition s
    -- Two-character operators first (before single-char > and <)
    | ">=" `isInfixOf` s = splitOn ">=" s >>= \(k, v) -> Just (trim k, ">=", trim v)
    | "<=" `isInfixOf` s = splitOn "<=" s >>= \(k, v) -> Just (trim k, "<=", trim v)
    | "==" `isInfixOf` s = splitOn "==" s >>= \(k, v) -> Just (trim k, "==", trim v)
    | "!=" `isInfixOf` s = splitOn "!=" s >>= \(k, v) -> Just (trim k, "!=", trim v)
    -- Single-character operators last
    | ">" `isInfixOf` s  = splitOn ">" s  >>= \(k, v) -> Just (trim k, ">",  trim v)
    | "<" `isInfixOf` s  = splitOn "<" s  >>= \(k, v) -> Just (trim k, "<",  trim v)
    | otherwise = Nothing
  where
    splitOn :: String -> String -> Maybe (String, String)
    splitOn needle haystack =
        case breakOn needle haystack of
            (before, after) | not (null after) ->
                Just (before, drop (length needle) after)
            _ -> Nothing

    breakOn :: String -> String -> (String, String)
    breakOn needle haystack = go "" haystack
      where
        go acc [] = (reverse acc, "")
        go acc str@(x:xs)
            | needle `isPrefixOf` str = (reverse acc, str)
            | otherwise = go (x:acc) xs

-- | Compare values based on operator
compareValues :: String -> String -> String -> Bool
compareValues "==" a b = a == b
compareValues "!=" a b = a /= b
compareValues ">=" a b = numericCompare (>=) a b
compareValues "<=" a b = numericCompare (<=) a b
compareValues ">"  a b = numericCompare (>)  a b
compareValues "<"  a b = numericCompare (<)  a b
compareValues _ _ _ = False

-- | Numeric comparison: parse both sides as integers, fall back to False
numericCompare :: (Int -> Int -> Bool) -> String -> String -> Bool
numericCompare op a b =
    case (readInt a, readInt b) of
        (Just na, Just nb) -> op na nb
        _ -> False

-- | Parse a string as an integer, returning Nothing on failure
readInt :: String -> Maybe Int
readInt [] = Nothing
readInt ('-':rest) = case readNat rest of
    Just n  -> Just (negate n)
    Nothing -> Nothing
readInt s = readNat s

-- | Parse a string as a natural number
readNat :: String -> Maybe Int
readNat [] = Nothing
readNat s
    | all isDigit s = Just (foldl (\acc c -> acc * 10 + digitToInt c) 0 s)
    | otherwise = Nothing
  where
    isDigit c = c >= '0' && c <= '9'
    digitToInt c = fromEnum c - fromEnum '0'

-- | Process {{#if}} conditionals in template
processConditionals :: Context -> String -> String
processConditionals ctx template = processIfBlocks ctx template

-- | Process {{#for}} loops in template
processLoops :: Context -> String -> String
processLoops ctx template = processForBlocks ctx template

-- | Process all DAX features (conditionals + loops)
processTemplate :: Context -> String -> String
processTemplate ctx template =
    let withConditionals = processConditionals ctx template
        withLoops = processLoops ctx withConditionals
    in withLoops

-- | Process {{#if condition}} ... {{#else}} ... {{/if}} blocks
-- Supports optional {{#else}} clause.
processIfBlocks :: Context -> String -> String
processIfBlocks ctx template = go template
  where
    go [] = []
    go str
        | "{{#if " `isPrefixOf` str =
            let (condition, rest1) = extractUntil "}}" (drop 6 str)
                (ifBody, rest2) = extractUntil "{{/if}}" rest1
                shouldShow = evalCondition ctx condition
                -- Split ifBody on {{#else}} if present
                (trueBlock, falseBlock) = splitElse ifBody
                result = if shouldShow then trueBlock else falseBlock
            in processIfBlocks ctx result ++ go rest2  -- recurse into chosen block for nested conditionals
        | otherwise = safeHead str ++ go (safeTail str)

-- | Split a block on {{#else}}, returning (trueBlock, falseBlock).
-- Respects nested {{#if}} blocks so inner {{#else}} is not consumed.
splitElse :: String -> (String, String)
splitElse = go 0 ""
  where
    go :: Int -> String -> String -> (String, String)
    go _ acc [] = (reverse acc, "")
    go depth acc s
        | depth == 0 && "{{#else}}" `isPrefixOf` s =
            (reverse acc, drop 9 s)
        | "{{#if " `isPrefixOf` s =
            go (depth + 1) (safeHeadChar s : acc) (safeTail s)
        | "{{/if}}" `isPrefixOf` s =
            go (depth - 1) (safeHeadChar s : acc) (safeTail s)
        | otherwise =
            go depth (safeHeadChar s : acc) (safeTail s)

-- | Process {{#for item in list}} ... {{/for}} blocks
-- Supports: {{#for tag in tags}} ... {{/for}}
-- List values can be comma-separated strings in context
processForBlocks :: Context -> String -> String
processForBlocks ctx template = go template
  where
    go [] = []
    go str
        | "{{#for " `isPrefixOf` str =
            let (loopSpec, rest1) = extractUntil "}}" (drop 7 str)  -- drop "{{#for "
                (loopBody, rest2) = extractUntil "{{/for}}" rest1
                result = processLoop ctx loopSpec loopBody
            in result ++ go rest2  -- extractUntil already dropped "{{/for}}"
        | otherwise = safeHead str ++ go (safeTail str)

-- | Process a single loop: extract variable name and list key, then iterate
-- Supports {{@index}} (0-based) inside loop body.
processLoop :: Context -> String -> String -> String
processLoop ctx loopSpec loopBody =
    case parseLoopSpec (trim loopSpec) of
        Just (itemVar, listKey) ->
            case Map.lookup listKey ctx of
                Just (FlexiText listStr _) ->
                    let items = splitList listStr
                        renderedItems = zipWith (renderLoopItemWithIndex itemVar loopBody) [0..] items
                    in concat renderedItems
                Nothing -> ""  -- List key not found, render nothing
        Nothing -> ""  -- Invalid loop syntax, render nothing

-- | Parse "item in listKey" into (item, listKey)
parseLoopSpec :: String -> Maybe (String, String)
parseLoopSpec spec =
    case words spec of
        [item, "in", listKey] -> Just (trim item, trim listKey)
        _ -> Nothing

-- | Split a comma-separated list
splitList :: String -> [String]
splitList str = map trim (splitOn ',' str)
  where
    splitOn _ [] = []
    splitOn delim s =
        let (chunk, rest) = break (== delim) s
        in chunk : case rest of
            [] -> []
            (_:xs) -> splitOn delim xs

-- | Render loop body with item variable and @index replaced
renderLoopItemWithIndex :: String -> String -> Int -> String -> String
renderLoopItemWithIndex varName body idx itemValue =
    let withItem = replacePlaceholder varName itemValue body
        withIndex = replaceIndexPlaceholder idx withItem
    in withIndex

-- | Replace {{@index}} with the current loop index (0-based)
replaceIndexPlaceholder :: Int -> String -> String
replaceIndexPlaceholder idx = go
  where
    go [] = []
    go str
        | "{{@index}}" `isPrefixOf` str = show idx ++ go (drop 10 str)
        | otherwise = safeHead str ++ go (safeTail str)

-- | Replace (:varName) or (:varName | filter) with value in string
-- Handles both simple placeholders and filter syntax
replacePlaceholder :: String -> String -> String -> String
replacePlaceholder varName value = go
  where
    placeholderStart = "(:" ++ varName
    go [] = []
    go str
        | placeholderStart `isPrefixOf` str =
            -- Found start of placeholder, find the closing )
            let afterStart = drop (length placeholderStart) str
                (filterPart, rest) = span (/= ')') afterStart
                closingRest = drop 1 rest  -- Drop the )
                -- Parse and apply filters if present
                filters = parseFilters (trim filterPart)
                filteredValue = applyFilters filters value
            in filteredValue ++ go closingRest
        | otherwise = safeHead str ++ go (safeTail str)

    -- Parse "| filter1 | filter2" into ["filter1", "filter2"]
    parseFilters "" = []
    parseFilters s
        | "|" `isPrefixOf` s =
            let parts = splitOn '|' (trim s)
            in map trim (filter (not . null) parts)
        | otherwise = []

    splitOn _ [] = []
    splitOn delim s =
        let (chunk, rest) = break (== delim) s
        in chunk : case rest of
            [] -> []
            (_:xs) -> splitOn delim xs

    applyFilters [] v = v
    applyFilters (f:fs) v = applyFilters fs (applyFilter f v)

-- Helper: Extract text until delimiter
extractUntil :: String -> String -> (String, String)
extractUntil delimiter str = go "" str
  where
    go acc [] = (reverse acc, "")
    go acc s
        | delimiter `isPrefixOf` s = (reverse acc, drop (length delimiter) s)
        | otherwise = go (safeHeadChar s : acc) (safeTail s)

-- | Safe head: return first character as string, or empty
safeHead :: String -> String
safeHead [] = ""
safeHead (x:_) = [x]

-- | Safe head: return first character, or null char (should not be reached)
safeHeadChar :: String -> Char
safeHeadChar [] = '\0'
safeHeadChar (x:_) = x

-- | Safe tail: return rest of string, or empty
safeTail :: String -> String
safeTail [] = ""
safeTail (_:xs) = xs

-- Helper functions
trim :: String -> String
trim = reverse . dropWhile isSpace . reverse . dropWhile isSpace
  where
    isSpace c = c == ' ' || c == '\t' || c == '\n' || c == '\r'

isInfixOf :: String -> String -> Bool
isInfixOf needle haystack = any (isPrefixOf needle) (tails haystack)
  where
    tails [] = [[]]
    tails s@(_:xs) = s : tails xs

isPrefixOf :: String -> String -> Bool
isPrefixOf [] _ = True
isPrefixOf _ [] = False
isPrefixOf (x:xs) (y:ys) = x == y && isPrefixOf xs ys

-- | Apply a filter function to a value.
-- Built-in filters are checked first, then plugin filters via the registry.
applyFilter :: String -> String -> String
applyFilter "thousands-separator" value = thousandsSeparator value
applyFilter "relativeTime" value = relativeTime value
applyFilter "uppercase" value = map toUpper value
applyFilter "lowercase" value = map toLower value
applyFilter "capitalize" value = capitalize value
applyFilter "round" value = roundValue value
-- Plugin filters (registered in PluginLoader)
applyFilter "emojify" value = emojifyBuiltin value
applyFilter "slug" value = slugBuiltin value
applyFilter "truncate" value = truncateBuiltin value
applyFilter "strip-html" value = stripHtmlBuiltin value
applyFilter "count-words" value = countWordsBuiltin value
applyFilter "reverse" value = reverse value
applyFilter _ value = value  -- Unknown filter, return as-is

-- | Emojify plugin: add emoji to phase/status values
emojifyBuiltin :: String -> String
emojifyBuiltin "alpha"       = "🔬 alpha"
emojifyBuiltin "beta"        = "🧪 beta"
emojifyBuiltin "stable"      = "✅ stable"
emojifyBuiltin "production"  = "🚀 production"
emojifyBuiltin "deprecated"  = "⚠️  deprecated"
emojifyBuiltin "complete"    = "✅ complete"
emojifyBuiltin "planned"     = "📋 planned"
emojifyBuiltin "scaffolded"  = "🏗️  scaffolded"
emojifyBuiltin "active"      = "✨ active"
emojifyBuiltin s             = s

-- | Slug plugin: convert to URL-safe slug
slugBuiltin :: String -> String
slugBuiltin = map slugChar . filter validSlugChar
  where
    slugChar ' ' = '-'
    slugChar c   = toLower c
    validSlugChar c = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
                   || (c >= '0' && c <= '9') || c == ' ' || c == '-' || c == '_'

-- | Truncate to 50 characters with ellipsis
truncateBuiltin :: String -> String
truncateBuiltin s
    | length s <= 50 = s
    | otherwise = take 47 s ++ "..."

-- | Strip HTML tags
stripHtmlBuiltin :: String -> String
stripHtmlBuiltin = go False
  where
    go _ [] = []
    go True  ('>':rest)  = go False rest
    go True  (_:rest)    = go True rest
    go False ('<':rest)  = go True rest
    go False (c:rest)    = c : go False rest

-- | Count words
countWordsBuiltin :: String -> String
countWordsBuiltin = show . length . words

-- | Add thousands separator to numbers
thousandsSeparator :: String -> String
thousandsSeparator str =
    let digits = reverse str
        grouped = groupBy3 digits
    in reverse $ intercalate "," grouped
  where
    groupBy3 [] = []
    groupBy3 s
        | length s <= 3 = [s]
        | otherwise = take 3 s : groupBy3 (drop 3 s)

    intercalate _ [] = ""
    intercalate _ [x] = x
    intercalate sep (x:xs) = x ++ sep ++ intercalate sep xs

-- | Convert ISO timestamp (YYYY-MM-DD or YYYY-MM-DDTHH:MM:SS) to relative description.
-- Compares against a reference date. For static rendering, describes the date itself.
relativeTime :: String -> String
relativeTime str =
    case parseISODate str of
        Just (y, m, d) -> formatRelativeDate y m d
        Nothing -> str  -- Not a valid date, return as-is

-- | Parse YYYY-MM-DD prefix from ISO timestamp
parseISODate :: String -> Maybe (Int, Int, Int)
parseISODate s =
    case s of
        (y1:y2:y3:y4:'-':m1:m2:'-':d1:d2:_) ->
            case (readInt [y1,y2,y3,y4], readInt [m1,m2], readInt [d1,d2]) of
                (Just y, Just m, Just d)
                    | m >= 1 && m <= 12 && d >= 1 && d <= 31 -> Just (y, m, d)
                _ -> Nothing
        _ -> Nothing

-- | Format a date as a human-readable relative description
formatRelativeDate :: Int -> Int -> Int -> String
formatRelativeDate y m _d =
    let monthNames = ["January","February","March","April","May","June",
                      "July","August","September","October","November","December"]
        monthName = if m >= 1 && m <= 12 then monthNames !! (m - 1) else "Unknown"
    in monthName ++ " " ++ show y

-- | Capitalize first letter
capitalize :: String -> String
capitalize [] = []
capitalize (x:xs) = toUpper x : xs

-- | Round a numeric value: truncates decimal portion.
-- "3.14" -> "3", "99.9" -> "100", "42" -> "42"
roundValue :: String -> String
roundValue str =
    case break (== '.') str of
        (intPart, '.':decPart) ->
            case (readInt intPart, readNatDigits decPart) of
                (Just n, Just (firstDec, _)) ->
                    if firstDec >= 5
                        then show (if n >= 0 then n + 1 else n - 1)
                        else show n
                _ -> str  -- Not a valid number
        _ -> str  -- No decimal point, return as-is
  where
    readNatDigits :: String -> Maybe (Int, Int)
    readNatDigits [] = Nothing
    readNatDigits (c:_)
        | c >= '0' && c <= '9' = Just (fromEnum c - fromEnum '0', 0)
        | otherwise = Nothing

-- | Convert to uppercase
toUpper :: Char -> Char
toUpper c
    | c >= 'a' && c <= 'z' = toEnum (fromEnum c - 32)
    | otherwise = c

-- | Convert to lowercase
toLower :: Char -> Char
toLower c
    | c >= 'A' && c <= 'Z' = toEnum (fromEnum c + 32)
    | otherwise = c
