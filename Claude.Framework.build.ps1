#Requires -Version 7.4
<#
.SYNOPSIS
    Invoke-Build script for Claude.Framework.

.DESCRIPTION
    Requirements  checks git, PowerShell, Pester, powershell-yaml, Docker, Docker Compose, CLAUDE_CHAIN_LEDGER and
                  Invoke-Build; reports each, fixes none, fails if any is not Ok.
    Bootstrap     runs build/Bootstrap.ps1 once; skipped while .framework/bootstrap.done exists, re-run with -Force.
    Sync          clones or fast-forwards every child in framework.yaml into repos/.
    Status        prints branch, ahead/behind, dirty count, last commit, build script and TestedAt per child.
                  TestedAt is the commit of the newest run record, with 'stale' when HEAD has moved since.
    Test          runs each child's test_task (default Test; full_test_task with -Full, where declared) in a fresh
                  pwsh in its folder (tasks_before_test first, verify after), then SelfTest the same way; prints
                  actual against the expect block in framework.yaml, with the commit tested (* when dirty).
                  -Only runs just the named children; the rest are listed as skipped (-Only).
                  Results go to .framework/test-runs/<stamp>/; the latest -KeepRuns run folders are kept.
    SelfTest      runs Framework's own Pester suite under tests/.
    Up            Requirements, Bootstrap, Sync, Test, Status; stops at the first failing task. Takes -Only and -Full.
#>
param(
    # Limit Test to these child names (and/or Claude.Framework). An unknown name fails before any child runs.
    [string[]]$Only,
    # Run each child's full_test_task where one is declared.
    [switch]$Full,
    # Run Bootstrap even when its marker exists.
    [switch]$Force,
    # How many run folders .framework/test-runs/ keeps.
    [int]$KeepRuns = 5
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

task Bootstrap {
    $r = Invoke-FrameworkBootstrap -StateRoot (Join-Path $BuildRoot '.framework') -Script (Join-Path $BuildRoot 'build' 'Bootstrap.ps1') -Force:$Force
    print Cyan "Bootstrap $($r.Action): $($r.Detail)"
}

task Sync {
    $rows = @(Sync-Framework -Manifest (Get-FrameworkManifest $ManifestPath) -ReposRoot $ReposRoot)
    $rows | Format-Table -AutoSize -Wrap | Out-String -Width 200
    $errors = @($rows | Where-Object Action -eq 'error')
    if ($errors) { throw "Sync failed for: $($errors.Name -join ', ')" }
}

task Status {
    Get-FrameworkStatus -Manifest (Get-FrameworkManifest $ManifestPath) -ReposRoot $ReposRoot -RunsRoot (Join-Path $BuildRoot '.framework' 'test-runs') |
        Format-Table -AutoSize | Out-String -Width 200
}

task Test {
    $rows = @(Invoke-FrameworkTest -Manifest (Get-FrameworkManifest $ManifestPath) -ReposRoot $ReposRoot -FrameworkRoot $BuildRoot -Only $Only -Full:$Full -KeepRuns $KeepRuns)
    $rows | Format-Table Name, Task, Result, Expected, Passed, Failed, Skipped, Verify, Commit, Seconds, Note -AutoSize -Wrap | Out-String -Width 250
    $failed = @($rows | Where-Object { $_.Result -eq 'FAIL' -or $_.Verify -eq 'does not' })
    if ($failed) { throw "Test failed for: $($failed.Name -join ', '). Logs: .framework/test-runs/" }
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

task Up Requirements, Bootstrap, Sync, Test, Status

task . Requirements, Status
