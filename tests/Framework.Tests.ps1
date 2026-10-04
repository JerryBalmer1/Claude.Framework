#Requires -Version 7.4
# Fixtures are local bare repos and fixture children under .framework/test-runs/<stamp>/ (gitignored, inside the
# repo), or under $env:FRAMEWORK_FIXTURE_ROOT when the Test task runs this suite. No network. Old run folders are
# pruned by New-FrameworkRunFolder, the one deletion CLAUDE.md allows.

BeforeDiscovery {
    # The -ForEach data below reads the manifest at discovery time.
    Import-Module (Join-Path (Split-Path $PSScriptRoot -Parent) 'build' 'Framework.Build.psm1') -Force
}

BeforeAll {
    $FrameworkRoot = Split-Path $PSScriptRoot -Parent
    Import-Module (Join-Path $FrameworkRoot 'build' 'Framework.Build.psm1') -Force

    $RunRoot = if ($env:FRAMEWORK_FIXTURE_ROOT) {
        (New-Item -ItemType Directory -Path $env:FRAMEWORK_FIXTURE_ROOT -Force).FullName
    }
    else { (New-FrameworkRunFolder -Root (Join-Path $FrameworkRoot '.framework' 'test-runs')).Path }

    function G { param([string]$Path) $out = & git -C $Path -c user.name=fixture -c user.email=fixture@example.invalid -c commit.gpgsign=false @args 2>&1; if ($LASTEXITCODE) { throw "git $args : $out" }; $out }

    # A bare repo whose main has one commit per entry in $Files. Returns the bare path.
    function New-BareRepo {
        param([string]$Name, [string[]]$Files = @('README.md'))
        $bare = Join-Path $RunRoot 'remotes' "$Name.git"
        $work = Join-Path $RunRoot 'work' $Name
        $null = New-Item -ItemType Directory -Path $bare, $work -Force
        G $bare init --quiet --bare --initial-branch=main | Out-Null
        G $work init --quiet --initial-branch=main | Out-Null
        foreach ($f in $Files) {
            Set-Content -LiteralPath (Join-Path $work $f) -Value "$Name $f"
            G $work add -- $f | Out-Null
            G $work commit --quiet -m "add $f" | Out-Null
        }
        G $work remote add origin $bare | Out-Null
        G $work push --quiet origin main | Out-Null
        $bare
    }

    function Add-RemoteCommit {
        param([string]$Name, [string]$File)
        $work = Join-Path $RunRoot 'work' $Name
        Set-Content -LiteralPath (Join-Path $work $File) -Value $File
        G $work add -- $File | Out-Null
        G $work commit --quiet -m "add $File" | Out-Null
        G $work push --quiet origin main | Out-Null
    }

    function New-Child { param([string]$Name, [string]$Url) [pscustomobject]@{ Name = $Name; Url = $Url; DefaultBranch = 'main'; BuildScript = $false } }

    function Get-Head { param([string]$Path) (& git -C $Path rev-parse HEAD) }
    function Get-Root { param([string]$Path) (& git -C $Path rev-list --max-parents=0 HEAD) }
}

