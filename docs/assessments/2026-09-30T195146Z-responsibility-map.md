# Responsibility map: 20260930T195146Z

Read-only pass over every directory under `C:\__Code\_____AIFramework`. Git was run only with `-c safe.directory=* --no-optional-locks`. Nothing in any repo was written, moved, fetched, reset or committed. Citations are `repo/path:line` relative to `_____AIFramework`. "Intent" marks a doc or commit-message claim rather than code behavior.

**Tree this pass read.** Five repos have commits dated today at 12:45–12:46 (local): Claude.Skills `6c3ee3e`, ClaudeGenesisTemp `e3ba606`, dgp-ai-governance `8299b45`, OntologyBuilder `5d8dee3` and TerraformAST `0fcd0f5`. Claude.Inspector (`cf5105f`) and Claude.Fuzzer (`1cf2c63`) were fast-forwarded by `pull` (reflog). All clean except Claude.Governor, whose `main` is unborn and has 13 untracked files. Ansible has no `.git`.

---

## Phase 0: prediction (written before reading any repo; not revised)

Written after reading only the prior inventory (`20260930T184806Z.md`) and the directory listing, so the only inputs are repo names, commit dates and that report's lineage notes.

- **Claude.Root.** I expect no repo to own this cleanly. Pieces will sit in dgp-ai-governance (law tags, witness chain) and Claude.Governor (policy/prompts), and possibly signing-key handling in ClaudeChain, so I expect a three-way split.
- **Claude.Chain.** I expect ClaudeChain to be the main holder, with ClaudeGenesisTemp holding an older duplicate of the ledger and checkers. dgp-ai-governance's "tamper-evident chain state" witness script probably duplicates part of the hash-chain idea.
- **Claude.Substrate.** I expect claude-code-cage (container/sandbox for Claude Code) and Ansible (build tooling) to carry this. I expect the image build to be split between them, with no registry anywhere.
- **Claude.Modules.** I expect PSModuleDependencyGraph plus the PowerShell modules scattered across TerraformTools, TerraformAST, Claude.Governor and OntologyBuilder's vendored PSGraphRender. I expect no local PSRepository feed to exist.
- **Claude.Skills.** I expect Claude.Skills to own this, mostly as docs and framework HTML rather than runnable skills. I expect it not to import modules by version yet.
- **Claude.Ontology.** I expect OntologyBuilder to own harvesting, with TerraformAST/TerraformTools duplicating the Terraform-parsing part. I expect no published contract.
- **Claude.Portal.** I expect OntologyBuilder (via vendored PSGraphRender) and PSModuleDependencyGraph to render graphs. Claude.Inspector may be a read-side viewer. I expect nothing to enforce "cannot write a claim".
- **Expected splits:** Chain (ClaudeChain / ClaudeGenesisTemp / dgp-ai-governance), Root (dgp-ai-governance / Governor), Ontology (OntologyBuilder / TerraformAST / TerraformTools), Portal (OntologyBuilder / PSModuleDependencyGraph).
- **Expected unmapped:** Claude.Fuzzer (testing/fuzzing of Claude behaviour) fits none of the seven.

---

## Phase 2a: ideal repo → existing repos carrying it

### Claude.Root: authority root, law tags, signing keys, the declaration others read

| repo | citation | portion carried | owned / duplicated |
|---|---|---|---|
| dgp-ai-governance | `charter/CHARTER.md:8` "This charter is the signed root of the DGP governance system"; `scripts/verify_charter.py:20-30` verifies an ECDSA P-384 signature over it; `charter/CHARTER.md.sig.json` | **Implemented** signed root document with principles and lines (`CHARTER.md:13-23`) | **owned** as implementation; the design is duplicated in ClaudeGenesisTemp SPEC |
| dgp-ai-governance | `custody/KEY_CUSTODY.md:4` private key at `.keys/private.pem`; `.gitignore:2-4` | Signing-key custody rules | **owned** (no other repo has key-custody rules; ClaudeGenesisTemp `GOD_PLAN.md:139-146` B5 is a design for synthetic keys only) |
| ClaudeGenesisTemp | `SPEC.md:12,28` `New-GenesisRoot` = rite `ordain-lawgiver`; `SPEC.md:102-108` root/successor keys, `root-revocation`; `SPEC.md:205-209` S8 | **Specified, not implemented**: root identity with successor key and revocation | **duplicated** (design) with dgp-ai-governance; implementation absent: `src/Genesis/Genesis.psd1` `FunctionsToExport = @()`, `Public/`/`Private/` hold only `.gitkeep` |
| — | — | "Law tags" (as git tags or labels) | **no evidence found** |
| — | — | "The declaration other repos read to learn what is authoritative" | **no evidence found**. No code in any repo reads another repo's root. claude-code-cage `README.md:3,7` says it is "Built by `dgp-ai-governance`" (intent), but the `scripts/Build-Cage.ps1` it cites (`README.md:39`) does not exist anywhere under the root |

