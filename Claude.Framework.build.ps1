#Requires -Version 7.4
<#
.SYNOPSIS
    Invoke-Build script for Claude.Framework.

.DESCRIPTION
    Requirements  checks git, PowerShell, Pester, powershell-yaml, Docker and Docker Compose; fails if any is missing.
    Sync          clones or fast-forwards every child in framework.yaml into repos/.
    Status        prints branch, ahead/behind, dirty count, last commit and build script per child.
    Test          runs each child's own Invoke-Build Test, then SelfTest; prints one table.
    SelfTest      runs Framework's own Pester suite under tests/.
#>
param(
    # Limit Test to these child names (and/or Claude.Framework).
    [string[]]$Only
)

Set-StrictMode -Version Latest

Import-Module (Join-Path $BuildRoot 'build' 'Framework.Build.psm1') -Force -ErrorAction Stop
$ManifestPath = Join-Path $BuildRoot 'framework.yaml'
$ReposRoot = Join-Path $BuildRoot 'repos'

task Requirements {
    $rows = Test-FrameworkRequirements -Manifest (Get-FrameworkManifest $ManifestPath)
    $rows | Format-Table -AutoSize | Out-String -Width 200
    $missing = @($rows | Where-Object { -not $_.Ok })
    if ($missing) { throw "Missing requirements: $($missing.Requirement -join ', ')" }
}

task Sync {
    $rows = @(Sync-Framework -Manifest (Get-FrameworkManifest $ManifestPath) -ReposRoot $ReposRoot)
    $rows | Format-Table -AutoSize -Wrap | Out-String -Width 200
    $errors = @($rows | Where-Object Action -eq 'error')
    if ($errors) { throw "Sync failed for: $($errors.Name -join ', ')" }
}

task Status {
    Get-FrameworkStatus -Manifest (Get-FrameworkManifest $ManifestPath) -ReposRoot $ReposRoot |
        Format-Table -AutoSize | Out-String -Width 200
}

task Test {
    $rows = @(Invoke-FrameworkTest -Manifest (Get-FrameworkManifest $ManifestPath) -ReposRoot $ReposRoot -FrameworkRoot $BuildRoot -Only $Only)
    $rows | Select-Object Name, Result, Passed, Failed, Skipped, Seconds | Format-Table -AutoSize | Out-String -Width 200
    $failed = @($rows | Where-Object Result -eq 'FAIL')
    if ($failed) { throw "Test failed for: $($failed.Name -join ', '). Logs: .framework/test-results/" }
}

task SelfTest {
    Import-Module Pester -MinimumVersion 5.5.0 -ErrorAction Stop
    $config = New-PesterConfiguration
    $config.Run.Path = Join-Path $BuildRoot 'tests'
    $config.Run.PassThru = $true
    $config.Output.Verbosity = 'Detailed'
    $result = Invoke-Pester -Configuration $config
    if ($result.FailedCount -gt 0 -or $result.Result -ne 'Passed') {
        throw "Pester: $($result.FailedCount) failed, result '$($result.Result)'."
    }
}

task . Requirements, Status
