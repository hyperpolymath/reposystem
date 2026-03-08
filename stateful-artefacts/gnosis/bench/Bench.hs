{- |
Module      : Bench
Description : Performance benchmarks for the Gnosis engine
Copyright   : (c) 2025-2026 Jonathan D.A. Jewell
License     : PMPL-1.0-or-later

Measures execution time for core operations:
- S-expression parsing (small, medium, large inputs)
- Template rendering (placeholder density variants)
- DAX conditional processing
- DAX loop expansion
- Filter pipeline throughput
- 6scm context loading
-}

module Main (main) where

import qualified Data.Map.Strict as Map
import Data.Time.Clock (getCurrentTime, diffUTCTime)
import System.IO (hFlush, stdout)

import Types (FlexiText(..), Context)
import SExp (parseSExp)
import Render (render, renderWithBadges)
import DAX (processConditionals, processLoops, processTemplate, applyFilter)

-- | Benchmark result
data BenchResult = BenchResult
    { benchName    :: String
    , benchIters   :: Int
    , benchTotalMs :: Double
    , benchAvgUs   :: Double
    } deriving (Show)

-- | Run a benchmark: execute action N times, measure total time
bench :: String -> Int -> IO a -> IO BenchResult
bench name iters action = do
    start <- getCurrentTime
    go iters
    end <- getCurrentTime
    let totalSec = realToFrac (diffUTCTime end start) :: Double
        totalMs  = totalSec * 1000
        avgUs    = (totalSec / fromIntegral iters) * 1000000
    return $ BenchResult name iters totalMs avgUs
  where
    go 0 = return ()
    go n = action >> go (n - 1)

-- | Run a pure benchmark
benchPure :: String -> Int -> a -> IO BenchResult
benchPure name iters val = bench name iters (val `seq` return val)

-- | Print benchmark result
printResult :: BenchResult -> IO ()
printResult r = do
    let padded = benchName r ++ replicate (40 - length (benchName r)) ' '
    putStrLn $ "  " ++ padded
        ++ show (round (benchTotalMs r) :: Int) ++ " ms total, "
        ++ show (round (benchAvgUs r) :: Int) ++ " us/iter"
        ++ " (" ++ show (benchIters r) ++ " iters)"

-- | Build a test context of given size
mkCtx :: Int -> Context
mkCtx n = Map.fromList
    [ ("key" ++ show i, FlexiText ("value" ++ show i) ("alt" ++ show i))
    | i <- [1..n]
    ]

-- | Generate a small SCM string
smallSCM :: String
smallSCM = "(state (metadata (version \"1.0\") (phase \"alpha\")))"

-- | Generate a medium SCM string (~50 key-value pairs)
mediumSCM :: String
mediumSCM = "(state\n" ++ concatMap mkPair [1..50 :: Int] ++ ")"
  where mkPair i = "  (key" ++ show i ++ " \"value" ++ show i ++ "\")\n"

-- | Generate a large SCM string (~500 key-value pairs, nested)
largeSCM :: String
largeSCM = "(state\n" ++ concatMap mkSection [1..10 :: Int] ++ ")"
  where
    mkSection s = "  (section" ++ show s ++ "\n"
        ++ concatMap (\k -> "    (key" ++ show s ++ "-" ++ show k
            ++ " \"value-" ++ show s ++ "-" ++ show k ++ "\")\n") [1..50 :: Int]
        ++ "  )\n"

-- | Generate a template with N placeholders
mkTemplate :: Int -> String
mkTemplate n = concatMap (\i -> "Item " ++ show i ++ ": (:key" ++ show i ++ ")\n") [1..n]

-- | Generate a template with N conditional blocks
mkCondTemplate :: Int -> String
mkCondTemplate n = concatMap (\i ->
    "{{#if key" ++ show i ++ " == value" ++ show i ++ "}}YES" ++ show i
    ++ "{{#else}}NO{{/if}}\n") [1..n]

-- | Generate a loop template iterating over a list
mkLoopTemplate :: String
mkLoopTemplate = "{{#for item in items}}[(:item)] {{@index}} {{/for}}"