### Claude.Chain: signed, append-only, hash-chained claims; survives-N growth loop; checkers

| repo | citation | portion carried | owned / duplicated |
|---|---|---|---|
| dgp-ai-governance | `scripts/ledger.py:81-113` `append()` verifies, links `prev`, SHA-384 hashes, **ECDSA-signs** (`:109`), appends (`:111`); `:25-31` block 0's `prev` is the charter hash; `:47-79` `verify()` | The only **signed**, implemented, append-only hash chain; its checker | **duplicated**: three other hash-chain writers exist (below), none signed |
| dgp-ai-governance | `build.ps1:29` `task . Verify, Witness`; `scripts/witness.py:2` dated tip snapshot | Checker entry point; external witness | owned |
| ClaudeGenesisTemp | `legacy/ledger/src/ledger/Ledger.psm1:298` `Add-LedgerRecord`, `:954` `Get-LedgerVerify`; `:18` genesis `'0' * 64`; `:35` payload keys (SHA-256, no signature field) | Unsigned SHA-256 receipt chain of model outputs, plus its verifier | **duplicated** with dgp (different hash, schema, language; unsigned) |
| ClaudeGenesisTemp | `SPEC.md:73-121` S3 receipt schema (`signature` required, `:90`); `SPEC.md:185-201` S7 verification; `SPEC.md:231` append-only | **Specified, not implemented** gpg-signed receipt chain | **duplicated** (design) with dgp |
| ClaudeGenesisTemp | `GOD_PLAN.md:200-211` B10 audit chain; `audit/inbox/` holds 30 hash-named files | Pre-chain review records awaiting unwritten functions (`GOD_PLAN.md:197` B9.2) | owned (unique concept), unarmed |
| Claude.Skills | `.claude/hooks/log-attempt.ps1:4` "Appends one hash-chained JSON line per event to tests/ledger/attempts.jsonl"; `tests/ledger/README.md:3` "append-only, hash-chained ledger… never restarts" | Unsigned SHA-256 chain of hook-observed tool attempts | **duplicated** (third chain format) |
| Claude.Skills | `tests/ledger/Test-TrapLedger.ps1:3` "Verifies the hash chain in a ledger written by .claude/hooks/log-attempt.ps1" | Checker for that chain | duplicated (per-chain checkers) |
| Claude.Inspector | `ClaudeGenesisTemp/legacy/ledger/src/ledger/Ledger.psm1:38-44` Ledger lazily imports `claude.build.inspector`; `Claude.Inspector/CLAUDE.md:10` "`claude.build.ledger` imports this repo, never the reverse" | A **checker** the ledger calls (read-only settings observer, `README.md:3`) | owned (only settings checker) |
| Claude.Fuzzer | `ClaudeGenesisTemp/legacy/ledger/tests/sandbox/fuzzer_import.ps1:4` "Prove Ledger can import the claude.build.fuzzer sibling and run its corpus through the leash"; `src/claude.build.fuzzer/claude.build.fuzzer.psm1:717-720` `Add-FuzzerRegression` "Appends one new frozen case… Never rewrites a line" | Adversarial **checker** and an append-only regression corpus | owned |
| Claude.Governor | `src/Claude.Governor/Claude.Governor.psm1:19-23` five hops `ledger-open → inspector → fuzzer → docs → ledger-close`; `:139` `Status = 'skeleton'` | Sequencing of a ledger-stamped pass (**skeleton**: `README.md:5` "No worker is called") | owned, unimplemented; untracked, no commits |
| — | — | **Survives-N growth loop** | **no evidence found** in any code. The only mention is `Claude.Skills/docs/framework/2026-09-30-altitude-map.html:383` (design). The nearest mechanism is Fuzzer's frozen-fold corpus, which counts folds, not survivals |
| ClaudeChain | `docs/GENESIS_AUDIT.md:107` "**The receipt ledger** … has no role in a static analyzer" (thrown away); `AGENTS.md:313` decision 25 | **None.** ClaudeChain explicitly declines this responsibility | n/a (see unmapped) |

