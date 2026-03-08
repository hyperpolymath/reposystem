# Plugin Usage Examples

## Filter Plugins

### Emojify Filter

Add emoji to phase names for visual appeal.

**Template:**
```markdown
# Project: (:name)

**Current Phase:** (:phase | emojify)
**Status:** (:status | emojify)
```

**Output:**
```
# Project: Gnosis

**Current Phase:** 🚀 production
**Status:** ✅ stable
```

### Custom Filter Chain

Combine multiple filters:

**Template:**
```markdown
Downloads: (:downloads | thousands-separator | emojify)
```

## AI Agent Plugins

### Core AI Agent

Analyze repository and get suggestions:

**Command:**
```bash
# Analyze current repository
gnosis agent analyze

# Output suggestions
✅ Suggestions for STATE.scm:

1. [Phase Transition] phase: "beta" → "stable"
   Reason: Project is 90+ days old with 50+ stars - ready for stable release
   Confidence: 90%

2. [Health Warning] health-score: "100" → "85"
   Reason: Calculated health: 85 (current: 100)
   Confidence: 80%

3. [Field Addition] tags: "" → "haskell metadata automation"
   Reason: Repository has topics that could be added as tags
   Confidence: 70%
```

**Apply Suggestions:**
```bash
# Apply specific suggestion
gnosis agent apply --id 1

# Apply all high-confidence suggestions
gnosis agent apply --threshold 80

# Preview changes without applying
gnosis agent apply --dry-run --all
```

### Custom AI Agent

Create your own analysis logic:

**Plugin: CustomAgent.hs**
```haskell
module Plugins.AI.CustomAgent where

import PluginAPI

customAnalysis :: RepoData -> [Suggestion]
customAnalysis repo =
  let stars = repoStars repo
      issues = repoOpenIssues repo
  in if stars > 100 && issues < 10
       then [ Suggestion MetadataUpdate "quality" "high"
               "High stars with low issues indicates quality project"
               95
            ]
       else []

plugin :: AIAgentPlugin
plugin = AIAgentPlugin
    { agentMetadata = PluginMetadata
        { pluginName = "custom-agent"
        , pluginVersion = "1.0.0"
        , pluginDescription = "Custom quality analyzer"
        , pluginAuthor = "You"
        , pluginLicense = "PMPL-1.0-or-later"
        }
    , agentName = "QualityAnalyzer"
    , analyzeFunction = customAnalysis
    }
```

## Data Source Plugins

### NPM Data Source

Fetch npm package statistics:

**Plugin: NPMDataSource.hs**
```haskell
module Plugins.DataSources.NPM where

import PluginAPI
import Network.HTTP.Client
import Data.Aeson

fetchNPMStats :: Map.Map String String -> IO [(String, String)]
fetchNPMStats config = do
  let packageName = Map.findWithDefault "unknown" "package" config

  -- Fetch from npm registry
  response <- httpLBS (parseRequest_ $ "https://registry.npmjs.org/" ++ packageName)
  let body = responseBody response
  let stats = decode body :: Maybe NpmPackage

  case stats of
    Just pkg -> return
      [ ("npm-downloads", show (downloadsLastWeek pkg))
      , ("npm-version", latestVersion pkg)
      , ("npm-maintainers", show (length (maintainers pkg)))
      ]
    Nothing -> return []

plugin :: DataSourcePlugin
plugin = DataSourcePlugin
    { dataSourceMetadata = PluginMetadata
        { pluginName = "npm-data-source"
        , pluginVersion = "1.0.0"
        , pluginDescription = "Fetches npm package statistics"
        , pluginAuthor = "Gnosis Team"
        , pluginLicense = "PMPL-1.0-or-later"
        }
    , dataSourceName = "npm"
    , fetchData = fetchNPMStats
    }
```

**Usage:**
```bash
# Configure data source
gnosis datasource config npm --package gnosis-haskell

# Fetch and merge into STATE.scm
gnosis datasource fetch npm

# Generated STATE.scm will include:
# (npm-stats
#   (downloads . "12345")
#   (version . "1.0.0")
#   (maintainers . "3"))
```

## Renderer Plugins

### JSON Renderer

Export STATE.scm as JSON:

