# Heartbeat 20261004-025134-418: Signs printed its real verdict, then an exception, then exited 0.
param([string]$Out)
Set-Content -LiteralPath (Join-Path $Out 'signs.json') -Value '{}'
Set-Content -LiteralPath (Join-Path $Out 'signs.md') -Value '# signs'
'12 signed, 0 unsigned, 0 dead, 0 unreadable, 7 wired, 0 missing, ok'
Write-Error 'MethodInvocationException: Exception calling "Deserialize" with "1" argument(s): "found invalid mapping."' -ErrorAction Continue
exit 0
