# QuickBlur

A custom Vencord plugin that blurs the whole Discord window with a configurable hotkey.

Created by DG  
Discord: `@dg_227`

## Features

- Choose your own blur hotkey
- Switch between `toggle` mode and `hold` mode
- Adjust blur strength and dim amount from Vencord settings

## Requirements

- `Node.js`

This is a custom Vencord `userplugin`, not an official built-in Vencord plugin.
The installer will set up a source-built Vencord checkout automatically, copy this plugin into it, build it, then run the official Vencord installer CLI against your Discord install.

Docs:

- Custom plugins: https://docs.vencord.dev/installing/custom-plugins/
- Installing Vencord from source: https://docs.vencord.dev/installing/

## Quick Install

1. Download this repo as a zip and extract it
2. Fully quit Discord
3. Double-click `install.bat`
4. The installer will try to do the rest automatically:
   - find an existing Vencord source folder
   - or download a fresh Vencord source checkout
   - copy the plugin into `src/userplugins/quickBlur`
   - install dependencies
   - build Vencord
   - download or update the Vencord installer CLI
   - detect your Discord install automatically
   - install or repair Vencord with your built plugin included
5. Open Discord again
6. Enable `QuickBlur` in Vencord settings

If Discord was not patched automatically, open the Vencord source folder the installer used and run:

```powershell
node scripts/runInstaller.mjs -- --install --branch auto
```

## Watch Mode

If you want the installer to start a watch build for development, run:

```powershell
.\install.bat -WatchBuild
```

## Manual Install

If you already have a Vencord source checkout:

1. Open your Vencord folder
2. Go to `src/userplugins`
3. Create `quickBlur`
4. Copy this repo's `index.tsx` to `src/userplugins/quickBlur/index.tsx`
5. Copy this repo's `styles.css` to `src/userplugins/quickBlur/styles.css`
6. Run:

```powershell
corepack pnpm build
```

7. Install or repair Discord with the official Vencord installer CLI:

```powershell
node scripts/runInstaller.mjs -- --install --branch auto
```

8. Restart Discord
9. Enable `QuickBlur`

## License

GPL-3.0-or-later
