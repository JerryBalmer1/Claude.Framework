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
    # The optional per-child expect block: tasks run before Test, the task Test and Up -Full run, a count of known
    # failures, or no test files. A known failure count or no_tests needs a one-line reason.
    param([string]$Name, $Block)
    $e = [pscustomobject]@{ TasksBeforeTest = @(); TestTask = 'Test'; FullTestTask = $null; ExpectedFailures = 0; NoTests = $false; Reason = $null }
    if ($null -eq $Block) { return $e }
    if ($Block -isnot [System.Collections.IDictionary]) { throw "Manifest entry '$Name': expect must be a mapping." }
    $unknown = @($Block.Keys | Where-Object { $_ -notin 'tasks_before_test', 'test_task', 'full_test_task', 'expected_failures', 'no_tests', 'reason' })
    if ($unknown) { throw "Manifest entry '$Name': unknown expect key(s) $($unknown -join ', ')." }
    foreach ($k in @(@('test_task', 'TestTask'), @('full_test_task', 'FullTestTask'))) {
        if (-not $Block.Contains($k[0])) { continue }
        if ($Block[$k[0]] -isnot [string] -or -not $Block[$k[0]]) { throw "Manifest entry '$Name': $($k[0]) must be a task name." }
        $e.($k[1]) = $Block[$k[0]]
    }
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

function ConvertTo-ChildResultFile {
    # How Test gets a result file from the child's build. Required when build_script is true.
    #   parameter   the build takes -PesterConfiguration (a TestResult section only)
    #   preference  the child's Invoke-Pester merges $PesterPreference
    #   none        neither; counts come from the Pester summary line the build prints
    param([string]$Name, [bool]$BuildScript, $Value)
    if ($null -eq $Value) {
        if ($BuildScript) { throw "Manifest entry '$Name': build_script is true, so result_file is required (parameter, preference or none)." }
        return $null
    }
    if ("$Value" -notin 'parameter', 'preference', 'none') { throw "Manifest entry '$Name': result_file must be parameter, preference or none, not '$Value'." }
    [string]$Value
}

function Test-RelativePath {
    # True for a relative path that never climbs out of its root: not rooted, no '..' segment.
    param([string]$Path)
    $Path -and -not [IO.Path]::IsPathRooted($Path) -and $Path -notmatch '^[\\/]' -and -not (@($Path -split '[\\/]') -contains '..')
}

function ConvertTo-FrameworkGetter {
    # One getters entry. name, order, cadence and entry are required; path is required unless entry is none.
    # path is relative to repos/ (CLAUDE.md: a getter runs only from under repos/), so it may not be rooted or climb.
    # entry is none, or a mapping: script (a .ps1 under tools/) and optional parameters, whose values may hold
    # {out}, {previous}, {framework_root} and {repos_root}. outputs lists file names the entry must leave under {out}.
    param($Block)
    if ($Block -isnot [System.Collections.IDictionary]) { throw "Manifest getters: each entry must be a mapping." }
    $name = $Block['name']
    foreach ($field in 'name', 'order', 'cadence', 'entry') {
        if (-not $Block.Contains($field) -or $null -eq $Block[$field] -or "$($Block[$field])" -eq '') { throw "Manifest getter '$name' is missing '$field'." }
    }
    $unknown = @($Block.Keys | Where-Object { $_ -notin 'name', 'path', 'entry', 'tests', 'expects', 'outputs', 'cadence', 'order', 'note', 'needs' })
    if ($unknown) { throw "Manifest getter '$name': unknown key(s) $($unknown -join ', ')." }
    if (($Block.order -isnot [int] -and $Block.order -isnot [long]) -or $Block.order -lt 0) { throw "Manifest getter '$name': order must be a whole number >= 0." }
    if ("$($Block.cadence)" -notin 'every', 'weekly') { throw "Manifest getter '$name': cadence must be every or weekly, not '$($Block.cadence)'." }

    $entry = $null
    if ($Block.entry -is [System.Collections.IDictionary]) {
        $script = [string]$Block.entry['script']
        if ($script -notmatch '^tools[\\/][^\\/].*\.ps1$' -or -not (Test-RelativePath $script)) { throw "Manifest getter '$name': entry.script must be a .ps1 under tools/, not '$script'." }
        $params = [ordered]@{}
        if ($null -ne $Block.entry['parameters']) {
            if ($Block.entry.parameters -isnot [System.Collections.IDictionary]) { throw "Manifest getter '$name': entry.parameters must be a mapping." }
            foreach ($k in $Block.entry.parameters.Keys) { $params[[string]$k] = $Block.entry.parameters[$k] }
        }
        $entry = [pscustomobject]@{ Script = $script -replace '\\', '/'; Parameters = $params }
    }
    elseif ("$($Block.entry)" -ne 'none') { throw "Manifest getter '$name': entry must be none or a mapping with script." }

    $path = $Block['path']
    if ($entry -and ($null -eq $path -or "$path" -eq '')) { throw "Manifest getter '$name' is missing 'path'." }
    if ($null -ne $path -and -not (Test-RelativePath ([string]$path))) { throw "Manifest getter '$name': path must be relative to repos/ and stay under it, not '$path'." }

    $tests = $false
    if ($Block.Contains('tests')) {
        if ($Block.tests -isnot [bool]) { throw "Manifest getter '$name': tests must be true or false." }
        $tests = $Block.tests
    }
    $outputs = @(foreach ($o in @($Block['outputs'] | Where-Object { $null -ne $_ })) {
            if ($o -isnot [string] -or -not (Test-RelativePath $o)) { throw "Manifest getter '$name': each output must be a file name relative to {out}, not '$o'." }
            $o
        })
    if ($null -ne $Block['expects']) {
        if ($Block.expects -isnot [System.Collections.IDictionary]) { throw "Manifest getter '$name': expects must be a mapping." }
        $bad = @($Block.expects.Keys | Where-Object { $_ -notin 'expected_failures', 'no_tests', 'reason' })
        if ($bad) { throw "Manifest getter '$name': unknown expects key(s) $($bad -join ', ')." }
    }
    # needs names other getters that must run first. Whether each exists, and whether they form a cycle, is
    # Get-FrameworkGetterOrder's to say: Heartbeat refuses to start on either.
    $needs = @(foreach ($n in @($Block['needs'] | Where-Object { $null -ne $_ })) {
            if ($n -isnot [string] -or -not $n) { throw "Manifest getter '$name': each need must be a getter name, not '$n'." }
            $n
        })
    [pscustomobject]@{
        Name    = [string]$name
        Path    = if ($null -ne $path) { [string]$path }
        Entry   = $entry
        Needs   = @($needs | Select-Object -Unique)
        Tests   = $tests
        Outputs = $outputs
        Expect  = ConvertTo-ChildExpectation -Name $name -Block $Block['expects']
        Cadence = [string]$Block.cadence
        Order   = [int]$Block.order
        Note    = if ($Block['note']) { [string]$Block.note }
    }
}

function ConvertTo-FrameworkGetters {
    # The getters list, sorted by order. Names and orders are unique, no getter shares a child's name, and Diff,
    # which compares one heartbeat with the one before, has the highest order.
    param($List, [string[]]$ChildNames)
    if ($null -eq $List) { return @() }
    $getters = @(foreach ($g in @($List)) { ConvertTo-FrameworkGetter $g })
    $dupes = $getters | Group-Object Name | Where-Object Count -gt 1
    if ($dupes) { throw "Manifest has duplicate getter names: $($dupes.Name -join ', ')" }
    $clash = @($getters.Name | Where-Object { $_ -in @($ChildNames) + 'Claude.Framework' })
    if ($clash) { throw "Manifest getter name(s) $($clash -join ', ') also name a child." }
    $same = $getters | Group-Object Order | Where-Object Count -gt 1
    if ($same) { throw "Manifest getters share an order: $(@($same | ForEach-Object { "$($_.Name) ($($_.Group.Name -join ', '))" }) -join '; ')" }
    $sorted = @($getters | Sort-Object Order)
    $diff = $sorted | Where-Object Name -eq 'Diff'
    if ($diff -and $sorted[-1].Name -ne 'Diff') { throw "Manifest getter Diff must be last (highest order); $($sorted[-1].Name) has order $($sorted[-1].Order), Diff $($diff.Order)." }
    $sorted
}

