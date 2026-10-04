[WORKSPACE: Claude.Framework] — slice four-j: pin child commits per heartbeat, trace the regression

Context: four-i graded the real fleet green but surfaced two things. Claude.Modules commit e060c0f landed mid-run, so getters ran at e060c0f while Modules tests ran at aa598e2; the run didn't know it was torn. Diff reported regressed (Secrets low 411 to 419, Shape holes 286 to 291) and nobody traced it. Both slices are committed: Framework at the four-i commit, Modules at e060c0f, Ontology at the catalogue seed commit. Report at docs/prompts/2026-10-04-slice-four-i.report.md.

Do:
1. Pin children. At heartbeat start, record each child's HEAD under repos/ into the heartbeat record (repo, branch, commit, dirty flag). At heartbeat end, read them again. If any child's commit moved, or dirty flipped, the heartbeat fails with a torn verdict naming the child and both commits. Status reads the pinned commit, not live HEAD. Add the pin block to the heartbeat schema; this is Framework's own schema, so editing it is in scope.

2. Rerun clean. Run one heartbeat on a clean tree (git status empty, no editing while it runs). Record it. If Secrets low and Shape holes fall back to 411 and 286, the four-i regression was the agent's own edits and the trace is one line in the report. If they don't, trace: diff the Secrets low findings and the Shape hole lists between heartbeat 20261004-035420-640 and the new run, name the files that carry the new ones, and state whether the cause is the four-i edits, the Modules e060c0f commit, or the Ontology catalogue seed. Do not fix anything you find; report it.

3. Dirty's own noise. Dirty says unfit when the agent's in-flight edits are in the tree. That is correct but makes every heartbeat run during a slice unfit. Add a `-Baseline` switch to the heartbeat that records the dirty file list at start and reports Dirty as unfit only for files that were not already dirty at start. Default off. Document that a baseline run is a working read, not a witness, and mark it as such in the record.

4. Tests. Pester for: pin block present and valid in a heartbeat record; a torn heartbeat is detected when a fixture child moves between start and end (fake it with a fixture repo and a commit mid-run); baseline mode excludes pre-existing dirty files and marks the record. Angle-bracket scan must stay green. Run SelfTest; report counts before and after.

5. Report at docs/prompts/<date>-slice-four-j.report.md: the pin block shape, the clean rerun's seven lines, the regression trace result, and anything you guessed.

Do not edit anything under repos/. Do not commit, push or tag. Edit and stage, then stop and report.
