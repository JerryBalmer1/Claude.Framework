#Requires -Version 7.4
# Placeholder for Framework's run-once setup. It does nothing yet but record that it ran.
# Invoke-FrameworkBootstrap calls it only when .framework/bootstrap.done is absent, or with -Force.
param([Parameter(Mandatory)][string]$StateRoot)

Add-Content -LiteralPath (Join-Path $StateRoot 'bootstrap.log') -Value "$(Get-Date -Format o) bootstrap placeholder ran"
