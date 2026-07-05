#!/usr/bin/env pwsh
# Small network-live check for public routes.
# Windows-native companion to setup/live-check.sh.
[CmdletBinding()]
param()

# "Continue", not "Stop": Windows PowerShell 5.1 promotes native stderr output
# to terminating errors under "Stop". Native calls below check $LASTEXITCODE.
$ErrorActionPreference = "Continue"

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$Run = Join-Path $Root "setup/run-engine.ps1"
$Tmp = Join-Path ([IO.Path]::GetTempPath()) ("aioffice-searchpro-live-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $Tmp | Out-Null

function Get-DefaultVenvDir {
  if ($env:AIOFFICE_SEARCHPRO_VENV) { return $env:AIOFFICE_SEARCHPRO_VENV }
  $localAppData = [Environment]::GetFolderPath("LocalApplicationData")
  if ($localAppData) { return (Join-Path $localAppData "aioffice-searchpro/venv") }
  return (Join-Path $HOME ".cache/aioffice-searchpro/venv")
}

function Check-Url {
  param(
    [string] $Name,
    [string[]] $EngineArgs
  )
  $Out = Join-Path $Tmp "$Name.json"
  $Err = Join-Path $Tmp "$Name.err"
  Write-Host -NoNewline "[$Name] "
  & $Run @EngineArgs --json > $Out 2> $Err
  if ($LASTEXITCODE -ne 0) {
    Write-Host "FAIL"
    Get-Content $Err -ErrorAction SilentlyContinue | Select-Object -First 20 | ForEach-Object { Write-Error $_ }
    exit 1
  }
  $Data = Get-Content $Out -Raw | ConvertFrom-Json
  if (-not $Data.ok) {
    Write-Host "FAIL ok=false"
    exit 1
  }
  Write-Host "ok verdict=$($Data.verdict) bytes=$($Data.content_length)"
}

try {
  Check-Url "html" @("https://example.com/", "--selector", "h1", "--no-playwright", "--max-attempts", "1")

  if ($env:AIOFFICE_SEARCHPRO_LIVE_EXTENDED -eq "1") {
    $Platforms = @("x", "hn", "arxiv")
    if ($env:AIOFFICE_SEARCHPRO_LIVE_REDDIT -eq "1") { $Platforms += "reddit" }
    if ($env:AIOFFICE_SEARCHPRO_LIVE_MEDIA -eq "1") { $Platforms += "youtube" }
    Write-Host "[platform battery] $($Platforms -join ' ')"
    $VenvDir = Get-DefaultVenvDir
    $VenvPython = Join-Path $VenvDir "Scripts/python.exe"
    if (-not (Test-Path $VenvPython)) {
      $VenvPython = Join-Path $VenvDir "bin/python"
    }
    $OldPythonPath = $env:PYTHONPATH
    $SkillRoot = Join-Path $Root "skills/aioffice-searchpro"
    if ($OldPythonPath) {
      $env:PYTHONPATH = "$SkillRoot$([IO.Path]::PathSeparator)$OldPythonPath"
    } else {
      $env:PYTHONPATH = $SkillRoot
    }
    & $VenvPython (Join-Path $Root "skills/aioffice-searchpro/tests/coverage_battery.py") @Platforms
    $Code = $LASTEXITCODE
    $env:PYTHONPATH = $OldPythonPath
    if ($Code -ne 0) { exit $Code }
  }
  Write-Host "live-check complete"
} finally {
  Remove-Item -Recurse -Force $Tmp -ErrorAction SilentlyContinue
}