**Plugin: JSONRenderer.hs**
```haskell
module Plugins.Renderers.JSON where

import PluginAPI
import qualified Data.Aeson as JSON
import qualified Data.Map.Strict as Map

renderToJSON :: Map.Map String String -> String
renderToJSON ctx = JSON.encode $ JSON.object
  [ "name" JSON..= Map.findWithDefault "unknown" "name" ctx
  , "phase" JSON..= Map.findWithDefault "unknown" "phase" ctx
  , "version" JSON..= Map.findWithDefault "0.0.0" "version" ctx
  , "health" JSON..= Map.findWithDefault "0" "health-score" ctx
  ]

plugin :: RendererPlugin
plugin = RendererPlugin
    { rendererMetadata = PluginMetadata
        { pluginName = "json-renderer"
        , pluginVersion = "1.0.0"
        , pluginDescription = "Exports STATE.scm as JSON"
        , pluginAuthor = "Gnosis Team"
        , pluginLicense = "PMPL-1.0-or-later"
        }
    , rendererFormat = "json"
    , renderFunction = renderToJSON
    }
```

**Usage:**
```bash
# Render STATE.scm as JSON
gnosis render --format json STATE.scm

# Output:
# {
#   "name": "Gnosis",
#   "phase": "production",
#   "version": "1.0.0",
#   "health": "95"
# }

# Pipe to jq for filtering
gnosis render --format json STATE.scm | jq '.phase'
```

## Plugin Configuration

### Global Config

**~/.gnosis/config.scm:**
```scheme
(gnosis-config
  (plugins
    (enabled . true)
    (auto-load . true)
    (directories
      . "~/.gnosis/plugins:/usr/local/share/gnosis/plugins"))

  (filters
    (emojify (enabled . true))
    (uppercase (enabled . true)))

  (ai-agents
    (core-agent
      (enabled . true)
      (auto-apply . false)
      (threshold . 70)))

  (data-sources
    (npm
      (enabled . true)
      (cache-ttl . 3600))))
```

### Project Config

**.gnosis/local-config.scm:**
```scheme
(gnosis-local-config
  (plugins
    (filters
      (emojify (enabled . false)))  ; Disable emojify for this project

    (ai-agents
      (core-agent
        (auto-apply . true)  ; Auto-apply suggestions for this repo
        (threshold . 85))))   ; Higher threshold
```

## Advanced Usage

### Plugin Chaining

Chain plugins together:

```bash
# Fetch npm stats → Analyze with AI → Render as JSON
gnosis datasource fetch npm | gnosis agent analyze | gnosis render --format json
```

### Conditional Plugins

Enable plugins based on conditions:

```bash
# Only use emojify filter if in production phase
gnosis render --if-phase production --filter emojify template.md
```

### Custom Plugin Pipeline

Create a custom pipeline:

**.gnosis/pipeline.yaml:**
```yaml
pipeline:
  - name: "fetch-data"
    plugin: "npm-data-source"
    config:
      package: "gnosis-haskell"

  - name: "analyze"
    plugin: "core-ai-agent"
    config:
      threshold: 80

  - name: "apply"
    plugin: "auto-applier"
    condition: "confidence > 90"

  - name: "render"
    plugin: "markdown-renderer"
    output: "README.md"
```

**Run pipeline:**
```bash
gnosis pipeline run .gnosis/pipeline.yaml
```

## Testing Plugins

### Unit Tests

```haskell
-- Test filter plugin
import Test.Hspec
import Plugins.Filters.Emojify

spec :: Spec
spec = describe "Emojify filter" $ do
  it "adds emoji to production" $
    emojify "production" `shouldBe` "🚀 production"

  it "passes through unknown values" $
    emojify "custom-phase" `shouldBe` "custom-phase"
```

### Integration Tests

```bash
# Test full plugin flow
gnosis test-plugin emojify-filter --input "alpha" --expected "🔬 alpha"

# Test AI agent suggestions
gnosis test-plugin core-ai-agent --repo hyperpolymath/gnosis --min-suggestions 2
```

## Troubleshooting

### Plugin Not Loading

```bash
# Check plugin status
gnosis plugin list

# Output:
# Installed Plugins:
# ✅ emojify-filter v1.0.0 (enabled)
# ✅ core-ai-agent v1.0.0 (enabled)
# ❌ broken-plugin v0.1.0 (failed to load: missing dependency)

# Show plugin details
gnosis plugin info emojify-filter

# Enable/disable plugin
gnosis plugin enable emojify-filter
gnosis plugin disable emojify-filter
```

### Debugging

```bash
# Run with plugin debug output
gnosis --debug-plugins render template.md

# Output:
# [DEBUG] Loading plugin: emojify-filter
# [DEBUG] Filter emojify applied: "alpha" → "🔬 alpha"
# [DEBUG] Rendering complete
```

## License

All example plugins are PMPL-1.0-or-later licensed.
