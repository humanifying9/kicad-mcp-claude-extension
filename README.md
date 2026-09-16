# kicad-mcp-claude-extension

Packages [KiCAD-MCP-Server](https://github.com/mixelpixx/KiCAD-MCP-Server)
as a Claude Desktop extension (`.dxt`/`.mcpb`) so Claude Desktop actually
detects and runs it.

## The problem

KiCAD-MCP-Server's README has you add it by editing
`claude_desktop_config.json`. On newer, Cowork-enabled Claude Desktop
builds, that file isn't picked up for manually-added servers — nothing
shows in Settings → Developer, and there's no error message to go on.
Those builds install local servers a different way: through Settings →
Extensions, by installing a `.dxt`/`.mcpb` package instead of editing
JSON.

If editing `claude_desktop_config.json` already works (check Settings →
Developer after a restart), this repo isn't needed — just follow
KiCAD-MCP-Server's normal instructions.

## How it works

1. `setup-windows.ps1` (from KiCAD-MCP-Server) detects the KiCAD, Node,
   and Python paths on the machine and writes `windows-mcp-config.json`.
2. `build.ps1` in this repo reads that file and repackages its `kicad`
   entry as a `.dxt`. The one fix it applies: if the generated `command`
   is a bare name like `"node"` instead of an absolute path, it resolves
   one — Claude Desktop's extension host doesn't reliably inherit the
   system PATH, so a bare command name can fail to launch with no error.
3. The result, `kicad-mcp.dxt`, gets dragged into Claude Desktop's
   Extensions settings.

## How to use it

**1. Set up KiCAD-MCP-Server, if not already done:**
```powershell
git clone https://github.com/mixelpixx/KiCAD-MCP-Server.git
cd KiCAD-MCP-Server
.\setup-windows.ps1
```
This writes `windows-mcp-config.json` in that folder.

**2. Build the extension:**
```powershell
git clone https://github.com/humanifying9/kicad-mcp-claude-extension.git
cd kicad-mcp-claude-extension
.\build.ps1 -KicadMcpServerPath "C:\path\to\your\KiCAD-MCP-Server"
```
Produces `kicad-mcp.dxt` in this folder.

**3. Install it:** Claude Desktop → Settings → Extensions → Advanced
settings → drag `kicad-mcp.dxt` onto the drop zone.

**4. Restart Claude Desktop:**
```powershell
Get-Process claude -ErrorAction SilentlyContinue | Stop-Process -Force
```
Then reopen it.

**5. Verify:** in a new chat, ask Claude to open or create a KiCAD
project. If it can call KiCAD tools, it's working.

## Troubleshooting

- PowerShell won't run the scripts: `Set-ExecutionPolicy RemoteSigned
  -Scope LocalMachine` (as admin).
- `windows-mcp-config.json` missing: `setup-windows.ps1` didn't finish —
  check its output.
- Extension installed but no KiCAD tools show up: repeat step 4, making
  sure the process is fully killed, not just the window closed.
- Still nothing: check the paths in `build\manifest.json` still exist —
  if either repo folder was moved, rebuild.

## What's in the `.dxt`

A zip with `manifest.json` at the root (generated per-machine by
`build.ps1`, gitignored since it contains absolute paths and a username)
and a one-line `index.js` stub required by the package format but never
actually run. The real server is the built
`KiCAD-MCP-Server\dist\index.js`, referenced by absolute path.

## Credit

All KiCAD functionality is
[mixelpixx/KiCAD-MCP-Server](https://github.com/mixelpixx/KiCAD-MCP-Server).
This repo only repackages its generated config for Claude Desktop's
extension installer.

## Disclaimer

MIT licensed, provided as-is. A workaround for a Claude Desktop packaging
quirk on one build — may become unnecessary or stop working as Claude
Desktop changes.
