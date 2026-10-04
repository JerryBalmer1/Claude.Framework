# Writes its outputs and exits 0, but its last line is not the shape the row's verdict regex names.
param([string]$Out)
Set-Content -LiteralPath (Join-Path $Out 'a.json') -Value '{}'
Set-Content -LiteralPath (Join-Path $Out 'a.md') -Value '# a'
'2 good'
