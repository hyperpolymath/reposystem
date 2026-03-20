# SPDX-License-Identifier: MPL-2.0-or-later
image:https://img.shields.io/badge/License-MPL_2.0-blue.svg[MPL-2.0-or-later,link="https://opensource.org/licenses/MPL-2.0"]



# Gittyup Integration for bitfuckit

[Gittyup](https://github.com/Murmele/Gittyup) is a Qt-based Git GUI.

## Current Status

Gittyup doesn't have a formal plugin API yet, but we can integrate via:

1. **Custom Tools Menu** - Add external tool definitions
2. **Git Hooks** - Triggered on Git operations

## Custom Tools Setup

Gittyup uses `~/.config/gittyup/tools.json` for custom tools:

```json
{
  "tools": [
    {
      "name": "Bitbucket: Create PR",
      "command": "bitfuckit",
      "arguments": ["pr", "create", "--branch", "$BRANCH"],
      "workdir": "$REPO_PATH"
    },
    {
      "name": "Bitbucket: List PRs",
      "command": "bitfuckit",
      "arguments": ["pr", "list"],
      "workdir": "$REPO_PATH"
    },
    {
      "name": "Bitbucket: Mirror",
      "command": "bitfuckit",
      "arguments": ["mirror"],
      "workdir": "$REPO_PATH"
    },
    {
      "name": "Bitbucket: Pipeline Status",
      "command": "bitfuckit",
      "arguments": ["pipeline", "status"],
      "workdir": "$REPO_PATH"
    }
  ]
}
```

## Installation

```bash
mkdir -p ~/.config/gittyup
cp tools.json ~/.config/gittyup/
```

## Future

We're tracking the Gittyup project for proper plugin API support.

When available, a full Qt plugin will be developed providing:
- Native UI integration
- Real-time pipeline status
- PR review inline
- Issue linking
