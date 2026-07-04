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

if (Test-Path (Join-Path $Root "requirements.lock")) {
  Ok "Python dependency lockfile present"
} else {
  Bad "requirements.lock is missing"
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

if (Get-Command node -ErrorAction SilentlyContinue) {
  Ok "Node.js found: $(& node --version)"
} else {
  Warn "Node.js not found; local real-Chrome Playwright fallback will be unavailable"
}

if (Test-Path (Join-Path $Root "skills/aioffice-searchpro/engine/templates/node_modules")) {
  Ok "local Playwright template dependencies installed"
} else {
  Warn "optional browser fallback not fully installed: run 'pwsh -NoProfile -ExecutionPolicy Bypass -File setup/browser.ps1'"
}

if (Get-Command claude -ErrorAction SilentlyContinue) {
  $mcpList = ""
  try { $mcpList = & claude mcp list 2>$null | Out-String } catch { $mcpList = "" }
  if ($mcpList -match "(?im)playwright") {
    Ok "Playwright MCP appears configured"
  } else {
    Warn "optional Playwright MCP not configured: run 'pwsh -NoProfile -ExecutionPolicy Bypass -File setup/browser.ps1'"
  }
} else {
  Warn "optional Playwright MCP not configured: Claude Code CLI not found"
}

if ($Fail) { exit 1 }
exit 0
