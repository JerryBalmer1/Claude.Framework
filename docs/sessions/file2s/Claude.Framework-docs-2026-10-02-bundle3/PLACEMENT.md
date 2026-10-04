# Placement — bundle 3 (2026-10-02, late)

Unzip and drop `docs/` onto `C:\__Code\Claude.Framework\`. Assumes bundles 1 and 2 are already in place.

New: docs/design/virtue-without-the-feeling.md + .html
Additive overwrites: docs/design/open-paths.md (items 14, 15), docs/design/index.md (row + reading order), docs/sessions/2026-10-02-spawn-budget-and-identity.md + .html (late-night section).

```powershell
Set-Location 'C:\__Code\Claude.Framework'
git add docs/design docs/sessions
git status --short
git commit -m 'Design: virtue without the feeling (triad as receipt patterns, sacrifice as pair, honor open); open paths 14-15; session page addendum'
git push
git log --oneline '@{upstream}..HEAD'
```
