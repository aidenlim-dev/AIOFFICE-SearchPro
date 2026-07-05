#!/usr/bin/env pwsh
# Local Codex install: junction this repo into ~/plugins/aioffice-searchpro and
# register it in ~/.agents/plugins/marketplace.json. The repo stays the source
# of truth, so local edits are live after a Codex restart.
# Uninstall with setup/codex-uninstall-local.ps1.
[CmdletBinding()]
param(
  [switch] $Force
)

# Pure PowerShell cmdlets only (no native calls), so "Stop" is safe here.
$ErrorActionPreference = "Stop"

function Write-Step {
  param([string] $Message)
  Write-Host "[install] $Message"
}

$PluginName = "aioffice-searchpro"
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$HomeRoot = [Environment]::GetFolderPath("UserProfile")
$TargetPlugin = Join-Path $HomeRoot "plugins\$PluginName"
$MarketplacePath = Join-Path $HomeRoot ".agents\plugins\marketplace.json"

# Sanity-check the Codex manifests before touching anything.
$ManifestPath = Join-Path $RepoRoot ".codex-plugin\plugin.json"
if (-not (Test-Path $ManifestPath)) {
  throw "Codex plugin manifest not found: $ManifestPath"
}
$Manifest = Get-Content $ManifestPath -Raw | ConvertFrom-Json
if ($Manifest.name -ne $PluginName) {
  throw "Plugin manifest name mismatch: expected '$PluginName', got '$($Manifest.name)'"
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $TargetPlugin) | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $MarketplacePath) | Out-Null

if (Test-Path $TargetPlugin) {
  $existing = Get-Item $TargetPlugin -Force
  if ($existing.Attributes -band [IO.FileAttributes]::ReparsePoint) {
    [System.IO.Directory]::Delete($TargetPlugin)
  } elseif ($Force) {
    Remove-Item $TargetPlugin -Recurse -Force
  } else {
    throw "Target plugin path already exists: $TargetPlugin. Re-run with -Force to replace it."
  }
}

Write-Step "Creating local junction"
New-Item -ItemType Junction -Path $TargetPlugin -Target $RepoRoot | Out-Null

function ConvertTo-PluginArray {
  param([object[]] $Plugins)
  $result = @()
  foreach ($plugin in $Plugins) {
    $result += @{
      name = $plugin.name
      source = @{
        source = $plugin.source.source
        path = $plugin.source.path
      }
      policy = @{
        installation = $plugin.policy.installation
        authentication = $plugin.policy.authentication
      }
      category = $plugin.category
    }
  }
  return $result
}

$Marketplace = @{
  name = "local-marketplace"
  interface = @{
    displayName = "Local Plugins"
  }
  plugins = @()
}

if (Test-Path $MarketplacePath) {
  $raw = Get-Content $MarketplacePath -Raw | ConvertFrom-Json
  $Marketplace = @{
    name = $raw.name
    interface = @{
      displayName = $raw.interface.displayName
    }
    plugins = @()
  }
  if ($raw.plugins) {
    $Marketplace.plugins = ConvertTo-PluginArray -Plugins $raw.plugins
  }
}

$Entry = @{
  name = $PluginName
  source = @{
    source = "local"
    path = "./plugins/$PluginName"
  }
  policy = @{
    installation = "AVAILABLE"
    authentication = "ON_INSTALL"
  }
  category = "Coding"
}

$Filtered = @()
foreach ($plugin in $Marketplace.plugins) {
  if ($plugin.name -ne $PluginName) {
    $Filtered += $plugin
  }
}
$Filtered += $Entry
$Marketplace.plugins = $Filtered

Write-Step "Updating home marketplace manifest"
$Marketplace | ConvertTo-Json -Depth 8 | Set-Content -Path $MarketplacePath -Encoding utf8

Write-Step "Installed $PluginName for local Codex use"
Write-Host "Plugin path: $TargetPlugin"
Write-Host "Marketplace: $MarketplacePath"
Write-Host "Restart Codex to load the plugin."