### Claude.Substrate: immutable agent images, registry, writing path baked in; Ansible builds it and is not in it

| repo | citation | portion carried | owned / duplicated |
|---|---|---|---|
| claude-code-cage | `Dockerfile:3-34` builds a Claude Code runtime image, non-root (`:10,30`), hooks baked root-owned mode 555 (`:18-22`), settings baked (`:25`) | The agent image definition, with immutable guard hooks | **owned** (only agent-image definition) |
| claude-code-cage | `README.md:39` `.\scripts\Build-Cage.ps1`; `README.md:27` entrypoint "verifies image signature" | Build and sign step (**intent only**) | **no evidence found**: `Build-Cage.ps1` exists nowhere; `docker/entrypoint.sh:1-20` checks uid and hook readability only, with no signature check |
| claude-code-cage | `README.md:8-10` "The ledger, the private keys, the charter, the scripts — none of that exists in this image's filesystem" | Explicitly **excludes** the ledger writing path from the image | contradicts the ideal ("writing path baked into the image") |
| Ansible | `.build.ps1:65-86` `docker build` of `ansible-pwsh`; `Dockerfile:18` `RUN pip3 install ansible` | Builds an image that **contains** Ansible (the opposite of "not in it"); it does not build the agent image | owned (only Ansible image) |
| Ansible | `.build.ps1:17` help text `Invoke-Build Publish -Registry ghcr.io/myorg`; `:38` registry only prefixes the tag | Registry push (**intent only**) | **no evidence found**: the file ends at `:97` mid-function, with no task defined |
| — | — | Container registry | **no evidence found** anywhere |
| — | — | Ansible playbook | **no evidence found**: no playbook exists; the only `.yml` files are compose and monitoring config |

### Claude.Modules: PowerShell monorepo publishing to a local PSRepository feed; capabilities

| repo | citation | portion carried | owned / duplicated |
|---|---|---|---|
| Ansible | `docker-compose.yml:94-107` `artifacts` service (BaGet, host 5555); `src/artifacts/README.md:3` "package server for local PowerShell modules"; `:28-40` `Publish-Module -Repository AnsibleArtifacts` / `Register-PSRepository` | The **only local PS feed** defined anywhere | **owned**. Nothing in any repo publishes to it |
| Ansible | `PSModules/PSAnsible/0.0.1/PSAnsible.psd1:65`; `PSModules/PSModuleToSwaggerJson/` | Two capability modules | owned |
| TerraformAST | `src/TerraformAST/TerraformAST.psd1:12` exports `Get-TerraformTools`; `.build.ps1:343-374` `Publish-Module … -Repository PSGallery` | HCL-parser capability, published to **PSGallery**, not a local feed | **duplicated** with TerraformTools (same GUID `2d0b1461-…` in both `.psd1`) |
| TerraformTools | `src/TerraformTools/TerraformTools.psd1:12` exports `Get-TerraformAST`, `Get-TerraformSchemaJson`, `…PlanJson`, `…StateJson`, `…OutputJson`, `…ValidationJson`; `.build.ps1:374` PSGallery | Terraform capability module | duplicated (see TerraformAST) |
| PSModuleDependencyGraph | `src/PSModuleDependencyGraph/PSModuleDependencyGraph.psd1:11` exports `Get-PSModuleDependencyGraph`, `Save-PSModuleDependencyGraphHtml`; `README.md:3` static AST graph | PS-code dependency analysis capability | owned (capability) |
| OntologyBuilder | `src/modules/PSGraphRender/PSGraphRender.psd1:3` `ModuleVersion = '0.13.2'`; `ontology.build.ps1:127` imported **by path** | Vendored copy of a module | duplicated (the upstream PSGraphRender repo is outside this root) |
| Claude.Inspector | `src/claude.build.inspector/claude.build.inspector.psd1:3,10` v0.2.0, `Invoke-ClaudeInspector` | Checker packaged as a module | owned |
| Claude.Fuzzer | `src/claude.build.fuzzer/claude.build.fuzzer.psd1:3,10` v0.1.0, three exports | Checker packaged as a module | owned |
| Claude.Governor | `src/Claude.Governor/Claude.Governor.psd1` / `.psm1` | Sequencer module (skeleton) | owned |
| ClaudeGenesisTemp | `src/Genesis/Genesis.psd1` (empty exports); `legacy/ledger/src/ledger/Ledger.psd1` exports `Invoke-LedgerForce`, `Get-LedgerStatus`, `Get-LedgerVerify`, `Get-LedgerEntry` | Two modules (one stub) | owned |
| — | — | Monorepo; module signing | **no evidence found** (no `Set-AuthenticodeSignature` anywhere) |

