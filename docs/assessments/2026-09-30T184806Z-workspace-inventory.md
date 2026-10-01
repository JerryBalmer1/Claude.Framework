# AIFramework workspace inventory — 20260930T184806Z

## Prediction (written before Phase 1, not edited afterwards)

- Workspace file: C:\__Code\_____AIFramework\AIFramework.code-workspace; all 13 folders are relative to that root.
- Root mtimes: 10 folders were written today at 11:31-11:33 (the interrupted copy). dgp-ai-governance (9/27),
  OntologyBuilder (9/28) and PSModuleDependencyGraph (9/29) were not, so I expect those 3 were moved or created in place and are intact.
- Expected DAMAGED: 2-3. My guesses: TerraformAST (VS Code shows "modified" right after a copy, which fits truncated
  or missing files from MAX_PATH in .terraform/providers paths), and one of claude-code-cage / Claude.Inspector
  (deep node_modules paths).
- Expected bloat: .terraform provider binaries in TerraformAST, TerraformTools and OntologyBuilder (hundreds of MB each);
  node_modules in claude-code-cage and/or Claude.Inspector/Fuzzer.
- Expected lineage: ClaudeGenesisTemp is a scratch iteration of genesis-protocol, and ClaudeChain is either
  its successor or its predecessor. I expect genesis-protocol to be newest, with ClaudeGenesisTemp as DEAD.
- Expected: the untracked files in Claude.Governor / Claude.Skills / dgp-ai-governance are mostly real work, not junk.

---

## Summary table

Sizes are on disk, including `.git`. Bloat is regenerable directories. "Behind N" is against locally cached remote refs (nothing was fetched).

| name | bucket | remote | branch | last commit | size | bloat | proposed action |
|---|---|---|---|---|---|---|---|
| ClaudeChain | **DAMAGED** | GitHub ClaudeChain | claude/grok-fingerprint-notes | 2026-09-26 | 84.3 MB | node_modules 83.5 MB | delete node_modules (all 32 missing files are inside it) |
| TerraformAST | **INTACT+WORK** | GitHub TerraformAST | main | 2026-09-24 | 20.6 MB | none | none. 8 files have an uncommitted TerraformAST→TerraformTools rename |
| Claude.Governor | **INTACT+WORK** | **none** | main (unborn, 0 commits) | never | 0.1 MB | none | none. The whole repo is untracked; only 2 copies exist on disk |
| Claude.Skills | **INTACT+WORK** | GitHub Claude.Skills | feature/settings-trap | 2026-09-29 | 0.6 MB | none | none. 10 untracked docs + **4 unpushed commits** |
| dgp-ai-governance | **INTACT+WORK** | GitHub dgp-ai-governance | main (behind 1) | 2026-09-27 | 0.1 MB | none | none. Untracked `witnesses/witness-2026-09-27.txt` |
| OntologyBuilder | **INTACT+WORK** | GitHub OntologyBuilder | main | 2026-09-28 | 129.3 MB | .terraform 61.9 + .cache 60.0 MB | none. Staged delete of a .docx; bloat protected by CLAUDE.md |
| Ansible | **UNKNOWN** | n/a (no .git) | n/a | n/a | 0.4 MB | none | none. Older working-tree snapshot of Ansible.Stack.Controller without .git |
| ClaudeGenesisTemp | INTACT | GitHub ClaudeGenesisTemp | claude/chain-stubs-20260926 | 2026-09-26 | 312.7 MB | .tools 286.7 MB | delete .tools (build.ps1 re-fetches, hash-pinned) |
| TerraformTools | INTACT | GitHub TerraformTools | feature/add-ast-parser | 2026-09-29 | 61.7 MB | infra/.terraform 35.8 MB | delete infra/.terraform |
| Claude.Fuzzer | INTACT | GitHub Claude.Fuzzer | main (behind 9) | 2026-09-19 | 0.3 MB | none | none |
| Claude.Inspector | INTACT | GitHub Claude.Inspector | main (behind 9) | 2026-09-19 | 0.2 MB | none | none |
| claude-code-cage | INTACT | GitHub claude-code-cage | main | 2026-09-27 | 0.1 MB | none | none |
| PSModuleDependencyGraph | INTACT | GitHub PSModuleDependencyGraph | develop | 2026-09-29 | 1.7 MB | none | none |
| *genesis-protocol* | INTACT+WORK (absent) | local bare `~/.genesis-heaven/heaven.git` only | main (1 unpushed) | 2026-09-24 | 0.2 MB | none | your call whether to add |
| *claude.agent.core* | INTACT (absent) | GitHub | develop | 2026-09-24 | 4.2 MB | none | add? was in OntologyBuilder.code-workspace |
| *claude.agent.images* | INTACT (absent) | GitHub | develop | 2026-09-25 | 7.3 MB | none | your call |
| *claude.agent.tools* | INTACT (absent) | GitHub | develop | 2026-09-25 | 3.5 MB | none | your call |
| *claude.agent.docs* | INTACT (absent) | GitHub | develop | 2026-09-24 | 0.6 MB | none | your call |
| *PSGraphRender* | INTACT (absent) | GitHub | main | 2026-08-27 | 74.1 MB | tests/browser/node_modules 10.6 MB | your call (vendored in OntologyBuilder) |
| *PSModuleGraph* (`PSModuleGraph_old`) | INTACT (absent) | GitHub PSModuleGraph | main | 2026-08-27 | 64.7 MB | none | your call; untracked `test.md` |

