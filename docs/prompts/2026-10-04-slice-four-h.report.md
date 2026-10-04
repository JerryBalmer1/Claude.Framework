# Slice four-h report: heartbeat grades getter output by contract

Before any edit, `repos\Claude.Modules` was clean at aa598e2: `git status --short` printed nothing. It was still clean after the SelfTest run. No heartbeat was run.

## What changed

- `framework.yaml`
  - Each of the seven runnable getter rows has a `verdict:` regex (listed below). The three `entry: none` rows have none.
  - The getters comment block now describes `verdict` and the outcome rules in order. It also carries the contract line: "ok means exit 0, every declared output present, and the last stdout line matching the row's verdict regex; nothing else counts."
  - The old line "The verdict line is the first line of {out}/verdict.txt, else the last line the entry printed" is gone. See "Chosen" below.
- `build/Framework.Build.psm1`
  - `ConvertTo-FrameworkGetter` reads `verdict`. It must be a non-empty string that parses as a regex, or the manifest fails to load. A runnable row without one still loads.
  - `Invoke-FrameworkHeartbeat` now refuses a runnable getter that has no `verdict`. The note is "no verdict contract in framework.yaml", and no pwsh is started. This check comes after `-Only`, needs and `entry: none`, and before the path and branch checks.
  - The outcome rules, in this order; the first one that holds wins:
    1. Last line matches `^refused:`: refused. Note and verdict are that line.
    2. Last line matches `^failed:`: failed. Note is that line.
    3. Exit code is not 0: failed. Note is the last line, or "entry exit N, nothing printed" when nothing was printed.
    4. A declared output is missing: failed. Note is "missing output(s) under {out}: <names>".
    5. Last line does not match the row's `verdict`: failed. Note is "verdict did not match contract: <last line>".
    6. `tests: true` and the Pester verdict is FAIL: failed. This is the existing rule, kept after the contract rules.
    7. Otherwise ok. The verdict is the last line.
  - Only ok and refused getters record a verdict. A failed getter records `verdict: null`, and its note says why.
  - `Get-FrameworkGetterOutcomes`: a failed row shows its note instead of its verdict, even when its result.json holds a verdict, as older heartbeats do. Ok and refused rows are unchanged.
- `Claude.Framework.build.ps1`: the help text for Status and Heartbeat describes the contract.
- `tests/fixtures/contract-getters/tools/`: seven stub getters.
  - `Signs-025134.ps1` is the 025134 case. It writes signs.json and signs.md, prints a valid Signs verdict, then writes a `MethodInvocationException ... found invalid mapping.` error, then exits 0.
  - `Ok.ps1`, `Refused.ps1`, `Failed.ps1`, `ExitNonZero.ps1`, `MissingOutput.ps1` and `Mismatch.ps1` each isolate one rule. `Failed.ps1` exits 0 with its outputs written, so only the `failed:` rule can catch it. `ExitNonZero.ps1` and `MissingOutput.ps1` print a line that matches the contract, so only their own rule can catch them.
