# FloatingText

A minimal macOS app that displays floating text on your screen, always visible above all windows.

## Features

- Pure floating text with no window chrome, background, or borders
- Always on top of all windows (including fullscreen apps)
- Click-through - doesn't intercept mouse events
- Visible on all Spaces/desktops
- Global keyboard shortcuts work even when app isn't focused
- Hidden from Dock

## Requirements

- macOS 12.0 or later
- Swift 5.9+

## Build

```bash
./build.sh
```

Or manually:

```bash
swift build -c release
```

## Run

```bash
./run.sh
```

Or manually:

```bash
./.build/release/FloatingText
```

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Ctrl+Option+→` | Next text |
| `Ctrl+Option+←` | Previous text |
| `Ctrl+Option+Q` | Quit |

## Accessibility Permissions

Global shortcuts require Accessibility permissions. On first run, macOS will prompt you to grant access:

**System Settings → Privacy & Security → Accessibility → Enable FloatingText**

Without this permission, shortcuts only work when the app window is focused.

## Configuration

Edit `demo_texts.txt` to customize the displayed texts. Each line is a separate text entry:

```
First message
Second message
Third message
```

The app looks for `demo_texts.txt` in the current working directory.

## License

MIT