function Get-FrameworkGetterOrder {
    # The getters in the order Heartbeat runs them: every getter after the getters it needs, ties broken by order.
    # Throws, so Heartbeat refuses to start, when a need names no getter, when needs form a cycle, or when the
    # needs would run anything after Diff.
    param([object[]]$Getters)
    $getters = @($Getters | Where-Object { $_ } | Sort-Object Order)
    $names = @($getters | ForEach-Object Name)
    $unknown = @(foreach ($g in $getters) { foreach ($n in @($g.Needs)) { if ($n -notin $names) { "$($g.Name) needs $n" } } })
    if ($unknown) { throw "Heartbeat refuses to start: unknown getter in needs: $($unknown -join '; '). Getters: $($names -join ', ')." }
    $done = [System.Collections.Generic.List[string]]::new()
    $ordered = [System.Collections.Generic.List[object]]::new()
    while ($ordered.Count -lt $getters.Count) {
        # The lowest-order getter whose needs have all run.
        $next = $getters | Where-Object { $_.Name -notin $done -and -not @(@($_.Needs) | Where-Object { $_ -notin $done }) } | Select-Object -First 1
        if (-not $next) {
            $left = @($getters | Where-Object Name -notin $done | ForEach-Object { "$($_.Name) needs $(@($_.Needs) -join ', ')" })
            throw "Heartbeat refuses to start: getter needs form a cycle: $($left -join '; ')."
        }
        $done.Add($next.Name)
        $ordered.Add($next)
    }
    if ($names -contains 'Diff' -and $ordered[-1].Name -ne 'Diff') { throw "Heartbeat refuses to start: needs put $($ordered[-1].Name) after Diff, which must run last." }
    @($ordered)
}

function Get-GetterOutcome {
    # One of ok, failed, refused, skipped for a getter's result as a heartbeat recorded it. Records written before
    # slice four-d say pass, fail or not runnable.
    param([string]$Result)
    switch ($Result) { 'pass' { 'ok' } 'fail' { 'failed' } 'not runnable' { 'skipped' } default { $Result } }
}

function Get-FrameworkGetterOutcomes {
    # How many getters in the newest heartbeat.json under $HeartbeatsRoot ended ok, failed, refused and skipped,
    # with that heartbeat's stamp and Diff's call (improved, regressed, mixed or unchanged) when its diff verdict reads
    # "N better, N worse, N unknown: <call>", else $null; $null when there is no heartbeat.
    param([string]$HeartbeatsRoot)
    foreach ($f in Get-StampFolders $HeartbeatsRoot) {
        $file = Join-Path $f.FullName 'heartbeat.json'
        if (-not (Test-Path -LiteralPath $file)) { continue }
        $hb = Get-Content -LiteralPath $file -Raw | ConvertFrom-Json
        $results = @($hb.getters | ForEach-Object { Get-GetterOutcome $_.result })
        return [pscustomobject]@{
            Stamp   = $f.Name
            Ok      = @($results | Where-Object { $_ -eq 'ok' }).Count
            Failed  = @($results | Where-Object { $_ -eq 'failed' }).Count
            Refused = @($results | Where-Object { $_ -eq 'refused' }).Count
            Skipped = @($results | Where-Object { $_ -eq 'skipped' }).Count
            Call    = if ("$($hb.diff)" -match '^\d+ better, \d+ worse, \d+ unknown: (\S+)$') { $Matches[1] }
        }
    }
    $null
}

function Expand-FrameworkPlaceholder {
    # $Text with each {key} in $Values replaced by its value. Non-strings pass through unchanged.
    param($Text, [Parameter(Mandatory)][hashtable]$Values)
    if ($Text -isnot [string]) { return $Text }
    foreach ($t in $Values.Keys) { $Text = $Text.Replace("{$t}", [string]$Values[$t]) }
    $Text
}

function ConvertTo-FrameworkEnv {
    # The env list: process environment variables the build derives itself. Each entry has name, value (which may
    # hold {framework_root} and {repos_root}) and wanted (file exists).
    param($List)
    if ($null -eq $List) { return @() }
    $entries = @(foreach ($e in @($List)) {
        if ($e -isnot [System.Collections.IDictionary]) { throw "Manifest env: each entry must be a mapping." }
        foreach ($field in 'name', 'value', 'wanted') {
            if (-not $e.Contains($field) -or "$($e[$field])" -eq '') { throw "Manifest env entry '$($e['name'])' is missing '$field'." }
        }
        $unknown = @($e.Keys | Where-Object { $_ -notin 'name', 'value', 'wanted' })
        if ($unknown) { throw "Manifest env entry '$($e.name)': unknown key(s) $($unknown -join ', ')." }
        if ("$($e.name)" -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') { throw "Manifest env entry '$($e.name)': name is not an environment variable name." }
        if ("$($e.wanted)" -ne 'file exists') { throw "Manifest env entry '$($e.name)': wanted must be 'file exists', not '$($e.wanted)'." }
        [pscustomobject]@{ Name = [string]$e.name; Value = [string]$e.value; Wanted = [string]$e.wanted }
    })
    $dupes = $entries | Group-Object Name | Where-Object Count -gt 1
    if ($dupes) { throw "Manifest has duplicate env names: $($dupes.Name -join ', ')" }
    $entries
}

function Resolve-FrameworkEnv {
    # Each env entry with its value derived from the roots: Name, Value, Wanted. FrameworkRoot defaults to the
    # manifest's folder, ReposRoot to repos/ under it.
    param([Parameter(Mandatory)]$Manifest, [string]$FrameworkRoot, [string]$ReposRoot)
    if (-not $FrameworkRoot) { $FrameworkRoot = $Manifest.Root }
    if (-not $ReposRoot) { $ReposRoot = Join-Path $FrameworkRoot 'repos' }
    $values = @{ framework_root = $FrameworkRoot; repos_root = $ReposRoot }
    foreach ($e in @($Manifest.Env)) {
        [pscustomobject]@{ Name = $e.Name; Value = (Expand-FrameworkPlaceholder $e.Value $values); Wanted = $e.Wanted }
    }
}

function Set-FrameworkEnv {
    # Sets each env entry in this process only, so every child pwsh, Verify and getter inherits it. Writes nothing
    # to User or Machine scope (Bootstrap does that). Returns Name, Value and Previous (what the shell had).
    param([Parameter(Mandatory)]$Manifest, [string]$FrameworkRoot, [string]$ReposRoot)
    foreach ($e in @(Resolve-FrameworkEnv -Manifest $Manifest -FrameworkRoot $FrameworkRoot -ReposRoot $ReposRoot)) {
        $previous = [Environment]::GetEnvironmentVariable($e.Name, 'Process')
        [Environment]::SetEnvironmentVariable($e.Name, $e.Value, 'Process')
        [pscustomobject]@{ Name = $e.Name; Value = $e.Value; Wanted = $e.Wanted; Previous = $previous }
    }
}

function Get-FrameworkEnvRecord {
    # The env block a run record carries: each env entry's name and the value this process holds for it now.
    param([Parameter(Mandatory)]$Manifest)
    $o = [ordered]@{}
    foreach ($e in @($Manifest.Env)) { $o[$e.Name] = [Environment]::GetEnvironmentVariable($e.Name, 'Process') }
    $o
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
        if ($c.ContainsKey('branch') -and ($c.branch -isnot [string] -or -not $c.branch)) { throw "Manifest entry '$($c.name)': branch must be a branch name." }
        [pscustomobject]@{
            Name          = [string]$c.name
            Url           = [string]$c.url
            DefaultBranch = [string]$c.default_branch
            Branch        = if ($c.ContainsKey('branch')) { [string]$c.branch } else { [string]$c.default_branch }
            BuildScript   = [bool]$c.build_script
            Expect        = ConvertTo-ChildExpectation -Name $c.name -Block $c['expect']
            Verify        = ConvertTo-ChildVerify -Name $c.name -Block $c['verify']
            ResultFile    = ConvertTo-ChildResultFile -Name $c.name -BuildScript $c.build_script -Value $c['result_file']
        }
    }
    $dupes = $children | Group-Object Name | Where-Object Count -gt 1
    if ($dupes) { throw "Manifest has duplicate names: $($dupes.Name -join ', ')" }
    [pscustomobject]@{
        Root         = Split-Path (Resolve-Path -LiteralPath $Path).Path -Parent
        Requirements = $raw['requirements']
        Env          = @(ConvertTo-FrameworkEnv $raw['env'])
        Children     = @($children)
        Getters      = @(ConvertTo-FrameworkGetters -List $raw['getters'] -ChildNames @($children | ForEach-Object Name))
    }
}

