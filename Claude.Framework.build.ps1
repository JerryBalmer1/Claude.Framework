#Requires -Version 7.4
<#
.SYNOPSIS
    Invoke-Build script for Claude.Framework.

.DESCRIPTION
    Requirements  checks git, PowerShell, Pester, powershell-yaml, Docker, Docker Compose, each env entry in
                  framework.yaml and Invoke-Build; reports each, fails if any is not Ok. An env entry (such as
                  CLAUDE_CHAIN_LEDGER) is derived from the repo and set in this process for every child to inherit;
                  Note says what the shell had. Nothing is written to User or Machine scope. Each cloned child must be
                  on its branch in framework.yaml; a row for one on any other branch fails and names the branch.
    Bootstrap     runs build/Bootstrap.ps1 once; skipped while .framework/bootstrap.done exists, re-run with -Force.
                  Writes each env entry to User scope, the only place the build writes outside the repo.
    Sync          clones or fast-forwards every child in framework.yaml into repos/.
    Status        prints branch (with "(expected <x>)" when it differs from framework.yaml), ahead/behind, dirty count, last commit, build script and TestedAt per child.
                  TestedAt is the commit of the newest run record, with 'stale' when HEAD has moved since. Then how many
                  getters in the newest heartbeat ended ok, failed, refused and skipped, with Diff's call beside them
                  when that heartbeat has one, then one row per getter: its outcome and the verdict line from its
                  <Getter>.result.json (the note when it left none).
    Test          runs each child's test_task (default Test; full_test_task with -Full, where declared) in a fresh
                  pwsh in its folder (tasks_before_test first), then SelfTest the same way; prints actual against
                  the expect block in framework.yaml, with the commit tested (* when dirty). A child's verify is
                  not run here: its Verify column says heartbeat, unless -Verify runs it after the child's Test.
                  -Only runs just the named children; the rest are listed as skipped (-Only). A child not on its
                  expected branch is not run: its row is FAIL and names the branch.
                  Results go to .framework/test-runs/<stamp>/; the latest -KeepRuns run folders are kept, plus the
                  run the newest heartbeat reused; a folder without summary.json is logged to .framework/prune.log
                  before it is pruned. summary.json and each result.json carry env, and partial: true with -Only.
    SelfTest      runs Framework's own Pester suite under tests/.
    Up            Requirements, Bootstrap, Sync, Test, Status; stops at the first failing task. Takes -Only and -Full.
                  A child on a branch other than its expected one fails Requirements, so Up stops before Sync.
                  Verify is heartbeat-only unless -Verify.
    Heartbeat     Requirements, Sync, Test (never Verify), then Verify for every child that declares it, then each
                  getter in framework.yaml in its own fresh pwsh rooted in its path under repos/, its Pester when
                  tests: true, Diff last against the newest earlier heartbeat, then Status. Getters run after the getters
                  their needs: name, ties broken by order; a need naming no getter, or needs in a cycle, refuse the run
                  before Sync. Each getter ends ok, failed, refused (non-zero exit, last line beginning "refused", kept
                  as the reason) or skipped; one whose need failed or refused is skipped with "needs <x>". Each row
                  carries its needs, getter and graded commits, seconds and verdict line; a declared output missing
                  under {out} fails it. A failing getter does not stop the run; the task fails at the end if any getter
                  failed or refused, or any child Test or Verify failed.
                  -SkipUp skips Sync and Test and reuses the newest test run, refusing one that is partial (-Only) or
                  has no summary.json unless -AllowPartial, which stamps heartbeat.json partial with the untested
                  children. -Only names children and/or getters.
                  Results go to .framework/heartbeats/<stamp>/ with heartbeat.json; the latest -KeepRuns are kept.
#>
param(
    # Limit Test to these child names (and/or Claude.Framework). An unknown name fails before any child runs.
    [string[]]$Only,
    # Run each child's full_test_task where one is declared.
    [switch]$Full,
    # Test and Up: run each declared child verify now instead of leaving it to Heartbeat.
    [switch]$Verify,
    # Heartbeat: skip Sync and Test and reuse the newest test-runs folder.
    [switch]$SkipUp,
    # Heartbeat: reuse a newest test run that is partial or has no summary.json, and record it as partial.
    [switch]$AllowPartial,
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
    $rows = Test-FrameworkRequirements -Manifest (Get-FrameworkManifest $ManifestPath) -FrameworkRoot $BuildRoot -ReposRoot $ReposRoot
    $rows | Format-Table -AutoSize | Out-String -Width 200
    $missing = @($rows | Where-Object { -not $_.Ok })
    if ($missing) { throw "Missing requirements: $(@($missing | ForEach-Object { if ($_.Note) { "$($_.Requirement) ($($_.Note))" } else { $_.Requirement } }) -join ', ')" }
}

