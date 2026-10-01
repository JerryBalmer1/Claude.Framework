**This is a proposal, not a finding.** It is an attested claim by Claude (Opus 5.5), written 20260930T195146Z for a human to read and rewrite. Nothing here was checked against anything, and nothing here is evidence for the responsibility map.

# Container declarations: proposal

Paths are relative to `C:\__Code\_____AIFramework`. "Move" means a human moves it later; nothing has moved.

```
container: Claude.Root
responsibility: authority root — the thing every identity derives from; law tags; signing keys; the declaration other repos read to learn what is authoritative
declared members:
  - dgp-ai-governance/charter/            (CHARTER.md, .sig.json, public key)
  - dgp-ai-governance/custody/KEY_CUSTODY.md
  - dgp-ai-governance/scripts/verify_charter.py
  - ClaudeGenesisTemp/SPEC.md §S1.2, §S4, §S8   (root/successor/revocation design, as a spec input, not code)
excluded:
  - dgp-ai-governance/.keys/               private key; never in any repo, root or otherwise
  - dgp-ai-governance/scripts/ledger.py    appends and signs claims; that is Chain using Root's key, not Root
  - Claude.Governor AGENTS.md "Laws"       agent working rules for one repo, not authority other repos derive from
  - ClaudeGenesisTemp/GOD_PLAN.md          playground procedure, not a declaration
sourced from: dgp-ai-governance (implementation), ClaudeGenesisTemp (design)
```

```
container: Claude.Chain
responsibility: the ledger — signed, append-only, hash-chained claims; the survives-N-cases growth loop; checkers
declared members:
  - dgp-ai-governance/scripts/ledger.py, witness.py, Append-Ledger.ps1, build.ps1   (the only signed chain)
  - ClaudeGenesisTemp/legacy/ledger/src/ledger/  (PowerShell receipt chain + verifier; reference for a PowerShell writer)
  - ClaudeGenesisTemp/SPEC.md §S3, §S5–S7, §S9–S13  (receipt schema, canonicalization, verify, mutants)
  - ClaudeGenesisTemp/audit/               (hash-named pre-chain records; keep, do not re-home without its B10 rules)
  - Claude.Inspector                       (checker, consumed as a module)
  - Claude.Fuzzer                          (checker + frozen regression corpus, consumed as a module)
  - Claude.Governor                        (pass sequencing; skeleton)
  - Claude.Skills/tests/ledger/Test-TrapLedger.ps1 + .claude/hooks/log-attempt.ps1   (the chain's hook-side writer and checker)
  - growth loop (survives-N): none — would be created
excluded:
  - ClaudeChain                            code analyzer; explicitly rejects the ledger (docs/GENESIS_AUDIT.md §7)
  - ClaudeGenesisTemp/legacy/ledger python snake   validate-retry loop around model calls; a capability, not the ledger
  - Claude.Skills/tests/ledger/attempts.jsonl      data, not code; stays where it was written
sourced from: dgp-ai-governance, ClaudeGenesisTemp, Claude.Inspector, Claude.Fuzzer, Claude.Governor, Claude.Skills
```

Open inside this container: three chain formats exist (SHA-384 + ECDSA; SHA-256 unsigned v1; SHA-256 unsigned v1→v2) and a fourth is specified (gpg + JCS). Picking one is a human decision.

```
container: Claude.Substrate
responsibility: builds immutable agent images; registry; the writing path baked into the image; Ansible builds it and is not in it
declared members:
  - claude-code-cage/                      (image definition, baked hooks, entrypoint, fail-first tests)
  - Ansible/.build.ps1, Ansible/Dockerfile  (image-build tooling, once repaired; the file is truncated)
  - registry: none — would be created
  - Build-Cage script: none — would be created (cited in cage README, exists nowhere)
excluded:
  - Ansible/src/artifacts/                 PS module feed; belongs to Modules
  - Ansible/src/controller, worker, monitor   remote-execution stack; see "does not fit"
  - TerraformAST/TerraformTools Dockerfile  builds a parser DLL, not an agent image
  - dgp-ai-governance                      the cage README says dgp builds the cage; this proposal disagrees — the builder is not the root
sourced from: claude-code-cage, Ansible
```

Tension to resolve: the cage's README keeps the ledger out of the image on purpose, while the ideal says the writing path is baked in. One of them changes.

