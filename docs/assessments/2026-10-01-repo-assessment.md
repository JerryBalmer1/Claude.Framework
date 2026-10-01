# Read-only repo assessment: `C:\__Code\_____AIFramework` (2026-10-01)

Nothing was modified. Git was used only for `status`, `log`, `branch`, `remote`, `ls-remote`, `rev-list`, `rev-parse`, `ls-tree` and `cat-file`, plus `merge-base --is-ancestor` once. No `fetch` was run, so "ahead/behind" compares against the local copy of the remote branch. Where it matters, the live remote was checked with `ls-remote`.

---

## 1. Canonical list (quoted source)

Only one canonical list exists. It is in `Claude.Skills/docs/framework/sessions/2026-09-30-altitude-map.html`, lines 379–390 (Band 5, "ideal repo" table):

| Ideal repo | Role (quoted) |
|---|---|
| Claude.Root | "The signed origin. Law tags. Nothing derives without it. Signs; never runs." |
| Claude.Chain | "The controller. Identity chain, seam-object schema, ledger writing path, the growth loop (survives-N)." |
| Claude.Substrate | "Builds agent images. Ansible lives here. Produces immutable images to a registry." |
| Claude.Modules | "PowerShell module monorepo + the build that publishes to the local feed. Test, sign, publish." |
| Claude.Skills | "Skills that consume modules by version and write seam objects. Schema enforced on write." |
| Claude.Ontology | "Ontology Builder. Dependent service Jerry happens to own. Harvests type systems into a registry." |
| Claude.Portal | "Renders the graph and the boards. The thing you look at. Consumes everything, authors nothing." |

- Lines 393–411 of the same file map the inventory as of `20260930T184806Z` onto these seven names. That mapping is used in section 3.
- `docs/html/the-four-visual.html` has no repo list. The only repo name in it is the footer at line 437 (`Claude.Skills/docs/ologies/`).
- `_reports/20260930T195146Z.responsibility-map.md` (lines 13–20 and 27 onward) uses the same seven names. It does not conflict with Band 5.

---

## 2. Inventory

Compared with the workspace list:

- **On disk but not in the workspace list:** `_reports`, `_undecided.ClaudeChain`, `Claude.Portal`, `dgp-ai-governance`.
- **In the workspace list but missing:** none.

Other gaps:

- This session's configured working directories name `Ansible`, `TerraformAST` and `TerraformTools`. None of them exist on disk.
- Band 5 also names `genesis-protocol`, `PSModuleGraph_old` and `claude.agent.*`. None of those are under this root either.
- There is a loose root file, `2026-09-30-conversation-as-containers.html`. A file with the same name is the one untracked file in Claude.Skills.

| Folder | Git | Remote | Branch | Ahead / behind | Uncommitted / untracked | Last commit | What it contains |
|---|---|---|---|---|---|---|---|
| `_reports` | no | none | — | — | — | — | 5 agent report files from 20260930 (inventory, remediate.ps1, handoff, responsibility map, container proposal) |
| `_undecided.ClaudeChain` | yes | github.com/JerryBalmer1/ClaudeChain | claude/grok-fingerprint-notes | 0 / 0 locally. `ls-remote`: "Repository not found" | 0 / 0 | 2026-09-26 | TypeScript/pnpm tool that turns a repo into typed objects (files, symbols, call edges, AST) with hashes and provenance (README) |
| `claude-code-cage` | yes | JerryBalmer1/claude-code-cage | main | 0 / 0 (live) | 0 / 0 | 2026-09-27 | Container image that cages Claude Code. README says it is "Built by dgp-ai-governance" |
| `Claude.Chain` | yes | JerryBalmer1/Claude.Chain | main | 2 ahead (live remote is at `2d41b37`) / 0 | 0 / 0 | 2026-09-30 | PowerShell module for the signed, append-only, hash-chained claim ledger (`Add-Claim`, `Add-Delegation`, `Test-Chain`), with `ledger/genesis.json` |
| `Claude.Fuzzer` | yes | JerryBalmer1/Claude.Fuzzer | main | 0 / 0 locally. `ls-remote`: "Repository not found" | 0 / 0 | 2026-09-19 | Frozen corpus of adversarial cases plus a dry-run oracle (README: "claude.build.fuzzer") |
| `Claude.Inspector` | yes | JerryBalmer1/Claude.Inspector | main | 0 / 0 locally. `ls-remote`: "Repository not found" | 0 / 0 | 2026-09-19 | Read-only inspector for `.claude/settings.json`, with optional policy halt (README: "claude.build.inspector") |
| `Claude.Modules` | yes | JerryBalmer1/Claude.Modules (no branches on the remote) | main (unborn) | no upstream | 0 / 0 | no commits | Empty, only `.git` |
| `Claude.Portal` | yes | JerryBalmer1/Claude.Portal (`ls-remote` returns no main) | main | no upstream, 3 local commits not on the remote | 0 / 0 | 2026-09-30 | Read-only view of a Claude.Chain ledger. The chain view is built; the graph and seam views are "blocked upstream" (README). `.modules/Claude.Chain/0.2.0` is installed from the feed |
| `Claude.Skills` | yes | JerryBalmer1/Claude.Skills | feature/settings-trap | 0 / 0 (live) | 0 / 1 (`docs/framework/sessions/2026-09-30-conversation-as-containers.html`) | 2026-09-30 | Checked-out branch: docs and framework HTML, `.claude`, `.githooks`, `tests`. `main` holds only `Claude.Chain.Identity/` and README.md. The two branches have separate histories: main is not an ancestor of HEAD |
| `Claude.Substrate` | yes | JerryBalmer1/Claude.Substrate | main | 0 / 0 (live) | 0 / 0 | 2026-09-30 (1 commit) | `Claude.Substrate.Feed` (local PSRepository feed module), `image/` (Dockerfile, compose, entrypoint) |
| `ClaudeGenesisTemp` | yes | JerryBalmer1/ClaudeGenesisTemp | claude/chain-stubs-20260926 | 0 / 0 (live) | 0 / 0 | 2026-09-30 | SPEC.md and GOD_PLAN.md for a Genesis PowerShell module, plus `.ledger`, `audit` and `legacy` folders. No README. 38 local and remote branches |
| `dgp-ai-governance` | yes | JerryBalmer1/dgp-ai-governance | main | 0 / 0 (live) | 0 / 0 | 2026-09-30 | Signed charter, key-custody rules, a 3-line signed ledger, witness scripts, `.keys` |
| `OntologyBuilder` | yes | JerryBalmer1/OntologyBuilder | main | 0 / 0 (live) | 0 / 0 | 2026-09-30 | Harvests Terraform schemas and renders graphs. Has a vendored copy of `src/modules/PSGraphRender` |
| `PSModuleDependencyGraph` | yes | JerryBalmer1/PSModuleDependencyGraph | develop | 0 / 0 (live) | 0 / 0 | 2026-09-29 | Static (AST) dependency graph of a PowerShell module |

