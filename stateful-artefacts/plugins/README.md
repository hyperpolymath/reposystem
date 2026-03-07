# Gnosis Plugin System

Extend Gnosis with custom filters, renderers, data sources, and AI-powered suggestions.

## Architecture

```
┌─────────────────────────────────────┐
│         Plugin Registry             │
│  - Discover plugins                 │
│  - Load & validate                  │
│  - Manage dependencies              │
└──────────────┬──────────────────────┘
               │
       ┌───────┼───────┬──────────┐
       │       │       │          │
   ┌───▼───┐ ┌▼────┐ ┌▼───────┐ ┌▼────────┐
   │Filter │ │Data │ │Renderer│ │AI Agent │
   │Plugin │ │Source│ │Plugin  │ │Plugin   │
   └───────┘ └─────┘ └────────┘ └─────────┘
```

## Plugin Types

### 1. Filter Plugins

Transform placeholder values during rendering.

**Example:**
```haskell
-- plugins/examples/EmojifyFilter.hs
module Plugins.Filters.Emojify where

emojify :: String -> String
emojify "production" = "🚀 production"
emojify "beta" = "🧪 beta"
emojify "alpha" = "🔬 alpha"
emojify s = s

filterName :: String
filterName = "emojify"
```

**Usage:**
```markdown
Phase: (:phase | emojify)
```

### 2. Data Source Plugins

Fetch data from external sources to populate STATE.scm.

**Example:**
```haskell
-- plugins/examples/NPMDataSource.hs
module Plugins.DataSources.NPM where

fetchNPMStats :: String -> IO [(String, String)]
fetchNPMStats packageName = do
  -- Fetch from npm registry
  return
    [ ("npm-downloads", "123456")
    , ("npm-version", "1.2.3")
    ]
```

### 3. Renderer Plugins

Custom output formats beyond Markdown and badges.

**Example:**
```haskell
-- plugins/examples/JSONRenderer.hs
module Plugins.Renderers.JSON where

import qualified Data.Aeson as JSON

renderToJSON :: Context -> JSON.Value
renderToJSON ctx = JSON.object
  [ "name" .= lookupOr "name" "unknown" ctx
  , "phase" .= lookupOr "phase" "unknown" ctx
  ]
```

### 4. AI Agent Plugins

Analyze repository activity and suggest STATE.scm updates.

**Example:**
```haskell
-- plugins/core/AIAgent.hs
module Plugins.AI.Suggestions where

analyzeSuggestions :: RepoData -> [Suggestion]
analyzeSuggestions repoData =
  [ if daysStale > 90
      then Suggestion "phase" "deprecated" "No commits in 90+ days"
      else NoSuggestion
  , if openIssues > 50
      then Suggestion "health-score" "70" "High issue count"
      else NoSuggestion
  ]
```

## Plugin Registry

### Structure

```
plugins/
├── registry/
│   └── plugin-manifest.json    # Registry of all plugins
├── core/
│   ├── PluginAPI.hs            # Plugin interface definitions
│   ├── PluginLoader.hs         # Dynamic plugin loading
│   └── AIAgent.hs              # AI suggestion engine
└── examples/
    ├── EmojifyFilter.hs        # Example filter
    ├── NPMDataSource.hs        # Example data source
    └── JSONRenderer.hs         # Example renderer
```

### Manifest Format

```json
{
  "plugins": [
    {
      "name": "emojify-filter",
      "type": "filter",
      "version": "1.0.0",
      "module": "Plugins.Filters.Emojify",
      "function": "emojify",
      "description": "Adds emoji to phase names",
      "author": "Gnosis Team",
      "license": "PMPL-1.0-or-later"
    },
    {
      "name": "npm-data-source",
      "type": "data-source",
      "version": "1.0.0",
      "module": "Plugins.DataSources.NPM",
      "function": "fetchNPMStats",
      "dependencies": ["http-client"],
      "description": "Fetches npm package statistics",
      "author": "Gnosis Team",
      "license": "PMPL-1.0-or-later"
    }
  ]
}
```

## Creating a Plugin

### Step 1: Choose Plugin Type

Decide what your plugin does:
- **Filter**: Transform values (uppercase, date formatting, etc.)
- **Data Source**: Fetch external data (API calls, databases, etc.)
- **Renderer**: Output custom formats (JSON, YAML, HTML, etc.)
- **AI Agent**: Analyze and suggest (health checks, recommendations, etc.)

### Step 2: Implement Interface

```haskell
-- Example Filter Plugin
module Plugins.Filters.MyFilter where

import Plugins.API (FilterPlugin(..))

myFilter :: String -> String
myFilter input = -- Your transformation logic

plugin :: FilterPlugin
plugin = FilterPlugin
  { pluginName = "my-filter"
  , pluginVersion = "1.0.0"
  , pluginDescription = "My custom filter"
  , filterFunction = myFilter
  }
```

### Step 3: Register Plugin

Add to `plugins/registry/plugin-manifest.json`:

```json
{
  "name": "my-filter",
  "type": "filter",
  "version": "1.0.0",
  "module": "Plugins.Filters.MyFilter",
  "function": "myFilter"
}
```

### Step 4: Test Plugin

```bash
# Build with plugin support
cd gnosis
stack build --flag gnosis:plugins

# Test plugin
echo "(:test | my-filter)" | gnosis --stdin
```