```
container: Claude.Modules
responsibility: PowerShell monorepo publishing to a local PSRepository feed; capabilities
declared members:
  - TerraformTools/src/TerraformTools/     (surviving Terraform module; public functions only)
  - TerraformAST                           (history merges into TerraformTools; not a second module)
  - PSModuleDependencyGraph/src/           (analysis half)
  - OntologyBuilder/src/modules/PSGraphRender  (as a package only; consumed from the feed, not vendored)
  - Claude.Inspector/src, Claude.Fuzzer/src, Claude.Governor/src   (packaged here; Chain consumes them)
  - ClaudeGenesisTemp/legacy/ledger/src/ledger/python snake   (validate-retry capability, if kept at all)
  - Ansible/PSModules/PSAnsible, PSModuleToSwaggerJson
  - Ansible/src/artifacts/                 (the local feed definition, BaGet)
  - monorepo layout and publish-to-local-feed build: none — would be created
excluded:
  - TerraformTools/src/TerraformTools/private/{Write-Ontology*,Write-Provider*,Get-InferredEdge,Get-CategoryRuleSet,…}   an unwired copy of Ontology's pipeline; one copy should exist, in Ontology
  - TerraformAST/.kilo/worktrees/          editor worktree, not source
  - ClaudeGenesisTemp/src/Genesis          empty stub; its spec belongs to Root/Chain
sourced from: TerraformTools, TerraformAST, PSModuleDependencyGraph, OntologyBuilder, Claude.Inspector, Claude.Fuzzer, Claude.Governor, ClaudeGenesisTemp, Ansible
```

```
container: Claude.Skills
responsibility: skills that import modules by version and write seam objects
declared members:
  - Claude.Skills/module.build.ps1, modules.requires.psd1   (version-pinned install mechanism)
  - Claude.Skills/docs/framework/          (seam-object and framework design)
  - ClaudeGenesisTemp/legacy/ledger/.claude/skills/*   (six existing skills, as candidates to rewrite against versioned modules)
  - skills that import capability modules by version: none — would be created
  - seam-object writer: none — would be created
excluded:
  - Claude.Skills/.claude/hooks/log-attempt.ps1, tests/ledger/   chain writer and checker; Chain
  - Claude.Skills/docs/html/               essays (grimes, the-four); not skills or schema
sourced from: Claude.Skills, ClaudeGenesisTemp
```

```
container: Claude.Ontology
responsibility: harvests type systems into a source registry; a dependent service with a published contract
declared members:
  - OntologyBuilder/sources/terraform/     (harvester, main.tf, lock file)
  - OntologyBuilder/ontology.build.ps1     (TerraformScript task)
  - OntologyBuilder/ontology-*.html        (design docs)
  - published registry contract (schema for index.json / types.json / links.json / graph.json): none — would be created
excluded:
  - OntologyBuilder/src/modules/PSGraphRender and the RenderGraph task   rendering; Portal
  - TerraformTools private harvest copy    duplicate; if the harvester is later split into functions, it is split here, not in a module
  - ClaudeChain, PSModuleDependencyGraph graph builder   code-structure analysis, not type-system harvest
  - OntologyBuilder/_scratch/              Jerry's sandbox
sourced from: OntologyBuilder
```

```
container: Claude.Portal
responsibility: reads the graph and renders it; must never be able to write a claim
declared members:
  - OntologyBuilder/ontology.build.ps1 RenderGraph task + the in-memory adapter
  - PSGraphRender, consumed from the Modules feed by version
  - PSModuleDependencyGraph Save-PSModuleDependencyGraphHtml (renderer half; or retire in favour of PSGraphRender)
  - claim-write guard (a portal that holds no key and no Chain writer): none — would be created
excluded:
  - Ansible/src/controller/ui              executes commands via POST /api/execute; a portal must not
  - dgp-ai-governance                      no rendering; Root/Chain
sourced from: OntologyBuilder, PSModuleDependencyGraph
```

## Does not fit the seven

- **ClaudeChain.** A TypeScript code-analysis engine that halts on itself. It isn't a ledger, an ontology registry or a module in the PowerShell feed. It might become a Skill's capability ("query a codebase like a database"), but it is TypeScript and versions through pnpm, so it doesn't fit Modules as defined. Keep it as its own thing until someone decides whether the framework needs a code analyzer at all.
- **The Ansible controller / worker / Prometheus / Grafana stack.** A remote-execution service with a UI. Of the seven, it would nearest belong to Substrate, but it doesn't build images: it runs things. Its role in this framework is unstated.
- **ClaudeGenesisTemp as a repo.** Every part of it is claimed above by Root, Chain, Modules or Skills. What doesn't fit is the playground itself (GOD_PLAN, payload/Receive, `grade.ps1`, CI). That is a build process for a product that was never built.
