{- |
Module      : Spec
Description : Test suite for Gnosis engine
Copyright   : (c) 2025-2026 Jonathan D.A. Jewell
License     : PMPL-1.0-or-later
-}

module Main (main) where

import qualified Data.Map.Strict as Map

import Types (FlexiText(..), Context)
import SExp (SExp(..), parseSExp, findInTree, findPair)
import Render (render, renderWithBadges)
import DAX

-- Simple test harness
data TestResult = Pass String | Fail String String String
type Test = IO TestResult

assertEqual :: (Show a, Eq a) => String -> a -> a -> Test
assertEqual name expected actual =
    if expected == actual
        then return (Pass name)
        else return (Fail name (show expected) (show actual))

assertBool :: String -> Bool -> Test
assertBool name True  = return (Pass name)
assertBool name False = return (Fail name "True" "False")

runTests :: [Test] -> IO ()
runTests tests = do
    results <- sequence tests
    let passes = length [() | Pass _ <- results]
    let fails  = [r | r@(Fail _ _ _) <- results]
    let total  = length results

    mapM_ printResult results
    putStrLn ""
    putStrLn $ show passes ++ "/" ++ show total ++ " tests passed"
    if null fails
        then putStrLn "ALL TESTS PASSED"
        else do
            putStrLn $ show (length fails) ++ " FAILURES:"
            mapM_ (\(Fail n _ _) -> putStrLn $ "  - " ++ n) fails

printResult :: TestResult -> IO ()
printResult (Pass name) = putStrLn $ "  PASS  " ++ name
printResult (Fail name expected actual) =
    putStrLn $ "  FAIL  " ++ name ++ "\n        expected: " ++ expected ++ "\n        actual:   " ++ actual

-- | Build a test context
mkCtx :: [(String, String)] -> Context
mkCtx = Map.fromList . map (\(k, v) -> (k, FlexiText v v))

main :: IO ()
main = do
    putStrLn "Gnosis Test Suite"
    putStrLn "================="
    putStrLn ""

    putStrLn "--- S-Expression Parser ---"
    runTests sexpTests

    putStrLn ""
    putStrLn "--- Template Renderer ---"
    runTests renderTests

    putStrLn ""
    putStrLn "--- DAX Conditionals ---"
    runTests daxCondTests

    putStrLn ""
    putStrLn "--- DAX Else Blocks ---"
    runTests daxElseTests

    putStrLn ""
    putStrLn "--- DAX Numeric Comparison ---"
    runTests daxNumericTests

    putStrLn ""
    putStrLn "--- DAX Loops ---"
    runTests daxLoopTests

    putStrLn ""
    putStrLn "--- DAX Loop Index ---"
    runTests daxIndexTests

    putStrLn ""
    putStrLn "--- DAX Filters ---"
    runTests daxFilterTests

    putStrLn ""
    putStrLn "--- relativeTime Filter ---"
    runTests relativeTimeTests

    putStrLn ""
    putStrLn "--- roundValue Filter ---"
    runTests roundValueTests

-- ============================================================================
-- S-Expression Parser Tests
-- ============================================================================