task Bootstrap {
    $values = [ordered]@{}
    Resolve-FrameworkEnv -Manifest (Get-FrameworkManifest $ManifestPath) -FrameworkRoot $BuildRoot -ReposRoot $ReposRoot | ForEach-Object { $values[$_.Name] = $_.Value }
    $r = Invoke-FrameworkBootstrap -StateRoot (Join-Path $BuildRoot '.framework') -Script (Join-Path $BuildRoot 'build' 'Bootstrap.ps1') -Environment $values -Force:$Force
    $r.Lines | ForEach-Object { print Cyan $_ }
    print Cyan "Bootstrap $($r.Action): $($r.Detail)"
}

$SyncJob = {
    $rows = @(Sync-Framework -Manifest (Get-FrameworkManifest $ManifestPath) -ReposRoot $ReposRoot)
    $rows | Format-Table -AutoSize -Wrap | Out-String -Width 200
    $errors = @($rows | Where-Object Action -eq 'error')
    if ($errors) { throw "Sync failed for: $($errors.Name -join ', ')" }
}

task Sync $SyncJob

task Status {
    Get-FrameworkStatus -Manifest (Get-FrameworkManifest $ManifestPath) -ReposRoot $ReposRoot -RunsRoot (Join-Path $BuildRoot '.framework' 'test-runs') |
        Format-Table -AutoSize | Out-String -Width 200
    Format-FrameworkGetterStatus (Join-Path $BuildRoot '.framework' 'heartbeats') | ForEach-Object { print Cyan $_ }
}

task Test {
    $rows = @(Invoke-FrameworkTest -Manifest (Get-FrameworkManifest $ManifestPath) -ReposRoot $ReposRoot -FrameworkRoot $BuildRoot -Only $Only -Full:$Full -Verify:$Verify -KeepRuns $KeepRuns)
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

# Heartbeat's failures, kept until Status has printed; the last job fails the task on any.
$HeartbeatFailures = @()

task Heartbeat Requirements, {
    # Refuses before Sync on a need naming no getter, or needs that form a cycle.
    $null = Get-FrameworkGetterOrder (Get-FrameworkManifest $ManifestPath).Getters
    if ($SkipUp) { print Cyan 'Sync and Test skipped (-SkipUp)' } else { . $SyncJob }
    $hb = Invoke-FrameworkHeartbeat -Manifest (Get-FrameworkManifest $ManifestPath) -ReposRoot $ReposRoot -FrameworkRoot $BuildRoot -Only $Only -Full:$Full -SkipUp:$SkipUp -AllowPartial:$AllowPartial -KeepRuns $KeepRuns
    print Cyan "Test run $($hb.TestRun.folder)$(if ($hb.TestRun.reused) { " (reused: $($hb.TestRun.reason))" })"
    if ($hb.Partial) { print Yellow "partial: true; untested: $(if ($hb.Untested) { $hb.Untested -join ', ' } else { 'none' })" }
    $hb.TestRows | Format-Table Name, Task, Result, Expected, Passed, Failed, Skipped, Verify, Commit, Seconds, Note -AutoSize -Wrap | Out-String -Width 250
    if ($hb.VerifyRows) { $hb.VerifyRows | Format-Table Name, Verify, Commit, Seconds, Note -AutoSize -Wrap | Out-String -Width 250 }
    $hb.Getters | Format-Table Name, Needs, Result, GetterCommit, GradedCommit, Passed, Failed, Seconds, Verdict, Note -AutoSize -Wrap | Out-String -Width 250
    if ($hb.Diff) { print Cyan "Diff: $($hb.Diff)" }
    print Cyan "Heartbeat record: $(Join-Path $hb.Folder 'heartbeat.json')"
    $script:HeartbeatFailures = @($hb.Failures)
}, Status, {
    if ($HeartbeatFailures) { throw "Heartbeat failed: $($HeartbeatFailures -join ', '). Record: .framework/heartbeats/" }
}

task . Requirements, Status
