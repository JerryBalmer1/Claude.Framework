# Placement — bundle 2 (2026-10-02)

Second bundle from the same evening. Drop `docs/` onto `C:\__Code\Claude.Framework\`. If bundle 1 (Claude.Framework-docs-2026-10-01.zip) was already unpacked, this bundle **overwrites three files it shipped**: docs/design/open-paths.md (items 11–13 added, nothing removed), docs/design/index.md (one row and one reading-order line added), docs/standard/page.shell.html (figure CSS added; existing pages unaffected). Everything else is new.

| File | Status |
|---|---|
| docs/design/everyone-gets-an-identity.md | new |
| docs/design/everyone-gets-an-identity.html | new; five inline SVG figures, no external assets |
| docs/design/open-paths.md | overwrites bundle 1 (additive) |
| docs/design/index.md | overwrites bundle 1 (additive) |
| docs/sessions/2026-10-02-spawn-budget-and-identity.md + .html | new |
| docs/standard/page.shell.html | overwrites bundle 1 (additive CSS) |

Bundle 1's other files are included unchanged so the folder stands alone if bundle 1 was never unpacked.

## Commit (Jerry runs; covers both bundles if bundle 1 is still uncommitted)

```powershell
Set-Location 'C:\__Code\Claude.Framework'
git add docs/design docs/standard docs/sessions
git status --short
git commit -m 'Design: everyone gets an identity (spawn budget, custody clause, scorer ledger, ecology, prior art); open paths 11-13; 2026-10-02 session page; figure CSS in shell'
git push
git log --oneline '@{upstream}..HEAD'
```