function Test-FrameworkRequirements {
    # Returns one row per requirement: Requirement, Wanted, Found, Ok, Note. Presence only: nothing here runs docker.
    # Each env entry is derived from the roots and set in this process (never User or Machine scope); a stale shell
    # value is noted, not failed. Only a missing file fails the row.
    param([Parameter(Mandatory)]$Manifest, [string]$FrameworkRoot, [string]$ReposRoot)
    $req = $Manifest.Requirements
    $rows = [System.Collections.Generic.List[object]]::new()
    $add = { param($Requirement, $Wanted, $Found, $Ok, $Note = '') $rows.Add([pscustomobject]@{ Requirement = $Requirement; Wanted = $Wanted; Found = $Found; Ok = [bool]$Ok; Note = $Note }) }

    $git = Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    $gitVer = if ($git) { ((& git --version) -replace '^git version\s*', '') } else { $null }
    & $add 'git' 'any' ($gitVer ?? 'missing') $git

    $psWanted = [version]$req.powershell
    & $add 'PowerShell' ">= $psWanted" "$($PSVersionTable.PSVersion)" ($PSVersionTable.PSVersion -ge $psWanted)

    foreach ($m in @(@{ Name = 'Pester'; Key = 'pester' }, @{ Name = 'powershell-yaml'; Key = 'powershell_yaml' })) {
        $wanted = [version]$req[$m.Key]
        $found = Get-Module -ListAvailable -Name $m.Name | Where-Object Version -eq $wanted | Select-Object -First 1
        $all = (Get-Module -ListAvailable -Name $m.Name | ForEach-Object { "$($_.Version)" } | Sort-Object -Unique) -join ', '
        & $add $m.Name "= $wanted" $(if ($all) { $all } else { 'missing' }) $found
    }

    $docker = Get-Command docker -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    & $add 'Docker' 'present' $(if ($docker) { $docker.Source } else { 'missing' }) $docker

    # Compose v2 ships as a CLI plugin next to docker or as a standalone docker-compose binary.
    $compose = Get-Command docker-compose -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    $composePath = if ($compose) { $compose.Source }
    if (-not $composePath -and $docker) {
        $exe = if ($IsWindows) { 'docker-compose.exe' } else { 'docker-compose' }
        $plugin = Join-Path (Split-Path (Split-Path $docker.Source)) 'cli-plugins' $exe
        if (Test-Path -LiteralPath $plugin) { $composePath = $plugin }
    }
    & $add 'Docker Compose' 'present' ($composePath ?? 'missing') $composePath

    # Derived files such as Claude.Chain's ledger. Reported, not created.
    foreach ($e in @(Set-FrameworkEnv -Manifest $Manifest -FrameworkRoot $FrameworkRoot -ReposRoot $ReposRoot)) {
        $note = if ($null -eq $e.Previous -or $e.Previous -eq '') { 'shell unset' } elseif ($e.Previous -ne $e.Value) { "shell had $($e.Previous)" } else { '' }
        & $add $e.Name $e.Wanted $e.Value (Test-Path -LiteralPath $e.Value -PathType Leaf) $note
    }

    # Each cloned child must be on its expected branch; one on a trap or feature branch fails its row, naming the branch.
    # A child not cloned yet passes (Sync clones it); Test and Status report it.
    if (-not $ReposRoot) { $ReposRoot = Join-Path ($FrameworkRoot ? $FrameworkRoot : $Manifest.Root) 'repos' }
    foreach ($b in @(Get-FrameworkBranchCheck -Manifest $Manifest -ReposRoot $ReposRoot)) {
        $note = if ($null -eq $b.Actual) { 'not cloned' } elseif (-not $b.Ok) { "on $($b.Actual), expected $($b.Expected)" } else { '' }
        & $add "$($b.Name) branch" $b.Expected ($b.Actual ?? 'not cloned') ($b.Ok -or $null -eq $b.Actual) $note
    }

    # Ok when this process can import the module, not merely when a copy is on disk.
    $ibVersions = @(@(Get-Module -ListAvailable -Name InvokeBuild) + @(Get-Module -Name InvokeBuild) |
            ForEach-Object { "$($_.Version)" } | Sort-Object -Unique)
    $ibOk = [bool](Get-Module -Name InvokeBuild)
    if (-not $ibOk) { try { Import-Module InvokeBuild -ErrorAction Stop; $ibOk = $true } catch { $ibOk = $false } }
    & $add 'Invoke-Build' 'present' $(if ($ibVersions) { $ibVersions -join ', ' } else { 'missing' }) $ibOk

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

function Get-ChildCheckout {
    # What a Test run tests: HEAD (null on a branch with no commits yet), whether the tree is dirty, and the branch.
    param([Parameter(Mandatory)][string]$Path)
    $head = Invoke-Git $Path rev-parse --verify --quiet HEAD -AllowFail
    $branch = @(Invoke-Git $Path branch --show-current)[0]
    [pscustomobject]@{
        Commit = if ($head.ExitCode -eq 0) { $head.Output[0] }
        Dirty  = @(Invoke-Git $Path status --porcelain | Where-Object { $_ }).Count -gt 0
        Branch = if ($branch) { $branch } else { '(detached)' }
    }
}

function Get-FrameworkBranchCheck {
    # One row per child: Name, Expected (the manifest's branch), Actual (the checked-out branch, '(detached)', or $null
    # when not cloned) and Ok. Reads only; nothing is checked out.
    param([Parameter(Mandatory)]$Manifest, [Parameter(Mandatory)][string]$ReposRoot)
    foreach ($c in $Manifest.Children) {
        $path = Join-Path $ReposRoot $c.Name
        $actual = if (Test-Path -LiteralPath (Join-Path $path '.git')) { (Get-ChildCheckout $path).Branch }
        [pscustomobject]@{ Name = $c.Name; Expected = $c.Branch; Actual = $actual; Ok = ($null -ne $actual -and $actual -eq $c.Branch) }
    }
}

function Get-BranchRefusal {
    # The note a run gives a child (or a getter rooted in one) whose checkout is not on its expected branch; $null when it is.
    param([Parameter(Mandatory)]$Child, [Parameter(Mandatory)]$Checkout)
    if ($Checkout.Branch -eq $Child.Branch) { return $null }
    "on branch $($Checkout.Branch), expected $($Child.Branch); not run"
}

function Format-ShortCommit {
    # Seven characters of the hash, and a trailing * when the tree was dirty; '-' when there is no commit.
    param([string]$Commit, [bool]$Dirty)
    if (-not $Commit) { return '-' }
    $Commit.Substring(0, [math]::Min(7, $Commit.Length)) + $(if ($Dirty) { '*' })
}

function Get-LatestRunRecord {
    # The <Name>.result.json in the newest run folder that has one, or $null. A record Verify wrote where Test had
    # left none (task: none) says nothing about what was tested and is passed over.
    param([string]$RunsRoot, [Parameter(Mandatory)][string]$Name)
    if (-not $RunsRoot -or -not (Test-Path -LiteralPath $RunsRoot)) { return $null }
    $folders = Get-ChildItem -LiteralPath $RunsRoot -Directory | Where-Object Name -match '^\d{8}-\d{6}-\d{3}$' | Sort-Object Name -Descending
    foreach ($f in $folders) {
        $file = Join-Path $f.FullName "$Name.result.json"
        if (-not (Test-Path -LiteralPath $file)) { continue }
        $record = Get-Content -LiteralPath $file -Raw | ConvertFrom-Json
        if ($record.task -ne 'none') { return $record }
    }
    $null
}

function Get-FrameworkStatus {
    # TestedAt reads the newest run record under $RunsRoot; Status runs nothing. 'stale' means HEAD has moved since.
    param([Parameter(Mandatory)]$Manifest, [Parameter(Mandatory)][string]$ReposRoot, [string]$RunsRoot)
    foreach ($c in $Manifest.Children) {
        $path = Join-Path $ReposRoot $c.Name
        $record = Get-LatestRunRecord -RunsRoot $RunsRoot -Name $c.Name
        $testedAt = if ($record -and $record.commit) { Format-ShortCommit $record.commit $false } else { '-' }
        if (-not (Test-Path -LiteralPath (Join-Path $path '.git'))) {
            [pscustomobject]@{ Name = $c.Name; Branch = '(not cloned)'; Ahead = $null; Behind = $null; Dirty = $null; LastCommit = $null; BuildScript = $null; TestedAt = $testedAt }
            continue
        }
        $head = Invoke-Git $path rev-parse --verify --quiet HEAD -AllowFail
        if ($testedAt -ne '-' -and ($head.ExitCode -ne 0 -or $record.commit -ne $head.Output[0])) { $testedAt += ' stale' }
        $branch = @(Invoke-Git $path rev-parse --abbrev-ref HEAD)[0]
        if ($branch -ne $c.Branch) { $branch += " (expected $($c.Branch))" }
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
            TestedAt    = $testedAt
        }
    }
}

function Read-JUnitCounts {
    param([string]$Path)
    # A file Pester left unfinished (its writer can stop mid-file) counts as no file.
    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) { return $null }
    try { [xml]$x = Get-Content -LiteralPath $Path -Raw } catch { return $null }
    [pscustomobject]@{
        Total   = $x.SelectNodes('//testcase').Count
        Failed  = $x.SelectNodes('//testcase[failure or error]').Count
        Skipped = $x.SelectNodes('//testcase[skipped]').Count
    }
}