Three remotes answer "Repository not found": `ClaudeChain`, `Claude.Fuzzer` and `Claude.Inspector`. `ls-remote` worked with the same credentials for the other repos. That suggests these three were renamed, deleted or moved (*inferred, not verified*).

---

## 3. Mapping

### Actual folder → canonical repo

| Actual | Canonical | Note |
|---|---|---|
| Claude.Chain | Claude.Chain | Name and role match |
| Claude.Skills | Claude.Skills, and temporarily part of Claude.Chain | `main` holds `Claude.Chain.Identity`, which belongs to Chain |
| Claude.Substrate | Claude.Substrate, and ambiguous for Claude.Modules | The feed module lives here. Band 5 gives "the build that publishes to the local feed" to Modules (*inferred conflict*) |
| Claude.Modules | Claude.Modules | Empty |
| Claude.Portal | Claude.Portal | Name and role match |
| OntologyBuilder | Claude.Ontology, and part of Claude.Modules and Claude.Portal | Band 5 line 403: vendored PSGraphRender should go to Modules. Graph rendering is the Portal's role (*inferred*) |
| PSModuleDependencyGraph | Claude.Modules | Band 5 line 402 |
| dgp-ai-governance | ambiguous: Claude.Root / Claude.Chain / Claude.Substrate | Signed charter and key custody fit Root (responsibility-map line 31). Its ledger was succeeded by Chain's genesis. claude-code-cage says dgp builds the cage, which is Substrate-shaped (*inferred*) |
| ClaudeGenesisTemp | ambiguous: Claude.Root / Claude.Chain, or graveyard | Band 5 line 398 calls it a graveyard with a successor |
| _undecided.ClaudeChain | ambiguous | Band 5 line 397 maps it to Claude.Chain. Its actual content (a TypeScript repo ingester) matches neither Chain's PowerShell ledger nor any other role cleanly. Closest are Ontology or Modules (*inferred*) |
| Claude.Fuzzer | ambiguous: Claude.Modules or Claude.Chain | Band 5 line 405 leaves this undecided |
| Claude.Inspector | ambiguous: Claude.Modules or Claude.Chain | Band 5 line 405 leaves this undecided |
| claude-code-cage | Claude.Substrate? | Band 5 line 409 says "Not enough to place" |
| _reports | no match | Report output, not a repo |

### Canonical repo → actual folders holding its function today

| Canonical | Where the function lives today |
|---|---|
| Claude.Root | No folder. `dgp-ai-governance` (charter, key custody), `ClaudeGenesisTemp` (spec only), and `genesis.json` in Claude.Chain (`root_fingerprint`) |
| Claude.Chain | Claude.Chain, Claude.Skills@main (Identity module), dgp-ai-governance (prior ledger), and possibly Fuzzer/Inspector |
| Claude.Substrate | Claude.Substrate and claude-code-cage. Ansible is absent from disk |
| Claude.Modules | Claude.Modules (empty), PSModuleDependencyGraph, OntologyBuilder/src/modules/PSGraphRender, Claude.Substrate.Feed (*inferred*) |
| Claude.Skills | Claude.Skills |
| Claude.Ontology | OntologyBuilder. No folder named Claude.Ontology |
| Claude.Portal | Claude.Portal (chain view), and OntologyBuilder's render step (graph) |

