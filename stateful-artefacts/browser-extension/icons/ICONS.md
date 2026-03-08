# Icon Placeholders

This directory should contain the following icon files:

- `icon-16.png` - 16x16 pixels (toolbar icon)
- `icon-48.png` - 48x48 pixels (extension management)
- `icon-128.png` - 128x128 pixels (Chrome Web Store)

## Creating Icons

### Simple Placeholder (for testing)

Use any 16x16, 48x48, and 128x128 PNG images. You can generate them with:

```bash
# Using ImageMagick
convert -size 16x16 xc:#0066cc icon-16.png
convert -size 48x48 xc:#0066cc icon-48.png
convert -size 128x128 xc:#0066cc icon-128.png
```

### Production Icons

For production, create proper icons with:
- Transparent background
- Clean, recognizable symbol (e.g., "Aa" for accessibility toggle, eye icon, etc.)
- Colors matching Gnosis branding
- SVG source for scaling

### Design Suggestions

**Symbol ideas:**
- Toggle switch (on/off)
- Eye icon (visibility)
- "Aa" text (typography/format)
- Accessibility icon
- Badge/shield icon

**Colors:**
- Primary: #0066cc (blue)
- Accent: #00cc66 (green)
- Background: Transparent

### Tools

- [Figma](https://figma.com) - Icon design
- [SVGOMG](https://jakearchibald.github.io/svgomg/) - SVG optimization
- [IconBaker](https://icon.kitchen/) - Generate all sizes from one image

## License

Icons should be PMPL-1.0-or-later licensed or public domain.
