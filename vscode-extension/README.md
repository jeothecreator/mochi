# Mochi for VS Code 🍡

Makes your [Mochi](https://github.com/jeothecreator/mochi) desktop pet react to your coding:

- 😰 **Errors appear after you save** → Mochi looks worried ("uh oh, 3 errors…")
- ✨ **All errors fixed** → Mochi celebrates
- 🎉 **Build/test task passes** → "WE DID IT" · 💥 **fails** → Mochi falls over

Requires the Mochi app for macOS (`brew install --cask jeothecreator/mochi/mochi` or the DMG from the releases page).

## Settings

- `mochi.reactToErrors` (default on)
- `mochi.errorScope` — `workspace` (default) or `activeFile`
- `mochi.reactToTasks` (default on)

Commands: **Mochi: Send a test cheer** / **Mochi: Send a test error**.

## Privacy

The extension only opens `mochi://` links on your own Mac with an error *count* or a task exit code. It never sends code, file names, or anything over the network.
