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
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    [xml]$x = Get-Content -LiteralPath $Path -Raw
    [pscustomobject]@{
        Total   = $x.SelectNodes('//testcase').Count
        Failed  = $x.SelectNodes('//testcase[failure or error]').Count
        Skipped = $x.SelectNodes('//testcase[skipped]').Count
    }
}

function Invoke-ChildTest {
    # Runs one Invoke-Build Test in a fresh pwsh so module versions and strict mode cannot leak between
    # children. $PesterPreference adds a JUnit result file without touching the child's own config.
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$BuildFile,
        [Parameter(Mandatory)][string]$ResultFile,
        [Parameter(Mandatory)][string]$LogFile,
        [string]$Task = 'Test'
    )
    if (Test-Path -LiteralPath $ResultFile) { Move-Item -LiteralPath $ResultFile -Destination "$ResultFile.$(Get-Date -Format yyyyMMddHHmmss).old" }
    $script = @'
param($BuildFile, $ResultFile, $Task, $PesterVersion)
Import-Module Pester -RequiredVersion $PesterVersion -ErrorAction Stop
$global:PesterPreference = New-PesterConfiguration
$global:PesterPreference.TestResult.Enabled = $true
$global:PesterPreference.TestResult.OutputFormat = 'JUnitXml'
$global:PesterPreference.TestResult.OutputPath = $ResultFile
Invoke-Build $Task -File $BuildFile
'@
    $quote = { "'" + ($args[0] -replace "'", "''") + "'" }
    $call = "& {{ {0} }} {1} {2} {3} {4}" -f $script, (& $quote $BuildFile), (& $quote $ResultFile), (& $quote $Task), (& $quote $script:PesterVersion)
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($call))
    $sw = [Diagnostics.Stopwatch]::StartNew()
    & pwsh -NoProfile -NonInteractive -EncodedCommand $encoded *> $LogFile
    $exit = $LASTEXITCODE
    $sw.Stop()
    $counts = Read-JUnitCounts $ResultFile
    [pscustomobject]@{
        Name     = $Name
        Result   = if ($exit -eq 0) { 'pass' } else { 'FAIL' }
        Passed   = if ($counts) { $counts.Total - $counts.Failed - $counts.Skipped } else { $null }
        Failed   = if ($counts) { $counts.Failed } else { $null }
        Skipped  = if ($counts) { $counts.Skipped } else { $null }
        Seconds  = [math]::Round($sw.Elapsed.TotalSeconds, 1)
        Log      = $LogFile
    }
}

$script:PesterVersion = $null

function Invoke-FrameworkTest {
    param(
        [Parameter(Mandatory)]$Manifest,
        [Parameter(Mandatory)][string]$ReposRoot,
        [Parameter(Mandatory)][string]$FrameworkRoot,
        [string[]]$Only
    )
    $script:PesterVersion = $Manifest.Requirements.pester
    $out = Join-Path $FrameworkRoot '.framework' 'test-results'
    if (-not (Test-Path -LiteralPath $out)) { $null = New-Item -ItemType Directory -Path $out -Force }

    foreach ($c in $Manifest.Children) {
        if ($Only -and $c.Name -notin $Only) { continue }
        $path = Join-Path $ReposRoot $c.Name
        $bs = if (Test-Path -LiteralPath $path) { Find-ChildBuildScript $path }
        if (-not $bs) {
            [pscustomobject]@{ Name = $c.Name; Result = 'no build script'; Passed = $null; Failed = $null; Skipped = $null; Seconds = $null; Log = $null }
            continue
        }
        Invoke-ChildTest -Name $c.Name -BuildFile $bs.FullName -ResultFile (Join-Path $out "$($c.Name).junit.xml") -LogFile (Join-Path $out "$($c.Name).log")
    }

    if (-not $Only -or 'Claude.Framework' -in $Only) {
        Invoke-ChildTest -Name 'Claude.Framework' -Task SelfTest -BuildFile (Join-Path $FrameworkRoot 'Claude.Framework.build.ps1') `
            -ResultFile (Join-Path $out 'Claude.Framework.junit.xml') -LogFile (Join-Path $out 'Claude.Framework.log')
    }
}

Export-ModuleMember -Function Get-FrameworkManifest, Test-FrameworkRequirements, Sync-Framework, Sync-FrameworkChild,
    Get-FrameworkStatus, Invoke-FrameworkTest, Invoke-ChildTest
