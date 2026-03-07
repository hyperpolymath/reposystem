# Gnosis Format Toggle Browser Extension

A cross-browser extension that allows users to toggle between visual and accessible formats for Gnosis-rendered content.

## Features

- **Visual Mode** (Default): Shows Shields.io badges and emoji for a rich visual experience
- **Accessible Mode**: Converts badges to plain text for better screen reader compatibility
- **Persistent Preference**: Saves your choice across all pages
- **Auto-Detection**: Automatically detects and transforms Gnosis content
- **Real-Time Toggle**: Switch modes without reloading the page

## Installation

### Chrome / Edge / Brave

1. Download this `browser-extension` folder
2. Open `chrome://extensions/`
3. Enable "Developer mode" (top right)
4. Click "Load unpacked"
5. Select the `browser-extension` folder

### Firefox

1. Download this `browser-extension` folder
2. Open `about:debugging#/runtime/this-firefox`
3. Click "Load Temporary Add-on"
4. Select the `manifest.json` file in the folder

## Usage

1. Click the Gnosis extension icon in your browser toolbar
2. Choose your preferred format:
   - 🎨 **Visual Mode**: Rich badges and emoji (default)
   - 📖 **Accessible Mode**: Plain text for screen readers
3. The page will automatically update to reflect your choice

## How It Works

### Detection

The extension scans pages for:
- Shields.io badge URLs (`img.shields.io/badge/...`)
- FlexiText patterns with alt-text

### Transformation

**Visual → Accessible:**
- Shields.io badges → Plain text spans with alt-text content
- Styled as monospace with background color
- Preserves semantic meaning

**Accessible → Visual:**
- Restores original badge images
- Maintains alt-text for accessibility

### Storage

- Preference stored in `chrome.storage.sync`
- Syncs across devices (if browser sync enabled)
- Default: Visual mode

## Technical Details

### Manifest V3

- Uses modern Manifest V3 API
- Compatible with Chrome 88+, Edge 88+, Firefox 109+
- Minimal permissions: `storage`, `activeTab`

### Content Script

- Runs on all pages (`<all_urls>`)
- Mutation observer for dynamic content (SPAs)
- No external dependencies

### Architecture

```
┌─────────────┐
│   Popup UI  │ ← User interaction
└──────┬──────┘
       │
       ├─ chrome.storage.sync (save preference)
       │
       └─ chrome.tabs.sendMessage
              │
              ▼
       ┌──────────────────┐
       │  Content Script  │ ← Transform page content
       └──────────────────┘
              │
              ▼
       ┌──────────────────┐
       │   DOM Updates    │ ← Badge ↔ Text conversion
       └──────────────────┘
```

## Development

### File Structure

```
browser-extension/
├── manifest.json           # Extension config (Manifest V3)
├── popup.html              # Extension popup UI
├── scripts/
│   ├── popup.js            # Popup interaction logic
│   └── content.js          # Page content transformation
├── icons/
│   ├── icon-16.png         # Toolbar icon (16x16)
│   ├── icon-48.png         # Extension page (48x48)
│   └── icon-128.png        # Chrome Web Store (128x128)
└── README.md               # This file
```

### Building Icons

Icons are simple placeholders. For production, create:
- 16x16 px for browser toolbar
- 48x48 px for extension management page
- 128x128 px for Chrome Web Store listing

### Testing

1. Load the extension in developer mode
2. Navigate to a page with Gnosis content (e.g., GitHub README with badges)
3. Toggle between Visual and Accessible modes
4. Verify:
   - Badges convert to text (and back)
   - Preference persists across page reloads
   - Works on dynamically loaded content

## Permissions

- **`storage`**: Save user's format preference
- **`activeTab`**: Access current tab to transform content

No data is collected or sent to external servers.

## Compatibility

| Browser | Version | Status |
|---------|---------|--------|
| Chrome  | 88+     | ✅ Full support |
| Edge    | 88+     | ✅ Full support |
| Brave   | 1.20+   | ✅ Full support |
| Firefox | 109+    | ✅ Full support (with minor manifest tweaks) |
| Safari  | 15.4+   | ⚠️  Requires Manifest V2 port |

## License

PMPL-1.0-or-later (same as parent project)

## Contributing

See [CONTRIBUTING.md](../CONTRIBUTING.md) in the parent repository.

## Security

This extension:
- ✅ Runs only when you interact with it (no background scripts)
- ✅ Uses minimal permissions
- ✅ Processes content locally (no network requests)
- ✅ Open source for audit

Report security issues to: [See SECURITY.md](../SECURITY.md)