sexpTests :: [Test]
sexpTests =
    [ assertEqual "parse atom"
        (Just (Atom "hello"))
        (parseSExp "hello")

    , assertEqual "parse quoted string"
        (Just (Atom "hello world"))
        (parseSExp "\"hello world\"")

    , assertEqual "parse simple list"
        (Just (List [Atom "a", Atom "b"]))
        (parseSExp "(a b)")

    , assertEqual "parse dotted pair"
        (Just (List [Atom "name", Atom ".", Atom "gnosis"]))
        (parseSExp "(name . gnosis)")

    , assertEqual "parse nested list"
        (Just (List [Atom "outer", List [Atom "inner", Atom "value"]]))
        (parseSExp "(outer (inner value))")

    , assertEqual "parse with quoted value"
        (Just (List [Atom "version", Atom ".", Atom "1.0"]))
        (parseSExp "(version . \"1.0\")")

    , assertEqual "parse strips comments"
        (Just (Atom "value"))
        (parseSExp ";; comment\nvalue")

    , assertEqual "findInTree: dotted pair"
        (Just "1.0")
        (findInTree "version" (List [List [Atom "version", Atom ".", Atom "1.0"]]))

    , assertEqual "findInTree: simple pair"
        (Just "active")
        (findInTree "status" (List [List [Atom "status", Atom "active"]]))

    , assertEqual "findInTree: nested"
        (Just "deep")
        (findInTree "key" (List [List [Atom "outer", List [Atom "key", Atom "deep"]]]))

    , assertEqual "findInTree: not found"
        Nothing
        (findInTree "missing" (List [List [Atom "other", Atom "val"]]))

    , assertEqual "findPair: dotted"
        (Just "v")
        (findPair "k" [Atom "k", Atom ".", Atom "v"])

    , assertEqual "findPair: simple"
        (Just "v")
        (findPair "k" [Atom "k", Atom "v"])

    , assertEqual "findPair: wrong key"
        Nothing
        (findPair "k" [Atom "other", Atom "v"])

    , assertBool "parse empty returns Nothing"
        (parseSExp "" == Nothing)
    ]

-- ============================================================================
-- Template Renderer Tests
-- ============================================================================

renderTests :: [Test]
renderTests =
    let ctx = mkCtx [("name", "Gnosis"), ("version", "1.1.0"), ("status", "alpha")]
    in
    [ assertEqual "simple placeholder"
        "Project: Gnosis"
        (render ctx "Project: (:name)")

    , assertEqual "multiple placeholders"
        "Gnosis v1.1.0"
        (render ctx "(:name) v(:version)")

    , assertEqual "missing placeholder"
        "(:MISSING:absent)"
        (render ctx "(:absent)")

    , assertEqual "no placeholders"
        "plain text"
        (render ctx "plain text")

    , assertEqual "empty template"
        ""
        (render ctx "")

    , assertEqual "placeholder with filter uppercase"
        "GNOSIS"
        (render ctx "(:name | uppercase)")

    , assertEqual "placeholder with filter lowercase"
        "gnosis"
        (render ctx "(:name | lowercase)")

    , assertEqual "placeholder with filter capitalize"
        "Alpha"
        (render ctx "(:status | capitalize)")

    , assertEqual "badge mode renders shields.io"
        True
        ("img.shields.io" `isIn` renderWithBadges ctx "(:name)")

    , assertEqual "badge mode has alt text"
        True
        ("![" `isIn` renderWithBadges ctx "(:name)")
    ]
  where
    isIn needle haystack = any (startsWith needle) (suffixes haystack)
    startsWith [] _ = True
    startsWith _ [] = False
    startsWith (x:xs) (y:ys) = x == y && startsWith xs ys
    suffixes [] = [[]]
    suffixes s@(_:xs) = s : suffixes xs

-- ============================================================================
-- DAX Conditionals Tests
-- ============================================================================

daxCondTests :: [Test]
daxCondTests =
    let ctx = mkCtx [("phase", "alpha"), ("status", "active"), ("count", "42")]
    in
    [ assertEqual "if true shows block"
        "visible"
        (processConditionals ctx "{{#if phase == alpha}}visible{{/if}}")

    , assertEqual "if false hides block"
        ""
        (processConditionals ctx "{{#if phase == beta}}hidden{{/if}}")

    , assertEqual "if != true shows block"
        "shown"
        (processConditionals ctx "{{#if phase != beta}}shown{{/if}}")

    , assertEqual "if != false hides block"
        ""
        (processConditionals ctx "{{#if phase != alpha}}hidden{{/if}}")

    , assertEqual "preserves text around if"
        "before visible after"
        (processConditionals ctx "before {{#if phase == alpha}}visible{{/if}} after")

    , assertEqual "missing key hides block"
        ""
        (processConditionals ctx "{{#if missing == x}}hidden{{/if}}")

    , assertEqual "multiple if blocks"
        "A B"
        (processConditionals ctx "{{#if phase == alpha}}A{{/if}} {{#if status == active}}B{{/if}}")
    ]

