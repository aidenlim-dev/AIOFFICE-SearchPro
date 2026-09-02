#!/usr/bin/env pwsh
# Run the aioffice-searchpro engine through an isolated uv environment.
# Windows-native companion to setup/run-engine.sh.
[CmdletBinding()]
param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]] $EngineArgs
)

# "Continue", not "Stop": Windows PowerShell 5.1 can promote native stderr
# output to terminating errors when streams are redirected. Native calls below
# check $LASTEXITCODE directly.
$ErrorActionPreference = "Continue"

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$EngineRoot = Join-Path $Root "skills/aioffice-searchpro"
function Get-DefaultVenvDir {
  if ($env:AIOFFICE_SEARCHPRO_VENV) {
    return $env:AIOFFICE_SEARCHPRO_VENV
  }
  $localAppData = [Environment]::GetFolderPath("LocalApplicationData")
  if ($localAppData) {
    return (Join-Path $localAppData "aioffice-searchpro/venv")
  }
  return (Join-Path $HOME ".cache/aioffice-searchpro/venv")
}

if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
  Write-Error "aioffice-searchpro: uv is required but was not found: https://docs.astral.sh/uv/getting-started/installation/"
  exit 127
}

$VenvDir = Get-DefaultVenvDir
$VenvPython = Join-Path $VenvDir "Scripts/python.exe"
if (-not (Test-Path $VenvPython)) {
  $VenvPython = Join-Path $VenvDir "bin/python"
}

$parent = Split-Path -Parent $VenvDir
if ($parent) {
  New-Item -ItemType Directory -Force -Path $parent | Out-Null
}
$Log = "$VenvDir.install.log"
$OldUvProjectEnvironment = $env:UV_PROJECT_ENVIRONMENT
$env:UV_PROJECT_ENVIRONMENT = $VenvDir
& uv sync --project $Root --frozen --no-install-project *> $Log
if ($LASTEXITCODE -ne 0) {
  Get-Content $Log -ErrorAction SilentlyContinue | Write-Error
  $env:UV_PROJECT_ENVIRONMENT = $OldUvProjectEnvironment
  exit 1
}
$env:UV_PROJECT_ENVIRONMENT = $OldUvProjectEnvironment

$VenvPython = Join-Path $VenvDir "Scripts/python.exe"
if (-not (Test-Path $VenvPython)) {
  $VenvPython = Join-Path $VenvDir "bin/python"
}

$OldPythonUtf8 = $env:PYTHONUTF8
$OldPythonIoEncoding = $env:PYTHONIOENCODING
$env:PYTHONUTF8 = "1"
$env:PYTHONIOENCODING = "utf-8"
$OldPythonPath = $env:PYTHONPATH
if ($OldPythonPath) {
  $env:PYTHONPATH = "$EngineRoot$([IO.Path]::PathSeparator)$OldPythonPath"
} else {
  $env:PYTHONPATH = $EngineRoot
}

Push-Location $EngineRoot
try {
  & $VenvPython -m engine @EngineArgs
  $Code = $LASTEXITCODE
} finally {
  Pop-Location
  $env:PYTHONPATH = $OldPythonPath
  $env:PYTHONUTF8 = $OldPythonUtf8
  $env:PYTHONIOENCODING = $OldPythonIoEncoding
}
exit $Code
