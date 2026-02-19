# ClipboardWhere

A dead-simple clipboard history manager for macOS. Press **Cmd+Option+V** to bring up a floating panel, select from your copy history, and paste instantly — like Windows' Win+V.

## Features

- **Global hotkey**: Cmd+Option+V opens clipboard history from anywhere
- **Instant paste**: Select an item to paste it into the active app
- **Search**: Filter clipboard history with live search
- **Pin items**: Pin frequently used snippets so they're always available
- **Keyboard navigation**: Arrow keys to navigate, Enter to paste, Escape to close
- **Click outside to dismiss**: Panel closes when you click anywhere else
- **Persistence**: History survives app restarts (stored as JSON)
- **Deduplication**: Re-copying the same text moves it to the top
- **Menu bar app**: Lives in your menu bar, no dock icon
- **50 item history**: Keeps the last 50 clipboard entries (pinned items are never evicted)

## Installation

### From DMG

1. Download the latest `.dmg` from [Releases](../../releases)
2. Open the DMG and drag **ClipboardWhere** to your Applications folder
3. Launch ClipboardWhere from Applications
4. **Grant Accessibility permission** (see below)

### Build from source

Requires **Xcode Command Line Tools** and **macOS 13+** (Ventura).

```bash
git clone https://github.com/YOUR_USERNAME/clipboardwhere.git
cd clipboardwhere
bash scripts/bundle.sh
open build/ClipboardWhere.app
```

## Accessibility Permission

ClipboardWhere needs Accessibility access to simulate Cmd+V and paste into other apps. **Without it, the app will copy text to your clipboard but can't paste automatically.**

### Granting permission

1. On first launch, the app will prompt you to grant access
2. Go to **System Settings > Privacy & Security > Accessibility**
3. Click the **+** button
4. Navigate to and select **ClipboardWhere.app**
5. Make sure the toggle is **ON**
6. **Restart ClipboardWhere** (Cmd+Q, then reopen)

### After rebuilding from source

Each rebuild changes the app's code signature, which invalidates the Accessibility permission. To fix:

1. Open **System Settings > Privacy & Security > Accessibility**
2. **Remove** the old ClipboardWhere entry (click **-**)
3. **Re-add** the new build (click **+**, select `build/ClipboardWhere.app`)
4. Restart the app

## Usage

| Action | Shortcut |
|---|---|
| Open clipboard history | **Cmd+Option+V** |
| Navigate items | **↑ / ↓** |
| Paste selected item | **Enter** or click |
| Close panel | **Escape** or click outside |
| Quit | **Cmd+Q** |

- Click the **menu bar icon** for options (show history, clear history, check accessibility, quit)
- **Hover** over an item to see pin and delete icons
- Switch between **All** and **Pinned** tabs at the bottom

## Tech Stack

- Swift / SwiftUI — native macOS, no Electron
- Swift Package Manager — no Xcode project needed
- Carbon `RegisterEventHotKey` — system-wide hotkey without extra permissions
- `NSPanel` with `.nonactivatingPanel` — floating panel that doesn't steal focus
- `CGEvent` — paste simulation via HID event tap

## License

MIT