Nothing is DEAD or ORPHAN. Reclaimable in the workspace by the script: **~406 MB** (83.5 + 286.7 + 35.8).

---

## Phase 1 detail

**Method.** All git calls used `git -c safe.directory=* --no-optional-locks`, so nothing was written to any repo or to config.
Commands: `status --porcelain=v1 --untracked-files=all`, `fsck --no-dangling`, `rev-list`, `log`. For partial-copy
detection, **git status alone is not enough**: ignored directories are invisible to it. Each copy was also diffed against
its source with `robocopy <src> <copy> /L /E /XJ /FFT` (list-only, no copy).

**Workspace file.** `C:\__Code\_____AIFramework\AIFramework.code-workspace`. All 13 entries are relative and resolve under `C:\__Code\_____AIFramework\`.

**Git status and fsck.** Exit code 0 for all 12 repos. fsck reported only `HEAD points to an unborn branch` for Claude.Governor.

**Source comparison (robocopy /L, source → workspace copy):**

| copy | source | missing in copy | other differences |
|---|---|---|---|
| ClaudeChain | C:\__Code\ClaudeChain | **32, all in node_modules, path length 264–295** | FETCH_HEAD |
| Claude.Fuzzer / Claude.Inspector / claude-code-cage / TerraformTools | C:\__Code\<same> | 1 commit-graph file each | copy has newer FETCH_HEAD, remote refs and new loose objects: **VS Code autofetched in the copy after it was made**, not damage |
| Claude.Governor | C:\__Code\Claude.Governor | 0 | copy has an empty FETCH_HEAD |
| Claude.Skills / ClaudeGenesisTemp / TerraformAST | C:\__Code\<same> | 0 | .git/config, FETCH_HEAD mtimes only |
| dgp-ai-governance | C:\__Code\_Repo\dgp-ai-governance | 3 pack files | same HEAD 5dce842; workspace copy is a separate clone (root mtime 9/27), not a byte copy |
| Ansible | C:\__Code\Ansible.Stack.Controller (excl. .git) | 0 | source has newer `.build.ps1` and `PSModuleToSwaggerJson.psm1` (uncommitted there); the copy has a newer `URLs.md` |

**No source found:** OntologyBuilder (`C:\__Code\OntologyBuilder.code-workspace` still references `C:\__Code\OntologyBuilder`, which no longer exists, so it was **moved**; the remote is in sync at 788d750). PSModuleDependencyGraph (no same-named dir; the remote is in sync).

**Every source that exists has the same HEAD as its copy**, and its status matches the copy's (same untracked files / same modifications).

**Untracked files, junk vs work:**
- Claude.Governor: 13 files (build.ps1, psm1/psd1, AGENTS.md, prompts…). **Real work.** No commits and no remote, so these two directories are the only copies anywhere.
- Claude.Skills: 9 HTML docs + `docs/framework/files.zip` dated 2026-09-30. **Real work.** The branch also has 4 commits (fdaf5f6..a2d9197) not on any remote ref.
- ClaudeGenesisTemp: `ClaudeGenesisTemp.code-workspace`. **Junk** (editor file).
- dgp-ai-governance: `witnesses/witness-2026-09-27.txt`. It's output of the committed witness script ("tamper-evident chain state"). **Probably meant to be committed. Needs your eyes.**
- OntologyBuilder: none untracked; `D Claude-Memory-Persistence-Disclosure.docx` is a **staged deletion**.
- TerraformAST: 8 modified files. The diff survives `--ignore-all-space --ignore-cr-at-eol`, so it isn't EOL noise. It renames TerraformAST → TerraformTools across .build.ps1, Dockerfile, psd1/psm1 and tests. **Real work**, identical in `C:\__Code\TerraformAST`.

**Bloat found (top-most dirs only):** ClaudeGenesisTemp `.tools` 286.7 MB (PSScriptAnalyzer 285.5) · ClaudeChain `node_modules` 83.5 MB · OntologyBuilder `sources/terraform/.terraform` 61.9 MB and `.cache` 60.0 MB · TerraformTools `infra/.terraform` 35.8 MB · PSGraphRender `tests/browser/node_modules` 10.6 MB. **No `*.tfstate*` anywhere. No .venv/obj/packages.**

---

## Lineage groups

### ClaudeChain / ClaudeGenesisTemp / genesis-protocol — **three separate histories**

| repo | root commit(s) | commits | newest commit |
|---|---|---|---|
| ClaudeGenesisTemp | 40b2890 | 64 | 372b78b 2026-09-26 03:47 (claude/chain-stubs-20260926) |
| ClaudeChain | e18e21e | 15 | 483fd9e origin/main, 74cc632 HEAD 2026-09-26 03:10 |
| genesis-protocol | fe9f0da, 8d2d3af | 4 | 845925f 2026-09-24 23:47 |

- **No root commits are shared, so none of the three is an ancestor of another.** `git merge-base --is-ancestor` has nothing in common to find. I am not picking one.
- **Content:** ClaudeChain ∩ ClaudeGenesisTemp share only `.gitattributes`, `.gitignore` and `ci.yml`. genesis-protocol (Python/shell ledger with receipts and hooks) shares 1 of 50 blobs with ClaudeGenesisTemp.
- **Relationship by intent, not history:** ClaudeChain commit 9669374 "docs: audit the Genesis playground before building" adds `docs/GENESIS_AUDIT.md`, which records what ClaudeGenesisTemp contains and what is carried forward or discarded. So ClaudeChain is a **deliberate rewrite/successor** of ClaudeGenesisTemp, not an iteration of its history. genesis-protocol predates both and shows no link to either except the "Genesis" name.
- The newest commit in the group is ClaudeGenesisTemp 372b78b (26 Sep 03:47), 37 minutes after ClaudeChain's HEAD. Both were active the same night.
- Other ClaudeGenesisTemp copies: `C:\__Code\ClaudeGenesisTemp` (identical, HEAD 372b78b), `C:\__Code\_ClaudeGeneBackup\ClaudeGenesisTemp` (HEAD 03dd980, **is an ancestor** of 372b78b, clean, nothing unpushed).
- genesis-protocol: its only remote is `heaven` → `C:/Users/jlbal/.genesis-heaven/heaven.git` (local bare). `heaven/main` (89d9cfd) is an ancestor of `main`; **845925f "Law v2: reproduction" exists only in the working repo.** No GitHub remote.

### PSModuleGraph family
- `C:\__Code\PS.Module.Dependency.Analyzer` (1 commit, "Init" 6bd30af) is the **root of PSModuleGraph**. `PSModuleGraph_old` (191 commits) and both `__AI.Agent.Claude.PowerShellModuleBuilder\scratch\PSModuleGraph*` share root 6bd30af.
- `scratch\PSModuleGraph-d39b125` has origin `C:/__Code/PSModuleGraph`, **a path that no longer exists** (renamed to `_old`). That clone's remote is broken.
- Workspace **PSModuleDependencyGraph has a different root (b645446), so it is not a copy or iteration by history**. It may be a successor by intent; I didn't find a document saying so.

### TerraformAST / TerraformTools
TerraformAST's uncommitted diff renames it to TerraformTools. TerraformTools is a separate repo (root d09cf86, 3 commits, `feature/add-ast-parser`). The two are separate histories; the diff reads like the move from one to the other was started but not finished.

### Ansible
Workspace `Ansible` has no `.git` and holds the working tree of `C:\__Code\Ansible.Stack.Controller` (GitHub Ansible.Stack.Controller, HEAD cf1cfe9 2026-08-04 "init"), minus the source's two uncommitted edits, plus a newer `URLs.md`. `C:\__Code\PS.Ansible` is a different project.

---

## Bucket evidence (one line each)

- **ClaudeChain → DAMAGED**: robocopy /L shows 32 files missing, all under node_modules with paths of 264–295 chars; clean source at the same HEAD exists.
- **TerraformAST → INTACT+WORK**: fsck ok; 8 `M` files that are a real rename, not EOL; the source has the same diff.
- **Claude.Governor → INTACT+WORK**: fsck ok; 0 commits, no remote, 13 untracked source files.
- **Claude.Skills → INTACT+WORK**: fsck ok; 10 untracked docs + 4 commits not on any remote.
- **dgp-ai-governance → INTACT+WORK**: fsck ok; untracked witness output that looks meant to be committed.
- **OntologyBuilder → INTACT+WORK**: fsck ok; staged deletion `D Claude-Memory-Persistence-Disclosure.docx`.
- **Ansible → UNKNOWN**: no `.git`; can't run status/fsck; differs from its apparent source in 3 files in both directions.
- **ClaudeGenesisTemp → INTACT, not DEAD**: fsck ok, only editor-file untracked. Has a successor, but also a GitHub remote and a 4-day-old commit, so it fails 2 of the 3 DEAD tests.
- **Claude.Fuzzer, Claude.Inspector, claude-code-cage, TerraformTools, PSModuleDependencyGraph → INTACT**: status clean, fsck ok, source (where it exists) at the same HEAD.

---

## Proposed script

`_reports\20260930T184806Z.remediate.ps1`. **Not run.** It passes the PowerShell parser.
The script was never run and was discarded on 2026-10-01 because its pinned paths and hashes were stale; its reasoning stays in this file.
Dry-run by default; `-Execute` to apply. Before each action it re-checks HEAD and status and skips if anything changed.
- DAMAGED ClaudeChain: re-verifies the missing set is still node_modules-only, then deletes node_modules.
  **Deviation from the brief:** the brief asked for `robocopy /E /MOVE`. /MOVE would empty `C:\__Code\ClaudeChain`,
  which is currently the clean independent copy. Since all the damage is inside a regenerable directory, removing that
  directory is the full repair. The /MOVE line is present but commented out.
- Bloat: ClaudeChain node_modules, TerraformTools infra/.terraform, ClaudeGenesisTemp .tools. Prints bytes reclaimed.
  **Excludes OntologyBuilder `.terraform` and `.cache`**, because OntologyBuilder/CLAUDE.md says never delete `.terraform` and the cache avoids minutes-long cold runs.
- DEAD: empty list (nothing qualified).
- Absent: `-AddToWorkspace <paths>` only, default empty. Backs up the workspace file before editing.

---

## Prediction vs result

| predicted | actual |
|---|---|
| 2–3 DAMAGED: TerraformAST + claude-code-cage or Claude.Inspector | **1 DAMAGED: ClaudeChain**, and only inside node_modules. TerraformAST's "modified" is real, pre-existing work. |
| .terraform bloat in TerraformAST/TerraformTools/OntologyBuilder | TerraformTools and OntologyBuilder yes; **TerraformAST has none**. The largest bloat was one I didn't predict: **ClaudeGenesisTemp `.tools` (PSScriptAnalyzer, 285 MB)** |
| node_modules in claude-code-cage / Inspector / Fuzzer | **None there**. The only node_modules in the workspace is in ClaudeChain. |
| genesis-protocol newest, ClaudeGenesisTemp DEAD | **Wrong on both.** genesis-protocol is the oldest (9/24) and unrelated by history. ClaudeGenesisTemp has the newest commit and isn't DEAD by your criteria. ClaudeChain is its successor by an explicit audit commit, not by history. |
| untracked in Governor/Skills/dgp = real work | Right, and it's more exposed than it looks: Governor has **no commits and no remote**, and Skills has **4 unpushed commits**. |
| 3 older-mtime folders intact | Right: OntologyBuilder was moved, dgp-ai-governance was a fresh clone, and PSModuleDependencyGraph has no other copy. |
| (not predicted) | Workspace `Ansible` isn't a git repo at all. |

### What would prove this classification wrong
- **INTACT here only means "matches the source on this disk"**, or "fsck ok" where no source exists. If a source is itself a damaged copy, the match proves nothing. OntologyBuilder and PSModuleDependencyGraph have no local source, and their remotes weren't fetched. A `git fetch` + `git status -sb` comparison against GitHub would show whether local and remote have diverged.
- robocopy /L compares size and timestamp (/FFT = 2 s granularity), **not content hashes**. A file that was truncated to its original size, or whose timestamp was preserved, would pass. `git status` covers tracked files; ignored/untracked files have only the size+time check.
- If the 32 missing ClaudeChain paths had included anything outside node_modules, the bucket would still be DAMAGED but the repair would have to be a real re-copy. The script re-checks this before acting.
- The ClaudeChain ⟂ ClaudeGenesisTemp conclusion rests on disjoint root commits. If one was built by `git replace` or a graft/shallow clone, the histories could be related in a way this check misses. Checked afterwards: none of the three is shallow, and none has replace refs or grafts, so disjoint roots means disjoint history.
- Ansible is UNKNOWN because it might be deliberately de-gitted (a snapshot), or it might have lost its `.git` in the copy. Only you know which.
