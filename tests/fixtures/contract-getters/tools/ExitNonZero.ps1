# Writes its outputs and prints a well-formed verdict, then exits 3: the exit code alone must fail it.
param([string]$Out)
Set-Content -LiteralPath (Join-Path $Out 'a.json') -Value '{}'
Set-Content -LiteralPath (Join-Path $Out 'a.md') -Value '# a'
'2 good, 0 bad'
exit 3
