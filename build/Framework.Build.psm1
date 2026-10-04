#Requires -Version 7.4
<#
.SYNOPSIS
    Functions behind the Claude.Framework Invoke-Build tasks: manifest, Requirements, Sync, Status, Test.

.DESCRIPTION
    Sync never resets, never creates a merge commit and never discards local work. A folder it cannot
    use is moved to repos/_aside/<name>-<yyyyMMddHHmm>, never deleted.
#>

Set-StrictMode -Version Latest

function Invoke-Git {
    # Runs git in a repo; returns trimmed stdout lines. Throws on non-zero exit unless -AllowFail.
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory, ValueFromRemainingArguments)][string[]]$GitArgs,
        [switch]$AllowFail
    )
    $out = & git -C $Path @GitArgs 2>&1
    $code = $LASTEXITCODE
    $text = @($out | ForEach-Object { "$_".TrimEnd() })
    if ($code -ne 0 -and -not $AllowFail) {
        throw "git $($GitArgs -join ' ') failed in '$Path' (exit $code): $($text -join "`n")"
    }
    if ($AllowFail) { return [pscustomobject]@{ ExitCode = $code; Output = $text } }
    return $text
}

function ConvertTo-ChildExpectation {
    # The optional per-child expect block: tasks run before Test, a count of known failures, or no test files.
    # A known failure count or no_tests needs a one-line reason.
    param([string]$Name, $Block)
    $e = [pscustomobject]@{ TasksBeforeTest = @(); ExpectedFailures = 0; NoTests = $false; Reason = $null }
    if ($null -eq $Block) { return $e }
    if ($Block -isnot [System.Collections.IDictionary]) { throw "Manifest entry '$Name': expect must be a mapping." }
    $unknown = @($Block.Keys | Where-Object { $_ -notin 'tasks_before_test', 'expected_failures', 'no_tests', 'reason' })
    if ($unknown) { throw "Manifest entry '$Name': unknown expect key(s) $($unknown -join ', ')." }
    if ($Block.Contains('tasks_before_test')) { $e.TasksBeforeTest = @($Block.tasks_before_test | ForEach-Object { [string]$_ }) }
    if ($Block.Contains('expected_failures')) {
        $n = $Block.expected_failures
        if (($n -isnot [int] -and $n -isnot [long]) -or $n -lt 0) { throw "Manifest entry '$Name': expected_failures must be a whole number >= 0." }
        $e.ExpectedFailures = [int]$n
    }
    if ($Block.Contains('no_tests')) {
        if ($Block.no_tests -isnot [bool]) { throw "Manifest entry '$Name': no_tests must be true or false." }
        $e.NoTests = $Block.no_tests
    }
    if ($Block.Contains('reason')) { $e.Reason = [string]$Block.reason }
    if (($e.ExpectedFailures -gt 0 -or $e.NoTests) -and -not $e.Reason) {
        throw "Manifest entry '$Name': expected_failures and no_tests need a reason."
    }
    $e
}

function ConvertTo-ChildVerify {
    # The optional per-child verify block: a script under the child, run once per plugin after Test.
    param([string]$Name, $Block)
    if ($null -eq $Block) { return $null }
    if (-not $Block.Contains('script') -or -not $Block.Contains('plugins')) { throw "Manifest entry '$Name': verify needs script and plugins." }
    [pscustomobject]@{ Script = [string]$Block.script; Plugins = @($Block.plugins | ForEach-Object { [string]$_ }) }
}

function Get-FrameworkManifest {
    param([Parameter(Mandatory)][string]$Path)
    Import-Module powershell-yaml -ErrorAction Stop
    $raw = ConvertFrom-Yaml (Get-Content -LiteralPath $Path -Raw)
    if (-not $raw -or -not $raw.ContainsKey('children')) { throw "Manifest '$Path' has no 'children' list." }
    $required = 'name', 'url', 'default_branch', 'build_script'
    $children = foreach ($c in $raw.children) {
        foreach ($field in $required) {
            if (-not $c.ContainsKey($field) -or $null -eq $c[$field] -or "$($c[$field])" -eq '') {
                throw "Manifest entry '$($c['name'])' is missing '$field'."
            }
        }
        if ($c.build_script -isnot [bool]) { throw "Manifest entry '$($c.name)': build_script must be true or false." }
        [pscustomobject]@{
            Name          = [string]$c.name
            Url           = [string]$c.url
            DefaultBranch = [string]$c.default_branch
            BuildScript   = [bool]$c.build_script
            Expect        = ConvertTo-ChildExpectation -Name $c.name -Block $c['expect']
            Verify        = ConvertTo-ChildVerify -Name $c.name -Block $c['verify']
        }
    }
    $dupes = $children | Group-Object Name | Where-Object Count -gt 1
    if ($dupes) { throw "Manifest has duplicate names: $($dupes.Name -join ', ')" }
    [pscustomobject]@{
        Requirements = $raw.requirements
        Children     = @($children)
    }
}

function Test-FrameworkRequirements {
    # Returns one row per requirement. Presence only: nothing here runs docker.
    param([Parameter(Mandatory)]$Manifest)
    $req = $Manifest.Requirements
    $rows = [System.Collections.Generic.List[object]]::new()

    $git = Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    $gitVer = if ($git) { ((& git --version) -replace '^git version\s*', '') } else { $null }
    $rows.Add([pscustomobject]@{ Requirement = 'git'; Wanted = 'any'; Found = $gitVer ?? 'missing'; Ok = [bool]$git })

    $psWanted = [version]$req.powershell
    $psOk = $PSVersionTable.PSVersion -ge $psWanted
    $rows.Add([pscustomobject]@{ Requirement = 'PowerShell'; Wanted = ">= $psWanted"; Found = "$($PSVersionTable.PSVersion)"; Ok = $psOk })

    foreach ($m in @(@{ Name = 'Pester'; Key = 'pester' }, @{ Name = 'powershell-yaml'; Key = 'powershell_yaml' })) {
        $wanted = [version]$req[$m.Key]
        $found = Get-Module -ListAvailable -Name $m.Name | Where-Object Version -eq $wanted | Select-Object -First 1
        $all = (Get-Module -ListAvailable -Name $m.Name | ForEach-Object { "$($_.Version)" } | Sort-Object -Unique) -join ', '
        $rows.Add([pscustomobject]@{ Requirement = $m.Name; Wanted = "= $wanted"; Found = if ($all) { $all } else { 'missing' }; Ok = [bool]$found })
    }

    $docker = Get-Command docker -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    $rows.Add([pscustomobject]@{ Requirement = 'Docker'; Wanted = 'present'; Found = if ($docker) { $docker.Source } else { 'missing' }; Ok = [bool]$docker })

    # Compose v2 ships as a CLI plugin next to docker or as a standalone docker-compose binary.
    $compose = Get-Command docker-compose -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    $composePath = if ($compose) { $compose.Source }
    if (-not $composePath -and $docker) {
        $exe = if ($IsWindows) { 'docker-compose.exe' } else { 'docker-compose' }
        $plugin = Join-Path (Split-Path (Split-Path $docker.Source)) 'cli-plugins' $exe
        if (Test-Path -LiteralPath $plugin) { $composePath = $plugin }
    }
    $rows.Add([pscustomobject]@{ Requirement = 'Docker Compose'; Wanted = 'present'; Found = $composePath ?? 'missing'; Ok = [bool]$composePath })

    $rows
}

function Get-RootCommits {
    param([string]$Path, [string]$Ref)
    $r = Invoke-Git $Path rev-list --max-parents=0 $Ref -AllowFail
    if ($r.ExitCode -ne 0) { return @() }
    @($r.Output | Where-Object { $_ })
}

function Move-ToAside {
    param([string]$ReposRoot, [string]$Name, [string]$Path)
    $aside = Join-Path $ReposRoot '_aside'
    if (-not (Test-Path -LiteralPath $aside)) { $null = New-Item -ItemType Directory -Path $aside }
    $stamp = Get-Date -Format 'yyyyMMddHHmm'
    $target = Join-Path $aside "$Name-$stamp"
    $n = 1
    while (Test-Path -LiteralPath $target) { $target = Join-Path $aside "$Name-$stamp-$n"; $n++ }
    Move-Item -LiteralPath $Path -Destination $target
    $target
}

function Invoke-Clone {
    param($Child, [string]$Path)
    $null = & git clone --quiet --branch $Child.DefaultBranch $Child.Url $Path 2>&1
    if ($LASTEXITCODE -ne 0) { throw "git clone $($Child.Url) failed (exit $LASTEXITCODE)." }
}

function Sync-FrameworkChild {
    # Returns one row: Name, Action, Detail. Action is one of
    # cloned, aside+cloned, fast-forwarded, up-to-date, skipped.
    param(
        [Parameter(Mandatory)]$Child,
        [Parameter(Mandatory)][string]$ReposRoot
    )
    $path = Join-Path $ReposRoot $Child.Name
    $row = { param($a, $d) [pscustomobject]@{ Name = $Child.Name; Action = $a; Detail = $d } }

    if (-not (Test-Path -LiteralPath $path)) {
        Invoke-Clone $Child $path
        return & $row 'cloned' $Child.DefaultBranch
    }

    $hasGit = Test-Path -LiteralPath (Join-Path $path '.git')
    if (-not $hasGit) {
        $items = @(Get-ChildItem -LiteralPath $path -Force)
        if ($items.Count -eq 0) {
            Invoke-Clone $Child $path
            return & $row 'cloned' "into empty folder; $($Child.DefaultBranch)"
        }
        $aside = Move-ToAside $ReposRoot $Child.Name $path
        Invoke-Clone $Child $path
        return & $row 'aside+cloned' "files without .git moved to $aside"
    }

    # Record the upstream as last known before fetching: after a force-push the new upstream
    # cannot tell local work apart from the old history.
    $branch = @(Invoke-Git $path rev-parse --abbrev-ref HEAD)[0]
    if ($branch -eq 'HEAD') {
        Invoke-Git $path fetch --quiet origin | Out-Null
        return & $row 'skipped' 'detached HEAD'
    }
    $up = Invoke-Git $path rev-parse --abbrev-ref --symbolic-full-name '@{u}' -AllowFail
    $upstream = if ($up.ExitCode -eq 0) { $up.Output[0] }
    $oldUpstreamSha = if ($upstream) { @(Invoke-Git $path rev-parse $upstream)[0] }

    Invoke-Git $path fetch --quiet origin | Out-Null

    $dirty = @(Invoke-Git $path status --porcelain | Where-Object { $_ })
    if ($dirty.Count -gt 0) { return & $row 'skipped' "dirty: $($dirty.Count) path(s) on $branch" }
    if (-not $upstream) { return & $row 'skipped' "branch $branch has no upstream" }

    $ahead = [int]@(Invoke-Git $path rev-list --count "$oldUpstreamSha..HEAD")[0]
    if ($ahead -gt 0) { return & $row 'skipped' "$branch is $ahead commit(s) ahead of $upstream" }

    $localRoots = @(Get-RootCommits $path HEAD)
    $remoteRoots = @(Get-RootCommits $path "origin/$($Child.DefaultBranch)")
    if ($remoteRoots.Count -gt 0 -and -not ($localRoots | Where-Object { $_ -in $remoteRoots })) {
        $aside = Move-ToAside $ReposRoot $Child.Name $path
        Invoke-Clone $Child $path
        return & $row 'aside+cloned' "unrelated history vs origin/$($Child.DefaultBranch); old clone moved to $aside"
    }

    $behind = [int]@(Invoke-Git $path rev-list --count "HEAD..$upstream")[0]
    if ($behind -eq 0) { return & $row 'up-to-date' $branch }
    $ff = Invoke-Git $path merge --ff-only --quiet $upstream -AllowFail
    if ($ff.ExitCode -ne 0) { return & $row 'skipped' "fast-forward of $branch refused: $($ff.Output -join ' ')" }
    & $row 'fast-forwarded' "$branch +$behind"
}

function Sync-Framework {
    param([Parameter(Mandatory)]$Manifest, [Parameter(Mandatory)][string]$ReposRoot)
    if (-not (Test-Path -LiteralPath $ReposRoot)) { $null = New-Item -ItemType Directory -Path $ReposRoot }
    foreach ($c in $Manifest.Children) {
        try { Sync-FrameworkChild -Child $c -ReposRoot $ReposRoot }
        catch { [pscustomobject]@{ Name = $c.Name; Action = 'error'; Detail = "$_" } }
    }
}

function Find-ChildBuildScript {
    param([string]$Path)
    @(Get-ChildItem -LiteralPath $Path -Filter '*.build.ps1' -File -ErrorAction SilentlyContinue) | Select-Object -First 1
}

function Get-FrameworkStatus {
    param([Parameter(Mandatory)]$Manifest, [Parameter(Mandatory)][string]$ReposRoot)
    foreach ($c in $Manifest.Children) {
        $path = Join-Path $ReposRoot $c.Name
        if (-not (Test-Path -LiteralPath (Join-Path $path '.git'))) {
            [pscustomobject]@{ Name = $c.Name; Branch = '(not cloned)'; Ahead = $null; Behind = $null; Dirty = $null; LastCommit = $null; BuildScript = $null }
            continue
        }
        $branch = @(Invoke-Git $path rev-parse --abbrev-ref HEAD)[0]
        $ahead = $behind = $null
        $counts = Invoke-Git $path rev-list --left-right --count 'HEAD...@{u}' -AllowFail
        if ($counts.ExitCode -eq 0) { $ahead, $behind = ($counts.Output[0] -split '\s+') | ForEach-Object { [int]$_ } }
        $dirty = @(Invoke-Git $path status --porcelain | Where-Object { $_ }).Count
        $last = @(Invoke-Git $path log -1 --format=%cI)[0]
        $bs = Find-ChildBuildScript $path
        [pscustomobject]@{
            Name        = $c.Name
            Branch      = $branch
            Ahead       = $ahead
            Behind      = $behind
            Dirty       = $dirty
            LastCommit  = ([datetimeoffset]$last).ToString('yyyy-MM-dd HH:mm zzz')
            BuildScript = if ($bs) { $bs.Name } else { '-' }
        }
    }
}

function Read-JUnitCounts {
    param([string]$Path)
    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) { return $null }
    [xml]$x = Get-Content -LiteralPath $Path -Raw
    [pscustomobject]@{
        Total   = $x.SelectNodes('//testcase').Count
        Failed  = $x.SelectNodes('//testcase[failure or error]').Count
        Skipped = $x.SelectNodes('//testcase[skipped]').Count
    }
}

function Invoke-ChildProcess {
    # Runs $Script in a fresh pwsh whose working directory is $WorkingDirectory. Nothing from this session reaches
    # it but the script text, its arguments and the inherited environment. All output goes to $LogFile (absolute).
    # Returns the exit code.
    param(
        [Parameter(Mandatory)][string]$WorkingDirectory,
        [Parameter(Mandatory)][string]$Script,
        [object[]]$ArgumentList = @(),
        [Parameter(Mandatory)][string]$LogFile,
        [hashtable]$Environment = @{}
    )
    $quote = { "'" + ("$($args[0])" -replace "'", "''") + "'" }
    $call = '& {{ {0} }} {1}' -f $Script, (@($ArgumentList | ForEach-Object { & $quote $_ }) -join ' ')
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($call))
    $saved = @{}
    foreach ($k in $Environment.Keys) {
        $saved[$k] = [Environment]::GetEnvironmentVariable($k)
        [Environment]::SetEnvironmentVariable($k, $Environment[$k])
    }
    # A native command starts in the current FileSystem location.
    Push-Location -LiteralPath $WorkingDirectory
    try {
        & pwsh -NoProfile -NonInteractive -EncodedCommand $encoded *> $LogFile
        $LASTEXITCODE
    }
    finally {
        Pop-Location
        foreach ($k in $saved.Keys) { [Environment]::SetEnvironmentVariable($k, $saved[$k]) }
    }
}

function Invoke-ChildTask {
    # Runs `Invoke-Build <Task>` in a fresh pwsh in the child's own folder, where Invoke-Build finds the child's
    # build script; the child's rules govern that process. Framework passes only the task name. With -ResultFile,
    # a $PesterPreference in that process adds a JUnit file; the child's own Pester configuration is not touched.
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Task,
        [Parameter(Mandatory)][string]$LogFile,
        [string]$ResultFile = '',
        [string]$PesterVersion = '',
        [hashtable]$Environment = @{}
    )
    $script = @'
param($Task, $ResultFile, $PesterVersion)
if ($ResultFile) {
    if ($PesterVersion) { Import-Module Pester -RequiredVersion $PesterVersion -ErrorAction Stop } else { Import-Module Pester -ErrorAction Stop }
    $global:PesterPreference = New-PesterConfiguration
    $global:PesterPreference.TestResult.Enabled = $true
    $global:PesterPreference.TestResult.OutputFormat = 'JUnitXml'
    $global:PesterPreference.TestResult.OutputPath = $ResultFile
}
Invoke-Build $Task
'@
    Invoke-ChildProcess -WorkingDirectory $Path -Script $script -ArgumentList $Task, $ResultFile, $PesterVersion -LogFile $LogFile -Environment $Environment
}

function Invoke-ChildVerify {
    # Runs the child's verify script once per plugin, each in a fresh pwsh in the child's folder, and writes what
    # it returns to <RunFolder>/<Name>.verify-<plugin>.json. Verify is 'reproduces' only if every plugin does.
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)]$Verify,
        [Parameter(Mandatory)][string]$RunFolder
    )
    $script = @'
param($ScriptPath, $Plugin, $OutFile)
$r = & (Join-Path $PWD $ScriptPath) -Plugin $Plugin
$r | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutFile
if (-not $r.Reproduces) { exit 1 }
'@
    $rows = foreach ($plugin in $Verify.Plugins) {
        $out = Join-Path $RunFolder "$Name.verify-$plugin.json"
        $exit = Invoke-ChildProcess -WorkingDirectory $Path -Script $script -ArgumentList $Verify.Script, $plugin, $out -LogFile (Join-Path $RunFolder "$Name.verify-$plugin.log")
        $r = if (Test-Path -LiteralPath $out) { Get-Content -LiteralPath $out -Raw | ConvertFrom-Json }
        [pscustomobject]@{ Plugin = $plugin; Reproduces = ($exit -eq 0 -and $r -and $r.Reproduces -eq $true) }
    }
    $no = @($rows | Where-Object { -not $_.Reproduces })
    [pscustomobject]@{
        Verify = if ($no) { 'does not' } else { 'reproduces' }
        Note   = if ($no) { "does not reproduce: $($no.Plugin -join ', ')" } else { "reproduces: $($rows.Plugin -join ', ')" }
    }
}

function Get-TestVerdict {
    # Compares one child's Test run with its expectation. Result is pass, pass-with-known, no-tests or FAIL.
    #   no_tests and no test files found      -> no-tests (Pester exits non-zero on an empty run; that is expected)
    #   no JUnit counts                       -> FAIL
    #   failed > expected_failures            -> FAIL
    #   0 < failed <= expected_failures       -> pass-with-known
    #   failed = 0 and the task exited 0      -> pass
    #   failed = 0 and the task exited non-0  -> FAIL (something other than a test broke)
    param(
        [Parameter(Mandatory)][int]$ExitCode,
        $Counts,
        [Parameter(Mandatory)]$Expect,
        [int]$TestFileCount = -1
    )
    $notes = [System.Collections.Generic.List[string]]::new()
    if ($Expect.NoTests) {
        if ($TestFileCount -eq 0 -or ($TestFileCount -lt 0 -and (-not $Counts -or $Counts.Total -eq 0))) {
            return [pscustomobject]@{ Result = 'no-tests'; Note = "$($Expect.Reason) (Test exit $ExitCode)" }
        }
        $notes.Add("no_tests is stale: $TestFileCount test file(s) found")
    }
    if (-not $Counts) {
        $notes.Add("no JUnit results; Test exit $ExitCode")
        return [pscustomobject]@{ Result = 'FAIL'; Note = $notes -join '; ' }
    }
    $expected = $Expect.ExpectedFailures
    $result = if ($Counts.Failed -gt $expected) {
        $notes.Add("$($Counts.Failed) failed, $expected expected")
        'FAIL'
    }
    elseif ($Counts.Failed -gt 0) {
        if ($Counts.Failed -lt $expected) { $notes.Add("fewer failures than expected ($($Counts.Failed) < $expected)") }
        $notes.Add($Expect.Reason)
        'pass-with-known'
    }
    elseif ($ExitCode -ne 0) {
        $notes.Add("no test failed but Test exit $ExitCode")
        'FAIL'
    }
    else {
        if ($expected -gt 0) { $notes.Add("expected $expected failures, none; lower expected_failures") }
        'pass'
    }
    [pscustomobject]@{ Result = $result; Note = $notes -join '; ' }
}

function New-FrameworkRunFolder {
    # Creates <Root>/<yyyyMMdd-HHmmss-fff> and removes the oldest run folders so that $Keep remain, the new one
    # included. CLAUDE.md names this as the one place Framework deletes; only folders named like a stamp are touched.
    param([Parameter(Mandatory)][string]$Root, [int]$Keep = 5)
    if ($Keep -lt 1) { throw "Keep must be at least 1." }
    if (-not (Test-Path -LiteralPath $Root)) { $null = New-Item -ItemType Directory -Path $Root -Force }
    do {
        $path = Join-Path $Root (Get-Date -Format 'yyyyMMdd-HHmmss-fff')
    } while (Test-Path -LiteralPath $path)
    $null = New-Item -ItemType Directory -Path $path
    $old = @(Get-ChildItem -LiteralPath $Root -Directory | Where-Object Name -match '^\d{8}-\d{6}-\d{3}$' |
            Sort-Object Name -Descending | Select-Object -Skip $Keep)
    foreach ($d in $old) { Remove-Item -LiteralPath $d.FullName -Recurse -Force }
    [pscustomobject]@{ Path = $path; Pruned = @($old | ForEach-Object Name) }
}

function Invoke-FrameworkTest {
    # Runs every child that has a build script through its own Test in a fresh pwsh, then Framework's SelfTest.
    # Results, logs and JUnit files go to .framework/test-runs/<stamp>/.
    param(
        [Parameter(Mandatory)]$Manifest,
        [Parameter(Mandatory)][string]$ReposRoot,
        [Parameter(Mandatory)][string]$FrameworkRoot,
        [string[]]$Only,
        [int]$KeepRuns = 5
    )
    $pester = [string]$Manifest.Requirements.pester
    $run = (New-FrameworkRunFolder -Root (Join-Path $FrameworkRoot '.framework' 'test-runs') -Keep $KeepRuns).Path
    $row = {
        param($Name, $Result, $Expected, $Counts, $Verify, $Seconds, $Note)
        [pscustomobject]@{
            Name = $Name; Result = $Result; Expected = $Expected
            Passed = if ($Counts) { $Counts.Total - $Counts.Failed - $Counts.Skipped }
            Failed = if ($Counts) { $Counts.Failed }
            Skipped = if ($Counts) { $Counts.Skipped }
            Verify = $Verify; Seconds = $Seconds; Note = $Note
        }
    }

    $rows = @(foreach ($c in $Manifest.Children) {
        if ($Only -and $c.Name -notin $Only) { continue }
        $e = $c.Expect
        $expected = if ($e.NoTests) { 'no tests' } elseif ($e.ExpectedFailures) { "$($e.ExpectedFailures) failed" } else { '0 failed' }
        $verifyCol = if ($c.Verify) { 'not run' } else { 'not applicable' }
        if (-not $c.BuildScript) { & $row $c.Name 'no build script' '-' $null 'not applicable' $null $null; continue }
        $path = Join-Path $ReposRoot $c.Name
        if (-not (Test-Path -LiteralPath (Join-Path $path '.git'))) { & $row $c.Name 'FAIL' $expected $null $verifyCol $null 'not cloned; run Sync'; continue }
        if (-not (Find-ChildBuildScript $path)) { & $row $c.Name 'FAIL' $expected $null $verifyCol $null 'manifest says build_script but none found'; continue }

        $sw = [Diagnostics.Stopwatch]::StartNew()
        $before = $null
        foreach ($t in $e.TasksBeforeTest) {
            $exit = Invoke-ChildTask -Path $path -Task $t -LogFile (Join-Path $run "$($c.Name).$t.log")
            if ($exit -ne 0) { $before = "$t failed (exit $exit); Test not run"; break }
        }
        if ($before) { & $row $c.Name 'FAIL' $expected $null $verifyCol ([math]::Round($sw.Elapsed.TotalSeconds, 1)) $before; continue }

        $junit = Join-Path $run "$($c.Name).junit.xml"
        $exit = Invoke-ChildTask -Path $path -Task Test -LogFile (Join-Path $run "$($c.Name).log") -ResultFile $junit -PesterVersion $pester
        $counts = Read-JUnitCounts $junit
        $files = if ($e.NoTests) { @(Get-ChildItem -LiteralPath $path -Recurse -File -Filter '*.Tests.ps1' -ErrorAction SilentlyContinue).Count } else { -1 }
        $verdict = Get-TestVerdict -ExitCode $exit -Counts $counts -Expect $e -TestFileCount $files
        $note = $verdict.Note
        if ($c.Verify) {
            $v = Invoke-ChildVerify -Name $c.Name -Path $path -Verify $c.Verify -RunFolder $run
            $verifyCol = $v.Verify
            $note = (@($note, $v.Note) | Where-Object { $_ }) -join '; '
        }
        & $row $c.Name $verdict.Result $expected $counts $verifyCol ([math]::Round($sw.Elapsed.TotalSeconds, 1)) $note
    })

    if (-not $Only -or 'Claude.Framework' -in $Only) {
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $junit = Join-Path $run 'Claude.Framework.junit.xml'
        $exit = Invoke-ChildTask -Path $FrameworkRoot -Task SelfTest -LogFile (Join-Path $run 'Claude.Framework.log') -ResultFile $junit `
            -PesterVersion $pester -Environment @{ FRAMEWORK_FIXTURE_ROOT = (Join-Path $run 'fixtures') }
        $counts = Read-JUnitCounts $junit
        $verdict = Get-TestVerdict -ExitCode $exit -Counts $counts -Expect (ConvertTo-ChildExpectation -Name 'Claude.Framework' -Block $null)
        $rows += & $row 'Claude.Framework' $verdict.Result '0 failed' $counts 'not applicable' ([math]::Round($sw.Elapsed.TotalSeconds, 1)) $verdict.Note
    }

    $rows | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $run 'summary.json')
    $rows
}