-- ============================================================================
-- DAX Else Blocks Tests
-- ============================================================================

daxElseTests :: [Test]
daxElseTests =
    let ctx = mkCtx [("phase", "alpha"), ("mode", "debug")]
    in
    [ assertEqual "else: true branch taken"
        "YES"
        (processConditionals ctx "{{#if phase == alpha}}YES{{#else}}NO{{/if}}")

    , assertEqual "else: false branch taken"
        "NO"
        (processConditionals ctx "{{#if phase == beta}}YES{{#else}}NO{{/if}}")

    , assertEqual "else: with surrounding text"
        "Status: active"
        (processConditionals ctx "Status: {{#if phase == alpha}}active{{#else}}inactive{{/if}}")

    , assertEqual "else: false with content"
        "Mode is not production"
        (processConditionals ctx "{{#if mode == production}}Mode is production{{#else}}Mode is not production{{/if}}")

    , assertEqual "no else: still works"
        "visible"
        (processConditionals ctx "{{#if phase == alpha}}visible{{/if}}")

    , assertEqual "no else: false hides"
        ""
        (processConditionals ctx "{{#if phase == beta}}hidden{{/if}}")
    ]

-- ============================================================================
-- DAX Numeric Comparison Tests
-- ============================================================================

daxNumericTests :: [Test]
daxNumericTests =
    let ctx = mkCtx [("count", "42"), ("limit", "100"), ("zero", "0"), ("negative", "-5")]
    in
    [ assertEqual "greater than: true"
        "yes"
        (processConditionals ctx "{{#if count > 10}}yes{{/if}}")

    , assertEqual "greater than: false"
        ""
        (processConditionals ctx "{{#if count > 100}}yes{{/if}}")

    , assertEqual "less than: true"
        "yes"
        (processConditionals ctx "{{#if count < 100}}yes{{/if}}")

    , assertEqual "less than: false"
        ""
        (processConditionals ctx "{{#if count < 10}}yes{{/if}}")

    , assertEqual "greater or equal: equal"
        "yes"
        (processConditionals ctx "{{#if count >= 42}}yes{{/if}}")

    , assertEqual "greater or equal: greater"
        "yes"
        (processConditionals ctx "{{#if limit >= 42}}yes{{/if}}")

    , assertEqual "less or equal: equal"
        "yes"
        (processConditionals ctx "{{#if count <= 42}}yes{{/if}}")

    , assertEqual "less or equal: less"
        "yes"
        (processConditionals ctx "{{#if count <= 100}}yes{{/if}}")

    , assertEqual "numeric with else"
        "small"
        (processConditionals ctx "{{#if count > 100}}big{{#else}}small{{/if}}")

    , assertEqual "non-numeric comparison falls back to false"
        ""
        (processConditionals ctx "{{#if count > abc}}yes{{/if}}")

    , assertEqual "readInt positive"
        (Just 42)
        (readInt "42")

    , assertEqual "readInt negative"
        (Just (-5))
        (readInt "-5")

    , assertEqual "readInt zero"
        (Just 0)
        (readInt "0")

    , assertEqual "readInt non-numeric"
        Nothing
        (readInt "abc")

    , assertEqual "readInt empty"
        Nothing
        (readInt "")
    ]

-- ============================================================================
-- DAX Loop Tests
-- ============================================================================

daxLoopTests :: [Test]
daxLoopTests =
    let ctx = mkCtx [("tags", "rust,haskell,zig"), ("items", "a,b"), ("single", "one")]
    in
    [ assertEqual "loop over comma list"
        "- rust\n- haskell\n- zig\n"
        (processLoops ctx "{{#for tag in tags}}- (:tag)\n{{/for}}")

    , assertEqual "loop two items"
        "[a][b]"
        (processLoops ctx "{{#for x in items}}[(:x)]{{/for}}")

    , assertEqual "loop single item"
        "one"
        (processLoops ctx "{{#for x in single}}(:x){{/for}}")

    , assertEqual "loop missing key"
        ""
        (processLoops ctx "{{#for x in missing}}(:x){{/for}}")

    , assertEqual "preserves text around loop"
        "before [a][b] after"
        (processLoops ctx "before {{#for x in items}}[(:x)]{{/for}} after")
    ]