### Claude.Skills: skills importing modules by version and writing seam objects

| repo | citation | portion carried | owned / duplicated |
|---|---|---|---|
| Claude.Skills | `README.md:6` `skill/<module-name>` branch convention (intent); `module.build.ps1:37` `Install-ModuleFast -CI` from `modules.requires.psd1:2-5` | Version-pinned module install: **tooling only** (Pester, InvokeBuild, ModuleFast), no capability module | owned mechanism |
| Claude.Skills | no `SKILL.md` anywhere in the repo (`git ls-files`) | Skills themselves | **no evidence found** |
| Claude.Skills | `docs/framework/2026-09-30-seam-object.html:136` "The state file for meaning. What a term has to carry to cross a seam." | Seam-object **design** (doc, not code) | owned (design) |
| ClaudeGenesisTemp | `legacy/ledger/.claude/skills/*/SKILL.md`, six skills (`build-snake`, `force-compliance`, `forensic-record`, `validate-output`, `test-verbose`, `build-covenant-test`) | The only actual Claude Code skills on disk | owned; none imports a module by version |
| — | — | Writing seam objects | **no evidence found** |

### Claude.Ontology: harvests type systems into a source registry; dependent service with a published contract

| repo | citation | portion carried | owned / duplicated |
|---|---|---|---|
| OntologyBuilder | `sources/terraform/terraform.schema.build.ps1:5` "Harvests Terraform provider schemas into a structured ontology source tree"; `:12-27` layout and phases; `:379` `Get-TerraformSchemaJson`; `:998` `Write-ProviderTypes`; `:1953` `Get-InferredEdge`; `:2151` `Get-CategoryRuleSet`; `:2411` `Write-OntologyGraph` | Full harvest → docs → flatten → links → classify → graph pipeline | **duplicated** in TerraformTools (unwired) |
| TerraformTools | `src/TerraformTools/private/Write-OntologyGraph.ps1:1-5`, `Write-ProviderTypes.ps1`, `Write-ProviderLinks.ps1`, `Write-ProviderCategories.ps1`, `Get-InferredEdge.ps1`, `Get-CategoryRuleSet.ps1`, `Get-SchemaDump.ps1`, … | Port of the same pipeline into private functions. **Not wired**: no public function calls `Write-OntologyGraph`, `Get-SchemaDump` or `Write-ProviderRecord` | duplicated |
| TerraformTools | `README.md:3-5`; `public/Get-TerraformSchemaJson.ps1` | The harvest's first step, as a public function | duplicated with `OntologyBuilder/…/terraform.schema.build.ps1:379` |
| — | — | **Published contract** for the registry | **no evidence found**. The only contract is the renderer's: `OntologyBuilder/src/modules/PSGraphRender/contract/viewmodel.schema.json:3-4` (`1.1.0`). `ontology.build.ps1:131-134` adapts `graph.json` to it in memory: "the view model is adapted here, in memory, and never written to disk" |

### Claude.Portal: reads the graph and renders it; must never be able to write a claim

