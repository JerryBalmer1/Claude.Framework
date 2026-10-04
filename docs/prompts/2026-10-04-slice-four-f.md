[WORKSPACE: Claude.Framework] — slice four-f: Diff getter wired, last in the order, first self-comparing heartbeat
If this prompt arrives truncated, say so before starting. It ends with END OF PROMPT.

Rooted in C:\__Code\Claude.Framework, main. Edit and stage only; no commit, push or tag. Record: save this prompt verbatim as docs\prompts\2026-10-04-slice-four-f.md and your final report beside it as 2026-10-04-slice-four-f.report.md, staged with the change. Children are read-only; if repos\Claude.Modules shows any unstaged, staged or untracked change, say so and stop before touching anything.

1. framework.yaml: Diff row gets entry Claude.Modules\tools\Get-FrameworkDiff.ps1 with -Root {framework_root} -Out {out}, outputs diff.json, diff.md, verdict.txt, needs Shape, order 90. Get-FrameworkGetterOrder already keeps Diff last; add a test that a row ordered after Diff is refused if one does not exist.

2. Diff reads its own heartbeat folder's parent as -After and the newest older heartbeat with heartbeat.json as -Before. Confirm in Framework.Build.psm1 that the heartbeat writes <Getter>.result.json for every getter before Diff runs and heartbeat.json after; if heartbeat.json is written before Diff, say so in the report and do not change the order (Diff's reader tolerates both). Diff's verdict is "N better, N worse, N unknown: <call>"; Status prints the call beside the four outcome counts when the newest heartbeat has one.

3. Diff's refusal "no earlier heartbeat to compare" is a refused outcome, not failed. One test with a fixture heartbeats folder holding a single heartbeat.

4. docs\: one line in the getters section naming Diff as the only getter that reads earlier heartbeats, and that it is always last.

VERIFY: Invoke-Build Test, count. Do not run a heartbeat; Jerry runs it. git status --short, all staged.

REPORT: what changed, the write-order finding from item 2, test count, anything chosen or not done.
END OF PROMPT
