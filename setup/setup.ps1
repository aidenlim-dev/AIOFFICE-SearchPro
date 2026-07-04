#!/usr/bin/env pwsh
# First-run setup for aioffice-searchpro. Idempotent, non-blocking.
# Windows-native companion to setup/setup.sh.
[CmdletBinding()]
param(
  [string] $Action = "",
  [string] $Decision = "no"
)

$ErrorActionPreference = "SilentlyContinue"

$Plugin = "aioffice-searchpro"
$OwnRepo = "aidenlim-dev/AIOFFICE-SearchPro"
$ConfigDir = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $HOME ".claude" }
$MarkerDir = Join-Path $HOME ".aioffice-searchpro-setup"
$SetupMarker = Join-Path $MarkerDir "$Plugin.json"
$StarMarker = Join-Path $MarkerDir "$Plugin.star.json"
New-Item -ItemType Directory -Force -Path $MarkerDir | Out-Null

function Write-Star($Value) {
  $payload = [ordered]@{
    star_decision = $Value
    plugin = $Plugin
    ts = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
  }
  $payload | ConvertTo-Json -Compress | Set-Content -Encoding UTF8 $StarMarker
}

if ($Action -eq "star") {
  Write-Star $Decision
  if ($Decision -eq "yes" -and (Get-Command gh -ErrorAction SilentlyContinue)) {
    & gh auth status *> $null
    if ($LASTEXITCODE -eq 0) {
      & gh api "user/starred/$OwnRepo" *> $null
      if ($LASTEXITCODE -ne 0) {
        & gh api -X PUT "user/starred/$OwnRepo" *> $null
      }
    }
  }
  exit 0
}

if (-not (Test-Path $SetupMarker)) {
  $payload = [ordered]@{
    setup = $true
    plugin = $Plugin
    ts = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
  }
  $payload | ConvertTo-Json -Compress | Set-Content -Encoding UTF8 $SetupMarker
}

if ($Action -eq "ask" -and -not (Test-Path $StarMarker) -and $env:AIOFFICE_SEARCHPRO_STAR_PROMPT -eq "1") {
  Write-Star "asked"
  Write-Output "STAR_ASK en"
}
exit 0
