#!/usr/bin/env pwsh
# Run the insane-search engine through an isolated Python environment.
# Windows-native companion to setup/run-engine.sh.
[CmdletBinding()]
param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]] $EngineArgs
)

$ErrorActionPreference = "Stop"

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$EngineRoot = Join-Path $Root "skills/insane-search"
$LockFile = Join-Path $Root "requirements.lock"

function Get-PythonExe {
  $candidates = @(
    @{ Command = "py"; Args = @("-3") },
    @{ Command = "python"; Args = @() },
    @{ Command = "python3"; Args = @() }
  )
  foreach ($candidate in $candidates) {
    if (-not (Get-Command $candidate.Command -ErrorAction SilentlyContinue)) {
      continue
    }
    $probeArgs = @($candidate.Args) + @("-c", "import sys; print(sys.executable)")
    try {
      $out = & $candidate.Command @probeArgs 2>$null
      if ($LASTEXITCODE -eq 0 -and $out) {
        return ($out | Select-Object -First 1).Trim()
      }
    } catch {
      continue
    }
  }
  throw "insane-search: Python 3 is required but was not found"
}

function Get-DefaultVenvDir {
  if ($env:INSANE_SEARCH_VENV) {
    return $env:INSANE_SEARCH_VENV
  }
  $localAppData = [Environment]::GetFolderPath("LocalApplicationData")
  if ($localAppData) {
    return (Join-Path $localAppData "insane-search/venv")
  }
  return (Join-Path $HOME ".cache/insane-search/venv")
}

$Python = Get-PythonExe
$VenvDir = Get-DefaultVenvDir
$VenvPython = Join-Path $VenvDir "Scripts/python.exe"
if (-not (Test-Path $VenvPython)) {
  $VenvPython = Join-Path $VenvDir "bin/python"
}
$Stamp = Join-Path $VenvDir ".insane-search-deps-v3"

if (-not (Test-Path $VenvPython)) {
  $parent = Split-Path -Parent $VenvDir
  if ($parent) {
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
  }
  & $Python -m venv $VenvDir
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }
  $VenvPython = Join-Path $VenvDir "Scripts/python.exe"
  if (-not (Test-Path $VenvPython)) {
    $VenvPython = Join-Path $VenvDir "bin/python"
  }
}

if (-not (Test-Path $Stamp)) {
  $Log = Join-Path $VenvDir "install.log"
  & $VenvPython -m pip install -U pip *> $Log
  if ($LASTEXITCODE -ne 0) {
    Get-Content $Log -ErrorAction SilentlyContinue | Write-Error
    exit 1
  }
  & $VenvPython -m pip install -U -r $LockFile *>> $Log
  if ($LASTEXITCODE -ne 0) {
    Get-Content $Log -ErrorAction SilentlyContinue | Write-Error
    exit 1
  }
  [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() | Set-Content -Encoding ASCII $Stamp
}

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
}
exit $Code