main :: IO ()
main = do
    putStrLn "Gnosis Performance Benchmarks"
    putStrLn "============================="
    putStrLn ""

    -- ======================================================================
    -- S-Expression Parsing
    -- ======================================================================
    putStrLn "--- S-Expression Parsing ---"

    r1 <- benchPure "parse: small (2 pairs)" 10000 (parseSExp smallSCM)
    printResult r1

    r2 <- benchPure "parse: medium (50 pairs)" 5000 (parseSExp mediumSCM)
    printResult r2

    r3 <- benchPure "parse: large (500 pairs, nested)" 1000 (parseSExp largeSCM)
    printResult r3

    let hugeInput = "(state\n" ++ concat (replicate 2000 "  (k \"v\")\n") ++ ")"
    r4 <- benchPure "parse: huge (2000 pairs)" 200 (parseSExp hugeInput)
    printResult r4
    putStrLn ""

    -- ======================================================================
    -- Template Rendering
    -- ======================================================================
    putStrLn "--- Template Rendering ---"

    let ctx10 = mkCtx 10
    let ctx100 = mkCtx 100
    let ctx1000 = mkCtx 1000

    r5 <- benchPure "render: 10 placeholders, 10 keys" 10000 (render ctx10 (mkTemplate 10))
    printResult r5

    r6 <- benchPure "render: 100 placeholders, 100 keys" 2000 (render ctx100 (mkTemplate 100))
    printResult r6

    r7 <- benchPure "render: 1000 placeholders, 1000 keys" 200 (render ctx1000 (mkTemplate 1000))
    printResult r7

    r8 <- benchPure "render: badges mode, 100 placeholders" 2000 (renderWithBadges ctx100 (mkTemplate 100))
    printResult r8

    let missingTpl = concatMap (\i -> "(:missing" ++ show i ++ ")\n") [1..100 :: Int]
    r9 <- benchPure "render: 100 missing placeholders" 5000 (render ctx10 missingTpl)
    printResult r9
    putStrLn ""

    -- ======================================================================
    -- DAX Conditionals
    -- ======================================================================
    putStrLn "--- DAX Conditionals ---"

    r10 <- benchPure "conditionals: 10 if blocks" 5000 (processConditionals ctx10 (mkCondTemplate 10))
    printResult r10

    r11 <- benchPure "conditionals: 50 if blocks" 1000 (processConditionals ctx100 (mkCondTemplate 50))
    printResult r11

    r12 <- benchPure "conditionals: 100 if/else blocks" 500 (processConditionals ctx100 (mkCondTemplate 100))
    printResult r12

    -- Nested conditionals (3 deep)
    let nestedCond = "{{#if key1 == value1}}L1{{#if key2 == value2}}L2{{#if key3 == value3}}L3{{/if}}{{/if}}{{/if}}"
    r13 <- benchPure "conditionals: 3-deep nesting" 10000 (processConditionals ctx10 nestedCond)
    printResult r13
    putStrLn ""

    -- ======================================================================
    -- DAX Loops
    -- ======================================================================
    putStrLn "--- DAX Loops ---"

    let loopCtx3 = Map.fromList [("items", FlexiText "a,b,c" "items")]
    let loopCtx10 = Map.fromList [("items", FlexiText (commaList 10) "items")]
    let loopCtx100 = Map.fromList [("items", FlexiText (commaList 100) "items")]
    let loopCtx1000 = Map.fromList [("items", FlexiText (commaList 1000) "items")]

    r14 <- benchPure "loops: 3 items" 10000 (processLoops loopCtx3 mkLoopTemplate)
    printResult r14

    r15 <- benchPure "loops: 10 items" 5000 (processLoops loopCtx10 mkLoopTemplate)
    printResult r15

    r16 <- benchPure "loops: 100 items" 1000 (processLoops loopCtx100 mkLoopTemplate)
    printResult r16

    r17 <- benchPure "loops: 1000 items" 100 (processLoops loopCtx1000 mkLoopTemplate)
    printResult r17
    putStrLn ""

    -- ======================================================================
    -- Filter Pipeline
    -- ======================================================================
    putStrLn "--- Filter Pipeline ---"

    let longStr = replicate 10000 'A'
    let shortStr = "hello world"

    r18 <- benchPure "filter: uppercase (short)" 50000 (applyFilter "uppercase" shortStr)
    printResult r18

    r19 <- benchPure "filter: uppercase (10K chars)" 5000 (applyFilter "uppercase" longStr)
    printResult r19

    r20 <- benchPure "filter: thousands-separator" 50000 (applyFilter "thousands-separator" "1234567890")
    printResult r20

    r21 <- benchPure "filter: relativeTime" 50000 (applyFilter "relativeTime" "2026-03-08T14:30:00")
    printResult r21

    r22 <- benchPure "filter: emojify" 50000 (applyFilter "emojify" "alpha")
    printResult r22

    r23 <- benchPure "filter: slug" 50000 (applyFilter "slug" "Hello World 123!")
    printResult r23

    r24 <- benchPure "filter: strip-html" 10000 (applyFilter "strip-html" "<div><p>Hello <b>World</b></p></div>")
    printResult r24
    putStrLn ""

    -- ======================================================================
    -- Full Pipeline (parse + DAX + render)
    -- ======================================================================
    putStrLn "--- Full Pipeline ---"

    let fullTemplate = "# (:name)\n\nVersion: (:version)\n\n"
            ++ "{{#if phase == alpha}}Alpha{{#else}}Not alpha{{/if}}\n\n"
            ++ "{{#for tag in tags}}* (:tag)\n{{/for}}\n"
            ++ "Score: (:score | thousands-separator)\n"
    let fullCtx = Map.fromList
            [ ("name", FlexiText "TestProject" "name")
            , ("version", FlexiText "2.0.0" "version")
            , ("phase", FlexiText "alpha" "phase")
            , ("tags", FlexiText "rust,haskell,zig,gleam,elixir" "tags")
            , ("score", FlexiText "1234567" "score")
            ]

    r25 <- benchPure "full pipeline: typical template" 5000 (render fullCtx (processTemplate fullCtx fullTemplate))
    printResult r25

    -- Large full pipeline
    let bigCtx = mkCtx 500
    let bigTemplate = mkTemplate 200
            ++ mkCondTemplate 50
            ++ "{{#for x in items}}(:x) {{/for}}\n"
    let bigCtxWithItems = Map.insert "items" (FlexiText (commaList 50) "items") bigCtx

    r26 <- benchPure "full pipeline: large (200 placeholders + 50 conds + 50 loops)" 100
        (render bigCtxWithItems (processTemplate bigCtxWithItems bigTemplate))
    printResult r26
    putStrLn ""

    -- ======================================================================
    -- Summary
    -- ======================================================================
    putStrLn "============================="
    putStrLn "Benchmarks complete."
    hFlush stdout

-- | Generate comma-separated list of N items
commaList :: Int -> String
commaList n = go 1
  where
    go i | i >= n    = "item" ++ show i
         | otherwise = "item" ++ show i ++ "," ++ go (i + 1)
