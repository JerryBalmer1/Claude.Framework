#Requires -Version 7.4
# Fixtures are local bare repos under .framework/test-runs/<stamp>/ (gitignored, inside the repo). No network.
# The fixture folders are left in place after the run: agents here do not delete.

BeforeAll {
    $FrameworkRoot = Split-Path $PSScriptRoot -Parent
    Import-Module (Join-Path $FrameworkRoot 'build' 'Framework.Build.psm1') -Force

    $RunRoot = Join-Path $FrameworkRoot '.framework' 'test-runs' (Get-Date -Format 'yyyyMMdd-HHmmss-fff')
    $null = New-Item -ItemType Directory -Path $RunRoot -Force

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