## AI Agent System

### Suggestion Types

1. **Phase Transitions**
   - alpha → beta (after 30 days, 10+ stars)
   - beta → stable (after 90 days, 50+ stars)
   - stable → production (1000+ stars)
   - active → deprecated (90+ days no activity)

2. **Health Warnings**
   - "health-score" < 70 → Investigate issues
   - open-issues > 50 → "Consider issue triage"
   - No license → "Add license file"

3. **Metadata Updates**
   - New major version detected → Update version field
   - Language change detected → Update language field
   - Description changed → Update tagline

### Agent Configuration

```scheme
; .gnosis/agent-config.scm
(agent-config
  (enabled . true)
  (auto-apply . false)  ; Suggest but don't auto-commit
  (check-interval . 86400)  ; Daily checks
  (suggestions
    (phase-transitions . true)
    (health-warnings . true)
    (metadata-updates . true)))
```

### Running the AI Agent

```bash
# Analyze and suggest updates
gnosis agent analyze

# Output:
# ✅ Suggestions for STATE.scm:
# 1. Update phase: "beta" → "stable" (Reason: 100+ stars, 120 days old)
# 2. Update health-score: "100" → "85" (Reason: 15 open issues)
# 3. Add tag: "haskell" (Reason: Primary language)

# Apply suggestions
gnosis agent apply --suggestion 1 --suggestion 3

# Auto-apply all
gnosis agent apply --all
```

## Security Considerations

### Plugin Sandboxing

Plugins run in restricted environment:
- ✅ Can read STATE.scm
- ✅ Can call approved APIs
- ❌ Cannot write to filesystem (except via API)
- ❌ Cannot execute arbitrary shell commands
- ❌ Cannot access environment variables

### Plugin Verification

- Plugins must be signed by trusted authors
- Source code review required for inclusion in core registry
- Third-party plugins display warning before loading

### Safe Mode

```bash
# Run without plugins
gnosis --no-plugins render template.md

# Run with specific plugins only
gnosis --plugins=emojify,npm-stats render template.md
```

## Examples

### Example 1: Sentiment Filter

```haskell
module Plugins.Filters.Sentiment where

sentiment :: String -> String
sentiment s
  | length (words s) > 100 = s ++ " 📚"
  | "critical" `elem` words s = "🚨 " ++ s
  | "success" `elem` words s = "✅ " ++ s
  | otherwise = s
```

**Usage:**
```markdown
Status: (:status-message | sentiment)
```

### Example 2: GitHub Trending Data Source

```haskell
module Plugins.DataSources.GitHubTrending where

import Network.HTTP.Client

fetchTrendingRank :: String -> String -> IO (Maybe Int)
fetchTrendingRank owner repo = do
  -- Query GitHub trending API
  -- Return rank if in trending, Nothing otherwise
```

**Usage:**
```haskell
-- In STATE.scm generation
trendingRank <- fetchTrendingRank "hyperpolymath" "gnosis"
case trendingRank of
  Just rank -> addField "trending-rank" (show rank)
  Nothing -> return ()
```

### Example 3: AI Suggestion Agent

```haskell
module Plugins.AI.IssueAnalysis where

analyzeIssues :: [Issue] -> [Suggestion]
analyzeIssues issues =
  let criticalCount = length (filter isCritical issues)
      staleFrac = staleRatio issues
  in [ if criticalCount > 5
         then Suggestion "Add blocker section to STATE.scm"
         else NoSuggestion
     , if staleFrac > 0.5
         then Suggestion "Consider issue cleanup sprint"
         else NoSuggestion
     ]
```

## API Reference

### FilterPlugin

```haskell
data FilterPlugin = FilterPlugin
  { pluginName :: String
  , pluginVersion :: String
  , filterFunction :: String -> String
  }
```

### DataSourcePlugin

```haskell
data DataSourcePlugin = DataSourcePlugin
  { pluginName :: String
  , pluginVersion :: String
  , fetchData :: IO [(String, FlexiText)]
  }
```

### RendererPlugin

```haskell
data RendererPlugin = RendererPlugin
  { pluginName :: String
  , pluginVersion :: String
  , renderFunction :: Context -> String
  }
```

### AIAgentPlugin

```haskell
data Suggestion = Suggestion
  { suggestionKey :: String
  , suggestionValue :: String
  , suggestionReason :: String
  }

data AIAgentPlugin = AIAgentPlugin
  { pluginName :: String
  , pluginVersion :: String
  , analyzeFn :: RepoData -> [Suggestion]
  }
```

## Roadmap

### v1.0 (Current)
- ✅ Plugin interface definitions
- ✅ Example plugins
- ✅ Plugin manifest format
- ✅ AI agent architecture

### v1.1 (Planned)
- [ ] Plugin loader implementation
- [ ] Dynamic plugin loading at runtime
- [ ] Plugin dependency resolution
- [ ] Plugin marketplace/registry

### v2.0 (Future)
- [ ] Web-based plugin editor
- [ ] Visual plugin composer
- [ ] Community plugin sharing
- [ ] Plugin analytics

## License

PMPL-1.0-or-later (same as parent project)

## Contributing

See [../CONTRIBUTING.md](../CONTRIBUTING.md) for plugin submission guidelines.