Describe 'framework.yaml' {
    BeforeAll {
        $manifest = Get-FrameworkManifest (Join-Path $FrameworkRoot 'framework.yaml')
        $readme = Get-Content (Join-Path $FrameworkRoot 'README.md') -Raw
        $readmeNames = [regex]::Matches($readme, '\[(Claude\.[A-Za-z.]+)\]\(https://github\.com/JerryBalmer1/') | ForEach-Object { $_.Groups[1].Value }
    }

    It 'parses and lists the seven children named in README.md' {
        $manifest.Children.Count | Should -Be 7
        @($manifest.Children.Name | Sort-Object) | Should -Be @($readmeNames | Sort-Object)
    }

    It 'does not list the Claude.Ontology.Old archive' {
        $manifest.Children.Name | Should -Not -Contain 'Claude.Ontology.Old'
    }

    It '<Name> has url, default branch and build_script' -ForEach @(
        (Get-FrameworkManifest (Join-Path (Split-Path $PSScriptRoot -Parent) 'framework.yaml')).Children | ForEach-Object { @{ Name = $_.Name; Child = $_ } }
    ) {
        $Child.Url | Should -Be "https://github.com/JerryBalmer1/$Name.git"
        $Child.DefaultBranch | Should -Not -BeNullOrEmpty
        $Child.BuildScript | Should -BeOfType [bool]
    }

    It 'pins a Pester version' {
        { [version]$manifest.Requirements.pester } | Should -Not -Throw
    }

    It 'rejects an entry with a missing field' {
        $bad = Join-Path $RunRoot 'bad.yaml'
        Set-Content -LiteralPath $bad -Value "children:`n  - name: X`n    url: https://example.invalid/x.git`n    build_script: false"
        { Get-FrameworkManifest $bad } | Should -Throw '*default_branch*'
    }

    It 'reads the expect and verify blocks' {
        $by = @{}; $manifest.Children | ForEach-Object { $by[$_.Name] = $_ }
        $by['Claude.Portal'].Expect.TasksBeforeTest | Should -Be @('Install')
        $by['Claude.Ontology'].Expect.ExpectedFailures | Should -Be 16
        $by['Claude.Ontology'].Expect.Reason | Should -Not -BeNullOrEmpty
        $by['Claude.Ontology'].Verify.Script | Should -Be 'forge/tools/Invoke-PluginVerify.ps1'
        $by['Claude.Skills'].Expect.NoTests | Should -BeTrue
        $by['Claude.Chain'].Expect.ExpectedFailures | Should -Be 0
        $by['Claude.Chain'].Verify | Should -BeNullOrEmpty
    }

    It 'rejects expected_failures without a reason' {
        $bad = Join-Path $RunRoot 'bad-expect.yaml'
        Set-Content -LiteralPath $bad -Value "children:`n  - name: X`n    url: u`n    default_branch: main`n    build_script: true`n    expect:`n      expected_failures: 2"
        { Get-FrameworkManifest $bad } | Should -Throw '*reason*'
    }
}