---

## 4. Migration status

| Functionality | Now | Should be | Status |
|---|---|---|---|
| Claude.Chain.Identity (ECDSA P-384 signing identity: `New-`/`Initialize-`/`Test-`/`Get-ChainIdentityStatus`, tests, `docs/GENESIS.md`) | Claude.Skills, `main` branch only (commits `df19c1f` "temporary home; belongs in Claude.Chain" and `50e39e9`). Not on the checked-out `feature/settings-trap` | Claude.Chain | **Not started.** Details below |
| PSGraphRender | `OntologyBuilder/src/modules/PSGraphRender` (vendored) | Claude.Modules, consumed from the feed | **Not started.** Claude.Modules has no commits |
| PSModuleDependencyGraph | its own repo | Claude.Modules | **Not started** |
| Module feed and publish build | `Claude.Substrate/Claude.Substrate.Feed` | Claude.Modules per Band 5 line 385 (*inferred reading*) | **Not started** in Modules. The feed works and Portal already installs Claude.Chain 0.2.0 from it |
| Ledger (hash chain) | `dgp-ai-governance/ledger` (3 lines, last change 2026-09-27) | Claude.Chain | **Complete** as a successor. Chain's `genesis.json` has `prior_chain: dgp-ai-governance/ledger/chain.jsonl` and `prior_final_hash: edbde09d…`. dgp's file has not been removed (and doesn't need to be) |
| Signed root, charter, key custody | dgp-ai-governance; ClaudeGenesisTemp SPEC (design only) | Claude.Root | **Not started.** No Claude.Root folder exists. Chain holds only the `root_fingerprint` |
| Genesis module (ClaudeGenesisTemp) | `ClaudeGenesisTemp/src/Genesis` | Claude.Chain / Claude.Root | **Partial.** Chain implements a ledger and genesis. Per responsibility-map line 33, GenesisTemp's `FunctionsToExport = @()`, so there was little code to carry over. Root succession and revocation in SPEC are not in Chain (Chain README: "scope, expiry and revocation are not implemented") |
| ClaudeChain (TypeScript ingester) | `_undecided.ClaudeChain` | Claude.Chain per Band 5 line 397 | **Not started**, and the mapping is doubtful. Claude.Chain has no TypeScript and no repo ingester. The remote is not found |
| Graph rendering | OntologyBuilder (PSGraphRender, RenderGraph task) | Claude.Portal | **Partial.** Portal has the chain view only. Its graph view is "blocked upstream" |
| Agent image | `Claude.Substrate/image` and claude-code-cage (own Dockerfile) | Claude.Substrate | **Partial** (*inferred*). Two separate images. The cage hasn't been folded in |
| Fuzzer / Inspector | own repos | Modules or Chain (undecided) | **Not started.** The target hasn't been decided |

### Claude.Chain.Identity in detail

- **Claude.Chain has a genesis entry:**
  - `ledger/genesis.json` exists. It records the root fingerprint `76107a0b…`.
  - `ledger/chain.jsonl` line 1 is `i:0`, `identity: chain.genesis`, `actor: jerry`.
  - Both were added in commit `d8627b3` on 2026-09-30.
- **The module itself is not in Claude.Chain.** Chain's tree has no Identity files.
- **Chain depends on it from outside the repo:**
  - README.md line 7: "Initialize-ChainIdentity from the Claude.Chain.Identity module"
  - Comments in `private/Get-ChainSigningKey.ps1`
- **The ledger records it.** `chain.jsonl` line 3 records "Claude.Chain.Identity 0.2.1" in the agent-0 image.
- **The current publish path still points at the temporary home.** Substrate's README publishes it from `<Claude.Skills main checkout>\Claude.Chain.Identity`.
- The precondition for moving it is met: the genesis entry exists. The move itself has not started.

---

## 5. Dead or duplicate candidates

No folder meets all three criteria (no remote, no commits in 30+ days, contents fully present elsewhere). Every repo has a remote URL configured, and the oldest last commit is 2026-09-19 (12 days ago).

Near-misses worth a decision (flagged only):

- **`_undecided.ClaudeChain`:** its remote returns "not found". Its last commit is 2026-09-26, and it is checked out on a non-main branch. Its contents are not present elsewhere.
- **`Claude.Fuzzer` and `Claude.Inspector`:** their remotes return "not found". If those repos were deleted, these local copies are the only copies. That makes them the opposite of duplicates (*inferred*).
- **`ClaudeGenesisTemp`:** the remote is live and it had a commit yesterday. Band 5 line 398 says it has a successor by an audit doc (`_undecided.ClaudeChain/docs/GENESIS_AUDIT.md` exists; not read).
- **`Claude.Portal`:** its 3 commits exist only locally. The remote has no main.
- **`Claude.Modules`:** an empty placeholder.
- **Root `2026-09-30-conversation-as-containers.html`:** likely duplicates the untracked file of the same name in Claude.Skills. Not diffed (*inferred*).

---

## 6. Refusals

None. Every folder was readable, and no tool, permission rule or settings check refused a read.