-- ============================================================================
-- DAX Loop Index Tests
-- ============================================================================

daxIndexTests :: [Test]
daxIndexTests =
    let ctx = mkCtx [("items", "a,b,c"), ("single", "x")]
    in
    [ assertEqual "@index basic"
        "0:a 1:b 2:c "
        (processLoops ctx "{{#for x in items}}{{@index}}:(:x) {{/for}}")

    , assertEqual "@index single item"
        "0:x"
        (processLoops ctx "{{#for x in single}}{{@index}}:(:x){{/for}}")

    , assertEqual "@index in list"
        "0. a\n1. b\n2. c\n"
        (processLoops ctx "{{#for x in items}}{{@index}}. (:x)\n{{/for}}")

    , assertEqual "@index without usage"
        "[a][b][c]"
        (processLoops ctx "{{#for x in items}}[(:x)]{{/for}}")
    ]

-- ============================================================================
-- DAX Filter Tests
-- ============================================================================

daxFilterTests :: [Test]
daxFilterTests =
    [ assertEqual "uppercase filter"
        "HELLO"
        (applyFilter "uppercase" "hello")

    , assertEqual "lowercase filter"
        "hello"
        (applyFilter "lowercase" "HELLO")

    , assertEqual "capitalize filter"
        "Hello"
        (applyFilter "capitalize" "hello")

    , assertEqual "thousands-separator"
        "1,234,567"
        (thousandsSeparator "1234567")

    , assertEqual "thousands-separator small"
        "42"
        (thousandsSeparator "42")

    , assertEqual "thousands-separator exact 3"
        "123"
        (thousandsSeparator "123")

    , assertEqual "unknown filter passes through"
        "value"
        (applyFilter "nonexistent" "value")

    , assertEqual "capitalize empty"
        ""
        (applyFilter "capitalize" "")
    ]

-- ============================================================================
-- relativeTime Filter Tests
-- ============================================================================

relativeTimeTests :: [Test]
relativeTimeTests =
    [ assertEqual "relativeTime ISO date"
        "January 2025"
        (relativeTime "2025-01-24")

    , assertEqual "relativeTime ISO datetime"
        "March 2026"
        (relativeTime "2026-03-07T14:30:00")

    , assertEqual "relativeTime December"
        "December 2024"
        (relativeTime "2024-12-01")

    , assertEqual "relativeTime invalid returns as-is"
        "not-a-date"
        (relativeTime "not-a-date")

    , assertEqual "parseISODate valid"
        (Just (2025, 1, 24))
        (parseISODate "2025-01-24")

    , assertEqual "parseISODate with time"
        (Just (2026, 3, 7))
        (parseISODate "2026-03-07T14:30:00")

    , assertEqual "parseISODate invalid month"
        Nothing
        (parseISODate "2025-13-01")

    , assertEqual "parseISODate too short"
        Nothing
        (parseISODate "2025-1")
    ]

-- ============================================================================
-- roundValue Filter Tests
-- ============================================================================

roundValueTests :: [Test]
roundValueTests =
    [ assertEqual "round 3.14 down"
        "3"
        (roundValue "3.14")

    , assertEqual "round 99.9 up"
        "100"
        (roundValue "99.9")

    , assertEqual "round 42.5 up"
        "43"
        (roundValue "42.5")

    , assertEqual "round integer unchanged"
        "42"
        (roundValue "42")

    , assertEqual "round non-numeric unchanged"
        "abc"
        (roundValue "abc")

    , assertEqual "round negative"
        "-4"
        (roundValue "-3.7")
    ]
