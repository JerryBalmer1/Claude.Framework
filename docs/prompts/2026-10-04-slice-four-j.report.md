# Slice four-j report: pinned children, the regression traced, Dirty baseline

The four-i regression was not four-i's own edits.

- **Secrets.** All of four-i's new low findings came from Claude.Modules commit aa598e2 and from Heartbeat's own retention pruning.
- **Shape.** Four-i's new holes came from Claude.Modules aa598e2, from Ontology's catalogue seed (then still untracked), and from four-h's committed fixtures.
- **The clean rerun.** It did not fall back to 411 and 286: it rose to 423 and 296. The trace below names the files.

The pin, the `-Baseline` switch and the heartbeat schema are in. SelfTest went from 159 to 168. Nothing under `repos\` was edited.

The clean rerun was itself torn. Another session started editing `repos\Claude.Ontology` two minutes after the run began. Under the new pin, that run fails as `torn: Claude.Ontology 195d3e7 -> 195d3e7*`.

## 1. Pin block

`heartbeat.json` gains three fields: `pin`, `witness` and `baseline`. They are described in the new `schema/heartbeat.schema.json`.

```json
"pin": {
  "verdict": "held | torn",
  "started_at": "yyyy-MM-ddTHH:mm:ss+zz:zz",
  "ended_at":   "yyyy-MM-ddTHH:mm:ss+zz:zz",
  "children": [
    { "repo": "Claude.Modules", "branch": "main", "commit": "<40 hex>", "dirty": false,
      "end": { "branch": "main", "commit": "<40 hex>", "dirty": false },
      "held": true }
  ],
  "torn": [ "Claude.Modules aa598e2 -> e060c0f", "Claude.Ontology 195d3e7 -> 195d3e7*" ]
},
"witness": true,
"baseline": null
```

How the pin works:

- **When it is read.** Inside `Invoke-FrameworkHeartbeat`, once after Sync and before Test, and once after the last getter. Every child in `framework.yaml` is read. A child that is not cloned gets null branch, commit and dirty.
- **What tears it.** A child holds when its commit and its dirty flag are both unchanged. When any child does not hold, `verdict` is `torn` and `torn` has one entry for that child. The entry has the form `<repo> <start> -> <end>`: each commit is seven characters, with `*` when dirty. A dirty flip therefore shows the same commit on both sides, with the end one starred.
- **The failure.** Each torn entry also goes into `failures` as `torn: <entry>`. The Heartbeat task then fails, and it prints `Pin: torn: ...` or `Pin: held, N children`.
- **The schema.** It ties `torn` to `verdict`: held has no entries, torn has at least one.
- **Status.**
  - It has a new `Pinned` column: the commit the newest heartbeat pinned, with `torn -> <end>` when that child moved during the run.
  - `TestedAt ... stale` is now judged against the pinned commit, not live HEAD. It falls back to live HEAD when the newest heartbeat has no pin, which is every record before this slice.
  - The getter block ends with a `Pin:` line, plus `Baseline run: a working read, not a witness` for a baseline record. With the pin, four-i's case reads `Pinned aa598e2 torn -> e060c0f` instead of an unexplained `stale`.

## 2. Clean rerun

Heartbeat `20261004-042636-716` ran with `Invoke-Build Heartbeat` and took 17m43s. The build failed on one thing: `test Claude.Modules`. I ran it before editing anything.

- Framework was at HEAD `7e1dc3b` with an empty `git status`.
- Every child was clean at the start: Chain 2c3da40, Modules e060c0f, Ontology 195d3e7, Portal f45a746, Root dd88d74, Skills a25212f, Substrate 5edffd5. Sync left them all up to date.
- The run predates the pin code. So I read the pin by hand before and after the run, and the record has no pin block.

The seven lines:

| Getter | Verdict |
|---|---|
| Dirty | `7 clean, 0 dirty, 0 wrong-branch, 1 nested, unfit` |
| Signs | `7 signed, 0 unsigned, 0 dead, 0 unreadable, 7 wired, 0 missing, ok` |
| Shape | `1 lit, 1 drift, 296 hole, 1 lie, 0 invalid, 1 skipped, 0 trivial` |
| Secrets | `0 high, 109 medium, 423 low, 1 allowlisted` |
| Coverage | `163 subjects, 134 covered, 9 named-elsewhere, 20 uncovered, 52 holes` |
| Refusals | `3 heartbeats, 0 refused, 0 failed, 9 witnessed, ok` |
| Diff | `0 better, 3 worse, 22 unknown: regressed` (against 035420-640) |

Getters: ok 7, failed 0, refused 0, skipped 3.

Child tests:

- Chain passed with 40.
- Modules failed: 395 passed, 2 failed.
- Skills passed with 37.
- Ontology was pass-with-known: 555 passed, 16 known failures.
- Portal passed with 16.
- SelfTest passed with 159.
- Ontology Verify reproduces all three plugins.

**The run was torn by Claude.Ontology.**

- Another session edited `repos\Claude.Ontology` from 04:28:12 to 04:39:01. The run started at 04:26:17.
- It modified 9 tracked files: `.gitignore`, `.gitattributes`, the seed's catalogue, maps and schemas, and `ontology/README.md`.
- It added `ontology/tools/`, `ontology/sources/`, `ontology/maps/terraform-azuread.map.yaml` and `tests/Ontology.Catalogue.Tests.ps1`.
- `ontology/sources/` holds embedded checkouts. That is Dirty's `1 nested`, and why Secrets now scans `Azure.azure-rest-api-specs` and `prowler-cloud.prowler`.
- During the run, Ontology's commit stayed 195d3e7 and its dirty flag went from false to true.
- The session later committed that work as `d713cb7` (04:48, "ontology: part-of relations, azuread source, reproducible label fetch"), after my run had ended.
- When I staged this slice, Ontology was clean at d713cb7. A rerun now would grade d713cb7, not the 195d3e7 the prompt describes.

**Claude.Modules Test FAIL, 2 tests.** Reported, not fixed.

- `FrameworkCoverage.Tests.ps1:227`, "graph schema copy is identical to FrameworkShape's". Commit e060c0f added `$defs.line` to Shape's `graph.schema.json` but not to Coverage's copy, so this one is e060c0f's own.
- `FrameworkSecrets.Tests.ps1:433`, "leaves git status unchanged in the Framework root and every child". Ontology's status changed while the test ran (`M .gitignore`, `?? ontology/sources/`). That was the other session, not Secrets.

## 3. Regression trace

The method: `findings[severity=low]` and Shape folder nodes with `card: hole` were diffed by repo, file, line, pattern and hash. Each new item was then attributed with `git log` and `git ls-tree` in the child, read-only.

### 035420-640 to 042636-716 (four-i to this run)

**Secrets low 419 to 423: +4, 0 gone.**

- All four are `dead-absolute-path` findings in Claude.Modules fixtures under `tests/fixtures/diff/heartbeats/20261004-002941-905/`:
  - `heartbeat.json` lines 164 and 182
  - `Secrets.result.json` line 14
  - `Shape.result.json` line 14
- They point at `.framework\heartbeats\20261004-002941-905\...`. This run's own retention (keep 5) pruned that folder before the getters ran, so the paths went dead.

**Shape holes 291 to 296: +5, 0 gone.** All five are in Claude.Ontology.

- `docs`, `docs/prompts` and `ontology/maps` were added by **the Ontology catalogue seed 195d3e7**: absent at 59265d3, present at 195d3e7.
- `ontology/sources` and `ontology/tools` are **the other session's uncommitted work** during this run.

### 025134-418 to 035420-640 (the four-i regression the prompt asked about)

**Secrets low 411 to 419: +10 new, 2 gone.**

- 6 are from **Claude.Modules aa598e2** ("Verdict last"): `docs/prompts/2026-10-04-verdict-last.md` (2) and `docs/prompts/2026-10-04-verdict-last.report.md` (4).
- 2 are a line shift in `tools/Find-FrameworkSecret.ps1` in aa598e2: the same two hashes moved from line 9 to line 10. That is 2 new and 2 gone, net 0.
- 2 are **retention**: `dead-absolute-path` in Modules fixtures (`diff/heartbeats/20261003-235345-014/heartbeat.json:178` and `Secrets.result.json:14`). They point at heartbeat `20261003-235345-014`, which was pruned between the two runs.
- None are from e060c0f, the Ontology seed, or the four-i edits. The Framework repo had no new low finding.

**Shape holes 286 to 291: +5.**

- `repos/Claude.Modules/tests/fixtures/signs/house/repos/Claude.Skills/skills/unreadable` is from **Modules aa598e2**.
- `repos/Claude.Ontology/ontology` is from **the Ontology catalogue seed**, then untracked at 59265d3 and committed later as 195d3e7.
- `tests/fixtures`, `tests/fixtures/contract-getters` and `tests/fixtures/contract-getters/tools` are from **four-h's commit a8f1937**. They did not exist at four-h's own heartbeat 025134, which graded d345314, and were committed at 03:50.

**Answer.** The cause is neither the four-i edits nor e060c0f.

- It is Modules aa598e2: 6 lows and 1 hole.
- It is the Ontology seed: 1 hole then, 3 more now.
- It is four-h's fixtures: 3 holes.
- It is Heartbeat's own retention: 2 lows then, 4 now.

The retention cause recurs on every run while Modules keeps fixtures holding absolute paths into `.framework\heartbeats\`. Each prune can turn more of them into `dead-absolute-path` lows. Not fixed: the fix belongs in Claude.Modules, either by making those fixture paths relative or by having Secrets skip that class under `tests/fixtures`.

Coverage `uncovered 19 to 20` is Diff's third worse item. The prompt did not ask for it, and I did not trace it.

## 4. -Baseline

- **Usage.** `Invoke-Build Heartbeat -Baseline`, default off.
- **At start.** It reads `git status --porcelain --untracked-files=all` for each checkout Dirty grades: the Framework root (`.`) and each `repos/<name>` with a `.git`.
- **After Dirty ends ok.** It reads `dirty.json` again. A checkout Dirty called `dirty` counts as clean under the baseline only when:
  - nothing is ahead or behind,
  - it has no incoming folder, and
  - every file git lists now was already dirty at start.
- **The re-graded line.** It is recomputed in Dirty's own form, `N clean, N dirty, N wrong-branch, N nested, ok|unfit`.
- **The record.**
  - `Dirty.result.json` keeps `verdict` as the line Dirty printed, so the contract is unchanged. It gains `baseline: { verdict, excused, new_dirty }`.
  - The heartbeat row and Status show the baseline line with `(baseline)`.
  - `heartbeat.json` says `witness: false` and `baseline: { read: "working", note: "working read, not a witness: ...", dirty_at_start: [...] }`.
- **Where it is documented.** In the build script's help and in the schema descriptions.

## 5. Tests

SelfTest went from 159 passed (HEAD `7e1dc3b`, inside the clean heartbeat) to **168 passed, 0 failed, 0 skipped** (`Invoke-Build SelfTest`). The title scan's two tests pass.

New Describe "Heartbeat pins each child", 4 tests. The fixture has children Kid and Other, plus a getter that commits into Kid and leaves an untracked file in Other while the heartbeat runs.

- The pin is present and held for both children, the record is a witness, and it validates against the schema.
- The commit made mid-run is detected: `torn`, `Kid <start7> -> <end7>` in the pin and as `torn: ...` in the failures, and `witness: false`. The record still validates.
- The dirty flip is detected with the same commit on both sides, the end one starred.
- Status: `Pinned` shows the tear. TestedAt at the pinned commit is not stale although HEAD moved, and without a pin it is stale as before. The getter block prints the `Pin: torn:` line.

New Describe "Heartbeat -Baseline", 5 tests. It uses the real Dirty entry copied from `repos\Claude.Modules`, with a fixture Framework whose `pre.txt` is modified before the heartbeat.

- Dirty prints `2 clean, 1 dirty, ..., unfit` and the baseline line is `3 clean, 0 dirty, ..., ok`, with `.` excused.
- The record is `witness: false`, `read: working`, and lists `pre.txt` dirty at start. It validates.
- Without `-Baseline` the same tree is unfit, the record is a witness, and it has no baseline.
- A file a getter writes after the start (`new.txt`) keeps Dirty unfit under the baseline and is named in `new_dirty`.
- Status prints the `(baseline)` line and the working-read line.

I also checked by hand that the schema rejects a record from before this slice, and a torn record edited to say held.

## Guesses

- **There was no heartbeat schema.** The prompt says to add the pin block to it, but Framework had none; the record's shape lived only in code. I created `schema/heartbeat.schema.json` for the whole record:
  - pin, witness and baseline are strict;
  - children, verify and the getter rows are loose;
  - it is checked in tests, not when the record is written, so a schema slip cannot fail a real heartbeat.
- **Heartbeat start means after Sync and before Test.** Sync moving a child is intended, not a tear.
- **Only children under `repos\` are pinned**, as the prompt says. The Framework root is not; its commit and dirty flag are still recorded once in `framework`.
- **A branch change alone does not tear the pin.** It is recorded in `end.branch`, but the prompt named commit and dirty only.
- **A torn run is also `witness: false`**, not only a baseline run.
- **Status staleness is judged against the newest heartbeat's pin.** If a standalone Test runs after that heartbeat at a newer HEAD, TestedAt shows `stale` against the older pin.
- **The baseline matches files by path, not content.** A file that was dirty at start and edited further mid-run is still excused. Dirt that is not a file (ahead, behind, incoming) is never excused. Dirty is found by the getter name `Dirty`, the way Diff is found by name.
- **The clean rerun has no pin block**, because it ran before the code existed so that the tree could be clean. I did not run a second real heartbeat with the new code. One would add another record to the history, and Ontology has since moved to d713cb7.

## Files

- `build/Framework.Build.psm1`:
  - new helpers `Get-FrameworkPin`, `Compare-FrameworkPin`, `Get-DirtyFiles`, `Get-FrameworkDirtyBaseline`, `Get-DirtyBaselineVerdict` and `Get-NewestHeartbeatPin`;
  - `Invoke-FrameworkHeartbeat` gets `-Baseline` and writes pin, witness and baseline;
  - `Get-FrameworkStatus` gets `-HeartbeatsRoot` and the `Pinned` column;
  - Status prints the pin and baseline lines.
- `Claude.Framework.build.ps1`: `-Baseline`, the pin line in the Heartbeat output, Status reads the heartbeats root, and the help text.
- `schema/heartbeat.schema.json`: new.
- `tests/Framework.Tests.ps1`: the two new Describes.
- `docs/prompts/2026-10-04-slice-four-j.md`: the prompt, verbatim.
- `docs/prompts/2026-10-04-slice-four-j.report.md`: this report.

All of these are staged. Nothing is committed, pushed or tagged, and nothing under `repos\` was edited. The new heartbeat folder and the pruning of `20261004-002941-905` are the build's own work.
