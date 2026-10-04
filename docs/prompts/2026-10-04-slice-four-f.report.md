# Slice four-f report: Diff getter wired

Before any edit, `repos\Claude.Modules` was clean: `git status --short` printed nothing, on `main...origin/main`.

## What changed

- **framework.yaml**
  - The Diff row is now runnable:
    - path `Claude.Modules`, entry `tools/Get-FrameworkDiff.ps1`
    - parameters `Root: '{framework_root}'` and `Out: '{out}'`
    - outputs `diff.json`, `diff.md` and `verdict.txt`
    - needs `[Shape]`, order 90, cadence every
  - The `note: not promoted` line is gone.
  - A comment above the row explains why `-Before` and `-After` are not passed.
  - In the getters header comment, the promoted list now includes Diff. One new line says Diff is the only getter that reads earlier heartbeats and that it always runs last (item 4; see "Chosen" below).
- **build/Framework.Build.psm1**
  - `Get-FrameworkGetterOutcomes` now returns a `Call` property: the `<call>` from the newest heartbeat's `diff` verdict when that verdict reads `N better, N worse, N unknown: <call>`, else `$null`.
- **Claude.Framework.build.ps1**
  - Status prints `; diff <call>` after the four outcome counts when `Call` is set.
  - In the help text:
    - Status's entry mentions the call.
    - Heartbeat's entry now says "Diff last against the newest earlier heartbeat".
- **tests/Framework.Tests.ps1**: four tests added and one updated.
  - Updated: the "registers seven getters" test. Diff is no longer expected to be `entry: none`.
  - New: Diff's manifest row has the right path, script, parameters, outputs, order, cadence and needs.
  - New: `Get-FrameworkGetterOrder` refuses a getter that would run after Diff.
    - By order: rows are built directly, because such a manifest already fails to load.
    - By needs: a row with a lower order that needs Diff.
    - Neither case had a test before; only the load-time "Diff not last" test existed.
  - New, in the `Diff with no earlier heartbeat` block: the real `Get-FrameworkDiff.ps1` and its `FrameworkDiff` module run in a fixture.
    - Both are copied from `repos\Claude.Modules` into a fixture getter repo.
    - The fixture heartbeats folder ends up holding a single heartbeat.
    - Diff's result is `refused`, not `failed`. Its verdict is `refused: no earlier heartbeat to compare`.
    - None of its three outputs is written.
    - The outcome counts are refused 1 and failed 0, and Status has no call.
  - New, in the same block: Status reads `mixed` from a fixture `heartbeat.json` whose diff verdict is `3 better, 1 worse, 0 unknown: mixed`.
- **docs/prompts/**: this prompt (verbatim) and this report.

No change was needed to make the refusal an outcome. The heartbeat already counts a non-zero exit whose last line begins `refused` as `refused`, and Diff prints exactly that and exits 1.

## Write-order finding (item 2)

The order is correct, and I did not change it.

- In `Invoke-FrameworkHeartbeat`, the getter loop writes `<Getter>.result.json` at the end of each getter's iteration. Every getter ordered before Diff therefore has its result.json on disk before Diff starts.
- Diff's own result.json is written after Diff exits.
- `heartbeat.json` is written only after the whole getter loop, so it comes after Diff.
- So when Diff runs, the current heartbeat folder (its `-After`) has every earlier getter's result.json but no `heartbeat.json` yet.

Wording note: Diff's `-After` is the parent of its `-Out` folder, which is the heartbeat folder itself, not the heartbeat folder's parent.

## Verify

`Invoke-Build Test` succeeded in 4:29.

| Child | Result |
|---|---|
| Claude.Chain | 40 pass |
| Claude.Modules | 292 pass, 6 skipped |
| Claude.Skills | 18 pass |
| Claude.Ontology | pass-with-known: 554 pass, 16 known failures, 14 skipped |
| Claude.Portal | 16 pass |
| Claude.Framework SelfTest | **126 pass, 0 failed** (122 before this slice, plus the 4 new tests) |

I did not run a heartbeat; Jerry runs it. `git status --short` shows every change staged.

## Chosen or not done

- **The docs line is in framework.yaml, not under docs\\.** No file under `docs\` has a getters section. The only getters write-up is the comment block above `getters:` in `framework.yaml`, so the line went there. I did not create a new doc to hold one line. If it should live under `docs\`, tell me which file.
- **The first heartbeat ever fails the Heartbeat task.** On a machine with no earlier heartbeat, Diff is `refused`, and `Failures` counts refused getters. This slice did not change that.
  - It does not affect Jerry's run while `.framework\heartbeats\` holds an earlier heartbeat with `heartbeat.json`.
- **Two different "previous" heartbeats.** The build's `{previous}` and its "no previous heartbeat" note use the newest stamp folder, whether or not it has a `heartbeat.json`. Diff's `-Before` uses the newest one that holds `heartbeat.json`. The two can differ after a heartbeat that died before writing its record. I left this alone.
- **The refusal test now needs repos\Claude.Modules.** It copies the real Diff script and module from there, so SelfTest needs that clone, as Test already does. The test only reads from `repos\`; it writes only under the fixture root.
- Status prints the call only, as asked, not the full `N better, N worse, N unknown` text.
