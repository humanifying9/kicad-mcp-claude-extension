# kicad-mcp-claude-extension

A small wrapper that packages [mixelpixx/KiCAD-MCP-Server](https://github.com/mixelpixx/KiCAD-MCP-Server)
as a **Claude Desktop extension** (`.dxt`/`.mcpb`), so Claude can actually
see and use it.

## Why this exists

KiCAD-MCP-Server's own README tells you to add it to Claude Desktop by
hand-editing `claude_desktop_config.json`'s `mcpServers` block. That's the
standard way to register a local MCP server — and it works on many Claude
Desktop builds.

On some current Claude Desktop builds (the newer Cowork-enabled ones), it
doesn't. Local MCP servers there are registered through the **Extensions**
system instead (Settings → Extensions), which installs `.dxt`/`.mcpb`
packages you drag onto the "Advanced settings" drop zone. A server that
only exists in `claude_desktop_config.json` never shows up — not even as a
failed/errored entry — because that build doesn't read that file for
manually-added servers at all. There's no error message; it just silently
never starts. (If you've been trying to debug an "it's configured
correctly but Claude Desktop doesn't see it at all" situation, this is why.)

This repo builds the `.dxt` package that mechanism actually needs, using
the exact server configuration [KiCAD-MCP-Server's own setup
script](https://github.com/mixelpixx/KiCAD-MCP-Server) already generates
for your machine — it doesn't re-detect your KiCAD/Node/Python paths
itself, it adapts what that script already found.

If your Claude Desktop build *does* pick up `claude_desktop_config.json`
correctly, you don't need any of this — just follow KiCAD-MCP-Server's own
README instead.

## How it works

1. You set up KiCAD-MCP-Server normally, including running its own
   `setup-windows.ps1`, which detects your KiCAD install, installs Python
   dependencies, builds the project, and — importantly — writes
   `windows-mcp-config.json` containing the exact `command`/`args`/`env`
   it detected for your machine.
2. `build.ps1` in this repo reads that generated file and drops its
   `mcpServers.kicad` block straight into a `.dxt` manifest, making one
   adjustment: if the generated `command` is a bare name like `"node"`
   rather than an absolute path, it resolves it to one (e.g.
   `C:\Program Files\nodejs\node.exe`). This matters because Claude
   Desktop's extension host doesn't reliably launch child processes with
   your normal user `PATH`, so a bare command name can fail to start with
   zero error output — exactly the symptom that motivated this repo.
3. It zips the result into `kicad-mcp.dxt`, which you drag into Claude
   Desktop's Extensions settings.

Nothing here reimplements KiCAD/Python/Node detection — that's
KiCAD-MCP-Server's job, and it already does it well via
`setup-windows.ps1`. This repo only bridges its output into the extension
format.

## Prerequisites

- Windows, with [KiCAD-MCP-Server](https://github.com/mixelpixx/KiCAD-MCP-Server)
  already cloned and set up — specifically, you must have already run its
  `setup-windows.ps1` so that `windows-mcp-config.json` exists in that
  folder:

  ```powershell
  git clone https://github.com/mixelpixx/KiCAD-MCP-Server.git
  cd KiCAD-MCP-Server
  .\setup-windows.ps1
  ```

  (If PowerShell refuses to run scripts, see
  [Troubleshooting](#troubleshooting) below.)

- Claude Desktop, with the Extensions settings page (Settings → Extensions
  → Advanced settings) showing a **"Drag .MCPB or .DXT files here to
  install"** drop zone. If your build instead shows the server correctly
  under Settings → Developer after a normal `claude_desktop_config.json`
  edit, you don't need this repo.

## Install and run

1. Clone this repo next to (or anywhere relative to) your
   `KiCAD-MCP-Server` clone:

   ```powershell
   git clone https://github.com/humanifying9/kicad-mcp-claude-extension.git
   cd kicad-mcp-claude-extension
   ```

2. Build the `.dxt`, pointing it at your `KiCAD-MCP-Server` clone (skip
   `-KicadMcpServerPath` if it's at the default `$HOME\KiCAD-MCP-Server`):

   ```powershell
   .\build.ps1 -KicadMcpServerPath "C:\path\to\your\KiCAD-MCP-Server"
   ```

   This writes `kicad-mcp.dxt` in this folder, built from your machine's
   own generated config.

3. Open Claude Desktop → Settings → Extensions → **Advanced settings**,
   and drag `kicad-mcp.dxt` onto the **"Drag .MCPB or .DXT files here to
   install"** area.

4. It should appear under "Installed on your computer" next to any other
   local extensions you have. If it doesn't start immediately, fully quit
   Claude Desktop and reopen it:

   ```powershell
   Get-Process claude -ErrorAction SilentlyContinue | Stop-Process -Force
   ```

   then relaunch from the Start Menu.

5. Verify: start a new Claude chat and ask it to check whether KiCAD tools
   are available, or just ask it to open/create a KiCAD project. If it can
   call `get_backend_state` (or similar) and gets a response instead of
   "no such tool," it's connected.

## Troubleshooting

- **PowerShell won't run `setup-windows.ps1` or `build.ps1`** — scripts
  are disabled by default on many Windows machines. Fix (as
  Administrator):
  ```powershell
  Set-ExecutionPolicy RemoteSigned -Scope LocalMachine
  ```

- **`windows-mcp-config.json` not found** — `build.ps1` will tell you
  this and stop; it means `setup-windows.ps1` hasn't been run successfully
  yet inside your `KiCAD-MCP-Server` folder.

- **The extension installs but doesn't start / no KiCAD tools show up** —
  fully quit all `claude` processes (see step 4 above) and relaunch, then
  recheck Settings → Extensions. If it still doesn't start, check that the
  paths inside `build\manifest.json` (printed by `build.ps1`) actually
  exist on disk — the built package is specific to the exact folder
  locations detected when you ran `setup-windows.ps1`, so moving either
  repo afterward will break it and you'll need to re-run `build.ps1`.

- **This isn't needed at all for you** — if adding the server directly via
  Settings → Developer → "Local MCP servers" → Edit config already works
  and shows KiCAD as running, use that instead; this repo is only a
  workaround for builds where that path is silently ignored.

## What's actually in the `.dxt`

A `.dxt`/`.mcpb` file is just a zip archive with a `manifest.json` at its
root. This one contains:

- `manifest.json` — generated by `build.ps1`, not committed to this repo
  (it's specific to your machine's paths).
- `index.js` — a one-line stub. It's never executed; it only satisfies the
  package format's required `entry_point` field. The real server that
  actually runs is whatever absolute path `manifest.json`'s
  `server.mcp_config.args` points to — your built
  `KiCAD-MCP-Server\dist\index.js`.

`manifest.template.json` in this repo is the template `build.ps1` fills
in; the machine-specific `build/manifest.json` and `kicad-mcp.dxt` it
produces are gitignored, since they contain absolute paths and a username
specific to whoever built them.

## Credits

All actual KiCAD functionality comes from
[mixelpixx/KiCAD-MCP-Server](https://github.com/mixelpixx/KiCAD-MCP-Server).
This repo doesn't modify or vendor that project — it only packages its
already-generated config for Claude Desktop's extension installer.

## Disclaimer

Provided as-is, no warranty. This is a workaround for a Claude Desktop
packaging quirk observed on one machine/build, not an officially
documented installation method — it may stop being necessary (or stop
working) as Claude Desktop changes. AI-generated design suggestions from
the underlying KiCAD MCP server do not replace qualified engineering
review; see KiCAD-MCP-Server's own disclaimer for details.
