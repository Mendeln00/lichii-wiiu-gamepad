#Requires -Version 5.1
<#
.SYNOPSIS
    Runs the Pester tests for the host module. Exits non-zero on failure.
#>
[CmdletBinding()]
param(
    [switch]$CI
)

$ErrorActionPreference = 'Stop'
Import-Module Pester -MinimumVersion 5.6

$config = New-PesterConfiguration
$config.Run.Path = $PSScriptRoot
$config.Run.Exit = $true
$config.Output.Verbosity = 'Detailed'
if ($CI) {
    $config.TestResult.Enabled = $true
    $config.TestResult.OutputPath = Join-Path $PSScriptRoot 'testResults.xml'
}

Invoke-Pester -Configuration $config
