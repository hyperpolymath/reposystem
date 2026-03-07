{- |
Module      : Paxos
Description : Paxos-Lite conflict resolution for concurrent STATE.scm updates
Copyright   : (c) 2025-2026 Jonathan D.A. Jewell
License     : PMPL-1.0-or-later
Maintainer  : hyperpolymath

Paxos-Lite uses timestamp-based ballot numbers for last-write-wins
conflict resolution when multiple automation scripts update STATE.scm
concurrently.
-}

module Paxos
    ( BallotNumber
    , getBallotNumber
    , compareBallots
    , mergeStates
    , getCurrentTimestamp
    ) where

import Data.Time.Clock.POSIX (getPOSIXTime)
import Data.List (sortBy)
import Data.Ord (comparing)

-- | Ballot number is Unix timestamp for simplicity
type BallotNumber = Integer

-- | Get current timestamp as ballot number
getCurrentTimestamp :: IO BallotNumber
getCurrentTimestamp = do
    posixTime <- getPOSIXTime
    return $ floor posixTime

-- | Extract ballot number from STATE.scm metadata
-- Looks for (last-updated . "1737002640")
getBallotNumber :: String -> Maybe BallotNumber
getBallotNumber content =
    case extractTimestamp content of
        Just ts -> case reads ts of
            [(n, "")] -> Just n
            _ -> Nothing
        Nothing -> Nothing
  where
    extractTimestamp :: String -> Maybe String
    extractTimestamp s
        | null s = Nothing
        | "last-updated" `elem` words s = extractAfterKey s
        | otherwise = extractTimestamp (drop 1 s)

    extractAfterKey :: String -> Maybe String
    extractAfterKey s =
        case dropWhile (/= '"') s of
            ('"':rest) -> Just (takeWhile (/= '"') rest)
            _ -> Nothing

-- | Compare two ballot numbers (timestamps)
-- Returns GT if first is newer, LT if second is newer, EQ if same
compareBallots :: BallotNumber -> BallotNumber -> Ordering
compareBallots = compare

-- | Merge two STATE.scm contents using last-write-wins
-- The version with higher ballot number (newer timestamp) wins
mergeStates :: String -> String -> String
mergeStates state1 state2 =
    let ballot1 = getBallotNumber state1
        ballot2 = getBallotNumber state2
    in case (ballot1, ballot2) of
        (Just b1, Just b2) ->
            case compareBallots b1 b2 of
                GT -> state1  -- First is newer, keep it
                LT -> state2  -- Second is newer, keep it
                EQ -> state1  -- Same timestamp, arbitrary choice
        (Just _, Nothing) -> state1  -- Only first has ballot
        (Nothing, Just _) -> state2  -- Only second has ballot
        (Nothing, Nothing) -> state1 -- Neither has ballot, arbitrary

-- | Merge a list of STATE.scm versions, keeping the newest
mergeManyStates :: [String] -> String
mergeManyStates [] = ""
mergeManyStates states =
    let withBallots = [(s, getBallotNumber s) | s <- states]
        sorted = sortBy (comparing snd) withBallots
    in case reverse sorted of
        ((newest, _):_) -> newest
        [] -> head states  -- Fallback

-- | Create a new STATE.scm with updated ballot number
updateBallot :: String -> IO String
updateBallot content = do
    newBallot <- getCurrentTimestamp
    return $ updateTimestampInContent content newBallot

-- | Update timestamp in STATE.scm content
updateTimestampInContent :: String -> BallotNumber -> String
updateTimestampInContent content newTimestamp =
    let timestampStr = show newTimestamp
    in replaceTimestamp content timestampStr
  where
    replaceTimestamp :: String -> String -> String
    replaceTimestamp s replacement
        | null s = s
        | "(last-updated . \"" `isPrefixOf` s =
            "(last-updated . \"" ++ replacement ++ "\")" ++ dropAfterTimestamp (drop 18 s)
        | otherwise = take 1 s ++ replaceTimestamp (drop 1 s) replacement

    isPrefixOf :: String -> String -> Bool
    isPrefixOf [] _ = True
    isPrefixOf _ [] = False
    isPrefixOf (x:xs) (y:ys) = x == y && isPrefixOf xs ys

    dropAfterTimestamp :: String -> String
    dropAfterTimestamp = dropWhile (/= ')') . dropWhile (/= '"') . drop 1
