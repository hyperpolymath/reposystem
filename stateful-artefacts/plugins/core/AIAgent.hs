{- |
Module      : Plugins.AI.CoreAgent
Description : Core AI agent for analyzing repository health and suggesting updates
Copyright   : (c) 2025-2026 Jonathan D.A. Jewell
License     : PMPL-1.0-or-later
Maintainer  : hyperpolymath

The core AI agent analyzes repository metrics and suggests STATE.scm updates.
-}

module Plugins.AI.CoreAgent
    ( plugin
    , analyzeRepo
    , suggestPhaseTransition
    , suggestHealthUpdate
    , suggestMetadataUpdate
    ) where

import PluginAPI
import Data.Time (UTCTime, diffUTCTime, getCurrentTime, nominalDay)
import qualified Data.Time.Clock as Clock

-- | Main analysis function
analyzeRepo :: RepoData -> [Suggestion]
analyzeRepo repo = concat
    [ suggestPhaseTransition repo
    , suggestHealthUpdate repo
    , suggestMetadataUpdate repo
    , suggestFieldAdditions repo
    ]

-- | Suggest phase transitions based on metrics
suggestPhaseTransition :: RepoData -> [Suggestion]
suggestPhaseTransition repo =
    let age = ageInDays (repoCreatedAt repo)
        stars = repoStars repo
        currentP = currentPhase repo
    in case currentP of
        "alpha" | age > 30 && stars >= 10 ->
            [ Suggestion PhaseTransition "phase" "beta"
                "Project is 30+ days old with 10+ stars - ready for beta"
                85
            ]
        "beta" | age > 90 && stars >= 50 ->
            [ Suggestion PhaseTransition "phase" "stable"
                "Project is 90+ days old with 50+ stars - ready for stable release"
                90
            ]
        "stable" | stars >= 1000 ->
            [ Suggestion PhaseTransition "phase" "production"
                "Project has 1000+ stars - ready for production status"
                95
            ]
        "active" | age > 365 && stars < 10 && daysSinceUpdate repo > 90 ->
            [ Suggestion PhaseTransition "phase" "inactive"
                "No recent activity and low engagement - consider marking inactive"
                70
            ]
        _ -> []

-- | Suggest health score updates
suggestHealthUpdate :: RepoData -> [Suggestion]
suggestHealthUpdate repo =
    let health = calculateHealth repo
        current = currentHealth repo
        diff = abs (health - current)
    in if diff > 10
        then [ Suggestion HealthWarning "health-score" (show health)
                ("Calculated health: " ++ show health ++ " (current: " ++ show current ++ ")")
                80
             ]
        else []

-- | Calculate health score
calculateHealth :: RepoData -> Int
calculateHealth repo =
    let baseScore = 100
        daysSince = daysSinceUpdate repo

        -- Activity penalty
        activityPenalty
            | daysSince > 180 = 40
            | daysSince > 90  = 30
            | daysSince > 30  = 15
            | otherwise       = 0

        -- Issue penalty
        issuePenalty
            | repoOpenIssues repo > 100 = 30
            | repoOpenIssues repo > 50  = 20
            | repoOpenIssues repo > 20  = 10
            | otherwise                 = 0

        -- License penalty
        licensePenalty = case repoLicense repo of
            Nothing -> 20
            Just _  -> 0

        -- Documentation penalty
        docsPenalty
            | not (repoHasWiki repo) = 10
            | otherwise              = 0

        -- Issue tracking penalty
        issuesPenalty
            | not (repoHasIssues repo) = 15
            | otherwise                = 0

        totalPenalty = activityPenalty + issuePenalty + licensePenalty + docsPenalty + issuesPenalty
    in max 0 (min 100 (baseScore - totalPenalty))

-- | Suggest metadata updates
suggestMetadataUpdate :: RepoData -> [Suggestion]
suggestMetadataUpdate repo = concat
    [ checkLicense repo
    , checkTopics repo
    ]

-- | Check for missing license
checkLicense :: RepoData -> [Suggestion]
checkLicense repo =
    case repoLicense repo of
        Nothing -> [ Suggestion MetadataUpdate "license" "PMPL-1.0-or-later"
                      "No license detected - consider adding PMPL license"
                      60
                   ]
        Just _ -> []

-- | Check if topics should be added as tags
checkTopics :: RepoData -> [Suggestion]
checkTopics repo =
    if not (null (repoTopics repo))
        then [ Suggestion FieldAddition "tags" (unwords (repoTopics repo))
                "Repository has topics that could be added as tags"
                70
             ]
        else []

-- | Suggest new fields to add
suggestFieldAdditions :: RepoData -> [Suggestion]
suggestFieldAdditions repo =
    let suggestions = []
        -- Could add more sophisticated suggestions here
    in suggestions

-- | Calculate days since last update
daysSinceUpdate :: RepoData -> Int
daysSinceUpdate repo = ageInDays (repoUpdatedAt repo)

-- | Calculate age in days
ageInDays :: UTCTime -> Int
ageInDays time =
    -- Simplified calculation - in real implementation would use current time
    -- For now, approximate based on year 2026
    let approxNow = read "2026-01-24 00:00:00 UTC" :: UTCTime
        diff = diffUTCTime approxNow time
    in floor (realToFrac diff / nominalDay)

-- | Plugin definition
plugin :: AIAgentPlugin
plugin = AIAgentPlugin
    { agentMetadata = PluginMetadata
        { pluginName = "core-ai-agent"
        , pluginVersion = "1.0.0"
        , pluginDescription = "Core AI agent for repository analysis and STATE.scm suggestions"
        , pluginAuthor = "Gnosis Team"
        , pluginLicense = "PMPL-1.0-or-later"
        }
    , agentName = "CoreAnalyzer"
    , analyzeFunction = analyzeRepo
    }
