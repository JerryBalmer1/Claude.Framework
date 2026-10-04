[WORKSPACE: Claude.Framework] — slice four-h: heartbeat grades getter output by contract, not exit code alone
If this arrives truncated, say so before starting.

Context: heartbeat 20261004-025134-418 recorded Signs as ok with the verdict text "MethodInvocationException: ... found invalid mapping." The tool printed its real verdict, then an exception, then exited 0, and the runner took the last line as the verdict. Claude.Modules (now at aa598e2) has since made every tool end on exactly one of: a verdict line, "refused: <reason>", or "failed: <message>". The Framework must now enforce that shape rather than trust it.

1. framework.yaml: each getter row gains a `verdict:` field holding a regex the last stdout line must match for an ok outcome. Write the seven regexes from the current verdict formats:
   Dirty    "N clean, N dirty, N wrong-branch, N nested, <ok|unfit>"
   Signs    "N signed, N unsigned, N dead, N unreadable, N wired, N missing, <ok|holes>"
   Shape    "N lit, N drift, N hole, N lie, N invalid, N skipped, N trivial"
   Secrets  "N high, N medium, N low, N allowlisted"
   Coverage "N subjects, N covered, N named-elsewhere, N uncovered, N holes"
   Refusals "N heartbeats, N refused, N failed, N witnessed, <ok|...>" (read the Refusals verdict format from ..\repos\Claude.Modules\modules\FrameworkRefusals\ for the closing word set)
   Diff     "N better, N worse, N unknown: <improved|regressed|mixed|unchanged>"
   Read each tool's current verdict format from its module's md/schema in Claude.Modules (read-only) and prefer that over my wording above if they differ; report any difference.

2. Outcome rules in the heartbeat runner, in this order:
   - last line matches ^refused: → outcome refused, note = that line (existing behaviour, keep)
   - last line matches ^failed:  → outcome failed, note = that line
   - exit code != 0              → failed, note = last line
   - any declared output missing under the getter's folder → failed, note names the missing file(s)
   - last line does not match the row's verdict regex → failed, note = "verdict did not match contract: <last line>"
   - otherwise ok, verdict = last line
   A row without `verdict:` is itself a Shape-style lie about the house: the runner refuses to run that getter with note "no verdict contract in framework.yaml".

3. Status: a failed getter prints "failed" plus its note in place of a verdict; unchanged for ok and refused.

4. Tests: add a fixture reproducing the 025134 Signs case (verdict line, then exception text, exit 0) and assert outcome failed with the contract note; one test per rule in item 2; one test that a row missing `verdict:` is refused. Use stub getter scripts under tests\fixtures, not Claude.Modules.

5. Docs: one line in the framework.yaml getters comment block stating the contract: "ok means exit 0, every declared output present, and the last stdout line matching the row's verdict regex; nothing else counts."

Record: save this prompt verbatim as docs\prompts\2026-10-04-slice-four-h.md and your final report beside it as 2026-10-04-slice-four-h.report.md, staged with the change.

Edit and stage only. No commit, no push. Do not run Heartbeat. Run Invoke-Build SelfTest and report count before and after, the seven regexes as written, and any verdict format in Claude.Modules that differed from the context above.
END OF PROMPT