function Read-PesterSummaryCounts {
    # For result_file: none. The last "Tests Passed: n, Failed: n, Skipped: n" line Pester printed into the log.
    param([string]$Path)
    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) { return $null }
    $text = (Get-Content -LiteralPath $Path -Raw) -replace '\x1b\[[0-9;]*[A-Za-z]', ''
    $m = [regex]::Matches($text, 'Tests Passed:\s*(\d+),\s*Failed:\s*(\d+),\s*Skipped:\s*(\d+)')
    if ($m.Count -eq 0) { return $null }
    $g = $m[$m.Count - 1].Groups
    $passed, $failed, $skipped = [int]$g[1].Value, [int]$g[2].Value, [int]$g[3].Value
    [pscustomobject]@{ Total = $passed + $failed + $skipped; Failed = $failed; Skipped = $skipped }
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
    # A native command starts in the current FileSystem location. The output is written to $LogFile only after the
    # process exits: a log held open for writing cannot be read, and a getter (Secrets) scans the Framework root,
    # .framework/ included, while it runs.
    Push-Location -LiteralPath $WorkingDirectory
    try {
        $output = & pwsh -NoProfile -NonInteractive -EncodedCommand $encoded *>&1
        $code = $LASTEXITCODE
        Set-Content -LiteralPath $LogFile -Value @($output | ForEach-Object { "$_" })
        $code
    }
    finally {
        Pop-Location
        foreach ($k in $saved.Keys) { [Environment]::SetEnvironmentVariable($k, $saved[$k]) }
    }
}

function Invoke-ChildTask {
    # Runs `Invoke-Build <Task>` in a fresh pwsh in the child's own folder, where Invoke-Build finds the child's
    # build script; the child's rules govern that process. Framework passes only the task name and, with -ResultFile,
    # the request for a JUnit file, in the way -ResultMode names:
    #   parameter   Invoke-Build <Task> -PesterConfiguration @{ TestResult = ... }, nothing else; no $PesterPreference
    #   preference  a $PesterPreference in that process adds the file; the child's own configuration is not touched
    #   none        nothing is passed
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Task,
        [Parameter(Mandatory)][string]$LogFile,
        [string]$ResultFile = '',
        [ValidateSet('parameter', 'preference', 'none')][string]$ResultMode = 'preference',
        [string]$PesterVersion = '',
        [hashtable]$Environment = @{}
    )
    $script = @'
param($Task, $ResultFile, $ResultMode, $PesterVersion)
if ($ResultFile -and $ResultMode -eq 'parameter') {
    Invoke-Build $Task -PesterConfiguration @{ TestResult = @{ Enabled = $true; OutputFormat = 'JUnitXml'; OutputPath = $ResultFile } }
    return
}
if ($ResultFile -and $ResultMode -eq 'preference') {
    if ($PesterVersion) { Import-Module Pester -RequiredVersion $PesterVersion -ErrorAction Stop } else { Import-Module Pester -ErrorAction Stop }
    $global:PesterPreference = New-PesterConfiguration
    $global:PesterPreference.TestResult.Enabled = $true
    $global:PesterPreference.TestResult.OutputFormat = 'JUnitXml'
    $global:PesterPreference.TestResult.OutputPath = $ResultFile
}
Invoke-Build $Task
'@
    Invoke-ChildProcess -WorkingDirectory $Path -Script $script -ArgumentList $Task, $ResultFile, $ResultMode, $PesterVersion -LogFile $LogFile -Environment $Environment
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
    #   no counts (JUnit or summary line)     -> FAIL
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
        $notes.Add("no test counts; Test exit $ExitCode")
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
    # Folders named in -Protect are never removed. With -PruneLog, a folder lacking -RequireFile (summary.json for
    # test runs) is removed only after a line naming it is appended to that log.
    param(
        [Parameter(Mandatory)][string]$Root,
        [int]$Keep = 5,
        [string[]]$Protect = @(),
        [string]$PruneLog,
        [string]$RequireFile = 'summary.json'
    )
    if ($Keep -lt 1) { throw "Keep must be at least 1." }
    if (-not (Test-Path -LiteralPath $Root)) { $null = New-Item -ItemType Directory -Path $Root -Force }
    do {
        $path = Join-Path $Root (Get-Date -Format 'yyyyMMdd-HHmmss-fff')
    } while (Test-Path -LiteralPath $path)
    $null = New-Item -ItemType Directory -Path $path
    $old = @(Get-ChildItem -LiteralPath $Root -Directory | Where-Object Name -match '^\d{8}-\d{6}-\d{3}$' |
            Sort-Object Name -Descending | Select-Object -Skip $Keep | Where-Object Name -notin @($Protect))
    foreach ($d in $old) {
        if ($PruneLog -and -not (Test-Path -LiteralPath (Join-Path $d.FullName $RequireFile))) {
            Add-Content -LiteralPath $PruneLog -Value "$(Get-Date -Format o) pruned $($d.FullName): no $RequireFile" -ErrorAction Stop
        }
        Remove-Item -LiteralPath $d.FullName -Recurse -Force
    }
    [pscustomobject]@{ Path = $path; Pruned = @($old | ForEach-Object Name) }
}

function Get-HeartbeatReusedRun {
    # The test-run folder name the newest heartbeat.json under $HeartbeatsRoot reused, or $null. Reads reused_run,
    # or test_run.folder from a record written before reused_run existed.
    param([string]$HeartbeatsRoot)
    if (-not $HeartbeatsRoot -or -not (Test-Path -LiteralPath $HeartbeatsRoot)) { return $null }
    $folders = Get-ChildItem -LiteralPath $HeartbeatsRoot -Directory | Where-Object Name -match '^\d{8}-\d{6}-\d{3}$' | Sort-Object Name -Descending
    foreach ($f in $folders) {
        $file = Join-Path $f.FullName 'heartbeat.json'
        if (-not (Test-Path -LiteralPath $file)) { continue }
        $hb = Get-Content -LiteralPath $file -Raw | ConvertFrom-Json
        if ($hb.PSObject.Properties['reused_run']) { return $hb.reused_run }
        if ($hb.test_run -and $hb.test_run.reused) { return $hb.test_run.folder }
        return $null
    }
    $null
}

function New-FrameworkTestRunFolder {
    # A test-runs folder under $StateRoot, pruned to $Keep: the run the newest heartbeat reused is kept, and a
    # summary-less folder is logged to <StateRoot>/prune.log before it goes.
    param([Parameter(Mandatory)][string]$StateRoot, [int]$Keep = 5)
    if (-not (Test-Path -LiteralPath $StateRoot)) { $null = New-Item -ItemType Directory -Path $StateRoot -Force }
    $protect = @(Get-HeartbeatReusedRun (Join-Path $StateRoot 'heartbeats') | Where-Object { $_ })
    New-FrameworkRunFolder -Root (Join-Path $StateRoot 'test-runs') -Keep $Keep -Protect $protect -PruneLog (Join-Path $StateRoot 'prune.log')
}

function Get-FrameworkTestPlan {
    # One row per child, then Claude.Framework: the task Test would run there, whether this run selects it, and
    # Verify: run (declared, and -Verify), heartbeat (declared; Heartbeat runs it) or not applicable.
    # -Full picks full_test_task where a child declares one, test_task elsewhere. An unknown -Only name throws,
    # listing the valid names, so a typo fails before any child runs.
    param([Parameter(Mandatory)]$Manifest, [string[]]$Only, [switch]$Full, [switch]$Verify)
    $valid = @($Manifest.Children | ForEach-Object Name) + 'Claude.Framework'
    $unknown = @($Only | Where-Object { $_ -and $_ -notin $valid })
    if ($unknown) { throw "Unknown -Only name(s): $($unknown -join ', '). Valid names: $($valid -join ', ')." }
    $selected = { param($n) -not $Only -or $n -in $Only }
    foreach ($c in $Manifest.Children) {
        $task = if (-not $c.BuildScript) { $null } elseif ($Full -and $c.Expect.FullTestTask) { $c.Expect.FullTestTask } else { $c.Expect.TestTask }
        $v = if (-not $c.Verify -or -not $c.BuildScript) { 'not applicable' } elseif ($Verify) { 'run' } else { 'heartbeat' }
        [pscustomobject]@{ Name = $c.Name; Task = $task; Selected = (& $selected $c.Name); Verify = $v; Child = $c }
    }
    [pscustomobject]@{ Name = 'Claude.Framework'; Task = 'SelfTest'; Selected = (& $selected 'Claude.Framework'); Verify = 'not applicable'; Child = $null }
}