| repo | citation | portion carried | owned / duplicated |
|---|---|---|---|
| OntologyBuilder (vendored PSGraphRender) | `src/modules/PSGraphRender/PSGraphRender.psd1:15-19` `New-RenderDocument`, `Show-RenderDocument`…; `TemplateSets/cytoscape/` | Graph-to-HTML renderer (Cytoscape) with a versioned view-model contract | **duplicated** with PSModuleDependencyGraph |
| OntologyBuilder | `ontology.build.ps1:123-168` `task RenderGraph` reads `graph.json`, writes `graph.html`; `:170` default task is `TerraformScript` only | The read-graph-render step for ontology output | owned |
| PSModuleDependencyGraph | `src/PSModuleDependencyGraph/PSModuleDependencyGraph.psd1:11` `Save-PSModuleDependencyGraphHtml`; `Private/ConvertTo-GraphHtml.ps1:8` bundles vis-network | Second, independent graph renderer (vis-network) | duplicated |
| — | — | "Must never be able to write a claim" | **no evidence found** of enforcement. Neither renderer writes anything but HTML, but nothing prevents a portal from writing a claim |

---

## Phase 2b: existing repo → ideal repos touched

| existing repo | touches | count | flag |
|---|---|---|---|
| ClaudeGenesisTemp | Root (spec), Chain (legacy ledger + spec + audit inbox), Modules (Ledger, Genesis stub), Skills (six legacy SKILL.md) | 4 | **⚑ ≥3** |
| OntologyBuilder | Ontology (harvester), Portal (RenderGraph + vendored PSGraphRender), Modules (vendored module) | 3 | **⚑ ≥3** |
| dgp-ai-governance | Root, Chain | 2 | |
| Ansible | Substrate (image build), Modules (local feed + 2 modules) | 2 | |
| TerraformTools | Modules, Ontology (unwired duplicate) | 2 | |
| PSModuleDependencyGraph | Modules, Portal | 2 | |
| Claude.Skills | Skills (mechanism + design), Chain (trap ledger + checker) | 2 | |
| Claude.Inspector | Chain (checker), Modules | 2 | |
| Claude.Fuzzer | Chain (checker, frozen corpus), Modules | 2 | |
| Claude.Governor | Chain (pass sequencing, skeleton), Modules | 2 | |
| claude-code-cage | Substrate | 1 | |
| TerraformAST | Modules | 1 | |
| ClaudeChain | — | 0 | unmapped |

## Unmapped

- **ClaudeChain.** A TypeScript static code-analysis engine: "ingests a repository and turns it into typed, JSON-serializable objects: files, modules, symbols, imports, exports, call edges…" (`AGENTS.md:8-12`), and halts on its own source (`AGENTS.md:14-16`). It declines the ledger (`docs/GENESIS_AUDIT.md:105-107`), the Genesis root design (`:111`) and model calls (`AGENTS.md:313`). The nearest ideal repo is Ontology, but that means harvesting *type systems* into a *source registry*. ClaudeChain harvests code structure into an in-memory store and snapshots (`AGENTS.md:49`), so I haven't forced a fit.
- **Portions of mapped repos with no ideal home:** the Ansible controller/worker/Prometheus/Grafana stack (`Ansible/docker-compose.yml:2-93`; `src/controller/api/server.py:200` `POST /api/execute` runs commands). It is a remote-execution UI, not a graph portal and not an image build. Also the TerraformAST/TerraformTools HCL parser (`src/go/hcl_parser.go`, `Get-TerraformAST`), which parses *configurations*, not type systems. It is a capability (Modules), not Ontology.

---

## Phase 3: band 5 verdicts (`Claude.Skills/docs/framework/2026-09-30-altitude-map.html`, `id="repos"`, rows `:396-410`)

