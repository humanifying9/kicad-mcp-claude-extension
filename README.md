# kicad-mcp-claude-extension

I ran into this while trying to get [KiCAD-MCP-Server](https://github.com/mixelpixx/KiCAD-MCP-Server)
working with Claude Desktop, and it took way longer than it should have to
figure out what was actually going on — so I'm sharing the fix.

## What's going on

KiCAD-MCP-Server's README tells you to add it to Claude Desktop by editing
`claude_desktop_config.json`. That's the normal way to add a local MCP
server, and it works for a lot of people.

It didn't work for me. I added the server, fully restarted Claude Desktop
(killed the process and reopened it, more than once), and it just...
never showed up. Not an error, not "failed" in Settings → Developer,
nothing at all. The server ran completely fine when I started it myself
in a terminal, so I knew it wasn't broken — Claude Desktop just wasn't
picking it up.

Turns out on newer, Cowork-enabled Claude Desktop builds, local servers
get registered a different way now: through Settings → Extensions, by
installing a `.dxt`/`.mcpb` package, not by hand-editing that config file.
Editing the JSON directly just gets silently ignored on these builds,
with zero indication anything went wrong.

If editing `claude_desktop_config.json` already works for you (check
Settings → Developer after a restart), you don't need any of this — just
follow KiCAD-MCP-Server's normal instructions.

## What this repo does

It takes the config that KiCAD-MCP-Server's own `setup-windows.ps1`
script already generates for your machine — it auto-detects your KiCAD,
Node, and Python paths, so there's no reason to redo that work — and
repackages it as a `.dxt` you can drag into Claude Desktop.

The one thing I actually had to fix on top of what that script generates:
it sets `"command": "node"` instead of the full path to `node.exe`.
That's fine when you run things yourself from a terminal where `node` is
on your PATH, but Claude Desktop's extension host doesn't seem to
inherit that PATH, so the bare command name silently fails to launch.
`build.ps1` resolves it to an absolute path for you.

## How to use it

**1. Set up KiCAD-MCP-Server first, if you haven't already:**
```powershell
git clone https://github.com/mixelpixx/KiCAD-MCP-Server.git
cd KiCAD-MCP-Server
.\setup-windows.ps1
```
Let it finish. It should end with `[OK] Setup completed successfully!`,
and it'll have written `windows-mcp-config.json` in that folder — that's
what the next step reads from.

**2. Clone this repo and build the extension:**
```powershell
git clone https://github.com/humanifying9/kicad-mcp-claude-extension.git
cd kicad-mcp-claude-extension
.\build.ps1 -KicadMcpServerPath "C:\path\to\your\KiCAD-MCP-Server"
```
This spits out `kicad-mcp.dxt` in the folder. Worth glancing at the
output — it prints the manifest it built, and the `command` field in
there should be a full path ending in `node.exe`, not just `node`.

**3. Open Claude Desktop → Settings → Extensions → Advanced settings,
and drag `kicad-mcp.dxt` onto the drop zone.**

**4. Restart Claude Desktop properly** — closing the window isn't
always enough:
```powershell
Get-Process claude -ErrorAction SilentlyContinue | Stop-Process -Force
```
Then reopen it from the Start Menu.

**5. Check it worked** — Settings → Extensions should show it installed,
and in a new chat you can ask Claude something like "do you have KiCAD
tools available?" or just ask it to open a KiCAD project.

## If it still doesn't work

- PowerShell refuses to run the scripts at all: `Set-ExecutionPolicy
  RemoteSigned -Scope LocalMachine` (as admin).
- `windows-mcp-config.json` is missing: `setup-windows.ps1` didn't
  finish — scroll up in its output to see why.
- It's installed but no KiCAD tools show up: redo the restart in step 4,
  making sure the process is actually killed first, not just the window
  closed.
- Still nothing: open `build\manifest.json` and check every path in it
  actually exists — if you moved either repo folder after building,
  you'll need to rebuild.

## What's actually in the .dxt

Just a zip with `manifest.json` at the root. `build.ps1` generates that
file for your machine — it's gitignored, since it has your username and
absolute paths baked in, so it's not something to commit. There's also a
one-line `index.js` stub in there that never actually runs; it just
satisfies a required field in the package format. The real server is
your own built `KiCAD-MCP-Server\dist\index.js`, which the manifest
points to directly.

## Credit

All the actual KiCAD functionality is
[mixelpixx/KiCAD-MCP-Server](https://github.com/mixelpixx/KiCAD-MCP-Server) —
this repo doesn't touch that code, it just repackages the config it
already generates so Claude Desktop can actually find it.

## Disclaimer

MIT licensed, use at your own risk. This is a workaround for a Claude
Desktop quirk I hit on one specific build — it might stop being
necessary (or stop working) as Claude Desktop changes. And as always:
AI-suggested PCB/schematic changes from the underlying server aren't a
substitute for actually checking your own designs.