function Write-ChildRunRecord {
    # <Name>.result.json next to the child's JUnit file: what was tested (commit, dirty, branch, when, which task),
    # what was expected, what happened. verify is ran, skipped (left to Heartbeat) or not applicable; verify_outcome
    # is reproduces or does not when it ran. env is each manifest env entry's value at run time; partial is true
    # when the run used -Only.
    param(
        [Parameter(Mandatory)][string]$RunFolder,
        [Parameter(Mandatory)]$Row,
        [Parameter(Mandatory)]$Checkout,
        [Parameter(Mandatory)][string]$TestedAt,
        $Expect,
        [System.Collections.IDictionary]$Env = [ordered]@{},
        [bool]$Partial
    )
    [ordered]@{
        name      = $Row.Name
        task      = $Row.Task
        commit    = $Checkout.Commit
        dirty     = $Checkout.Dirty
        branch    = $Checkout.Branch
        tested_at = $TestedAt
        result    = $Row.Result
        expected  = [ordered]@{ failures = $Expect.ExpectedFailures; no_tests = $Expect.NoTests; reason = $Expect.Reason }
        actual    = [ordered]@{ passed = $Row.Passed; failed = $Row.Failed; skipped = $Row.Skipped }
        verify    = switch ($Row.Verify) { 'not applicable' { 'not applicable' } { $_ -in 'heartbeat', 'not run' } { 'skipped' } default { 'ran' } }
        verify_outcome = if ($Row.Verify -in 'reproduces', 'does not') { $Row.Verify }
        seconds   = $Row.Seconds
        note      = $Row.Note
        env       = $Env
        partial   = $Partial
    } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $RunFolder "$($Row.Name).result.json")
}

function Invoke-FrameworkTest {
    # Runs every child that has a build script through its own test task in a fresh pwsh, then Framework's SelfTest.
    # -Only runs just those names; every child still gets a row. -Full runs full_test_task where one is declared.
    # Verify is Heartbeat's: a child that declares it shows 'heartbeat' unless -Verify runs it here.
    # Results, logs, JUnit files and one <Name>.result.json per tested child go to <StateRoot>/test-runs/<stamp>/;
    # StateRoot defaults to <FrameworkRoot>/.framework. Each env entry is set in this process first, so children
    # inherit the derived value, not the shell's. summary.json and every record carry env, and partial when -Only.
    param(
        [Parameter(Mandatory)]$Manifest,
        [Parameter(Mandatory)][string]$ReposRoot,
        [Parameter(Mandatory)][string]$FrameworkRoot,
        [string[]]$Only,
        [switch]$Full,
        [switch]$Verify,
        [int]$KeepRuns = 5,
        [string]$StateRoot
    )
    if (-not $StateRoot) { $StateRoot = Join-Path $FrameworkRoot '.framework' }
    $plan = @(Get-FrameworkTestPlan -Manifest $Manifest -Only $Only -Full:$Full -Verify:$Verify)
    $pester = [string]$Manifest.Requirements.pester
    $null = Set-FrameworkEnv -Manifest $Manifest -FrameworkRoot $FrameworkRoot -ReposRoot $ReposRoot
    $envRecord = Get-FrameworkEnvRecord -Manifest $Manifest
    $partial = [bool]@($Only | Where-Object { $_ }).Count
    $run = (New-FrameworkTestRunFolder -StateRoot $StateRoot -Keep $KeepRuns).Path
    $stamp = Split-Path $run -Leaf
    $row = {
        param($Name, $Result, $Expected, $Counts, $Verify, $Seconds, $Note, $Task = '-', $Checkout = $null)
        [pscustomobject]@{
            Name = $Name; Task = $Task; Result = $Result; Expected = $Expected
            Passed = if ($Counts) { $Counts.Total - $Counts.Failed - $Counts.Skipped }
            Failed = if ($Counts) { $Counts.Failed }
            Skipped = if ($Counts) { $Counts.Skipped }
            Verify = $Verify
            Commit = if ($Checkout) { Format-ShortCommit $Checkout.Commit $Checkout.Dirty } else { '-' }
            Seconds = $Seconds; Note = $Note
        }
    }
    $now = { [DateTimeOffset]::Now.ToString('yyyy-MM-ddTHH:mm:sszzz') }

    $rows = @(foreach ($p in $plan) {
        if ($p.Name -eq 'Claude.Framework') { continue }
        $c = $p.Child
        $e = $c.Expect
        $task = $p.Task
        $expected = if ($e.NoTests) { 'no tests' } elseif ($e.ExpectedFailures) { "$($e.ExpectedFailures) failed" } else { '0 failed' }
        $verifyCol = switch ($p.Verify) { 'run' { 'not run' } default { $_ } }
        if (-not $c.BuildScript) { & $row $c.Name 'no build script' '-' $null 'not applicable' $null $null; continue }
        if (-not $p.Selected) { & $row $c.Name 'skipped (-Only)' $expected $null $(if ($c.Verify) { 'not run' } else { 'not applicable' }) $null $null $task; continue }
        $path = Join-Path $ReposRoot $c.Name
        if (-not (Test-Path -LiteralPath (Join-Path $path '.git'))) { & $row $c.Name 'FAIL' $expected $null $verifyCol $null 'not cloned; run Sync' $task; continue }
        if (-not (Find-ChildBuildScript $path)) { & $row $c.Name 'FAIL' $expected $null $verifyCol $null 'manifest says build_script but none found' $task; continue }

        # Taken before tasks_before_test, so an Install that writes into the tree does not mark the run dirty.
        $checkout = Get-ChildCheckout $path
        $testedAt = & $now
        # A child on a trap or feature branch is never tested: the row fails and names the branch.
        $refusal = Get-BranchRefusal $c $checkout
        if ($refusal) {
            $r = & $row $c.Name 'FAIL' $expected $null $verifyCol $null $refusal $task $checkout
            Write-ChildRunRecord -RunFolder $run -Row $r -Checkout $checkout -TestedAt $testedAt -Expect $e -Env $envRecord -Partial $partial
            $r
            continue
        }
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $before = $null
        foreach ($t in $e.TasksBeforeTest) {
            $exit = Invoke-ChildTask -Path $path -Task $t -LogFile (Join-Path $run "$($c.Name).$t.log")
            if ($exit -ne 0) { $before = "$t failed (exit $exit); $task not run"; break }
        }
        if ($before) {
            $r = & $row $c.Name 'FAIL' $expected $null $verifyCol ([math]::Round($sw.Elapsed.TotalSeconds, 1)) $before $task $checkout
            Write-ChildRunRecord -RunFolder $run -Row $r -Checkout $checkout -TestedAt $testedAt -Expect $e -Env $envRecord -Partial $partial
            $r
            continue
        }

        # parameter children get <Name>.xml through -PesterConfiguration; preference children keep <Name>.junit.xml.
        $log = Join-Path $run "$($c.Name).log"
        $junit = switch ($c.ResultFile) {
            'parameter' { Join-Path $run "$($c.Name).xml" }
            'preference' { Join-Path $run "$($c.Name).junit.xml" }
            default { '' }
        }
        $exit = Invoke-ChildTask -Path $path -Task $task -LogFile $log -ResultFile $junit -ResultMode $c.ResultFile -PesterVersion $pester
        $source = $null
        $counts = if ($c.ResultFile -eq 'none') { Read-PesterSummaryCounts $log } else { Read-JUnitCounts $junit }
        if ($counts -and $c.ResultFile -eq 'none') { $source = 'counts from output' }
        if (-not $counts -and $c.ResultFile -ne 'none' -and (Test-Path -LiteralPath $junit)) {
            $counts = Read-PesterSummaryCounts $log
            if ($counts) { $source = "result file $(Split-Path $junit -Leaf) unreadable; counts from output" }
        }
        $files = if ($e.NoTests) { @(Get-ChildItem -LiteralPath $path -Recurse -File -Filter '*.Tests.ps1' -ErrorAction SilentlyContinue).Count } else { -1 }
        $verdict = Get-TestVerdict -ExitCode $exit -Counts $counts -Expect $e -TestFileCount $files
        $note = (@($source, $verdict.Note) | Where-Object { $_ }) -join '; '
        if ($verdict.Result -eq 'no-tests') {
            # The branch Sync left checked out, so the note cannot go stale the way a branch named in the reason did.
            $branch = $checkout.Branch
            $note += "; checkout on $branch"
        }
        if ($p.Verify -eq 'run') {
            $v = Invoke-ChildVerify -Name $c.Name -Path $path -Verify $c.Verify -RunFolder $run
            $verifyCol = $v.Verify
            $note = (@($note, $v.Note) | Where-Object { $_ }) -join '; '
        }
        $r = & $row $c.Name $verdict.Result $expected $counts $verifyCol ([math]::Round($sw.Elapsed.TotalSeconds, 1)) $note $task $checkout
        Write-ChildRunRecord -RunFolder $run -Row $r -Checkout $checkout -TestedAt $testedAt -Expect $e -Env $envRecord -Partial $partial
        $r
    })

    $self = $plan[-1]
    if ($self.Selected) {
        $checkout = Get-ChildCheckout $FrameworkRoot
        $testedAt = & $now
        $selfExpect = ConvertTo-ChildExpectation -Name 'Claude.Framework' -Block $null
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $junit = Join-Path $run 'Claude.Framework.junit.xml'
        $exit = Invoke-ChildTask -Path $FrameworkRoot -Task $self.Task -LogFile (Join-Path $run 'Claude.Framework.log') -ResultFile $junit `
            -PesterVersion $pester -Environment @{ FRAMEWORK_FIXTURE_ROOT = (Join-Path $StateRoot 'fixtures' $stamp) }
        $counts = Read-JUnitCounts $junit
        $verdict = Get-TestVerdict -ExitCode $exit -Counts $counts -Expect $selfExpect
        $r = & $row 'Claude.Framework' $verdict.Result '0 failed' $counts 'not applicable' ([math]::Round($sw.Elapsed.TotalSeconds, 1)) $verdict.Note $self.Task $checkout
        Write-ChildRunRecord -RunFolder $run -Row $r -Checkout $checkout -TestedAt $testedAt -Expect $selfExpect -Env $envRecord -Partial $partial
        $rows += $r
    }
    else { $rows += & $row 'Claude.Framework' 'skipped (-Only)' '0 failed' $null 'not applicable' $null $null $self.Task }

    [ordered]@{ partial = $partial; only = @($Only | Where-Object { $_ }); env = $envRecord; rows = $rows } |
        ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $run 'summary.json')
    $rows
}

function Read-TestRunSummary {
    # A test-run folder as Heartbeat reuses it: Rows, Partial, Env and HasSummary. summary.json is an object with rows,
    # or, before slice four-b, the bare rows array, where a 'skipped (-Only)' row marks the run partial. With no
    # summary.json the rows come from the result.json files Test left (task: none records excluded).
    param([Parameter(Mandatory)][string]$Path)
    $file = Join-Path $Path 'summary.json'
    if (Test-Path -LiteralPath $file) {
        $raw = Get-Content -LiteralPath $file -Raw | ConvertFrom-Json -NoEnumerate
        if ($raw -is [array]) {
            $rows = @($raw)
            return [pscustomobject]@{ Rows = $rows; Partial = [bool]@($rows | Where-Object Result -eq 'skipped (-Only)').Count; Env = $null; HasSummary = $true }
        }
        return [pscustomobject]@{ Rows = @($raw.rows); Partial = [bool]$raw.partial; Env = $raw.env; HasSummary = $true }
    }
    $rows = @(Get-ChildItem -LiteralPath $Path -Filter '*.result.json' -File | ForEach-Object {
            $r = Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json
            if ($r.task -ne 'none') { [pscustomobject]@{ Name = $r.name; Task = $r.task; Result = $r.result; Verify = $r.verify } }
        })
    [pscustomobject]@{ Rows = $rows; Partial = $true; Env = $null; HasSummary = $false }
}

function Get-StampFolders {
    # Folders under $Root named like a run stamp (yyyyMMdd-HHmmss-fff), newest first.
    param([string]$Root)
    if (-not $Root -or -not (Test-Path -LiteralPath $Root)) { return @() }
    @(Get-ChildItem -LiteralPath $Root -Directory | Where-Object Name -match '^\d{8}-\d{6}-\d{3}$' | Sort-Object Name -Descending)
}

function Get-CheckoutOrNone {
    # Get-ChildCheckout, or $null where $Path is missing or not in a git work tree.
    param([string]$Path)
    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) { return $null }
    if ((Invoke-Git $Path rev-parse --is-inside-work-tree -AllowFail).ExitCode -ne 0) { return $null }
    Get-ChildCheckout $Path
}

function Read-RunRecordFields {
    # Fields of a <Name>.result.json, read through JsonNode so tested_at stays the string it was written as.
    param([Parameter(Mandatory)][string]$Path)
    $n = [System.Text.Json.Nodes.JsonNode]::Parse((Get-Content -LiteralPath $Path -Raw))
    $o = [ordered]@{}
    foreach ($k in 'name', 'task', 'commit', 'dirty', 'branch', 'tested_at', 'result', 'verify', 'verify_outcome') {
        $v = if ($n.AsObject().ContainsKey($k)) { $n[$k] }
        $o[$k] = if ($null -eq $v) { $null } elseif ($k -eq 'dirty') { $v.ToString() -eq 'true' } else { $v.ToString() }
    }
    $o
}

function Set-RunRecordVerify {
    # Marks a child's run record verify: ran, with the outcome and the heartbeat that ran it. Other fields are untouched.
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Outcome, [Parameter(Mandatory)][string]$By)
    $n = [System.Text.Json.Nodes.JsonNode]::Parse((Get-Content -LiteralPath $Path -Raw))
    $n['verify'] = [System.Text.Json.Nodes.JsonValue]::Create([string]'ran')
    $n['verify_outcome'] = [System.Text.Json.Nodes.JsonValue]::Create([string]$Outcome)
    $n['verify_by'] = [System.Text.Json.Nodes.JsonValue]::Create([string]$By)
    Set-Content -LiteralPath $Path -Value $n.ToJsonString([System.Text.Json.JsonSerializerOptions]@{ WriteIndented = $true })
}

function Get-GetterInvocation {
    # A getter entry's parameters with {out}, {previous}, {framework_root} and {repos_root} filled in, and the line
    # that records what ran.
    param([Parameter(Mandatory)]$Entry, [Parameter(Mandatory)][hashtable]$Values)
    $params = [ordered]@{}
    foreach ($k in $Entry.Parameters.Keys) { $params[$k] = Expand-FrameworkPlaceholder $Entry.Parameters[$k] $Values }
    $parts = foreach ($k in $params.Keys) {
        $v = $params[$k]
        if ($v -is [bool]) { if ($v) { "-$k" } else { "-${k}:`$false" } }
        else { "-$k '" + ("$v" -replace "'", "''") + "'" }
    }
    [pscustomobject]@{ Parameters = $params; Line = (@("& ./$($Entry.Script)") + @($parts)) -join ' ' }
}