Describe 'Test runs each child in its own process' {
    BeforeAll {
        $pester = [string](Get-FrameworkManifest (Join-Path $FrameworkRoot 'framework.yaml')).Requirements.pester
        $childRepos = Join-Path $RunRoot 'children'
        $child = Join-Path $childRepos 'Fixture'
        $null = New-Item -ItemType Directory -Path (Join-Path $child 'tests') -Force
        G $child init --quiet --initial-branch=main | Out-Null
        Set-Content -LiteralPath (Join-Path $child 'FixtureChild.psm1') -Value 'function Get-FixtureChild { $PID }'
        Set-Content -LiteralPath (Join-Path $child 'Fixture.build.ps1') -Value @'
Import-Module (Join-Path $BuildRoot 'FixtureChild.psm1')
task Before { Set-Content -LiteralPath (Join-Path $BuildRoot 'before.txt') -Value 'ran' }
task Test {
    Set-Content -LiteralPath (Join-Path $BuildRoot 'proof.txt') -Value "$PID|$((Get-Location).Path)|$([bool](Get-Module FixtureChild))"
    $config = New-PesterConfiguration
    $config.Run.Path = Join-Path $BuildRoot 'tests'
    $config.Run.PassThru = $true
    $r = Invoke-Pester -Configuration $config
    if ($r.FailedCount) { throw "$($r.FailedCount) failed" }
}
'@
        Set-Content -LiteralPath (Join-Path $child 'tests' 'Fixture.Tests.ps1') -Value @'
Describe 'fixture' {
    It 'passes one' { 1 | Should -Be 1 }
    It 'passes two' { 2 | Should -Be 2 }
    It 'fails' { 1 | Should -Be 2 }
    It 'skips' -Skip { }
}
'@
    }

    It 'runs Test in a fresh pwsh in the child folder and leaves no child module in this session' {
        $out = Join-Path $RunRoot 'child-out'
        $null = New-Item -ItemType Directory -Path $out -Force
        $junit = Join-Path $out 'Fixture.junit.xml'
        $exit = Invoke-ChildTask -Path $child -Task Test -LogFile (Join-Path $out 'Fixture.log') -ResultFile $junit -PesterVersion $pester

        $exit | Should -Not -Be 0
        $proofPid, $proofCwd, $loaded = (Get-Content -LiteralPath (Join-Path $child 'proof.txt')) -split '\|'
        [int]$proofPid | Should -Not -Be $PID
        $proofCwd | Should -Be (Resolve-Path $child).Path
        $loaded | Should -Be 'True'
        Get-Module FixtureChild | Should -BeNullOrEmpty
        $junit | Should -Exist
    }

    It 'runs tasks_before_test, reads JUnit and applies the expectation' {
        $yaml = Join-Path $RunRoot 'fixture.yaml'
        Set-Content -LiteralPath $yaml -Value @"
requirements:
  pester: '$pester'
children:
  - name: Fixture
    url: https://example.invalid/fixture.git
    default_branch: main
    build_script: true
    expect:
      tasks_before_test: [Before]
      expected_failures: 1
      reason: the fixture fails one test on purpose
"@
        $root = Join-Path $RunRoot 'framework-root'
        $rows = @(Invoke-FrameworkTest -Manifest (Get-FrameworkManifest $yaml) -ReposRoot $childRepos -FrameworkRoot $root -Only Fixture)

        $rows.Count | Should -Be 1
        $rows[0].Result | Should -Be 'pass-with-known'
        $rows[0].Passed, $rows[0].Failed, $rows[0].Skipped | Should -Be @(2, 1, 1)
        $rows[0].Verify | Should -Be 'not applicable'
        Join-Path $child 'before.txt' | Should -Exist
        $run = @(Get-ChildItem (Join-Path $root '.framework' 'test-runs') -Directory)
        $run.Count | Should -Be 1
        Join-Path $run[0].FullName 'Fixture.junit.xml' | Should -Exist
        Join-Path $run[0].FullName 'Fixture.Before.log' | Should -Exist
        Get-Module FixtureChild | Should -BeNullOrEmpty
    }
}

Describe 'expected-failures arithmetic' {
    BeforeAll {
        function E { param([int]$Fail = 0, [switch]$NoTests) [pscustomobject]@{ TasksBeforeTest = @(); ExpectedFailures = $Fail; NoTests = [bool]$NoTests; Reason = 'r' } }
        function C { param([int]$Total, [int]$Failed, [int]$Skipped = 0) [pscustomobject]@{ Total = $Total; Failed = $Failed; Skipped = $Skipped } }
    }

    It '<Case>' -ForEach @(
        @{ Case = 'all pass, none expected -> pass'; Exit = 0; Total = 10; Failed = 0; Expected = 0; Want = 'pass' }
        @{ Case = 'one failure, none expected -> FAIL'; Exit = 1; Total = 10; Failed = 1; Expected = 0; Want = 'FAIL' }
        @{ Case = 'failures equal expected -> pass-with-known'; Exit = 1; Total = 578; Failed = 16; Expected = 16; Want = 'pass-with-known' }
        @{ Case = 'failures below expected -> pass-with-known'; Exit = 1; Total = 578; Failed = 15; Expected = 16; Want = 'pass-with-known' }
        @{ Case = 'failures above expected -> FAIL'; Exit = 1; Total = 578; Failed = 17; Expected = 16; Want = 'FAIL' }
        @{ Case = 'expected failures, all pass -> pass'; Exit = 0; Total = 578; Failed = 0; Expected = 16; Want = 'pass' }
        @{ Case = 'no failures but task failed -> FAIL'; Exit = 1; Total = 10; Failed = 0; Expected = 0; Want = 'FAIL' }
    ) {
        (Get-TestVerdict -ExitCode $Exit -Counts (C $Total $Failed) -Expect (E $Expected)).Result | Should -Be $Want
    }

    It 'no JUnit file is FAIL' {
        (Get-TestVerdict -ExitCode 1 -Counts $null -Expect (E)).Result | Should -Be 'FAIL'
    }

    It 'no_tests with no test files is reported as no-tests, even though Pester exits non-zero' {
        $v = Get-TestVerdict -ExitCode 1 -Counts $null -Expect (E -NoTests) -TestFileCount 0
        $v.Result | Should -Be 'no-tests'
        $v.Note | Should -Match 'r'
    }

    It 'no_tests with test files present is judged normally and says the expectation is stale' {
        $v = Get-TestVerdict -ExitCode 1 -Counts (C 3 1) -Expect (E -NoTests) -TestFileCount 2
        $v.Result | Should -Be 'FAIL'
        $v.Note | Should -Match 'stale'
    }
}