- `tests/Framework.Tests.ps1`
  - New Describe "Getter output is graded by contract". It copies the stubs into a fixture repo under a fixture `repos\` and runs one heartbeat over eight rows. The eighth row reuses `Ok.ps1` with no `verdict:`. It has nine tests:
    - the 025134 case is failed with the contract note and no verdict
    - one test for each of the six rules in item 2
    - the row without `verdict:` is refused and never runs
    - Status prints failed plus the note for failed rows, and unchanged rows for ok and refused
  - New in "framework.yaml getters":
    - seven tests, one per real regex. Each matches sample lines in its tool's format, and rejects the 025134 exception line, a valid line with trailing text, and a `refused:` line.
    - every runnable row has a contract, and `entry: none` rows have none
    - `verdict` is read, and a regex that does not parse fails the load
  - Existing fixtures updated for the contract:
    - every runnable fixture row now has a `verdict:`
    - the Good and Compare stubs print a verdict line
    - the Bad and Base notes are now their last printed line instead of "entry exit 1"
    - the Status rows test also checks that the failed Coverage row shows its note

## Test count

`Invoke-Build SelfTest`: before 132, after **150 passed, 0 failed**, so 18 new tests. The 132 was counted by Pester discovery on a scratch copy of HEAD d345314, and it matches the four-g report. The first run after the edits failed 3 new tests. Their titles held `<reason>`, `<message>` and `<line>`, which Pester reads as template variables, the same trap as in four-g. I renamed the three titles, and the second run passed.

## The seven regexes as written

| Getter | verdict |
|---|---|
| Dirty | `^\d+ clean, \d+ dirty, \d+ wrong-branch, \d+ nested, (ok\|unfit)$` |
| Signs | `^\d+ signed, \d+ unsigned, \d+ dead, \d+ unreadable, \d+ wired, \d+ missing, (ok\|holes)$` |
| Shape | `^\d+ lit, \d+ drift, \d+ hole, \d+ lie, \d+ invalid, \d+ skipped, \d+ trivial$` |
| Secrets | `^\d+ high, \d+ medium, \d+ low, \d+ allowlisted$` |
| Coverage | `^\d+ subjects, \d+ covered, \d+ named-elsewhere, \d+ uncovered, \d+ holes$` |
| Refusals | `^\d+ heartbeats, \d+ refused, \d+ failed, \d+ witnessed, (ok\|review)$` |
| Diff | `^\d+ better, \d+ worse, \d+ unknown: (improved\|regressed\|mixed\|unchanged)$` |

The `\|` is table escaping only. framework.yaml has a plain `|`. Matching is case-sensitive.

## Verdict formats in Claude.Modules compared with the prompt

None differ from the prompt's wording. The one open slot was filled from the module:

- **Refusals**: the closing word is `ok` or `review`. `review` means the newest heartbeat holds a refused getter (`FrameworkRefusals.psm1`, `review_when: refused` in `data/outcomes.yaml`). `schema/refusals.schema.json` gives the same pattern.
- Dirty, Signs, Secrets and Coverage match the `verdict` pattern in each module's schema exactly.
- Shape's schema has no verdict pattern. I read the format from the `Status` line in `FrameworkShape.psm1`, and it matches the prompt.
- Diff's schema pattern covers only `N better, N worse, N unknown`. The tool prints that line plus `: <call>` (`tools/Get-FrameworkDiff.ps1`), and `Get-DiffCall` returns improved, regressed, mixed or unchanged. That matches the prompt.

## Chosen

- **What "last stdout line" means.** It is the last non-blank line of the getter's log. The log holds every stream, because `Invoke-ChildProcess` captures with `*>&1`. In the 025134 case the exception came on the error stream. If only true stdout were read, the last line would be the valid verdict, and the case would pass as ok.
- **The refused rule changed in two ways.**
  - Before, it was a non-zero exit with a last line beginning "refused". Now it is any last line beginning "refused:", whatever the exit code, as item 2 lists it.
  - Every Claude.Modules tool already prints "refused: ..." and exits 1, so their behaviour does not change. A bare "refused" with no colon would now be graded by the later rules.
- **verdict.txt is no longer read.** The verdict is the last printed line, as item 2 says. Diff prints the same text it writes to verdict.txt, so `heartbeat.json`'s `diff` and Status's call read the same as before. Diff still lists verdict.txt in its outputs, so a missing one still fails it.
- **The note of a failed getter is the rule's note alone.** Before, notes piled up, for example the row note plus "entry exit 1". Ok getters keep their notes as before: the row note and the tests note. Diff's "no previous heartbeat" note is no longer added to a failed Diff.
- **A failed getter records no verdict.** So no tool can read a failed run's last line as a verdict. Refusals reads a failed reason from `note` first, so it is unaffected. Diff reads the Shape, Secrets and Coverage verdicts, and gets none from a failed run.
- **An exit that is not 0 with nothing printed** gets the note "entry exit N, nothing printed", since there is no last line to use.
- **A `verdict` that is not a valid regex** fails the manifest load. Its absence does not, because item 2 asks for a refusal at run time.

## Not done

- No heartbeat was run, as the prompt says. The real seven tools have not yet been graded under the new rules.
- Nothing committed or pushed.