function Invoke-FrameworkHeartbeat {
    # Test (or, with -SkipUp, the newest test run reused), then Verify for every child that declares it, then each
    # getter in its own fresh pwsh rooted in its path under repos/, its Pester when tests: true, Diff last against the
    # previous heartbeat. Getters run after the getters they need, ties broken by order; an unknown need or a cycle
    # refuses the run before it starts. Each getter ends ok, failed, refused or skipped; one whose need failed or
    # refused is skipped with "needs <x>". A failing getter is recorded and the next one runs. Output, logs and one
    # <getter>.result.json per getter go to .framework/heartbeats/<stamp>/, which keeps the latest -KeepRuns folders;
    # heartbeat.json at its root is the record. -Only names children and/or getters; anything not named is skipped.
    # Failures lists every getter failed or refused, child Test FAIL and Verify 'does not'; the build fails the task on any.
    # A reused run (-SkipUp, or -Only naming no child) must be the newest test run, with summary.json and not partial;
    # -AllowPartial accepts a partial or summary-less one and the record says partial with the children left untested.
    # StateRoot (default <FrameworkRoot>/.framework) holds test-runs/ and heartbeats/.
    param(
        [Parameter(Mandatory)]$Manifest,
        [Parameter(Mandatory)][string]$ReposRoot,
        [Parameter(Mandatory)][string]$FrameworkRoot,
        [string[]]$Only,
        [switch]$Full,
        [switch]$SkipUp,
        [switch]$AllowPartial,
        [int]$KeepRuns = 5,
        [string]$StateRoot
    )
    if (-not $StateRoot) { $StateRoot = Join-Path $FrameworkRoot '.framework' }
    # Refuses here, before anything runs or is written, on an unknown need or a cycle.
    $getters = @(Get-FrameworkGetterOrder $Manifest.Getters)
    $childNames = @($Manifest.Children | ForEach-Object Name) + 'Claude.Framework'
    $valid = $childNames + @($getters | ForEach-Object Name)
    $unknown = @($Only | Where-Object { $_ -and $_ -notin $valid })
    if ($unknown) { throw "Unknown -Only name(s): $($unknown -join ', '). Valid names: $($valid -join ', ')." }
    $selected = { param($n) -not $Only -or $n -in $Only }
    $onlyChildren = @($Only | Where-Object { $_ -in $childNames })
    $pester = [string]$Manifest.Requirements.pester
    $runsRoot = Join-Path $StateRoot 'test-runs'
    $hbRoot = Join-Path $StateRoot 'heartbeats'
    $now = { [DateTimeOffset]::Now.ToString('yyyy-MM-ddTHH:mm:sszzz') }
    $null = Set-FrameworkEnv -Manifest $Manifest -FrameworkRoot $FrameworkRoot -ReposRoot $ReposRoot
    $envRecord = Get-FrameworkEnvRecord -Manifest $Manifest
    # The names a full Test runs: children with a build script, and Claude.Framework.
    $testable = @(@($Manifest.Children | Where-Object BuildScript | ForEach-Object Name) + 'Claude.Framework')
    $untestedIn = { param($Rows) @($testable | Where-Object { $n = $_; -not ($Rows | Where-Object { $_.Name -eq $n -and $_.Result -ne 'skipped (-Only)' }) }) }

    # Checked before the heartbeat folder exists, so a run with nothing to reuse, or one refused, leaves nothing behind.
    $reuse = if ($SkipUp) { '-SkipUp' } elseif ($Only -and -not $onlyChildren) { '-Only names no child' }
    $usedRun = $null
    $summary = $null
    if ($reuse) {
        $usedRun = Get-StampFolders $runsRoot | Select-Object -First 1
        if (-not $usedRun) { throw "Heartbeat ($reuse): no test run under $runsRoot to reuse; run Invoke-Build Test first." }
        $summary = Read-TestRunSummary $usedRun.FullName
        $why = if (-not $summary.HasSummary) { 'has no summary.json' } elseif ($summary.Partial) { 'is partial (Test ran with -Only)' }
        if ($why -and -not $AllowPartial) {
            throw "Heartbeat ($reuse): the newest test run $($usedRun.FullName) $why. Run Invoke-Build Test, then Heartbeat -SkipUp; or pass -AllowPartial to reuse it and record it as partial."
        }
    }

    # When each weekly getter last ran, from the heartbeats kept so far.
    $lastRan = @{}
    foreach ($f in Get-StampFolders $hbRoot) {
        $file = Join-Path $f.FullName 'heartbeat.json'
        if (-not (Test-Path -LiteralPath $file)) { continue }
        foreach ($g in @((Get-Content -LiteralPath $file -Raw | ConvertFrom-Json).getters)) {
            if ((Get-GetterOutcome $g.result) -in 'ok', 'failed', 'refused' -and -not $lastRan.ContainsKey($g.name)) { $lastRan[$g.name] = [datetimeoffset]$g.tested_at }
        }
    }

    $folder = (New-FrameworkRunFolder -Root $hbRoot -Keep $KeepRuns).Path
    $stamp = Split-Path $folder -Leaf
    $previous = Get-StampFolders $hbRoot | Where-Object Name -ne $stamp | Select-Object -First 1

    if (-not $reuse) {
        $null = Invoke-FrameworkTest -Manifest $Manifest -ReposRoot $ReposRoot -FrameworkRoot $FrameworkRoot -Only $onlyChildren -Full:$Full -KeepRuns $KeepRuns -StateRoot $StateRoot
        $usedRun = Get-StampFolders $runsRoot | Select-Object -First 1
        $summary = Read-TestRunSummary $usedRun.FullName
    }
    $testRows = @($summary.Rows)
    $partial = [bool]$summary.Partial
    $untested = if ($partial) { & $untestedIn $testRows } else { @() }

    $verifyRows = @(foreach ($c in @($Manifest.Children | Where-Object { $_.Verify -and $_.BuildScript })) {
        $vr = { param($Result, $Commit, $Seconds, $Note) [pscustomobject]@{ Name = $c.Name; Verify = $Result; Commit = $Commit; Seconds = $Seconds; Note = $Note } }
        if (-not (& $selected $c.Name)) { & $vr 'skipped (-Only)' '-' $null $null; continue }
        $path = Join-Path $ReposRoot $c.Name
        if (-not (Test-Path -LiteralPath (Join-Path $path '.git'))) { & $vr 'not run' '-' $null 'not cloned; run Sync'; continue }
        $checkout = Get-ChildCheckout $path
        $refusal = Get-BranchRefusal $c $checkout
        if ($refusal) { & $vr 'refused' (Format-ShortCommit $checkout.Commit $checkout.Dirty) $null $refusal; continue }
        $verifyRoot = Join-Path $folder 'verify'
        $null = New-Item -ItemType Directory -Path $verifyRoot -Force
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $v = Invoke-ChildVerify -Name $c.Name -Path $path -Verify $c.Verify -RunFolder $verifyRoot
        $note = $v.Note
        $record = Join-Path $usedRun.FullName "$($c.Name).result.json"
        if (Test-Path -LiteralPath $record) { Set-RunRecordVerify -Path $record -Outcome $v.Verify -By "heartbeat $stamp" }
        else {
            # Test did not run this child here (-Only); the record says so with task: none and carries the verify.
            [ordered]@{
                name           = $c.Name
                task           = 'none'
                commit         = $checkout.Commit
                dirty          = $checkout.Dirty
                branch         = $checkout.Branch
                tested_at      = $null
                result         = 'not tested'
                verify         = 'ran'
                verify_outcome = $v.Verify
                verify_by      = "heartbeat $stamp"
                env            = $envRecord
                partial        = $partial
            } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $record
            $note += "; test run $($usedRun.Name) had no $($c.Name).result.json; wrote one with task: none"
        }
        & $vr $v.Verify (Format-ShortCommit $checkout.Commit $checkout.Dirty) ([math]::Round($sw.Elapsed.TotalSeconds, 1)) $note
    })

    $getterScript = @'
param($ScriptPath, $ParamsJson)
$p = if ($ParamsJson) { $ParamsJson | ConvertFrom-Json -AsHashtable } else { @{} }
$global:LASTEXITCODE = 0
& (Join-Path $PWD $ScriptPath) @p
if ($LASTEXITCODE) { exit $LASTEXITCODE }
'@
    $testScript = @'
param($TestsPath, $ResultFile, $PesterVersion)
if ($PesterVersion) { Import-Module Pester -RequiredVersion $PesterVersion -ErrorAction Stop } else { Import-Module Pester -ErrorAction Stop }
$c = New-PesterConfiguration
$c.Run.Path = $TestsPath
$c.Run.PassThru = $true
$c.TestResult.Enabled = $true
$c.TestResult.OutputFormat = 'JUnitXml'
$c.TestResult.OutputPath = $ResultFile
$r = Invoke-Pester -Configuration $c
if ($r.FailedCount -or $r.Result -ne 'Passed') { exit 1 }
'@
    $graded = Get-CheckoutOrNone $FrameworkRoot
    $diffVerdict = $null
    $records = [System.Collections.Generic.List[object]]::new()
    # Getters that failed or refused, or were skipped for a need of theirs; anything needing one is skipped.
    $blocked = [System.Collections.Generic.HashSet[string]]::new()
    $getterRows = @(foreach ($g in $getters) {
        $testedAt = & $now
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $path = if ($g.Path) { Join-Path $ReposRoot $g.Path }
        $checkout = Get-CheckoutOrNone $path
        # A getter rooted in a child's folder runs only from that child's expected branch.
        $owner = if ($g.Path) { $Manifest.Children | Where-Object Name -eq (@($g.Path -split '[\\/]')[0]) | Select-Object -First 1 }
        $refusal = if ($owner -and $checkout) { Get-BranchRefusal $owner $checkout }
        $unmet = @(@($g.Needs) | Where-Object { $blocked.Contains($_) })
        $line = $null; $counts = $null; $seconds = $null; $verdictLine = $null
        # Every getter ends in exactly one of ok, failed, refused or skipped.
        $result, $note = if (-not (& $selected $g.Name)) { 'skipped', '-Only' }
        elseif ($unmet) { 'skipped', "needs $($unmet -join ', ')" }
        elseif (-not $g.Entry) { 'skipped', ((@('entry: none', $g.Note) | Where-Object { $_ }) -join '; ') }
        elseif (-not (Test-Path -LiteralPath $path -PathType Container)) { 'skipped', "repos/$($g.Path) not found" }
        elseif ($refusal) { 'refused', "$($owner.Name) $refusal" }
        elseif ($g.Cadence -eq 'weekly' -and $g.Name -notin @($Only) -and $lastRan.ContainsKey($g.Name) -and $lastRan[$g.Name] -gt [DateTimeOffset]::Now.AddDays(-7)) {
            'skipped', "weekly; last ran $($lastRan[$g.Name].ToString('yyyy-MM-dd HH:mm'))"
        }
        else { $null, $null }

        if (-not $result) {
            $out = Join-Path $folder $g.Name
            $null = New-Item -ItemType Directory -Path $out -Force
            $inv = Get-GetterInvocation -Entry $g.Entry -Values @{
                out = $out; previous = if ($previous) { $previous.FullName } else { '' }; framework_root = $FrameworkRoot; repos_root = $ReposRoot
            }
            $line = $inv.Line
            $notes = [System.Collections.Generic.List[string]]::new()
            if ($g.Note) { $notes.Add($g.Note) }
            $exit = Invoke-ChildProcess -WorkingDirectory $path -Script $getterScript -ArgumentList $g.Entry.Script, ($inv.Parameters | ConvertTo-Json -Compress -Depth 4) -LogFile (Join-Path $folder "$($g.Name).log")
            if ($exit -ne 0) { $notes.Add("entry exit $exit") }
            # The last line the entry printed. A non-zero exit whose last line begins with "refused" is a refusal, and
            # that line is its reason; its tests and outputs are not checked.
            $printed = @(Get-Content -LiteralPath (Join-Path $folder "$($g.Name).log") -ErrorAction SilentlyContinue | Where-Object { "$_".Trim() })
            $lastLine = if ($printed) { "$($printed[-1])".Trim() }
            $refused = $exit -ne 0 -and $lastLine -like 'refused*'
            $verdict = $null
            if ($g.Tests -and -not $refused) {
                $junit = Join-Path $out "$($g.Name).junit.xml"
                $testsPath = if (Test-Path -LiteralPath (Join-Path $path 'tests') -PathType Container) { Join-Path $path 'tests' } else { $path }
                $texit = Invoke-ChildProcess -WorkingDirectory $path -Script $testScript -ArgumentList $testsPath, $junit, $pester -LogFile (Join-Path $folder "$($g.Name).tests.log")
                $counts = Read-JUnitCounts $junit
                $files = if ($g.Expect.NoTests) { @(Get-ChildItem -LiteralPath $path -Recurse -File -Filter '*.Tests.ps1' -ErrorAction SilentlyContinue).Count } else { -1 }
                $verdict = Get-TestVerdict -ExitCode $texit -Counts $counts -Expect $g.Expect -TestFileCount $files
                if ($verdict.Note) { $notes.Add("tests $($verdict.Result): $($verdict.Note)") }
            }
            $missing = @(if (-not $refused) { $g.Outputs | Where-Object { -not (Test-Path -LiteralPath (Join-Path $out $_) -PathType Leaf) } })
            if ($missing) { $notes.Add("missing output(s) under {out}: $($missing -join ', ')") }
            if ($refused) { $notes.Clear(); $notes.Add($lastLine) }
            $result = if ($refused) { 'refused' } elseif ($exit -ne 0 -or $missing -or ($verdict -and $verdict.Result -eq 'FAIL')) { 'failed' } else { 'ok' }
            # The verdict line: the first line of verdict.txt in the getter's output, else the last line it printed.
            $vf = Join-Path $out 'verdict.txt'
            $verdictLine = $lastLine
            if (Test-Path -LiteralPath $vf) {
                $vlines = @(Get-Content -LiteralPath $vf | Where-Object { "$_".Trim() })
                $verdictLine = if ($vlines) { "$($vlines[0])".Trim() }
            }
            if ($g.Name -eq 'Diff') {
                if (-not $previous) { $notes.Add('no previous heartbeat') }
                $diffVerdict = $verdictLine
            }
            $note = $notes -join '; '
            $seconds = [math]::Round($sw.Elapsed.TotalSeconds, 1)
        }

        $rec = [ordered]@{
            name          = $g.Name
            result        = $result
            getter_commit = if ($checkout) { $checkout.Commit }
            getter_dirty  = if ($checkout) { $checkout.Dirty }
            graded_commit = if ($graded) { $graded.Commit }
            graded_dirty  = if ($graded) { $graded.Dirty }
            passed        = if ($counts) { $counts.Total - $counts.Failed - $counts.Skipped }
            failed        = if ($counts) { $counts.Failed }
            seconds       = $seconds
            verdict       = $verdictLine
            note          = $note
            tested_at     = $testedAt
            entry_line    = $line
            cadence       = $g.Cadence
            order         = $g.Order
            needs         = @($g.Needs)
        }
        $rec | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $folder "$($g.Name).result.json")
        $records.Add($rec)
        if ($result -in 'failed', 'refused' -or ($result -eq 'skipped' -and $unmet)) { $null = $blocked.Add($g.Name) }
        [pscustomobject]@{
            Name         = $g.Name
            Needs        = if ($g.Needs) { $g.Needs -join ', ' } else { '-' }
            Result       = $result
            GetterCommit = if ($checkout) { Format-ShortCommit $checkout.Commit $checkout.Dirty } else { '-' }
            GradedCommit = if ($graded) { Format-ShortCommit $graded.Commit $graded.Dirty } else { '-' }
            Passed       = $rec.passed
            Failed       = $rec.failed
            Seconds      = $seconds
            Verdict      = $verdictLine
            Note         = $note
        }
    })

    $children = @(foreach ($c in $Manifest.Children) {
        $file = Join-Path $usedRun.FullName "$($c.Name).result.json"
        if (Test-Path -LiteralPath $file) { Read-RunRecordFields $file; continue }
        $row = $testRows | Where-Object Name -eq $c.Name | Select-Object -First 1
        [ordered]@{ name = $c.Name; commit = $null; result = if ($row) { $row.Result } else { 'no record' } }
    })
    $failures = @(
        @($testRows | Where-Object Result -eq 'FAIL' | ForEach-Object { "test $($_.Name)" })
        @($verifyRows | Where-Object Verify -in 'does not', 'refused' | ForEach-Object { "verify $($_.Name)" })
        @($getterRows | Where-Object Result -in 'failed', 'refused' | ForEach-Object { "getter $($_.Name)" })
    )
    $outcomes = [ordered]@{}
    foreach ($o in 'ok', 'failed', 'refused', 'skipped') { $outcomes[$o] = @($getterRows | Where-Object Result -eq $o).Count }
    $testRun = [ordered]@{ folder = $usedRun.Name; reused = [bool]$reuse; reason = $reuse }
    [ordered]@{
        stamp      = $stamp
        framework  = [ordered]@{ commit = if ($graded) { $graded.Commit }; dirty = if ($graded) { $graded.Dirty }; branch = if ($graded) { $graded.Branch } }
        test_run   = $testRun
        reused_run = if ($reuse) { $usedRun.Name }
        partial    = $partial
        untested   = @($untested)
        env        = $envRecord
        previous   = if ($previous) { $previous.Name }
        children  = $children
        verify    = @($verifyRows | ForEach-Object { [ordered]@{ name = $_.Name; verify = $_.Verify; commit = $_.Commit; seconds = $_.Seconds; note = $_.Note } })
        getters   = @($records)
        getter_outcomes = $outcomes
        diff      = $diffVerdict
        failures  = $failures
    } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $folder 'heartbeat.json')

    [pscustomobject]@{
        Folder     = $folder
        Stamp      = $stamp
        TestRun    = [pscustomobject]$testRun
        Partial    = $partial
        Untested   = @($untested)
        Env        = $envRecord
        TestRows   = $testRows
        VerifyRows = $verifyRows
        Getters    = $getterRows
        Outcomes   = [pscustomobject]$outcomes
        Diff       = $diffVerdict
        Failures   = $failures
    }
}

