# kicad-mcp-claude-extension

Packages [mixelpixx/KiCAD-MCP-Server](https://github.com/mixelpixx/KiCAD-MCP-Server)
as a Claude Desktop **extension** (`.dxt`/`.mcpb`) so Claude Desktop actually
detects and runs it.

## Why

KiCAD-MCP-Server's README has you register it by hand-editing
`claude_desktop_config.json`. On some Claude Desktop builds (the newer
Cowork-enabled ones), that file is silently ignored for manually-added
servers — no error, nothing in Settings → Developer, it just never starts.
Those builds register local servers through **Settings → Extensions**
instead, by installing a `.dxt`/`.mcpb` package.

If editing `claude_desktop_config.json` already works for you (check
Settings → Developer after restarting), you don't need this repo — just
follow KiCAD-MCP-Server's own instructions.

## How it works

1. `setup-windows.ps1` (from KiCAD-MCP-Server) detects your KiCAD/Node/Python
   paths and writes `windows-mcp-config.json`.
2. This repo's `build.ps1` reads that file and repackages its `kicad`
   server entry as a `.dxt`. Its only real adaptation: if the detected
   `command` is a bare name (e.g. `"node"`) rather than an absolute path,
   it resolves one — Claude's extension host doesn't reliably inherit your
   user `PATH`, so a bare command can fail to start with zero error output.
3. The result, `kicad-mcp.dxt`, gets dragged into Claude Desktop's
   Extensions settings.

## Install — step by step

Each step tells you what to run and what you should see before moving on.
If what you see doesn't match, stop there — the next step will fail too.

### Step 1 — Set up KiCAD-MCP-Server

Skip this if you've already done it.

```powershell
git clone https://github.com/mixelpixx/KiCAD-MCP-Server.git
cd KiCAD-MCP-Server
.\setup-windows.ps1
```

Let it run to the end. It should finish with `[OK] Setup completed
successfully!` and a **"Configuration Preview"** block printed to the
screen — that's your server's `command`/`args`/`env`, auto-detected for
this machine. You don't need to copy that block anywhere yourself; the
next steps read it straight from the file it just wrote.

Confirm the file exists:

```powershell
Get-Content .\windows-mcp-config.json
```

You should see JSON with a `"kicad"` entry under `"mcpServers"`. If this
command errors with "file not found," `setup-windows.ps1` didn't finish —
scroll up in its output for the failure and fix that first.

### Step 2 — Build the extension from that config

```powershell
git clone https://github.com/humanifying9/kicad-mcp-claude-extension.git
cd kicad-mcp-claude-extension
.\build.ps1 -KicadMcpServerPath "C:\path\to\your\KiCAD-MCP-Server"
```

(Use the actual path to the folder from Step 1.)

Watch the output — it should print `[OK] Found generated config: ...`,
then `[OK] Wrote manifest for this machine:` followed by the actual
manifest JSON it built (this is your Step 1 config, adapted). Check that
block: the `command` field should be a full path ending in `node.exe`,
not just the word `node`. It should finish with:

```
=== Done ===
Built: ...\kicad-mcp.dxt
```

Confirm the file landed:

```powershell
Get-Item .\kicad-mcp.dxt
```

### Step 3 — Install it in Claude Desktop

Open Claude Desktop → **Settings → Extensions → Advanced settings**. Drag
`kicad-mcp.dxt` onto the **"Drag .MCPB or .DXT files here to install"**
box.

It should appear under "Installed on your computer." If it doesn't, redo
the drag — sometimes the drop target needs a second attempt.

### Step 4 — Restart Claude Desktop

Extensions can need a full restart, not just closing the window:

```powershell
Get-Process claude -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2
Get-Process claude -ErrorAction SilentlyContinue
```

That last command should print nothing — confirming Claude Desktop is
fully closed. Then reopen it from the Start Menu.

### Step 5 — Verify

Back in Settings → Extensions, `kicad-mcp-server` should now show as
installed and running, not just listed.

Then, in a new Claude chat, ask something like *"do you have KiCAD
tools available?"* or *"create a new KiCAD project"*. If Claude can call
KiCAD tools instead of saying it doesn't have any, you're done.

## Troubleshooting

| Problem | Fix |
|---|---|
| PowerShell won't run either `.ps1` script | As admin: `Set-ExecutionPolicy RemoteSigned -Scope LocalMachine` |
| `windows-mcp-config.json` not found (Step 1) | `setup-windows.ps1` didn't complete — re-run it and read its output for the actual failure |
| `build.ps1` says it can't find `windows-mcp-config.json` (Step 2) | You passed the wrong `-KicadMcpServerPath`, or Step 1 wasn't finished there yet |
| Extension installed but no KiCAD tools appear (Step 5) | Redo Step 4 (force-quit, confirm the process list is empty, reopen) |
| Still nothing after that | Open `build\manifest.json` (from Step 2) and confirm every path in it still exists on disk — if you moved either repo folder, re-run `build.ps1` |

## What's in the `.dxt`

A `.dxt` is just a zip with `manifest.json` at its root. This one has:
- `manifest.json` — generated by `build.ps1`, **not committed** (contains
  your machine's absolute paths and username; see `.gitignore`)
- `index.js` — a one-line stub required by the package format, never
  actually executed. The real server is your built
  `KiCAD-MCP-Server\dist\index.js`, referenced by absolute path inside
  `manifest.json`.

## Credits

All KiCAD functionality is [mixelpixx/KiCAD-MCP-Server](https://github.com/mixelpixx/KiCAD-MCP-Server).
This repo doesn't modify it — it only repackages its generated config for
Claude Desktop's extension installer.

## Disclaimer

MIT licensed, provided as-is. This is a workaround for a Claude Desktop
packaging quirk observed on one build, not an official installation
method — it may become unnecessary, or stop working, as Claude Desktop
changes. AI-generated PCB/schematic suggestions from the underlying server
don't replace engineering review — see KiCAD-MCP-Server's own disclaimer.
