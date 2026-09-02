#!/usr/bin/env pwsh
# Course/student readiness check for aioffice-searchpro.
# Windows-native companion to setup/doctor.sh.
[CmdletBinding()]
param()

$ErrorActionPreference = "Continue"

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$RunEngine = Join-Path $Root "setup/run-engine.ps1"
$Fail = $false

function Ok($Message) { Write-Host "ok  $Message" }
function Warn($Message) { Write-Host "warn $Message" }
function Bad($Message) { Write-Host "bad $Message"; $script:Fail = $true }

if (Get-Command claude -ErrorAction SilentlyContinue) {
  try {
    Ok "Claude Code found: $((& claude --version 2>$null | Select-Object -First 1))"
  } catch {
    Ok "Claude Code found"
  }
  & claude plugin validate $Root *> $null
  if ($LASTEXITCODE -eq 0) {
    Ok "Claude plugin validator passes"
  } else {
    Bad "Claude plugin validation failed: run 'claude plugin validate $Root'"
  }
} else {
  Bad "Claude Code CLI not found. Install Claude Code first."
}

if (Test-Path (Join-Path $Root ".claude-plugin/marketplace.json")) {
  if (Get-Command claude -ErrorAction SilentlyContinue) {
    & claude plugin validate $Root *> $null
    if ($LASTEXITCODE -eq 0) {
      Ok "marketplace/plugin files are present"
    } else {
      Warn "marketplace file is present, but validation could not be confirmed"
    }
  } else {
    Warn "marketplace file is present, but validation could not be confirmed"
  }
} else {
  Bad ".claude-plugin/marketplace.json is missing"
}

if ((Test-Path (Join-Path $Root "pyproject.toml")) -and (Test-Path (Join-Path $Root "uv.lock"))) {
  Ok "uv project and dependency lockfile present"
} else {
  Bad "pyproject.toml or uv.lock is missing"
}

if (Get-Command uv -ErrorAction SilentlyContinue) {
  Ok "uv found: $(& uv --version)"
} else {
  Bad "uv not found. Install it from https://docs.astral.sh/uv/getting-started/installation/"
}

if (Test-Path (Join-Path $Root "skills/aioffice-searchpro/engine/templates/package-lock.json")) {
  Ok "Node dependency lockfile present"
} else {
  Warn "Node dependency lockfile missing; optional browser setup may drift"
}

$Temp = [IO.Path]::GetTempPath()
$SmokeOut = Join-Path $Temp "aioffice-searchpro-doctor.json"
$SmokeErr = Join-Path $Temp "aioffice-searchpro-doctor.err"
& $RunEngine "https://example.com/" --selector h1 --no-playwright --max-attempts 1 --json > $SmokeOut 2> $SmokeErr
if ($LASTEXITCODE -eq 0) {
  Ok "engine smoke test passed"
} else {
  Bad "engine smoke test failed"
  Get-Content $SmokeErr -ErrorAction SilentlyContinue | Select-Object -First 20 | ForEach-Object { Write-Host $_ }
}

$HasNode = [bool](Get-Command node -ErrorAction SilentlyContinue)
if ($HasNode) {
  Ok "Node.js found: $(& node --version)"
} else {
  Warn "Node.js not found; local real-Chrome Playwright fallback will be unavailable"
}

$HasBrowserDeps = Test-Path (Join-Path $Root "skills/aioffice-searchpro/engine/templates/node_modules")
if ($HasBrowserDeps) {
  Ok "local Playwright template dependencies installed"
} else {
  Warn "optional browser fallback not fully installed: run 'powershell -NoProfile -ExecutionPolicy Bypass -File setup/browser.ps1'"
}

$HasMcp = $false
if (Get-Command claude -ErrorAction SilentlyContinue) {
  $mcpList = ""
  try { $mcpList = & claude mcp list 2>$null | Out-String } catch { $mcpList = "" }
  if ($mcpList -match "(?im)playwright") {
    $HasMcp = $true
    Ok "Playwright MCP appears configured"
  } else {
    Warn "optional Playwright MCP not configured: run 'powershell -NoProfile -ExecutionPolicy Bypass -File setup/browser.ps1'"
  }
} else {
  Warn "optional Playwright MCP not configured: Claude Code CLI not found"
}

Write-Host ""
Write-Host "=== doctor summary ==="
if ($Fail) {
  Write-Host "CORE: NOT READY - fix the 'bad' items above, then re-run doctor."
} else {
  Write-Host "CORE: ready - blocked-page reading works now; no further setup is required."
}
if ($HasNode -and $HasBrowserDeps -and $HasMcp) {
  Write-Host "OPTIONAL browser fallback: fully installed."
} else {
  Write-Host "OPTIONAL browser fallback: not fully installed. Only needed for heavy JS/WAF sites (Cloudflare/Akamai class); everything else already works."
  Write-Host "  To enable later:"
  if (-not $HasNode) {
    Write-Host "    1) Install Node.js 18+ (e.g. winget install OpenJS.NodeJS.LTS)"
    Write-Host "    2) powershell -NoProfile -ExecutionPolicy Bypass -File setup/browser.ps1"
    Write-Host "       (or let the script install Node for you: setup/browser.ps1 -InstallNode)"
  } else {
    Write-Host "    powershell -NoProfile -ExecutionPolicy Bypass -File setup/browser.ps1"
  }
  Write-Host "  AI agents: relay this optional gap to the user and ask before installing Node.js or MCP servers - never install system software silently."
}

if ($Fail) { exit 1 }
exit 0