function Invoke-FrameworkBootstrap {
    # Runs the run-once script unless <StateRoot>/bootstrap.done exists; -Force runs it again. The marker is
    # written only after the script succeeds, and records when it ran and which script. -Environment (name to value,
    # the resolved env entries) is passed to the script only when it holds something. Lines is what the script printed.
    param(
        [Parameter(Mandatory)][string]$StateRoot,
        [Parameter(Mandatory)][string]$Script,
        [System.Collections.IDictionary]$Environment,
        [switch]$Force
    )
    $marker = Join-Path $StateRoot 'bootstrap.done'
    if ((Test-Path -LiteralPath $marker) -and -not $Force) {
        return [pscustomobject]@{ Action = 'skipped'; Detail = "marker exists: $(Get-Content -LiteralPath $marker -Raw)".Trim(); Lines = @() }
    }
    if (-not (Test-Path -LiteralPath $StateRoot)) { $null = New-Item -ItemType Directory -Path $StateRoot -Force }
    $splat = @{ StateRoot = $StateRoot }
    if ($Environment -and $Environment.Count) { $splat.Environment = $Environment }
    $lines = @(& $Script @splat | ForEach-Object { "$_" })
    Set-Content -LiteralPath $marker -Value "$(Get-Date -Format o) $Script"
    [pscustomobject]@{ Action = if ($Force) { 'ran (-Force)' } else { 'ran' }; Detail = "marker written: $marker"; Lines = $lines }
}

Export-ModuleMember -Function Get-FrameworkManifest, Test-FrameworkRequirements, Sync-Framework, Sync-FrameworkChild,
    Get-FrameworkStatus, Get-FrameworkTestPlan, Get-FrameworkBranchCheck, Invoke-FrameworkTest, Invoke-ChildTask, Invoke-ChildVerify, Get-TestVerdict,
    New-FrameworkRunFolder, Invoke-FrameworkBootstrap, Invoke-FrameworkHeartbeat, Resolve-FrameworkEnv, Get-HeartbeatReusedRun,
    Get-FrameworkGetterOrder, Get-FrameworkGetterOutcomes
