# Placement

Drop the `docs/` folder from this bundle onto `C:\__Code\Claude.Framework\`. Nothing here overwrites an existing file; `docs/design/` and `docs/standard/` are new folders, `docs/sessions/` gains two files beside the 2026-09-30 handoff.

| File | Goes to |
|---|---|
| docs/design/index.md | docs/design/index.md |
| docs/design/the-stitch.md | docs/design/ |
| docs/design/graph-and-diagram.md | docs/design/ |
| docs/design/readers-see-frames-not-sessions.md + .html | docs/design/ |
| docs/design/compression-and-weights.md | docs/design/ |
| docs/design/mortality-and-lineage.md | docs/design/ |
| docs/design/open-paths.md | docs/design/ |
| docs/sessions/2026-10-01-ledger-continuity.md + .html | docs/sessions/ |
| docs/standard/page.shell.html | docs/standard/ (first file of the docs standard; the two HTML pages were generated from it) |

The HTML shell was built without sight of the 2026-09-30 altitude-map page, so it follows the same shape (dated page, numbered bands, pointers band) but not necessarily the same CSS. If the two should match, the shell is the only file to change; regenerate the two pages from it.

Tone: written for a reader who was not in the room. Parables kept; nothing else from the evening carried over.

## Review prompt (read-only, optional)

```
Step 0. List your working directories. Root must be C:\__Code\Claude.Framework; read CLAUDE.md; if either fails, stop and say so.

Step 1. Read docs/design/index.md and every file it links. Read docs/sessions/2026-10-01-ledger-continuity.md. Report: any claim about a repo's current state that contradicts what is actually in repos/<child> (for example, a schema field described as absent that exists, or a file path that does not resolve). Quote file and line.

Step 2. Check every relative link in docs/design/*.md and docs/sessions/2026-10-01-ledger-continuity.*  resolves on disk. List the ones that do not.

Step 3. Do not edit anything. Stop and print the report as a single block.
```

## Commit (Jerry runs)

```powershell
Set-Location 'C:\__Code\Claude.Framework'
git add docs/design docs/standard docs/sessions/2026-10-01-ledger-continuity.md docs/sessions/2026-10-01-ledger-continuity.html
git status --short
git commit -m 'Design notes from 2026-10-01 session: stitch, graph/diagram, frames-not-sessions, compression, mortality/lineage, open paths; session page; first page shell'
git push
git log --oneline '@{upstream}..HEAD'
```
