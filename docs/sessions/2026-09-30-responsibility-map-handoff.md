# Handoff: responsibility map, 20260930T195146Z

**What this is.** `C:\__Code\_____AIFramework` is Jerry's workspace for an accountability framework for AI agents doing infrastructure work: signed claims, checkers, agent images, PowerShell capabilities, skills and a type-system ontology. It holds 12 git repos plus `Ansible` (no `.git`), listed in `AIFramework.code-workspace`, with `Claude.Governor` on disk but removed from that file.

**The seven ideal repos (fixed reference; do not add or rename):**
- Claude.Root: authority root; law tags; signing keys; the declaration others read to learn what is authoritative
- Claude.Chain: signed, append-only, hash-chained claims; the survives-N growth loop; checkers
- Claude.Substrate: immutable agent images; registry; writing path baked in; Ansible builds it and is not in it
- Claude.Modules: PowerShell monorepo publishing to a local PSRepository feed; capabilities
- Claude.Skills: skills that import modules by version and write seam objects
- Claude.Ontology: harvests type systems into a source registry; dependent service with a published contract
- Claude.Portal: reads the graph and renders it; must never be able to write a claim

**What this pass found:**
- ClaudeChain is not the Chain. It is a TypeScript code analyzer that explicitly throws the ledger away, and it fits none of the seven.
- dgp-ai-governance is Root + Chain: the only signed root (ECDSA P-384 charter) and the only signed ledger. Two more unsigned hash chains exist (ClaudeGenesisTemp legacy ledger, Claude.Skills trap ledger), and a fourth is spec-only (Genesis).
- ClaudeGenesisTemp (4 responsibilities) and OntologyBuilder (3) are the flagged multi-role repos.
- Nothing implements the growth loop, a container registry, a published ontology contract, a seam-object writer, or a portal claim-write guard. A local PS feed is defined (Ansible BaGet), but nothing publishes to it.
- TerraformTools holds an unwired copy of OntologyBuilder's whole harvest pipeline. `Ansible/.build.ps1` is truncated at line 97.

**Undecided (each for a human to answer):**
- Which ledger format is the Chain: dgp's SHA-384 + ECDSA, the legacy SHA-256, the Skills v2, or Genesis's gpg + JCS spec?
- Should the ledger writing path be baked into the agent image, as the ideal says, or kept out, as claude-code-cage's README says?
- Is `Ansible` a deliberate snapshot or a copy that lost `.git`, given its truncated `.build.ps1`?
- Which repo keeps the name TerraformTools, and does the private harvest copy in TerraformTools get deleted or become the Ontology's implementation?
- Does ClaudeChain belong in this framework at all, and if so, where?
- Is ClaudeGenesisTemp graveyarded when its ledger, Root/Chain spec and skills have no other home yet?
- Does Claude.Governor get committed somewhere? It has no commits and no remote.
- What does the Ontology's published contract (the registry as a seam object) look like?
- Where does the Ansible controller/worker stack belong?
- One repo or four for claude.agent.*? (Not under this root; not read.)

**Do not do without asking Jerry:** delete, move, rename, push, tag, commit, merge, fetch, or `git init` anything, in any repo or in `Ansible`. Don't graveyard ClaudeGenesisTemp or Claude.Governor. Don't touch `dgp-ai-governance/.keys/` or any `*.jsonl` chain file. Don't run `terraform init` or read `OntologyBuilder/.../out/`. OntologyBuilder's `CLAUDE.md` has its own task list, which includes deletions; this pass did not execute it.

**Pointers:**
- `docs/assessments/2026-09-30T195146Z-responsibility-map.md`: evidence, both-direction tables, band-5 verdicts, deviations
- `docs/roles/2026-09-30-container-declarations.PROPOSAL.md`: proposed containers (a proposal, not evidence)
- `docs/assessments/2026-09-30T184806Z-workspace-inventory.md`: prior health inventory (a few statements are now stale; see the map's band-5 notes)
- Altitude map: `Claude.Skills\docs\framework\2026-09-30-altitude-map.html`, band 5 = `id="repos"`