Describe 'Bootstrap gate' {
    It 'runs once, skips while the marker exists, and runs again with -Force' {
        $state = Join-Path $RunRoot 'bootstrap-state'
        $script = Join-Path $RunRoot 'bootstrap-fixture.ps1'
        Set-Content -LiteralPath $script -Value 'param($StateRoot) Add-Content -LiteralPath (Join-Path $StateRoot "count.txt") -Value x'
        $count = { @(Get-Content -LiteralPath (Join-Path $state 'count.txt')).Count }

        (Invoke-FrameworkBootstrap -StateRoot $state -Script $script).Action | Should -Be 'ran'
        Join-Path $state 'bootstrap.done' | Should -Exist
        & $count | Should -Be 1

        (Invoke-FrameworkBootstrap -StateRoot $state -Script $script).Action | Should -Be 'skipped'
        & $count | Should -Be 1

        (Invoke-FrameworkBootstrap -StateRoot $state -Script $script -Force).Action | Should -Be 'ran (-Force)'
        & $count | Should -Be 2
    }

    It 'writes no marker when the script fails' {
        $state = Join-Path $RunRoot 'bootstrap-fail'
        $script = Join-Path $RunRoot 'bootstrap-throws.ps1'
        Set-Content -LiteralPath $script -Value 'param($StateRoot) throw "boom"'
        { Invoke-FrameworkBootstrap -StateRoot $state -Script $script } | Should -Throw '*boom*'
        Join-Path $state 'bootstrap.done' | Should -Not -Exist
    }

    It 'the real placeholder records that it ran' {
        $state = Join-Path $RunRoot 'bootstrap-real'
        Invoke-FrameworkBootstrap -StateRoot $state -Script (Join-Path $FrameworkRoot 'build' 'Bootstrap.ps1') | Out-Null
        Get-Content -LiteralPath (Join-Path $state 'bootstrap.log') | Should -Match 'bootstrap placeholder ran'
    }
}

Describe 'test-runs retention' {
    It 'keeps the newest run folders, the new one included, and leaves other names alone' {
        $root = Join-Path $RunRoot 'retention'
        $old = '20200101-000000-001', '20200101-000000-002', '20200101-000000-003', '20200101-000000-004',
            '20200101-000000-005', '20200101-000000-006', '20200101-000000-007'
        foreach ($n in $old + 'not-a-run') { $null = New-Item -ItemType Directory -Path (Join-Path $root $n) -Force }
        Set-Content -LiteralPath (Join-Path $root '20200101-000000-001' 'f.txt') -Value x

        $r = New-FrameworkRunFolder -Root $root -Keep 5
        $r.Pruned | Sort-Object | Should -Be @('20200101-000000-001', '20200101-000000-002', '20200101-000000-003')
        $left = @(Get-ChildItem -LiteralPath $root -Directory).Name | Sort-Object
        $left | Should -Contain 'not-a-run'
        $left | Should -Contain (Split-Path $r.Path -Leaf)
        @($left | Where-Object { $_ -match '^\d{8}-\d{6}-\d{3}$' }).Count | Should -Be 5
    }

    It 'refuses to keep fewer than one' {
        { New-FrameworkRunFolder -Root (Join-Path $RunRoot 'retention0') -Keep 0 } | Should -Throw
    }
}

