#Requires -Version 7.4
# Fixtures are local bare repos and fixture children under .framework/fixtures/<stamp>/ (gitignored, inside the
# repo), or under $env:FRAMEWORK_FIXTURE_ROOT when the Test task runs this suite. No network. Nothing here writes
# to .framework/test-runs/ or .framework/heartbeats/, so a test run never takes a retention slot from a real run;
# every run and heartbeat folder a test makes is under a fixture root. Fixture folders are not pruned.

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
    else { (New-Item -ItemType Directory -Path (Join-Path $FrameworkRoot '.framework' 'fixtures' (Get-Date -Format 'yyyyMMdd-HHmmss-fff')) -Force).FullName }

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

    It 'reads result_file: parameter for Claude.Ontology, preference for the other build-script children' {
        $by = @{}; $manifest.Children | ForEach-Object { $by[$_.Name] = $_ }
        $by['Claude.Ontology'].ResultFile | Should -Be 'parameter'
        'Claude.Chain', 'Claude.Skills', 'Claude.Portal' | ForEach-Object { $by[$_].ResultFile | Should -Be 'preference' }
        $by['Claude.Root'].ResultFile | Should -BeNullOrEmpty
    }

    It 'reads test_task and full_test_task: Test and TestFull for Claude.Ontology, Test and none elsewhere' {
        $by = @{}; $manifest.Children | ForEach-Object { $by[$_.Name] = $_ }
        $by['Claude.Ontology'].Expect.TestTask | Should -Be 'Test'
        $by['Claude.Ontology'].Expect.FullTestTask | Should -Be 'TestFull'
        $by['Claude.Ontology'].Expect.ExpectedFailures | Should -Be 16
        $by['Claude.Ontology'].Expect.Reason | Should -Be 'contract tests need built graphs'
        $by['Claude.Chain'].Expect.TestTask | Should -Be 'Test'
        $by['Claude.Chain'].Expect.FullTestTask | Should -BeNullOrEmpty
    }

    It 'the Claude.Skills no-tests reason names no branch' {
        $skills = $manifest.Children | Where-Object Name -eq 'Claude.Skills'
        $skills.Expect.Reason | Should -Not -Match 'develop|main|feature/'
    }

    It 'rejects a build-script child without result_file, and an unknown result_file' {
        $bad = Join-Path $RunRoot 'bad-result.yaml'
        Set-Content -LiteralPath $bad -Value "children:`n  - name: X`n    url: u`n    default_branch: main`n    build_script: true"
        { Get-FrameworkManifest $bad } | Should -Throw '*result_file*'
        Set-Content -LiteralPath $bad -Value "children:`n  - name: X`n    url: u`n    default_branch: main`n    build_script: true`n    result_file: junit"
        { Get-FrameworkManifest $bad } | Should -Throw '*parameter, preference or none*'
    }

    It 'rejects expected_failures without a reason' {
        $bad = Join-Path $RunRoot 'bad-expect.yaml'
        Set-Content -LiteralPath $bad -Value "children:`n  - name: X`n    url: u`n    default_branch: main`n    build_script: true`n    expect:`n      expected_failures: 2"
        { Get-FrameworkManifest $bad } | Should -Throw '*reason*'
    }
}

Describe 'framework.yaml getters' {
    BeforeAll {
        $base = "children:`n  - name: X`n    url: u`n    default_branch: main`n    build_script: false`ngetters:`n"
        function Write-Getters { param([string]$Name, [string]$Body) $p = Join-Path $RunRoot "getters-$Name.yaml"; Set-Content -LiteralPath $p -Value ($base + $Body); $p }
        $ok = "  - name: A`n    path: getters/A`n    entry:`n      script: tools/Run.ps1`n    cadence: every`n    order: 1"
    }

    It 'registers the six getters as entry: none, no path, not promoted yet, Diff last' {
        $g = (Get-FrameworkManifest (Join-Path $FrameworkRoot 'framework.yaml')).Getters
        $g.Name | Should -Be @('Catalogue', 'Hardening', 'Incidents', 'Shape', 'Secrets', 'Diff')
        foreach ($x in $g) {
            $x.Entry | Should -BeNullOrEmpty
            $x.Path | Should -BeNullOrEmpty
            $x.Note | Should -Be 'not promoted to repos/ yet'
        }
    }

    It 'reads a runnable getter' {
        $g = (Get-FrameworkManifest (Write-Getters 'ok' $ok)).Getters
        $g.Count | Should -Be 1
        $g[0].Entry.Script | Should -Be 'tools/Run.ps1'
        $g[0].Path | Should -Be 'getters/A'
        $g[0].Tests | Should -BeFalse
    }

    It 'a getter missing <Field> fails to load' -ForEach @(
        @{ Field = 'name'; Body = "  - path: getters/A`n    entry: none`n    cadence: every`n    order: 1" }
        @{ Field = 'order'; Body = "  - name: A`n    entry: none`n    cadence: every" }
        @{ Field = 'cadence'; Body = "  - name: A`n    entry: none`n    order: 1" }
        @{ Field = 'path'; Body = "  - name: A`n    entry:`n      script: tools/Run.ps1`n    cadence: every`n    order: 1" }
    ) {
        { Get-FrameworkManifest (Write-Getters "missing-$Field" $Body) } | Should -Throw "*missing '$Field'*"
    }

    It 'a path outside repos/ fails to load' {
        $body = "  - name: A`n    path: C:\elsewhere\A`n    entry:`n      script: tools/Run.ps1`n    cadence: every`n    order: 1"
        { Get-FrameworkManifest (Write-Getters 'rooted' $body) } | Should -Throw '*under it*'
        $body = "  - name: A`n    path: ../A`n    entry:`n      script: tools/Run.ps1`n    cadence: every`n    order: 1"
        { Get-FrameworkManifest (Write-Getters 'climb' $body) } | Should -Throw '*under it*'
    }

    It 'two getters with the same order fail to load' {
        $body = "  - name: A`n    entry: none`n    cadence: every`n    order: 1`n  - name: B`n    entry: none`n    cadence: weekly`n    order: 1"
        { Get-FrameworkManifest (Write-Getters 'same-order' $body) } | Should -Throw '*share an order*'
    }

    It 'Diff not last fails to load' {
        $body = "  - name: Diff`n    entry: none`n    cadence: every`n    order: 5`n  - name: B`n    entry: none`n    cadence: every`n    order: 6"
        { Get-FrameworkManifest (Write-Getters 'diff-first' $body) } | Should -Throw '*Diff must be last*'
    }
}

