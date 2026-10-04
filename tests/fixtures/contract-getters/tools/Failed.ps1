# Ends on "failed: <message>" but exits 0 with its outputs written: the failed line alone must fail it.
param([string]$Out)
Set-Content -LiteralPath (Join-Path $Out 'a.json') -Value '{}'
Set-Content -LiteralPath (Join-Path $Out 'a.md') -Value '# a'
'failed: could not read framework.yaml'
exit 0