Describe 'Sync' {
    BeforeAll {
        $repos = Join-Path $RunRoot 'repos'
        $null = New-Item -ItemType Directory -Path $repos -Force
    }

    It 'clones when the folder is absent, and a second run changes nothing' {
        $child = New-Child 'Absent' (New-BareRepo 'Absent')
        (Sync-FrameworkChild -Child $child -ReposRoot $repos).Action | Should -Be 'cloned'
        $head = Get-Head (Join-Path $repos 'Absent')

        (Sync-FrameworkChild -Child $child -ReposRoot $repos).Action | Should -Be 'up-to-date'
        Get-Head (Join-Path $repos 'Absent') | Should -Be $head
        Join-Path $repos '_aside' | Should -Not -Exist
    }

    It 'is idempotent across a whole manifest' {
        $manifest = [pscustomobject]@{ Children = @(
                (New-Child 'IdemA' (New-BareRepo 'IdemA')),
                (New-Child 'IdemB' (New-BareRepo 'IdemB'))) }
        $idemRoot = Join-Path $RunRoot 'repos-idem'
        $first = @(Sync-Framework -Manifest $manifest -ReposRoot $idemRoot)
        $first.Action | Should -Be @('cloned', 'cloned')
        $heads = $manifest.Children | ForEach-Object { Get-Head (Join-Path $idemRoot $_.Name) }

        $second = @(Sync-Framework -Manifest $manifest -ReposRoot $idemRoot)
        $second.Action | Should -Be @('up-to-date', 'up-to-date')
        $manifest.Children | ForEach-Object { Get-Head (Join-Path $idemRoot $_.Name) } | Should -Be $heads
        @(Get-ChildItem $idemRoot -Force).Name | Sort-Object | Should -Be @('IdemA', 'IdemB')
    }

    It 'clones into an existing empty folder' {
        $child = New-Child 'Empty' (New-BareRepo 'Empty')
        $null = New-Item -ItemType Directory -Path (Join-Path $repos 'Empty')
        (Sync-FrameworkChild -Child $child -ReposRoot $repos).Action | Should -Be 'cloned'
        Join-Path $repos 'Empty' '.git' | Should -Exist
        Join-Path $repos 'Empty' 'README.md' | Should -Exist
    }

    It 'moves files without .git aside, then clones' {
        $child = New-Child 'Loose' (New-BareRepo 'Loose')
        $loose = Join-Path $repos 'Loose'
        $null = New-Item -ItemType Directory -Path $loose
        Set-Content -LiteralPath (Join-Path $loose 'mine.txt') -Value 'local work'

        $r = Sync-FrameworkChild -Child $child -ReposRoot $repos
        $r.Action | Should -Be 'aside+cloned'
        Join-Path $loose '.git' | Should -Exist
        Join-Path $loose 'mine.txt' | Should -Not -Exist
        $aside = @(Get-ChildItem (Join-Path $repos '_aside') -Directory -Filter 'Loose-*')
        $aside.Count | Should -Be 1
        $aside[0].Name | Should -Match '^Loose-\d{12}$'
        Get-Content (Join-Path $aside[0].FullName 'mine.txt') | Should -Be 'local work'
    }

    It 'moves an unrelated-history clone aside and reclones (the rename case)' {
        $bare = New-BareRepo 'Renamed' -Files 'old.md'
        $child = New-Child 'Renamed' $bare
        (Sync-FrameworkChild -Child $child -ReposRoot $repos).Action | Should -Be 'cloned'
        $local = Join-Path $repos 'Renamed'
        $oldRoot = Get-Root $local

        # Replace the remote's main with a history that shares no commit.
        $other = New-BareRepo 'RenamedNew' -Files 'new.md'
        $otherWork = Join-Path $RunRoot 'work' 'RenamedNew'
        G $otherWork push --quiet --force $bare main | Out-Null

        $r = Sync-FrameworkChild -Child $child -ReposRoot $repos
        $r.Action | Should -Be 'aside+cloned'
        Get-Root $local | Should -Not -Be $oldRoot
        Join-Path $local 'new.md' | Should -Exist
        $aside = @(Get-ChildItem (Join-Path $repos '_aside') -Directory -Filter 'Renamed-*')
        $aside.Count | Should -Be 1
        Get-Root $aside[0].FullName | Should -Be $oldRoot
    }

    It 'fast-forwards when behind' {
        $child = New-Child 'Behind' (New-BareRepo 'Behind')
        Sync-FrameworkChild -Child $child -ReposRoot $repos | Out-Null
        Add-RemoteCommit 'Behind' 'two.md'
        $r = Sync-FrameworkChild -Child $child -ReposRoot $repos
        $r.Action | Should -Be 'fast-forwarded'
        Join-Path $repos 'Behind' 'two.md' | Should -Exist
    }

    It 'reports and leaves alone a dirty tree' {
        $child = New-Child 'Dirty' (New-BareRepo 'Dirty')
        Sync-FrameworkChild -Child $child -ReposRoot $repos | Out-Null
        Add-RemoteCommit 'Dirty' 'two.md'
        $local = Join-Path $repos 'Dirty'
        Add-Content -LiteralPath (Join-Path $local 'README.md') -Value 'edit'
        $head = Get-Head $local

        $r = Sync-FrameworkChild -Child $child -ReposRoot $repos
        $r.Action | Should -Be 'skipped'
        $r.Detail | Should -Match 'dirty'
        Get-Head $local | Should -Be $head
        (Get-Content (Join-Path $local 'README.md'))[-1] | Should -Be 'edit'
    }

    It 'reports and leaves alone a branch ahead of its upstream, even after the remote history is replaced' {
        $bare = New-BareRepo 'Ahead'
        $child = New-Child 'Ahead' $bare
        Sync-FrameworkChild -Child $child -ReposRoot $repos | Out-Null
        $local = Join-Path $repos 'Ahead'
        Set-Content -LiteralPath (Join-Path $local 'local.md') -Value 'x'
        G $local add -- local.md | Out-Null
        G $local commit --quiet -m local | Out-Null
        $head = Get-Head $local

        $null = New-BareRepo 'AheadNew' -Files 'new.md'
        G (Join-Path $RunRoot 'work' 'AheadNew') push --quiet --force $bare main | Out-Null

        $r = Sync-FrameworkChild -Child $child -ReposRoot $repos
        $r.Action | Should -Be 'skipped'
        $r.Detail | Should -Match 'ahead'
        Get-Head $local | Should -Be $head
    }
}

