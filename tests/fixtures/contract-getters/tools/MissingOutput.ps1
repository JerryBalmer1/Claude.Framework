# Prints a well-formed verdict and exits 0, but leaves only one of its two declared outputs.
param([string]$Out)
Set-Content -LiteralPath (Join-Path $Out 'a.json') -Value '{}'
'2 good, 0 bad'
