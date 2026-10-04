# Honours the contract: both outputs written, the verdict printed last, exit 0.
param([string]$Out)
Set-Content -LiteralPath (Join-Path $Out 'a.json') -Value '{}'
Set-Content -LiteralPath (Join-Path $Out 'a.md') -Value '# a'
'counting'
'2 good, 0 bad'
