#Requires -Version 5.1
<#
.SYNOPSIS
  Builds kicad-mcp.dxt, a Claude Desktop extension package for the
  mixelpixx/KiCAD-MCP-Server MCP server, tailored to this machine.

.DESCRIPTION
  This script does NOT re-detect your KiCAD / Node / Python paths itself.
  Instead it reads windows-mcp-config.json, the config file that
  KiCAD-MCP-Server's own setup-windows.ps1 script already generates after
  detecting your KiCAD install, Python environment, and Node install. It
  takes that generated "kicad" mcpServers block as the source of truth and
  adapts it into the .dxt/manifest.json format Claude Desktop's Extensions
  system expects (see README.md for why a plain claude_desktop_config.json
  edit is not enough on some Claude Desktop builds).

  The one adjustment this script makes on top of the generated config: if
  the "command" field is a bare executable name (e.g. "node") rather than
  an absolute path, it resolves it to an absolute path via Get-Command.
  This matters because Claude Desktop's extension host does not always
  launch child processes with your normal user PATH, so a bare "node"
  can silently fail to start with no error and no log.

.PARAMETER KicadMcpServerPath
  Path to your local clone of https://github.com/mixelpixx/KiCAD-MCP-Server
  (the folder containing windows-mcp-config.json after you've run its
  setup-windows.ps1 script). Defaults to "$HOME\KiCAD-MCP-Server".

.PARAMETER AuthorName
  Name to put in the generated manifest's author field. Defaults to your
  Windows username.

.PARAMETER OutFile
  Where to write the finished .dxt package. Defaults to
  ".\kicad-mcp.dxt" in this repo's folder.

.EXAMPLE
  .\build.ps1
  .\build.ps1 -KicadMcpServerPath "D:\dev\KiCAD-MCP-Server"
#>

param(
  [string]$KicadMcpServerPath = (Join-Path $HOME "KiCAD-MCP-Server"),
  [string]$AuthorName = $env:USERNAME,
  [string]$OutFile = (Join-Path $PSScriptRoot "kicad-mcp.dxt")
)

$ErrorActionPreference = "Stop"

function Fail($msg) {
  Write-Host "[ERROR] $msg" -ForegroundColor Red
  exit 1
}

Write-Host "=== Building kicad-mcp.dxt ===" -ForegroundColor Cyan

# 1. Locate the config that KiCAD-MCP-Server's own setup script generated.
if (-not (Test-Path $KicadMcpServerPath)) {
  Fail "Can't find KiCAD-MCP-Server at '$KicadMcpServerPath'. Pass -KicadMcpServerPath pointing at your clone."
}

$generatedConfigPath = Join-Path $KicadMcpServerPath "windows-mcp-config.json"
if (-not (Test-Path $generatedConfigPath)) {
  Fail @"
'$generatedConfigPath' doesn't exist yet.

This script builds on top of KiCAD-MCP-Server's own setup output rather than
re-detecting your KiCAD/Node/Python paths itself. Run its setup script first:

    cd '$KicadMcpServerPath'
    .\setup-windows.ps1

That detects your KiCAD install, installs Python deps, builds the project,
and writes windows-mcp-config.json -- then re-run this script.
"@
}

Write-Host "[OK] Found generated config: $generatedConfigPath"

# 2. Pull out the "kicad" server block it generated.
$generated = Get-Content $generatedConfigPath -Raw | ConvertFrom-Json
$kicadServer = $generated.mcpServers.kicad
if (-not $kicadServer) {
  Fail "windows-mcp-config.json doesn't contain a 'mcpServers.kicad' entry. Re-run setup-windows.ps1 in KiCAD-MCP-Server."
}

$cmd = $kicadServer.command
$args = @($kicadServer.args)
$env = $kicadServer.env

# 3. Adapt: resolve a bare command name to an absolute path.
#    (Claude Desktop's extension host doesn't reliably inherit user PATH.)
$isAbsolute = [System.IO.Path]::IsPathRooted($cmd)
if (-not $isAbsolute) {
  Write-Host "[INFO] Config's command '$cmd' isn't an absolute path -- resolving it..."
  $resolved = (Get-Command $cmd -ErrorAction SilentlyContinue).Source
  if ($resolved) {
    Write-Host "[OK] Resolved '$cmd' -> '$resolved'"
    $cmd = $resolved
  } else {
    Write-Host "[WARN] Could not resolve '$cmd' on PATH. The extension may fail to start silently. Consider editing the generated manifest.json's command field by hand." -ForegroundColor Yellow
  }
}

# 4. Sanity check the server entry point actually exists.
if ($args.Count -gt 0 -and -not (Test-Path $args[0])) {
  Write-Host "[WARN] '$($args[0])' doesn't exist on disk. Did the build step in setup-windows.ps1 succeed?" -ForegroundColor Yellow
}

# 5. Build the manifest from the template, with the adapted server block.
$templatePath = Join-Path $PSScriptRoot "manifest.template.json"
$manifest = Get-Content $templatePath -Raw | ConvertFrom-Json
$manifest.author.name = $AuthorName
$manifest.server.mcp_config = [ordered]@{
  command = $cmd
  args    = $args
  env     = $env
}

$buildDir = Join-Path $PSScriptRoot "build"
New-Item -ItemType Directory -Path $buildDir -Force | Out-Null
$manifestOut = Join-Path $buildDir "manifest.json"
$manifest | ConvertTo-Json -Depth 10 | Set-Content -Path $manifestOut -Encoding UTF8
Copy-Item (Join-Path $PSScriptRoot "index.js") (Join-Path $buildDir "index.js") -Force

Write-Host "[OK] Wrote manifest for this machine:"
Get-Content $manifestOut | Write-Host

# 6. Zip it into a .dxt (a .dxt/.mcpb is just a zip with manifest.json at its root).
if (Test-Path $OutFile) { Remove-Item $OutFile -Force }
Compress-Archive -Path (Join-Path $buildDir "*") -DestinationPath ($OutFile + ".zip") -Force
Move-Item ($OutFile + ".zip") $OutFile -Force

Write-Host ""
Write-Host "=== Done ===" -ForegroundColor Green
Write-Host "Built: $OutFile"
Write-Host ""
Write-Host "Next: open Claude Desktop -> Settings -> Extensions -> Advanced settings,"
Write-Host "and drag $OutFile onto the 'Drag .MCPB or .DXT files here to install' area."