Describe 'Heartbeat' {
    BeforeAll {
        $pester = [string](Get-FrameworkManifest (Join-Path $FrameworkRoot 'framework.yaml')).Requirements.pester
        function New-CommittedFolder {
            param([string]$Path, [hashtable]$Files)
            foreach ($k in $Files.Keys) {
                $file = Join-Path $Path $k
                $null = New-Item -ItemType Directory -Path (Split-Path $file) -Force
                Set-Content -LiteralPath $file -Value $Files[$k]
            }
            G $Path init --quiet --initial-branch=main | Out-Null
            G $Path add -A | Out-Null
            G $Path commit --quiet -m fixture | Out-Null
            (& git -C $Path rev-parse HEAD)
        }
        # A test run to reuse, the way Test leaves one: summary.json with partial, env and rows.
        function New-FakeTestRun {
            param([string]$Root, [string]$Stamp, [switch]$NoSummary, [switch]$Partial)
            $run = Join-Path $Root '.framework' 'test-runs' $Stamp
            $null = New-Item -ItemType Directory -Path $run -Force
            if (-not $NoSummary) {
                $self = if ($Partial) { 'skipped (-Only)' } else { 'pass' }
                Set-Content -LiteralPath (Join-Path $run 'summary.json') -Value (@{
                        partial = [bool]$Partial; only = @(if ($Partial) { 'Kid' }); env = @{}
                        rows = @(@{ Name = 'Kid'; Result = 'no build script'; Verify = 'not applicable' }, @{ Name = 'Claude.Framework'; Result = $self; Verify = 'not applicable' })
                    } | ConvertTo-Json -Depth 4)
            }
            $run
        }

        $hbRepos = Join-Path $RunRoot 'hb-repos'
        $goodHead = New-CommittedFolder (Join-Path $hbRepos 'getters' 'Good') @{
            'tools/Write-Out.ps1'  = 'param($Out) Set-Content -LiteralPath (Join-Path $Out "out.txt") -Value "good"; exit 0'
            'tests/Good.Tests.ps1' = "Describe 'good' { It 'passes' { 1 | Should -Be 1 } }"
        }
        $null = New-CommittedFolder (Join-Path $hbRepos 'getters' 'Bad') @{ 'tools/Fail.ps1' = 'param($Out) "bad getter ran"; exit 1' }
        $null = New-CommittedFolder (Join-Path $hbRepos 'getters' 'Diff') @{
            'tools/Compare.ps1' = 'param($Out, $Previous) $p = if ($Previous) { Split-Path $Previous -Leaf } else { "none" }; Set-Content -LiteralPath (Join-Path $Out "verdict.txt") -Value "previous: $p"'
        }
        $hbYaml = Join-Path $RunRoot 'fixture-heartbeat.yaml'
        Set-Content -LiteralPath $hbYaml -Value @"
requirements:
  pester: '$pester'
children:
  - name: Kid
    url: https://example.invalid/Kid.git
    default_branch: main
    build_script: false
getters:
  - name: Good
    path: getters/Good
    entry:
      script: tools/Write-Out.ps1
      parameters:
        Out: '{out}'
    tests: true
    cadence: every
    order: 1
  - name: Bad
    path: getters/Bad
    entry:
      script: tools/Fail.ps1
      parameters:
        Out: '{out}'
    cadence: every
    order: 2
  - name: Later
    entry: none
    cadence: every
    order: 3
    note: not promoted to repos/ yet
  - name: Diff
    path: getters/Diff
    entry:
      script: tools/Compare.ps1
      parameters:
        Out: '{out}'
        Previous: '{previous}'
    cadence: every
    order: 9
"@
        $hbManifest = Get-FrameworkManifest $hbYaml

        $hbFramework = Join-Path $RunRoot 'hb-framework'
        $gradedHead = New-CommittedFolder $hbFramework @{ 'README.md' = 'fixture framework'; '.gitignore' = '.framework/' }
        $reused = New-FakeTestRun $hbFramework '20260101-000000-001'

        $first = Invoke-FrameworkHeartbeat -Manifest $hbManifest -ReposRoot $hbRepos -FrameworkRoot $hbFramework -SkipUp
        $second = Invoke-FrameworkHeartbeat -Manifest $hbManifest -ReposRoot $hbRepos -FrameworkRoot $hbFramework -SkipUp
        $by = @{}; $first.Getters | ForEach-Object { $by[$_.Name] = $_ }
    }

    It 'the pass row and the fail row both appear, and the fail does not stop the run' {
        $first.Getters.Name | Should -Be @('Good', 'Bad', 'Later', 'Diff')
        $by['Good'].Result | Should -Be 'pass'
        $by['Bad'].Result | Should -Be 'fail'
        $by['Bad'].Note | Should -Match 'entry exit 1'
        $by['Diff'].Result | Should -Be 'pass'
        Join-Path $first.Folder 'Good' 'out.txt' | Should -Exist
        Get-Content (Join-Path $first.Folder 'Bad.log') | Should -Contain 'bad getter ran'
    }

    It 'a failing getter makes the heartbeat fail' {
        $first.Failures | Should -Be @('getter Bad')
        (Get-Content (Join-Path $first.Folder 'heartbeat.json') -Raw | ConvertFrom-Json).failures | Should -Be @('getter Bad')
    }

    It 'runs the getter''s Pester when tests: true, with JUnit under its folder' {
        $by['Good'].Passed, $by['Good'].Failed | Should -Be @(1, 0)
        Join-Path $first.Folder 'Good' 'Good.junit.xml' | Should -Exist
    }

    It 'result.json carries the getter commit, the graded commit, tested_at and the entry line' {
        $raw = Get-Content -LiteralPath (Join-Path $first.Folder 'Good.result.json') -Raw
        $rec = $raw | ConvertFrom-Json
        $rec.getter_commit | Should -Be $goodHead
        $rec.graded_commit | Should -Be $gradedHead
        $rec.getter_dirty | Should -BeFalse
        $rec.result | Should -Be 'pass'
        $raw | Should -Match '"tested_at":\s*"\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d[+-]\d\d:\d\d"'
        $rec.entry_line | Should -Be "& ./tools/Write-Out.ps1 -Out '$(Join-Path $first.Folder 'Good')'"
        $by['Good'].GetterCommit | Should -Be $goodHead.Substring(0, 7)
        $by['Good'].GradedCommit | Should -Be $gradedHead.Substring(0, 7)
    }

    It 'entry: none is listed as not runnable with its note' {
        $by['Later'].Result | Should -Be 'not runnable'
        $by['Later'].Note | Should -Be 'entry: none; not promoted to repos/ yet'
        Join-Path $first.Folder 'Later.log' | Should -Not -Exist
        Join-Path $first.Folder 'Later' | Should -Not -Exist
    }

    It 'entry: none spawns no pwsh' {
        Mock -ModuleName Framework.Build Invoke-ChildProcess { 0 }
        $r = Invoke-FrameworkHeartbeat -Manifest $hbManifest -ReposRoot $hbRepos -FrameworkRoot $hbFramework -Only Later
        ($r.Getters | Where-Object Name -eq 'Later').Result | Should -Be 'not runnable'
        @($r.Getters | Where-Object Name -ne 'Later').Result | Should -Be @('skipped', 'skipped', 'skipped')
        Should -Invoke -ModuleName Framework.Build Invoke-ChildProcess -Times 0 -Exactly
    }

    It '-SkipUp reuses the newest test run when it is whole, and the record says reused, not partial' {
        $first.TestRun.folder | Should -Be '20260101-000000-001'
        $first.TestRun.reused | Should -BeTrue
        $first.Partial | Should -BeFalse
        $rec = Get-Content (Join-Path $first.Folder 'heartbeat.json') -Raw | ConvertFrom-Json
        $rec.test_run.reused | Should -BeTrue
        $rec.test_run.reason | Should -Be '-SkipUp'
        $rec.test_run.folder | Should -Be '20260101-000000-001'
        $rec.reused_run | Should -Be '20260101-000000-001'
        $rec.partial | Should -BeFalse
        @($rec.untested).Count | Should -Be 0
        $rec.PSObject.Properties.Name | Should -Contain 'env'
        $rec.framework.commit | Should -Be $gradedHead
        $rec.children[0].name | Should -Be 'Kid'
        @(Get-ChildItem (Join-Path $hbFramework '.framework' 'test-runs') -Directory).Count | Should -Be 1
    }

    It '-SkipUp refuses a partial newest run, naming it, and leaves no heartbeat folder' {
        $root = Join-Path $RunRoot 'hb-partial'
        $null = New-FakeTestRun $root '20260101-000000-001'
        $null = New-FakeTestRun $root '20260101-000000-002' -Partial
        { Invoke-FrameworkHeartbeat -Manifest $hbManifest -ReposRoot $hbRepos -FrameworkRoot $root -SkipUp -Only Later } |
            Should -Throw '*20260101-000000-002*is partial*Invoke-Build Test, then Heartbeat -SkipUp*-AllowPartial*'
        Join-Path $root '.framework' 'heartbeats' | Should -Not -Exist
    }

    It '-SkipUp refuses a newest run with no summary.json, even when an older one has one' {
        $root = Join-Path $RunRoot 'hb-nosummary'
        $null = New-FakeTestRun $root '20260101-000000-001'
        $null = New-FakeTestRun $root '20260101-000000-002' -NoSummary
        { Invoke-FrameworkHeartbeat -Manifest $hbManifest -ReposRoot $hbRepos -FrameworkRoot $root -SkipUp -Only Later } |
            Should -Throw '*20260101-000000-002*has no summary.json*-AllowPartial*'
    }

    It '-SkipUp -AllowPartial reuses the partial run and stamps partial and untested' {
        $root = Join-Path $RunRoot 'hb-partial'
        $r = Invoke-FrameworkHeartbeat -Manifest $hbManifest -ReposRoot $hbRepos -FrameworkRoot $root -SkipUp -AllowPartial -Only Later
        $r.TestRun.folder | Should -Be '20260101-000000-002'
        $r.Partial | Should -BeTrue
        $r.Untested | Should -Be @('Claude.Framework')
        $rec = Get-Content (Join-Path $r.Folder 'heartbeat.json') -Raw | ConvertFrom-Json
        $rec.partial | Should -BeTrue
        @($rec.untested) | Should -Be @('Claude.Framework')
        $rec.reused_run | Should -Be '20260101-000000-002'
    }

    It 'Diff runs last against the previous heartbeat folder' {
        $first.Diff | Should -Be 'previous: none'
        $second.Diff | Should -Be "previous: $($first.Stamp)"
        (Get-Content (Join-Path $second.Folder 'heartbeat.json') -Raw | ConvertFrom-Json).diff | Should -Be "previous: $($first.Stamp)"
    }

    It 'keeps the newest 5 heartbeat folders' {
        $root = Join-Path $RunRoot 'hb-retention'
        $null = New-FakeTestRun $root '20260101-000000-001'
        foreach ($i in 1..6) { $null = New-Item -ItemType Directory -Path (Join-Path $root '.framework' 'heartbeats' "20200101-000000-00$i") -Force }
        $r = Invoke-FrameworkHeartbeat -Manifest $hbManifest -ReposRoot $hbRepos -FrameworkRoot $root -Only Later
        $left = @(Get-ChildItem (Join-Path $root '.framework' 'heartbeats') -Directory).Name | Sort-Object
        $left.Count | Should -Be 5
        $left | Should -Contain $r.Stamp
        $left | Should -Not -Contain '20200101-000000-002'
    }
}

