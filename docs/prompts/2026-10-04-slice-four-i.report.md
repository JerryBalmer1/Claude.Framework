# Slice four-i report: the real seven getters graded under the contract

Heartbeat ran once. All seven real getters ended ok under four-h's contract, and none was rejected. The framework.yaml verdict regexes are now tested against Claude.Modules' schemas. A new test scans tests/ for the angle-bracket title trap. Nothing under `repos\` was edited.

## 1. Fleet grading

Heartbeat `20261004-035420-640`, `Invoke-Build Heartbeat`, 11m58s, build succeeded.

- Test run `20261004-035420-730`: every child passed. Ontology was pass-with-known (16 expected failures), and its Verify reproduces all three plugins.
- Getters: ok 7, failed 0, refused 0, skipped 3 (Catalogue, Hardening and Incidents are `entry: none`).

The rule column uses four-h's order:

1. `refused:`
2. `failed:`
3. exit not 0
4. output missing
5. verdict mismatch
6. tests FAIL
7. ok

Every real getter passed rules 1 to 6 and ended at rule 7. Each last line below is the last non-blank line of `<getter>.log`, and it equals the verdict recorded in `<getter>.result.json`.

| Getter | Last printed line | Rule hit | Outcome / verdict |
|---|---|---|---|
| Dirty | `6 clean, 2 dirty, 0 wrong-branch, 0 nested, unfit` | 7 | ok, that line |
| Signs | `7 signed, 0 unsigned, 0 dead, 0 unreadable, 7 wired, 0 missing, ok` | 7 | ok, that line |
| Shape | `1 lit, 1 drift, 291 hole, 1 lie, 0 invalid, 1 skipped, 0 trivial` | 7 | ok, that line |
| Secrets | `0 high, 109 medium, 419 low, 1 allowlisted` | 7 | ok, that line |
| Coverage | `162 subjects, 134 covered, 9 named-elsewhere, 19 uncovered, 52 holes` | 7 | ok, that line |
| Refusals | `3 heartbeats, 0 refused, 0 failed, 9 witnessed, ok` | 7 | ok, that line |
| Diff | `0 better, 2 worse, 30 unknown: regressed` | 7 | ok, that line |

No real getter failed the contract, so there is no rejected line to report.

What the run measured, as found:

- **Dirty is `unfit` partly because of this slice.**
  - The Framework checkout was dirty while the heartbeat ran: 2 modified files (framework.yaml, tests) and 1 untracked (this prompt). These were my in-progress edits.
  - Claude.Ontology has 3 untracked files that were already there.
  - "unfit" is still a verdict that matches the contract, so the outcome is ok.
- **Diff compared against `20261004-025134-418`**, the heartbeat four-h was written about. The 2 worse items:
  - `secrets-verdict` low went from 411 to 419.
  - `shape-status` hole went from 286 to 291.

  I did not trace which files caused them, and this slice's own changes are among the candidates.
- **Claude.Modules moved during the run.**
  - The child Test ran Claude.Modules at `aa598e2`.
  - Commit `e060c0f` (04:03, "Add printed-line patterns to Diff and Shape schemas with per-tool tests") landed in `repos\Claude.Modules` after Sync. So every getter ran at `e060c0f`, and Status marks Modules' TestedAt `stale`.
  - The tests that `e060c0f` adds were not run by this heartbeat.
- **The Framework SelfTest inside the heartbeat ran against my half-done tree.**
  - It printed 158 passed and 1 skipped. The skip was an interim Shape test that skipped while `graph.schema.json` had no pattern. That test is now replaced.
  - The SelfTest count below comes from a separate run on the finished tree.

## 2. One source of truth for verdict shape

- **Not done by me: the schema edits.**
  - Both schemas are under `repos\Claude.Modules`. CLAUDE.md allows an edit there only when the prompt names the child, and this prompt is tagged `[REPO: Claude.Framework]`. I asked, and Jerry said Framework only.
  - The prompt's "fix Diff's schema pattern" would also have broken diff.json. `properties.verdict` in `diff.schema.json` describes diff.json's `verdict` field, which really has no call. The call is the separate `call` field. Adding `: <call>` there would make every diff.json fail its own schema.
- **Resolved upstream during the slice.** Commit `e060c0f` in Claude.Modules adds `$defs.line` to `diff.schema.json` and `graph.schema.json`. Each is the printed line, marked "not a diff.json field" or "not part of graph.json". Both patterns are identical to the regexes four-h wrote into framework.yaml. So no framework.yaml regex changed.
- **framework.yaml**: the `verdict` comment now says where each regex comes from. It is copied from the getter's schema, never written from module code: the pattern of `properties.verdict`, or of `$defs.line` for Shape and Diff. It also says a test holds each regex equal to its schema.
- **tests/Framework.Tests.ps1** has 7 new tests, one row per runnable getter. Each asserts with `-BeExactly` that the framework.yaml `verdict` equals the schema pattern. The schemas are read from `repos\<path>\` and never written.

  | Getter | Schema | Pointer |
  |---|---|---|
  | Dirty | `modules/FrameworkDirty/schema/dirty.schema.json` | `properties.verdict` |
  | Signs | `modules/FrameworkSigns/schema/signs.schema.json` | `properties.verdict` |
  | Shape | `modules/FrameworkShape/schema/graph.schema.json` | `$defs.line` |
  | Secrets | `modules/FrameworkSecrets/schema/finding.schema.json` | `properties.verdict` |
  | Coverage | `modules/FrameworkCoverage/schema/coverage.schema.json` | `properties.verdict` |
  | Refusals | `modules/FrameworkRefusals/schema/refusals.schema.json` | `properties.verdict` |
  | Diff | `modules/FrameworkDiff/schema/diff.schema.json` | `$defs.line` |

  - The test fails on a schema with no pattern at the pointer.
  - With a `repos\Claude.Modules` older than `e060c0f`, the Shape and Diff rows fail. That is intended.

## 3. Angle-bracket title scan

New Describe "Pester titles hold no stray angle brackets", 2 tests:

- **The real scan.**
  - It parses every `.ps1` and `.psm1` under `tests/` and checks each `It`, `Describe` and `Context` title.
  - It fails on any `<` or `>` left after removing the templates the block's data names. "The block's data" means hashtable keys inside the block's own `-ForEach` or `-TestCases`, or an enclosing Describe's or Context's.
  - It fails with `file:line: title` for each hit.
- **A self-check on a sample script.** The scan must name these three titles:
  - a bare `<reason>`, which is the four-g and four-h trap
  - a template whose key is not in the data
  - a stray `->`

  It must also pass a `<Kind>` key that is named only by the enclosing Describe.

**Chosen: a narrower rule than "titles containing angle brackets".** A literal ban would fail five correct data-driven titles: `<Name>` twice, `<Field>`, `<Case>`, and `<Name>` with `<Order>`. Pester fills those from `-ForEach`. Line 72 builds its keys inside a `ForEach-Object`, so the scan takes hashtable keys from anywhere inside the `-ForEach` argument.

## 4. verdict.txt

Diff still writes it, and nothing in code reads it. I searched the Framework and all seven clones under `repos\`:

- **Framework**: only `framework.yaml` reads it, where Diff's `outputs` lists it. A Diff that stops writing it would therefore fail rule 4. The test at `tests/Framework.Tests.ps1` "Diff runs ..." asserts that outputs list. The heartbeat runner has not read the file since four-h.
- **Claude.Modules**: it writes the file (`FrameworkDiff.psm1:990`). Its own tests assert the content (`tests/FrameworkDiff.Tests.ps1` 212, 435, 637, 641). The tool help, the README and the new `$defs.line` description mention it. Nothing reads it to decide anything.
- **Claude.Skills**: `skills/framework-diff/SKILL.md` step 4 tells the reader it is one of the files under `-Out`. This is documentation, not a reader in code.
- Root, Chain, Substrate, Ontology and Portal: no mention.

Recommendation, not done: retire it in order, in three separate prompts:

1. Remove it from Diff's `outputs` here.
2. Have Claude.Modules stop writing it and change its four tests.
3. Update the Claude.Skills SKILL.md line.

Not deleted this slice.

## SelfTest counts

- **Before: 150** at HEAD `a8f1937`, the same count as four-h's report.
  - Counted by running the suite on a `git archive` copy of HEAD in scratch: 145 passed, 5 failed.
  - All 5 failures come from the copy: it is not a git checkout, and it has no `repos\Claude.Modules` to copy the Diff module from. They are not failures at HEAD.
- **After: 159 passed, 0 failed, 0 skipped** (`Invoke-Build SelfTest` in the repo).
- The 9 new tests are the 7 schema-equality rows and the 2 title-scan tests.

## Disagreements between a schema and its tool

None left unresolved.

- The two the prompt named are closed by Claude.Modules `e060c0f`: Shape had no pattern, and Diff's pattern lacked the call.
- Diff's `properties.verdict` still has no call. That is correct, because it describes diff.json's field and not the printed line.

## Files

- `framework.yaml`: the verdict comment, 3 lines
- `tests/Framework.Tests.ps1`: 7 schema-equality rows and the title-scan Describe
- `docs/prompts/2026-10-04-slice-four-i.md`: the prompt, verbatim
- `docs/prompts/2026-10-04-slice-four-i.report.md`: this report

All four are staged. Nothing is committed, pushed or tagged. Nothing under `repos\` was edited. The heartbeat folder and its pruning are the build's own work.
