[REPO: Claude.Framework at C:\__Code\Claude.Framework] — four-h proved the grader, four-i grades the fleet

Context: four-h made Heartbeat grade each getter's last printed line against a verdict regex in framework.yaml. Stubs pass; the seven real tools have not been run under the new rules. Two schemas disagree with their tools.

Do:
1. Run Heartbeat once against the real seven getters. Record each getter's last printed line, which rule it hit, and its verdict in the report. If any real getter fails the contract, do not fix the tool; report the exact line and which rule rejected it.
2. One source of truth for verdict shape. Add a verdict pattern to Shape's schema matching the module's output. Fix Diff's schema pattern to include the ": <call>" suffix the tool prints. framework.yaml regexes must be derived from the schemas, not from module code; add a test that asserts each framework.yaml verdict regex equals the corresponding schema pattern.
3. Add a Pester test that scans tests/ for It/Describe/Context titles containing angle brackets and fails with the file and line. This trap has hit in four-g and four-h.
4. Decide verdict.txt: Diff still writes it, nothing reads it. Report whether anything else in the fleet reads it. Do not delete it this slice.
5. Write docs/prompts/<date>-slice-four-i.md (this prompt) and the matching .report.md with: fleet grading table, SelfTest counts before and after, and any disagreement between a schema and its tool that you could not resolve.

Do not commit, push or tag. Edit and stage, then stop and report.\
