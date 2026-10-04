# Claude.Framework

Claude.Framework controls the Claude framework and is the home of its docs. It holds the documentation, the tests that run across the whole fleet, and the survey records. It contains no code from the seven child repos. The Sync task clones each child into `repos/`, which git ignores.

## Child repos

The roles below come from a proposal: [docs/roles/2026-09-30-container-declarations.PROPOSAL.md](docs/roles/2026-09-30-container-declarations.PROPOSAL.md). They have not been confirmed.

| Repo | Role (from the proposal) |
|---|---|
| [Claude.Root](https://github.com/JerryBalmer1/Claude.Root) | The authority root: law tags, signing keys, and the declaration other repos read to learn what is authoritative |
| [Claude.Chain](https://github.com/JerryBalmer1/Claude.Chain) | The ledger: signed, append-only, hash-chained claims, the survives-N growth loop, and checkers |
| [Claude.Substrate](https://github.com/JerryBalmer1/Claude.Substrate) | Builds immutable agent images with the writing path baked in, plus a registry; Ansible builds the images and is not part of them |
| [Claude.Modules](https://github.com/JerryBalmer1/Claude.Modules) | PowerShell monorepo of capabilities, published to a local PSRepository feed |
| [Claude.Skills](https://github.com/JerryBalmer1/Claude.Skills) | Skills that import modules by version and write seam objects |
| [Claude.Ontology](https://github.com/JerryBalmer1/Claude.Ontology) | Harvests type systems into a source registry; a dependent service with a published contract |
| [Claude.Portal](https://github.com/JerryBalmer1/Claude.Portal) | Reads the graph and renders it; must never be able to write a claim |

## Docs

See [docs/](docs/), which contains `assessments/`, `prompts/`, `roles/`, `sessions/` and `theory/`.

The docs index is [docs/README.md](docs/README.md).