function Invoke-FrameworkBootstrap {
    # Runs the run-once script unless <StateRoot>/bootstrap.done exists; -Force runs it again. The marker is
    # written only after the script succeeds, and records when it ran and which script.
    param(
        [Parameter(Mandatory)][string]$StateRoot,
        [Parameter(Mandatory)][string]$Script,
        [switch]$Force
    )
    $marker = Join-Path $StateRoot 'bootstrap.done'
    if ((Test-Path -LiteralPath $marker) -and -not $Force) {
        return [pscustomobject]@{ Action = 'skipped'; Detail = "marker exists: $(Get-Content -LiteralPath $marker -Raw)".Trim() }
    }
    if (-not (Test-Path -LiteralPath $StateRoot)) { $null = New-Item -ItemType Directory -Path $StateRoot -Force }
    & $Script -StateRoot $StateRoot
    Set-Content -LiteralPath $marker -Value "$(Get-Date -Format o) $Script"
    [pscustomobject]@{ Action = if ($Force) { 'ran (-Force)' } else { 'ran' }; Detail = "marker written: $marker" }
}

Export-ModuleMember -Function Get-FrameworkManifest, Test-FrameworkRequirements, Sync-Framework, Sync-FrameworkChild,
    Get-FrameworkStatus, Invoke-FrameworkTest, Invoke-ChildTask, Invoke-ChildVerify, Get-TestVerdict,
    New-FrameworkRunFolder, Invoke-FrameworkBootstrap