Describe 'Verify moves to heartbeat cadence' {
    BeforeAll {
        $pester = [string](Get-FrameworkManifest (Join-Path $FrameworkRoot 'framework.yaml')).Requirements.pester
        $vRepos = Join-Path $RunRoot 'children-verify'
        $vChild = Join-Path $vRepos 'Verified'
        $null = New-Item -ItemType Directory -Path (Join-Path $vChild 'tests'), (Join-Path $vChild 'tools') -Force
        Set-Content -LiteralPath (Join-Path $vChild 'Verified.build.ps1') -Value @'
task Test {
    $config = New-PesterConfiguration
    $config.Run.Path = Join-Path $BuildRoot 'tests'
    $config.Run.PassThru = $true
    $r = Invoke-Pester -Configuration $config
    if ($r.FailedCount) { throw "$($r.FailedCount) failed" }
}
'@
        Set-Content -LiteralPath (Join-Path $vChild 'tests' 'Verified.Tests.ps1') -Value "Describe 'fixture' { It 'passes' { 1 | Should -Be 1 } }"
        Set-Content -LiteralPath (Join-Path $vChild 'tools' 'Verify.ps1') -Value 'param($Plugin) [pscustomobject]@{ Plugin = $Plugin; Reproduces = $true }'
        G $vChild init --quiet --initial-branch=main | Out-Null
        G $vChild add -A | Out-Null
        G $vChild commit --quiet -m fixture | Out-Null
        $vYaml = Join-Path $RunRoot 'fixture-verify.yaml'
        Set-Content -LiteralPath $vYaml -Value "requirements:`n  pester: '$pester'`nchildren:`n  - name: Verified`n    url: u`n    default_branch: main`n    build_script: true`n    result_file: preference`n    verify:`n      script: tools/Verify.ps1`n      plugins: [One]"
        $vManifest = Get-FrameworkManifest $vYaml
        function Get-NewestRecord { param([string]$Root) $run = @(Get-ChildItem (Join-Path $Root '.framework' 'test-runs') -Directory | Sort-Object Name -Descending)[0].FullName; Join-Path $run 'Verified.result.json' }
    }

    It 'the plan for Claude.Ontology says heartbeat without -Verify and run with it' {
        $manifest = Get-FrameworkManifest (Join-Path $FrameworkRoot 'framework.yaml')
        $plain = @{}; Get-FrameworkTestPlan -Manifest $manifest | ForEach-Object { $plain[$_.Name] = $_.Verify }
        $forced = @{}; Get-FrameworkTestPlan -Manifest $manifest -Verify | ForEach-Object { $forced[$_.Name] = $_.Verify }
        $plain['Claude.Ontology'] | Should -Be 'heartbeat'
        $forced['Claude.Ontology'] | Should -Be 'run'
        foreach ($n in 'Claude.Chain', 'Claude.Portal', 'Claude.Root', 'Claude.Framework') {
            $plain[$n] | Should -Be 'not applicable'
            $forced[$n] | Should -Be 'not applicable'
        }
    }

    It 'without -Verify the column says heartbeat and the record says verify: skipped' {
        $root = Join-Path $RunRoot 'framework-root-verify-skip'
        $row = @(Invoke-FrameworkTest -Manifest $vManifest -ReposRoot $vRepos -FrameworkRoot $root -Only Verified)[0]
        $row.Verify | Should -Be 'heartbeat'
        $rec = Get-Content -LiteralPath (Get-NewestRecord $root) -Raw | ConvertFrom-Json
        $rec.verify | Should -Be 'skipped'
        $rec.verify_outcome | Should -BeNullOrEmpty
    }

    It 'with -Verify it runs and the record says verify: ran with its outcome' {
        $root = Join-Path $RunRoot 'framework-root-verify-run'
        $row = @(Invoke-FrameworkTest -Manifest $vManifest -ReposRoot $vRepos -FrameworkRoot $root -Only Verified -Verify)[0]
        $row.Verify | Should -Be 'reproduces'
        $rec = Get-Content -LiteralPath (Get-NewestRecord $root) -Raw | ConvertFrom-Json
        $rec.verify | Should -Be 'ran'
        $rec.verify_outcome | Should -Be 'reproduces'
    }

    It 'Heartbeat runs the verify after Test and marks the child''s record ran, leaving tested_at as written' {
        $root = Join-Path $RunRoot 'framework-root-verify-skip'
        $file = Get-NewestRecord $root
        $before = [regex]::Match((Get-Content -LiteralPath $file -Raw), '"tested_at":\s*"[^"]+"').Value
        # The run reused was made with -Only, so it is partial and -SkipUp needs -AllowPartial to take it.
        $hb = Invoke-FrameworkHeartbeat -Manifest $vManifest -ReposRoot $vRepos -FrameworkRoot $root -SkipUp -AllowPartial
        $hb.Partial | Should -BeTrue
        $hb.Untested | Should -Be @('Claude.Framework')
        $hb.VerifyRows[0].Verify | Should -Be 'reproduces'
        $hb.Failures | Should -BeNullOrEmpty
        Join-Path $hb.Folder 'verify' 'Verified.verify-One.json' | Should -Exist
        $raw = Get-Content -LiteralPath $file -Raw
        $raw | Should -Match ([regex]::Escape($before))
        $rec = $raw | ConvertFrom-Json
        $rec.verify | Should -Be 'ran'
        $rec.verify_outcome | Should -Be 'reproduces'
        $rec.verify_by | Should -Be "heartbeat $($hb.Stamp)"
        (Get-Content (Join-Path $hb.Folder 'heartbeat.json') -Raw | ConvertFrom-Json).children[0].verify | Should -Be 'ran'
    }

    It 'Verify writes a result.json with task: none when the reused run has none for the child' {
        $root = Join-Path $RunRoot 'framework-root-verify-none'
        $run = Join-Path $root '.framework' 'test-runs' '20260101-000000-001'
        $null = New-Item -ItemType Directory -Path $run -Force
        Set-Content -LiteralPath (Join-Path $run 'summary.json') -Value (@{
                partial = $true; only = @('Claude.Framework'); env = @{}
                rows = @(@{ Name = 'Verified'; Result = 'skipped (-Only)'; Verify = 'not run' }, @{ Name = 'Claude.Framework'; Result = 'pass'; Verify = 'not applicable' })
            } | ConvertTo-Json -Depth 4)
        $hb = Invoke-FrameworkHeartbeat -Manifest $vManifest -ReposRoot $vRepos -FrameworkRoot $root -SkipUp -AllowPartial
        $hb.Untested | Should -Be @('Verified')
        $file = Join-Path $run 'Verified.result.json'
        $file | Should -Exist
        $rec = Get-Content -LiteralPath $file -Raw | ConvertFrom-Json
        $rec.task | Should -Be 'none'
        $rec.verify | Should -Be 'ran'
        $rec.verify_outcome | Should -Be 'reproduces'
        $rec.verify_by | Should -Be "heartbeat $($hb.Stamp)"
        $rec.commit | Should -Be (Get-Head $vChild)
        $rec.partial | Should -BeTrue
        $hb.VerifyRows[0].Note | Should -Match 'wrote one with task: none'
        # Status does not take a verify-only record as the tested commit.
        (Get-FrameworkStatus -Manifest $vManifest -ReposRoot $vRepos -RunsRoot (Join-Path $root '.framework' 'test-runs'))[0].TestedAt | Should -Be '-'
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
    result_file: preference
    expect:
      tasks_before_test: [Before]
      expected_failures: 1
      reason: the fixture fails one test on purpose
"@
        $root = Join-Path $RunRoot 'framework-root'
        $rows = @(Invoke-FrameworkTest -Manifest (Get-FrameworkManifest $yaml) -ReposRoot $childRepos -FrameworkRoot $root -Only Fixture | Where-Object Result -ne 'skipped (-Only)')

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

Describe 'Test gets a result file in the way result_file names' {
    BeforeAll {
        $pester = [string](Get-FrameworkManifest (Join-Path $FrameworkRoot 'framework.yaml')).Requirements.pester
        $childRepos = Join-Path $RunRoot 'children-modes'
        $tests = @'
Describe 'fixture' {
    It 'passes one' { 1 | Should -Be 1 }
    It 'passes two' { 2 | Should -Be 2 }
    It 'fails' { 1 | Should -Be 2 }
    It 'skips' -Skip { }
}
'@
        function New-FixtureChild {
            param([string]$Name, [string]$Build)
            $path = Join-Path $childRepos $Name
            $null = New-Item -ItemType Directory -Path (Join-Path $path 'tests') -Force
            G $path init --quiet --initial-branch=main | Out-Null
            Set-Content -LiteralPath (Join-Path $path "$Name.build.ps1") -Value $Build
            Set-Content -LiteralPath (Join-Path $path 'tests' "$Name.Tests.ps1") -Value $tests
            $path
        }

        # Like Claude.Ontology: takes -PesterConfiguration, refuses any key but TestResult, ignores $PesterPreference.
        $paramChild = New-FixtureChild 'ParamFixture' @'
param([hashtable]$PesterConfiguration = @{})
task Test {
    $pref = $null -ne (Get-Variable PesterPreference -Scope Global -ValueOnly -ErrorAction SilentlyContinue)
    $keys = @($PesterConfiguration.Keys) -join ','
    $sub = if ($PesterConfiguration['TestResult']) { @($PesterConfiguration.TestResult.Keys | Sort-Object) -join ',' }
    Set-Content -LiteralPath (Join-Path $BuildRoot 'received.txt') -Value "$keys|$sub|$pref"
    $foreign = @($PesterConfiguration.Keys | Where-Object { $_ -ne 'TestResult' })
    assert ($foreign.Count -eq 0) "PesterConfiguration may hold only TestResult, not: $($foreign -join ', ')."
    $config = New-PesterConfiguration -Hashtable $PesterConfiguration
    $config.Run.Path = Join-Path $BuildRoot 'tests'
    $config.Run.PassThru = $true
    $r = Invoke-Pester -Configuration $config
    if ($r.FailedCount) { throw "$($r.FailedCount) failed" }
}
'@
        $null = New-FixtureChild 'PrefFixture' @'
task Test {
    $config = New-PesterConfiguration
    $config.Run.Path = Join-Path $BuildRoot 'tests'
    $config.Run.PassThru = $true
    $r = Invoke-Pester -Configuration $config
    if ($r.FailedCount) { throw "$($r.FailedCount) failed" }
}
'@
        # Writes no result file whatever it is offered: TestResult forced off.
        $null = New-FixtureChild 'NoneFixture' @'
task Test {
    $config = New-PesterConfiguration
    $config.Run.Path = Join-Path $BuildRoot 'tests'
    $config.Run.PassThru = $true
    $config.TestResult.Enabled = $false
    $r = Invoke-Pester -Configuration $config
    if ($r.FailedCount) { throw "$($r.FailedCount) failed" }
}
'@
        $yaml = Join-Path $RunRoot 'fixture-modes.yaml'
        $entries = foreach ($m in @(@('ParamFixture', 'parameter'), @('PrefFixture', 'preference'), @('NoneFixture', 'none'))) {
            "  - name: $($m[0])`n    url: https://example.invalid/x.git`n    default_branch: main`n    build_script: true`n    result_file: $($m[1])`n    expect:`n      expected_failures: 1`n      reason: the fixture fails one test on purpose"
        }
        Set-Content -LiteralPath $yaml -Value ("requirements:`n  pester: '$pester'`nchildren:`n" + ($entries -join "`n"))
        $modesRoot = Join-Path $RunRoot 'framework-root-modes'
        $rows = @(Invoke-FrameworkTest -Manifest (Get-FrameworkManifest $yaml) -ReposRoot $childRepos -FrameworkRoot $modesRoot -Only ParamFixture, PrefFixture, NoneFixture | Where-Object Result -ne 'skipped (-Only)')
        $by = @{}; $rows | ForEach-Object { $by[$_.Name] = $_ }
        $run = @(Get-ChildItem (Join-Path $modesRoot '.framework' 'test-runs') -Directory)[0].FullName
    }

    It 'each of the three modes produces a row with counts' {
        $rows.Count | Should -Be 3
        foreach ($n in 'ParamFixture', 'PrefFixture', 'NoneFixture') {
            $by[$n].Result | Should -Be 'pass-with-known'
            $by[$n].Passed, $by[$n].Failed, $by[$n].Skipped | Should -Be @(2, 1, 1)
        }
    }

    It 'parameter: the build that refuses foreign keys receives only TestResult, and no $PesterPreference' {
        $keys, $sub, $pref = (Get-Content -LiteralPath (Join-Path $paramChild 'received.txt')) -split '\|'
        $keys | Should -Be 'TestResult'
        $sub | Should -Be 'Enabled,OutputFormat,OutputPath'
        $pref | Should -Be 'False'
        Join-Path $run 'ParamFixture.xml' | Should -Exist
        Join-Path $run 'ParamFixture.junit.xml' | Should -Not -Exist
        $by['ParamFixture'].Note | Should -Not -Match 'counts from output'
    }

    It 'preference: keeps the .junit.xml file name' {
        Join-Path $run 'PrefFixture.junit.xml' | Should -Exist
    }

    It 'none: counts come from the printed summary and the row says so' {
        Get-ChildItem -LiteralPath $run -Filter 'NoneFixture*.xml' | Should -BeNullOrEmpty
        $by['NoneFixture'].Note | Should -Match 'counts from output'
    }

    It 'a result file Pester left unfinished gives a row with counts from output, not an error' {
        # Pester's JUnit writer can stop mid-file (an 0x1B in a failure message); the fixture truncates it the same way.
        $null = New-FixtureChild 'TruncFixture' @'
param([hashtable]$PesterConfiguration = @{})
task Test {
    $config = New-PesterConfiguration -Hashtable $PesterConfiguration
    $config.Run.Path = Join-Path $BuildRoot 'tests'
    $config.Run.PassThru = $true
    $r = Invoke-Pester -Configuration $config
    $out = $config.TestResult.OutputPath.Value
    Set-Content -LiteralPath $out -Value ((Get-Content -LiteralPath $out -Raw).Substring(0, 400) + '<failure message="')
    if ($r.FailedCount) { throw "$($r.FailedCount) failed" }
}
'@
        $truncYaml = Join-Path $RunRoot 'fixture-trunc.yaml'
        Set-Content -LiteralPath $truncYaml -Value "requirements:`n  pester: '$pester'`nchildren:`n  - name: TruncFixture`n    url: u`n    default_branch: main`n    build_script: true`n    result_file: parameter`n    expect:`n      expected_failures: 1`n      reason: the fixture fails one test on purpose"
        $r = @(Invoke-FrameworkTest -Manifest (Get-FrameworkManifest $truncYaml) -ReposRoot $childRepos -FrameworkRoot (Join-Path $RunRoot 'framework-root-trunc') -Only TruncFixture | Where-Object Result -ne 'skipped (-Only)')
        $r.Count | Should -Be 1
        $r[0].Result | Should -Be 'pass-with-known'
        $r[0].Passed, $r[0].Failed, $r[0].Skipped | Should -Be @(2, 1, 1)
        $r[0].Note | Should -Match 'TruncFixture\.xml unreadable; counts from output'
    }
}

Describe 'Test -Only, the run record and Status TestedAt' {
    BeforeAll {
        $pester = [string](Get-FrameworkManifest (Join-Path $FrameworkRoot 'framework.yaml')).Requirements.pester
        $childRepos = Join-Path $RunRoot 'children-only'

        # A committed repo with a trivial build: one passing test, so a run takes seconds and needs no network.
        function New-CommittedChild {
            param([string]$Name)
            $path = Join-Path $childRepos $Name
            $null = New-Item -ItemType Directory -Path (Join-Path $path 'tests') -Force
            G $path init --quiet --initial-branch=main | Out-Null
            Set-Content -LiteralPath (Join-Path $path "$Name.build.ps1") -Value @'
task Test {
    $config = New-PesterConfiguration
    $config.Run.Path = Join-Path $BuildRoot 'tests'
    $config.Run.PassThru = $true
    $r = Invoke-Pester -Configuration $config
    if ($r.FailedCount) { throw "$($r.FailedCount) failed" }
}
'@
            Set-Content -LiteralPath (Join-Path $path 'tests' "$Name.Tests.ps1") -Value "Describe 'fixture' { It 'passes' { 1 | Should -Be 1 } }"
            G $path add -A | Out-Null
            G $path commit --quiet -m 'fixture' | Out-Null
            $path
        }
        $portal = New-CommittedChild 'Portal'
        $null = New-CommittedChild 'Other'

        $yaml = Join-Path $RunRoot 'fixture-only.yaml'
        $entries = foreach ($n in 'Portal', 'Other') { "  - name: $n`n    url: https://example.invalid/$n.git`n    default_branch: main`n    build_script: true`n    result_file: preference" }
        $entries += "  - name: Plain`n    url: https://example.invalid/Plain.git`n    default_branch: main`n    build_script: false"
        $envBlock = "env:`n  - name: FRAMEWORK_FIXTURE_LEDGER`n    value: '{repos_root}\ledger.jsonl'`n    wanted: file exists`n"
        Set-Content -LiteralPath $yaml -Value ("requirements:`n  pester: '$pester'`n" + $envBlock + "children:`n" + ($entries -join "`n"))
        $manifest = Get-FrameworkManifest $yaml

        $root = Join-Path $RunRoot 'framework-root-only'
        $runs = Join-Path $root '.framework' 'test-runs'
        $rows = @(Invoke-FrameworkTest -Manifest $manifest -ReposRoot $childRepos -FrameworkRoot $root -Only Portal)
        $by = @{}; $rows | ForEach-Object { $by[$_.Name] = $_ }
        $run = @(Get-ChildItem -LiteralPath $runs -Directory)[0].FullName
        $head = Get-Head $portal
    }

    It '-Only Portal runs one child and lists the rest as skipped (-Only)' {
        $rows.Name | Should -Be @('Portal', 'Other', 'Plain', 'Claude.Framework')
        $by['Portal'].Result | Should -Be 'pass'
        $by['Other'].Result | Should -Be 'skipped (-Only)'
        $by['Claude.Framework'].Result | Should -Be 'skipped (-Only)'
        $by['Plain'].Result | Should -Be 'no build script'
        Join-Path $run 'Portal.log' | Should -Exist
        Join-Path $run 'Other.log' | Should -Not -Exist
        Join-Path $run 'Other.result.json' | Should -Not -Exist
    }

    It '-Only Nope fails before running anything and lists the valid names' {
        $nopeRoot = Join-Path $RunRoot 'framework-root-nope'
        { Invoke-FrameworkTest -Manifest $manifest -ReposRoot $childRepos -FrameworkRoot $nopeRoot -Only Portal, Nope } |
            Should -Throw '*Nope*Valid names: Portal, Other, Plain, Claude.Framework*'
        Join-Path $nopeRoot '.framework' | Should -Not -Exist
    }

    It 'the run record carries commit, dirty, branch, tested_at and task' {
        $file = Join-Path $run 'Portal.result.json'
        $file | Should -Exist
        $raw = Get-Content -LiteralPath $file -Raw
        $rec = $raw | ConvertFrom-Json
        $rec.commit | Should -Be $head
        $rec.dirty | Should -BeFalse
        $rec.branch | Should -Be 'main'
        $rec.task | Should -Be 'Test'
        # ConvertFrom-Json turns the timestamp into a DateTime, so the offset is checked in the text.
        $raw | Should -Match '"tested_at":\s*"\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d[+-]\d\d:\d\d"'
        $rec.result | Should -Be 'pass'
        $rec.expected.failures | Should -Be 0
        $rec.actual.passed, $rec.actual.failed, $rec.actual.skipped | Should -Be @(1, 0, 0)
        $rec.verify | Should -Be 'not applicable'
        $by['Portal'].Commit | Should -Be $head.Substring(0, 7)
    }

    It 'result.json and summary.json carry env and partial; a -Only run is partial' {
        $ledger = Join-Path $childRepos 'ledger.jsonl'
        $rec = Get-Content -LiteralPath (Join-Path $run 'Portal.result.json') -Raw | ConvertFrom-Json
        $rec.env.FRAMEWORK_FIXTURE_LEDGER | Should -Be $ledger
        $rec.partial | Should -BeTrue
        $sum = Get-Content -LiteralPath (Join-Path $run 'summary.json') -Raw | ConvertFrom-Json
        $sum.partial | Should -BeTrue
        $sum.only | Should -Be @('Portal')
        $sum.env.FRAMEWORK_FIXTURE_LEDGER | Should -Be $ledger
        $sum.rows.Name | Should -Be @('Portal', 'Other', 'Plain', 'Claude.Framework')
        $env:FRAMEWORK_FIXTURE_LEDGER | Should -Be $ledger
    }

    It 'a run without -Only is not partial' {
        # Every child task is mocked, so Claude.Framework's SelfTest does not run this suite again.
        Mock -ModuleName Framework.Build Invoke-ChildTask { 0 }
        $wholeRoot = Join-Path $RunRoot 'framework-root-whole'
        $null = Invoke-FrameworkTest -Manifest $manifest -ReposRoot $childRepos -FrameworkRoot $wholeRoot
        $wholeRun = @(Get-ChildItem (Join-Path $wholeRoot '.framework' 'test-runs') -Directory)[0].FullName
        (Get-Content -LiteralPath (Join-Path $wholeRun 'summary.json') -Raw | ConvertFrom-Json).partial | Should -BeFalse
        (Get-Content -LiteralPath (Join-Path $wholeRun 'Portal.result.json') -Raw | ConvertFrom-Json).partial | Should -BeFalse
    }

    It 'a dirty child is recorded dirty and its Commit ends in *' {
        Set-Content -LiteralPath (Join-Path $portal 'untracked.txt') -Value x
        $again = @(Invoke-FrameworkTest -Manifest $manifest -ReposRoot $childRepos -FrameworkRoot $root -Only Portal)
        $again[0].Commit | Should -Be ($head.Substring(0, 7) + '*')
        $newest = @(Get-ChildItem -LiteralPath $runs -Directory | Sort-Object Name -Descending)[0].FullName
        (Get-Content -LiteralPath (Join-Path $newest 'Portal.result.json') -Raw | ConvertFrom-Json).dirty | Should -BeTrue
    }

    It 'Status shows the tested hash, then "stale" once HEAD moves, and "-" with no record' {
        $s = @{}; Get-FrameworkStatus -Manifest $manifest -ReposRoot $childRepos -RunsRoot $runs | ForEach-Object { $s[$_.Name] = $_ }
        $s['Portal'].TestedAt | Should -Be $head.Substring(0, 7)
        $s['Other'].TestedAt | Should -Be '-'

        Set-Content -LiteralPath (Join-Path $portal 'next.md') -Value x
        G $portal add -- next.md | Out-Null
        G $portal commit --quiet -m next | Out-Null
        $s = @{}; Get-FrameworkStatus -Manifest $manifest -ReposRoot $childRepos -RunsRoot $runs | ForEach-Object { $s[$_.Name] = $_ }
        $s['Portal'].TestedAt | Should -Be "$($head.Substring(0, 7)) stale"
        $s['Other'].TestedAt | Should -Be '-'
    }
}

Describe 'Test -Full plans full_test_task where declared' {
    It 'picks TestFull for Claude.Ontology with -Full, test_task elsewhere, and Test without -Full' {
        $manifest = Get-FrameworkManifest (Join-Path $FrameworkRoot 'framework.yaml')
        $plain = @{}; Get-FrameworkTestPlan -Manifest $manifest | ForEach-Object { $plain[$_.Name] = $_.Task }
        $full = @{}; Get-FrameworkTestPlan -Manifest $manifest -Full | ForEach-Object { $full[$_.Name] = $_.Task }

        $plain['Claude.Ontology'] | Should -Be 'Test'
        $full['Claude.Ontology'] | Should -Be 'TestFull'
        foreach ($n in 'Claude.Chain', 'Claude.Skills', 'Claude.Portal') {
            $plain[$n] | Should -Be 'Test'
            $full[$n] | Should -Be 'Test'
        }
        foreach ($n in 'Claude.Root', 'Claude.Substrate', 'Claude.Modules') { $full[$n] | Should -BeNullOrEmpty }
        $full['Claude.Framework'] | Should -Be 'SelfTest'
    }

    It 'uses a declared test_task when no full_test_task is declared' {
        $yaml = Join-Path $RunRoot 'fixture-plan.yaml'
        Set-Content -LiteralPath $yaml -Value "requirements: {}`nchildren:`n  - name: X`n    url: u`n    default_branch: main`n    build_script: true`n    result_file: none`n    expect:`n      test_task: Check"
        (Get-FrameworkTestPlan -Manifest (Get-FrameworkManifest $yaml) -Full)[0].Task | Should -Be 'Check'
    }
}

Describe 'Requirements: env entries and Invoke-Build' {
    BeforeAll {
        $manifest = Get-FrameworkManifest (Join-Path $FrameworkRoot 'framework.yaml')
        $savedLedger = $env:CLAUDE_CHAIN_LEDGER
        $savedUser = [Environment]::GetEnvironmentVariable('CLAUDE_CHAIN_LEDGER', 'User')
        # A fixture repos root holding Claude.Chain's ledger where the real manifest's env entry derives it.
        $reqRepos = Join-Path $RunRoot 'req-repos'
        $derived = Join-Path $reqRepos 'Claude.Chain' 'ledger' 'chain.jsonl'
        $null = New-Item -ItemType Directory -Path (Split-Path $derived) -Force
        Set-Content -LiteralPath $derived -Value '{}'
        function Get-Row {
            param([string]$Name, [string]$Repos = $reqRepos)
            Test-FrameworkRequirements -Manifest $manifest -FrameworkRoot $RunRoot -ReposRoot $Repos | Where-Object Requirement -eq $Name
        }
    }
    AfterAll { $env:CLAUDE_CHAIN_LEDGER = $savedLedger }

    It 'framework.yaml derives CLAUDE_CHAIN_LEDGER from repos_root' {
        $e = @($manifest.Env)
        $e.Count | Should -Be 1
        $e[0].Name | Should -Be 'CLAUDE_CHAIN_LEDGER'
        $e[0].Value | Should -Be '{repos_root}\Claude.Chain\ledger\chain.jsonl'
        $e[0].Wanted | Should -Be 'file exists'
    }

    It 'shell unset: sets the derived path in this process, Ok true, Note "shell unset"' {
        $env:CLAUDE_CHAIN_LEDGER = $null
        $r = Get-Row 'CLAUDE_CHAIN_LEDGER'
        $r.Wanted | Should -Be 'file exists'
        $r.Found | Should -Be $derived
        $r.Ok | Should -BeTrue
        $r.Note | Should -Be 'shell unset'
        $env:CLAUDE_CHAIN_LEDGER | Should -Be $derived
    }

    It 'shell wrong: Ok true, Note "shell had ...", and the derived path replaces it' {
        $dead = Join-Path $RunRoot 'dead' 'chain.jsonl'
        $env:CLAUDE_CHAIN_LEDGER = $dead
        $r = Get-Row 'CLAUDE_CHAIN_LEDGER'
        $r.Ok | Should -BeTrue
        $r.Note | Should -Be "shell had $dead"
        $env:CLAUDE_CHAIN_LEDGER | Should -Be $derived
    }

    It 'shell equal: Note blank' {
        $env:CLAUDE_CHAIN_LEDGER = $derived
        (Get-Row 'CLAUDE_CHAIN_LEDGER').Note | Should -Be ''
    }

    It 'derived file missing: Ok false' {
        $r = Get-Row 'CLAUDE_CHAIN_LEDGER' -Repos (Join-Path $RunRoot 'no-such-repos')
        $r.Found | Should -Be (Join-Path $RunRoot 'no-such-repos' 'Claude.Chain' 'ledger' 'chain.jsonl')
        $r.Ok | Should -BeFalse
    }

    It 'writes nothing to User scope' {
        $null = Get-Row 'CLAUDE_CHAIN_LEDGER'
        [Environment]::GetEnvironmentVariable('CLAUDE_CHAIN_LEDGER', 'User') | Should -Be $savedUser
    }

    It 'every row has a Note column' {
        Test-FrameworkRequirements -Manifest $manifest -FrameworkRoot $RunRoot -ReposRoot $reqRepos | ForEach-Object { $_.PSObject.Properties.Name | Should -Contain 'Note' }
    }

    It 'Invoke-Build is importable in this process' {
        $r = Get-Row 'Invoke-Build'
        $r.Wanted | Should -Be 'present'
        $r.Found | Should -Not -Be 'missing'
        $r.Ok | Should -BeTrue
    }
}

Describe 'the Ontology rename' {
    It 'no file outside repos\ contains the old workspace header' {
        # Built in two parts so this file does not match itself. .framework/test-runs is skipped: it holds child
        # output, and Claude.Ontology's own tests name the old header as the foreign one. .framework/fixtures holds
        # this suite's scratch repos.
        $needle = 'WORKSPACE: ' + 'plugins'
        $skip = @((Join-Path $FrameworkRoot '.framework' 'test-runs'), (Join-Path $FrameworkRoot '.framework' 'fixtures'))
        $files = Get-ChildItem -LiteralPath $FrameworkRoot -Force | Where-Object Name -notin 'repos', '.git' | ForEach-Object {
            if ($_.PSIsContainer) { Get-ChildItem -LiteralPath $_.FullName -Recurse -File -Force } else { $_ }
        } | Where-Object { $f = $_.FullName; -not ($skip | Where-Object { $f.StartsWith($_, [StringComparison]::OrdinalIgnoreCase) }) }
        $files | Should -Not -BeNullOrEmpty
        $hits = @($files | Select-String -SimpleMatch -Pattern $needle -List | ForEach-Object Path)
        $hits | Should -BeNullOrEmpty
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

    It 'the real script records that it ran' {
        $state = Join-Path $RunRoot 'bootstrap-real'
        Invoke-FrameworkBootstrap -StateRoot $state -Script (Join-Path $FrameworkRoot 'build' 'Bootstrap.ps1') | Out-Null
        Get-Content -LiteralPath (Join-Path $state 'bootstrap.log') | Should -Match 'bootstrap ran; 0 env var'
    }
}

Describe 'Bootstrap persists env entries to User scope' {
    BeforeAll {
        # A fixture variable, never the real CLAUDE_CHAIN_LEDGER; removed from User scope after.
        $name = 'FRAMEWORK_FIXTURE_BOOTSTRAP_ENV'
        $script = Join-Path $FrameworkRoot 'build' 'Bootstrap.ps1'
        $state = Join-Path $RunRoot 'bootstrap-env'
        $user = { [Environment]::GetEnvironmentVariable($name, 'User') }
    }
    AfterAll { [Environment]::SetEnvironmentVariable($name, $null, 'User') }

    It 'writes the value to User scope, honours the done marker, and writes again with -Force' {
        & $user | Should -BeNullOrEmpty
        $r = Invoke-FrameworkBootstrap -StateRoot $state -Script $script -Environment ([ordered]@{ $name = 'first' })
        $r.Action | Should -Be 'ran'
        & $user | Should -Be 'first'
        $r.Lines | Should -Contain "wrote User $name=first"

        $r = Invoke-FrameworkBootstrap -StateRoot $state -Script $script -Environment ([ordered]@{ $name = 'second' })
        $r.Action | Should -Be 'skipped'
        & $user | Should -Be 'first'

        $r = Invoke-FrameworkBootstrap -StateRoot $state -Script $script -Environment ([ordered]@{ $name = 'second' }) -Force
        $r.Action | Should -Be 'ran (-Force)'
        & $user | Should -Be 'second'
        [Environment]::GetEnvironmentVariable($name, 'Machine') | Should -BeNullOrEmpty
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

    It 'keeps the test run the newest heartbeat reused, past -KeepRuns' {
        $state = Join-Path $RunRoot 'retention-protect'
        $runs = Join-Path $state 'test-runs'
        foreach ($i in 1..7) {
            $d = Join-Path $runs "20200101-000000-00$i"
            $null = New-Item -ItemType Directory -Path $d -Force
            Set-Content -LiteralPath (Join-Path $d 'summary.json') -Value '{}'
        }
        # An older heartbeat cites -002; the newest kept one cites -001, and only that one counts.
        foreach ($h in @(@('20200101-000000-001', '20200101-000000-002'), @('20200101-000000-002', '20200101-000000-001'))) {
            $hb = Join-Path $state 'heartbeats' $h[0]
            $null = New-Item -ItemType Directory -Path $hb -Force
            Set-Content -LiteralPath (Join-Path $hb 'heartbeat.json') -Value (@{ reused_run = $h[1]; test_run = @{ folder = $h[1]; reused = $true } } | ConvertTo-Json)
        }
        Get-HeartbeatReusedRun (Join-Path $state 'heartbeats') | Should -Be '20200101-000000-001'

        $r = InModuleScope Framework.Build -Parameters @{ S = $state } { param($S) New-FrameworkTestRunFolder -StateRoot $S -Keep 5 }
        $left = @(Get-ChildItem -LiteralPath $runs -Directory).Name
        $left | Should -Contain '20200101-000000-001'
        $left | Should -Not -Contain '20200101-000000-002'
        $left | Should -Not -Contain '20200101-000000-003'
        $left | Should -Contain (Split-Path $r.Path -Leaf)
        Join-Path $state 'prune.log' | Should -Not -Exist
    }

    It 'reads the reused run from a heartbeat.json written before reused_run existed' {
        $hbRoot = Join-Path $RunRoot 'retention-legacy' 'heartbeats'
        $hb = Join-Path $hbRoot '20200101-000000-001'
        $null = New-Item -ItemType Directory -Path $hb -Force
        Set-Content -LiteralPath (Join-Path $hb 'heartbeat.json') -Value '{"test_run":{"folder":"20190101-000000-001","reused":true,"reason":"-SkipUp"}}'
        Get-HeartbeatReusedRun $hbRoot | Should -Be '20190101-000000-001'
    }

    It 'logs a summary-less folder to prune.log before pruning it' {
        $state = Join-Path $RunRoot 'retention-log'
        $runs = Join-Path $state 'test-runs'
        foreach ($i in 1..6) {
            $d = Join-Path $runs "20200101-000000-00$i"
            $null = New-Item -ItemType Directory -Path $d -Force
            if ($i -ne 1) { Set-Content -LiteralPath (Join-Path $d 'summary.json') -Value '{}' }
        }
        $r = InModuleScope Framework.Build -Parameters @{ S = $state } { param($S) New-FrameworkTestRunFolder -StateRoot $S -Keep 4 }
        $r.Pruned | Sort-Object | Should -Be @('20200101-000000-001', '20200101-000000-002', '20200101-000000-003')
        $log = @(Get-Content -LiteralPath (Join-Path $state 'prune.log'))
        $log.Count | Should -Be 1
        $log[0] | Should -Match ([regex]::Escape((Join-Path $runs '20200101-000000-001')) + ': no summary\.json')
        Join-Path $runs '20200101-000000-001' | Should -Not -Exist
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
