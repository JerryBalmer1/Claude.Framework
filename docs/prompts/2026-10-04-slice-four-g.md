[WORKSPACE: Claude.Framework] — slice four-g: Dirty, Signs, Refusals getters wired; seven-getter heartbeat
If this prompt arrives truncated, say so before starting. It ends with END OF PROMPT.

Rooted in C:\__Code\Claude.Framework, main. Edit and stage only; no commit, push or tag. Record: save this prompt verbatim as docs\prompts\2026-10-04-slice-four-g.md and your final report beside it as 2026-10-04-slice-four-g.report.md, staged with the change. Children are read-only; if repos\Claude.Modules shows any change, say so and stop.

1. framework.yaml, three new getter rows, each entry Claude.Modules\tools\Get-Framework<Name>.ps1 with -Root {framework_root} -Out {out}, needs none:
   - Dirty, order 10, outputs dirty.json dirty.md. First, because it grades whether the checkouts are fit to be graded at all.
   - Signs, order 20, outputs signs.json signs.md.
   - Refusals, order 80, outputs refusals.json refusals.md. It reads earlier heartbeats' heartbeat.json; the current one is not yet written when it runs, which is correct.
   Resulting order: Dirty, Signs, Shape, Coverage, Refusals, Diff. Catalogue, Hardening, Incidents stay entry none. Update the getters comment block.

2. Status: after the outcome counts, print each getter's verdict line from the newest heartbeat's <Getter>.result.json, one row per getter, so a single Status call reads the whole house. Keep the existing diff call.

3. Tests: the three manifest rows; Get-FrameworkGetterOrder yields the six-getter order above; Status prints seven verdict rows from a fixture heartbeat.

VERIFY: Invoke-Build Test, count. Do not run a heartbeat. git status --short, all staged.

REPORT: what changed, test count, anything chosen or not done.
END OF PROMPT
