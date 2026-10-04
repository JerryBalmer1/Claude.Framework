# Slice four-g report: Dirty, Signs, Refusals getters wired

Before any edit, `repos\Claude.Modules` was clean: `git status --short` printed nothing. It was still clean after the Test run.

## What changed

- `framework.yaml`
  - Three new getter rows. Each runs from `path: Claude.Modules` with `tools/Get-Framework<Name>.ps1`, passes `Root: '{framework_root}'` and `Out: '{out}'`, needs nothing, and has `tests: false` and `cadence: every`.
    - Dirty: order 10, outputs `dirty.json`, `dirty.md`.
    - Signs: order 20, outputs `signs.json`, `signs.md`.
    - Refusals: order 80, outputs `refusals.json`, `refusals.md`. It does not pass `-Heartbeats`, so the script falls back to `{framework_root}\.framework\heartbeats`. A row comment says so.
  - The getters comment block now names the seven promoted getters and says why Dirty is first. It also says Refusals and Diff both read earlier heartbeats. The old line said Diff was the only one, which is no longer true.
  - Catalogue moved from order 10 to 15, and Hardening from 20 to 25. Both stay `entry: none`. See "Chosen" below.
- `build/Framework.Build.psm1`
  - `Get-FrameworkGetterOutcomes` now also returns `Rows`. That is one row per getter in heartbeat.json order (Name, Result, Verdict), read from that heartbeat's `<Getter>.result.json`. When a getter left no verdict line, its note is shown instead. When its result.json is missing, the row says `no result.json`.
  - New exported function `Format-FrameworkGetterStatus`. It returns the lines Status prints: the existing count line with the diff call, then one verdict row per getter. With no heartbeat it returns `Getters: no heartbeat yet`, as before.
- `Claude.Framework.build.ps1`: the Status task prints the lines from `Format-FrameworkGetterStatus`. The Status help text now describes the verdict rows.
- `tests/Framework.Tests.ps1`
  - The registration test now expects ten getters in manifest order: Dirty, Catalogue, Signs, Hardening, Incidents, Shape, Secrets, Coverage, Refusals, Diff.
  - New: one test per new manifest row (Dirty, Signs, Refusals), checking path, script, parameters, outputs, order, cadence and no needs.
  - New: `Get-FrameworkGetterOrder` on the real manifest gives the runnable getters in this order: Dirty, Signs, Shape, Secrets, Coverage, Refusals, Diff.
  - New: Status prints seven verdict rows from a fixture heartbeat, after the count line with the diff call. An older heartbeat sits beside it to show that only the newest is read.
  - New: Status says "no heartbeat yet" when there is none.

## Test count

`Invoke-Build Test` passed with 0 errors. Claude.Framework SelfTest: 132 passed, 0 failed (was 126). The children:

| Child | Result | Passed | Failed | Skipped |
|---|---|---|---|---|
| Claude.Chain | pass | 40 | 0 | 0 |
| Claude.Modules | pass | 385 | 0 | 6 |
| Claude.Skills | pass | 30 | 0 | 0 |
| Claude.Ontology | pass-with-known | 554 | 16 | 14 |
| Claude.Portal | pass | 16 | 0 | 0 |

No heartbeat was run.

## Chosen

- **The order numbers clashed.** Catalogue already had order 10 and Hardening had 20. The build refuses two getters with the same order, entry-none rows included. I gave Dirty and Signs the orders the prompt asked for and moved Catalogue to 15 and Hardening to 25. Entry-none getters never run, so this changes nothing at run time.
- **Six or seven getters.** The prompt's "resulting order" has six getters and leaves out Secrets (order 50). But the slice title says a seven-getter heartbeat, and the Status test asks for seven rows. Seven only works with Secrets in. So the order test expects Dirty, Signs, Shape, Secrets, Coverage, Refusals, Diff. I did not remove Secrets.
- **What the order test checks.** `Get-FrameworkGetterOrder` also returns the three entry-none getters, so the test filters to getters that have an entry.
- **Status rows.** Status prints a row for every getter in the newest heartbeat. A real heartbeat also records the three entry-none getters as skipped, so a real Status shows ten rows; those three show their note. The fixture heartbeat holds the seven runnable getters, so the test sees seven rows.
- **Where the formatting lives.** It moved into the module (`Format-FrameworkGetterStatus`) so the test checks the exact lines Status prints.

## Not done

- No heartbeat run, as the prompt says. The three new getters have not run under Heartbeat yet.
- The first Test run failed one new test. Its title had `<Getter>` in it, which Pester reads as a template variable, and that throws under the strict mode the Test task uses. I renamed the test, and the second run passed.