| current (row) | maps to | verdict | deciding citation |
|---|---|---|---|
| genesis-protocol (`:396`) | Root + Chain | **not verified** | Not under `_____AIFramework`; outside this pass's scope |
| ClaudeChain (`:397`) | Claude.Chain | **reject** | `ClaudeChain/AGENTS.md:8-12` (code analyzer); `docs/GENESIS_AUDIT.md:107` throws the receipt ledger away. The row's "signed successor claim" is false: `git log --format=%G? 9669374` → `N` (unsigned). Across HEAD's 13 commits: 12 `N`, 1 `E` (a signature is present but couldn't be checked locally) |
| ClaudeGenesisTemp (`:398`) | graveyard | **partial** | The successor claim covers only principles (`ClaudeChain/docs/GENESIS_AUDIT.md:87-101`). ClaudeGenesisTemp still holds the only PowerShell ledger implementation (`legacy/ledger/src/ledger/Ledger.psm1:298,954`), the only root+chain spec (`SPEC.md:7-209`) and the only skills on disk. ClaudeChain carried none of these forward (`GENESIS_AUDIT.md:105-111`) |
| claude.agent.* (`:399`) | Substrate | **not verified** | Not under the root |
| Ansible (`:400`) | Substrate? | **partial** | Builds an image (`.build.ps1:65-86`), but Ansible is *inside* it (`Dockerfile:18`) and there's no playbook. It also hosts the only local PS feed (`docker-compose.yml:94-107`), which is Modules. `.build.ps1` is truncated at line 97 |
| Claude.Skills (`:401`) | Claude.Skills | **partial** | Right name; no `SKILL.md`; versioned install covers tooling only (`modules.requires.psd1:2-5`). Its trap ledger is Chain-shaped (`.claude/hooks/log-attempt.ps1:4`). "4 unpushed commits" no longer holds: `status -sb` shows the branch in sync with `origin/feature/settings-trap` at `6c3ee3e` |
| PSModuleGraph_old · PSModuleDependencyGraph (`:402`) | Modules | **partial** | PSModuleDependencyGraph is a module (`.psd1:11`) but also a second renderer (`Save-PSModuleDependencyGraphHtml`) = Portal. PSModuleGraph_old is not under the root |
| PSGraphRender (`:403`) | Modules | **partial** | A module (`PSGraphRender.psd1:3`), vendored and imported by path (`OntologyBuilder/ontology.build.ps1:127`), which confirms the vendoring. Its responsibility is rendering = Portal |
| TerraformAST → TerraformTools (`:404`) | Modules | **confirm** (TerraformAST) / **partial** (TerraformTools) | Both are modules with the same GUID. TerraformTools also carries an unwired Ontology pipeline copy (`src/TerraformTools/private/Write-OntologyGraph.ps1`). The rename is now committed in TerraformAST (`0fcd0f5`), but `src/TerraformAST/TerraformAST.psd1` declares `RootModule = 'TerraformTools.psm1'` beside a file named `TerraformAST.psm1` |
| Claude.Fuzzer · Claude.Inspector (`:405`) | Modules or Chain | **partial → Chain as checkers** | The ledger imports both (`ClaudeGenesisTemp/legacy/ledger/src/ledger/Ledger.psm1:38-44`; `…/tests/sandbox/fuzzer_import.ps1:4`), and Governor places them as pass hops (`Claude.Governor.psm1:20-21`). They are packaged as modules. "9 behind their remotes" is stale: both show `## main...origin/main` after a 12:45 fast-forward |
| Claude.Governor (`:406`) | removed | **partial** | Removed from `AIFramework.code-workspace` (not among its 12 folders), but the directory is still on disk with 13 untracked files and an unborn `main`. It is the only place its pass design lives |
| OntologyBuilder (`:407`) | Claude.Ontology | **confirm** | `sources/terraform/terraform.schema.build.ps1:5`. Caveat: it also carries Portal (`ontology.build.ps1:123`), and it publishes no contract of its own |
| dgp-ai-governance (`:408`) | Portal? Chain? | **reject Portal; partial Chain; also Root** | No rendering code. Signed root: `charter/CHARTER.md:8`, `scripts/verify_charter.py:20-30`. Signed ledger: `scripts/ledger.py:81-113` |
| claude-code-cage (`:409`) | Substrate? | **confirm** | `Dockerfile:3-34` defines the agent image. Caveats: its build script doesn't exist, there's no registry, and there's no signature check despite `README.md:27` |
| (nothing) → Portal (`:410`) | Portal | **partial** | No Portal repo, but rendering already exists in PSGraphRender (vendored in OntologyBuilder) and PSModuleDependencyGraph. dgp-ai-governance is not it |

**The six open questions (`:416-421`):**

1. *Ansible: lost .git, or deliberately a snapshot?* **Not settled by this pass.** New evidence: `Ansible/.build.ps1` ends at line 97 inside `Invoke-Native`, with no closing brace and no tasks. That is consistent with an incomplete copy, but it doesn't decide the question.
2. *TerraformAST vs TerraformTools: which name survives?* **The name is settled; which repo is not.** Both trees now call the module TerraformTools (`TerraformAST/CLAUDE.md:1,21`, `TerraformTools/CLAUDE.md:23`) and share one GUID. Which repo survives is not settled by this pass.
3. *Fuzzer / Inspector: checkers or capabilities?* **Settled by evidence: checkers.** The ledger imports them (citations above). They are also packaged as modules, so they would ship as modules the Chain consumes.
4. *dgp-ai-governance: what is it?* **Settled.** It is a signed root (charter + ECDSA P-384 signature + key custody) and a signed, append-only SHA-384 ledger anchored to that root. It carries Root and Chain, not Portal.
5. *claude.agent.* ×4: one repo or four?* **Not settled by this pass** (not under the root).
6. *Ontology Builder's crossing as a seam object?* **Not settled by this pass.** Evidence: the only contract on either side is PSGraphRender's view model `1.1.0`, and the crossing today is an in-memory adapter (`ontology.build.ps1:131-150`), not a declared object.

---

## Where the prediction was wrong

- **Chain in ClaudeChain: wrong.** ClaudeChain is a code analyzer that rejects the ledger. The only *signed* chain is in dgp-ai-governance. Unsigned chains live in ClaudeGenesisTemp's legacy ledger and, not predicted at all, in Claude.Skills.
- **Root split three ways: wrong.** Governor carries no root. ClaudeChain holds no keys. Root is dgp-ai-governance (implemented) plus a ClaudeGenesisTemp spec (unimplemented).
- **"No local PSRepository feed": wrong.** Ansible defines one (BaGet, `AnsibleArtifacts`); nothing publishes to it.
- **TerraformAST/TerraformTools duplicating Ontology: half right.** TerraformAST doesn't. TerraformTools does, more than predicted (the whole pipeline), but it's unwired.
- **Fuzzer unmapped: wrong.** It is a Chain checker by the ledger's own imports. ClaudeChain is the unmapped repo.
- **Claude.Inspector as read-side viewer (Portal): wrong.** It reads settings, not the graph, and is a Chain checker.
- **Right:** Substrate has no registry. Skills has no runnable skills and no module imports by version. Ontology has no published contract. Portal is split OntologyBuilder/PSModuleDependencyGraph with no claim-write guard.

---

## Deviations

1. **Restart.** Phase 1 was run twice. The first read was interrupted, and files changed on disk between that read and the restart: a sync committed or pulled changes in seven repos (see "Tree this pass read"). Every citation here comes from the second read. Phase 0 was written before either read and is reproduced unchanged; a new prediction could not have been blind.
2. **OntologyBuilder's `CLAUDE.md` task list was not executed.** It directs the agent to delete stray root artifacts first. This pass is read-only and the brief takes priority, so that list was ignored. The conflict is noted, not resolved.
3. **Scope.** Only directories under `_____AIFramework` were read. Band-5 rows for genesis-protocol, claude.agent.* and PSModuleGraph_old are marked "not verified" rather than read from elsewhere on disk.
4. **Entry-point order.** The brief says to stop reading once a repo's purpose is clear. For the harvester, SPEC and GOD_PLAN I read past the first-referenced file into specific functions and sections, because a citation needed a line. Ansible has no playbook, so its compose file and `.build.ps1` stood in.
5. **Governor's untracked files were read.** They are the only evidence for its role; nothing was written.
6. **Not read:** `.keys/`, `ledger/chain.jsonl`, `.ledger/*.jsonl`, `attempts.jsonl` contents, `out/`, `.terraform/`, `.tools/`, `.cache/`, `node_modules/`.
7. **`AGENTS.md` / `README.md` claims** are cited as a repo's own description where they describe that repo. Where one repo describes another (cage → dgp, map → everything), it is labelled intent.