Describe 'build/ boundaries' {
    BeforeAll {
        $files = @(Get-ChildItem (Join-Path $FrameworkRoot 'build') -Recurse -Include *.ps1, *.psm1 -File)
        $files += Get-Item (Join-Path $FrameworkRoot 'Claude.Framework.build.ps1')
        $commands = foreach ($f in $files) {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$null, [ref]$null)
            $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.CommandAst] }, $true) |
                ForEach-Object { [pscustomobject]@{ File = $f.Name; Name = $_.GetCommandName(); Text = $_.Extent.Text } }
        }
    }

    It 'does not shell out to claude or docker' {
        $hits = $commands | Where-Object { $_.Name -match '^(claude|docker|docker-compose)(\.exe)?$' -or
            ($_.Name -in 'Start-Process', 'saps', 'start' -and $_.Text -match '\b(claude|docker)') }
        $hits | Should -BeNullOrEmpty
    }

    It 'never resets, and only merges fast-forward' {
        $all = ($files | ForEach-Object { Get-Content $_.FullName -Raw }) -join "`n"
        $all | Should -Not -Match 'reset\s+--hard'
        $merges = [regex]::Matches($all, '\bmerge\b[^\r\n]*') | ForEach-Object Value | Where-Object { $_ -match 'Invoke-Git|git ' }
        $merges | ForEach-Object { $_ | Should -Match '--ff-only' }
    }
}
