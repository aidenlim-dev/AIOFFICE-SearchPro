#!/usr/bin/env pwsh
# Undo setup/codex-install-local.ps1: remove the ~/plugins/aioffice-searchpro
# junction and drop the entry from ~/.agents/plugins/marketplace.json.
[CmdletBinding()]
param()

# Pure PowerShell cmdlets only (no native calls), so "Stop" is safe here.
$ErrorActionPreference = "Stop"

function Write-Step {
  param([string] $Message)
  Write-Host "[uninstall] $Message"
}

$PluginName = "aioffice-searchpro"
$HomeRoot = [Environment]::GetFolderPath("UserProfile")
$TargetPlugin = Join-Path $HomeRoot "plugins\$PluginName"
$MarketplacePath = Join-Path $HomeRoot ".agents\plugins\marketplace.json"

if (Test-Path $TargetPlugin) {
  Write-Step "Removing local plugin junction"
  $existing = Get-Item $TargetPlugin -Force
  if ($existing.Attributes -band [IO.FileAttributes]::ReparsePoint) {
    [System.IO.Directory]::Delete($TargetPlugin)
  } else {
    Remove-Item $TargetPlugin -Recurse -Force
  }
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
    $Filtered = @()
    foreach ($plugin in $raw.plugins) {
      if ($plugin.name -ne $PluginName) {
        $Filtered += @{
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
    }
    $Marketplace.plugins = $Filtered
    Write-Step "Updating home marketplace manifest"
    $Marketplace | ConvertTo-Json -Depth 8 | Set-Content -Path $MarketplacePath -Encoding utf8
  }
}

Write-Step "Removed $PluginName from local Codex setup"
