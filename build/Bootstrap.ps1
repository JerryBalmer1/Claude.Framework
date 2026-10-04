#Requires -Version 7.4
# Framework's run-once setup. Invoke-FrameworkBootstrap calls it only when .framework/bootstrap.done is absent, or with
# -Force. It persists each env entry from framework.yaml (resolved, name to value) to User scope, so shells opened
# later inherit it. This is the only place the build writes outside the repo. A differing Machine-scope value is
# reported, never cleared.
param(
    [Parameter(Mandatory)][string]$StateRoot,
    [System.Collections.IDictionary]$Environment = @{}
)

$log = Join-Path $StateRoot 'bootstrap.log'
foreach ($name in $Environment.Keys) {
    $value = [string]$Environment[$name]
    [Environment]::SetEnvironmentVariable($name, $value, 'User')
    "wrote User $name=$value"
    $machine = [Environment]::GetEnvironmentVariable($name, 'Machine')
    if ($machine -and $machine -ne $value) { "Machine scope has $name=$machine (differs; left as is)" }
}
Add-Content -LiteralPath $log -Value "$(Get-Date -Format o) bootstrap ran; $($Environment.Count) env var(s) written to User scope"
