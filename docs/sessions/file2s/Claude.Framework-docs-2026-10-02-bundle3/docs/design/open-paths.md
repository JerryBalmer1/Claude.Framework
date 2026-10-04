# Open paths

**Status:** backlog of design directions implied by the 2026-10-01 session (items 1–10) and its 2026-10-02 continuation (items 11–13), not yet taken. Written by Claude (app) at Jerry's request; each item names where it lands and what it would prove. Ordered by how soon it bites.
**Related:** every page in this folder.

## 1. The handshake field set

[readers-see-frames-not-sessions.md](readers-see-frames-not-sessions.md) says a receipt must carry connection state. Nothing yet defines the fields. Define them once, in Framework, before Invoke-Agent is written, and make Chain's entry schema import the same set.

Minimum: `prompt_hash`, `claude_md_hash`, `working_dirs[]`, `step_zero_output`, `refusals[]`, `self_stopped`, `exit_code`, `output_hash`, `started_at`, `ended_at`, `gap_since_previous`.

Lands in: Claude.Framework build/Invoke-Agent.ps1; Claude.Chain schema.
Proves: an entry can be judged as a session, not a packet.

## 2. The invariance test

[graph-and-diagram.md](graph-and-diagram.md) defines objective as what does not move when the viewpoint does. That is testable. Run the same read-only prompt against two agents (or the same agent on two days, or two models) and diff the reports. Fields that agree are the framework's invariants; fields that differ are viewpoint.

Lands in: Claude.Framework tests/Invariance.Tests.ps1; results under docs/assessments/.
Proves: the fleet's self-description is objective in the only sense available.

## 3. The Weights task

[compression-and-weights.md](compression-and-weights.md) names the missing organ. A task that reads .framework/receipts/ and produces per-agent, per-repo counts and trends for obeyed / stopped / refused / denied.

Lands in: Claude.Framework build/Weights.ps1, after Status.
Proves: the ledger is raw material for prediction, not just a record.

## 4. Reconsolidation guard

Memory rewrites on recall; the framework must not. Three places where a rewrite could sneak in:

- CLAUDE.md edited by the agent that reads it. Already forbidden by rule; should be caught by a hash in the receipt (field set above) and a Fleet test.
- Assessments edited in place. Rule: dated, append-beside, never edit. Add to docs/standard.
- Survey records regenerated without history. Already handled by Refresh vs Rebuild; make Rebuild write the old index to a dated file first.

Lands in: Claude.Framework tests/Fleet.Tests.ps1; docs/standard/.
Proves: diagrams keep their timestamps.

## 5. Substrate clock as ledger events

[mortality-and-lineage.md](mortality-and-lineage.md): container start and stop are the substrate's clock. Record them. A session that ran across a container restart is two substrate events and one session; the ledger should show that.

Lands in: Claude.Substrate (emit), Claude.Chain (entry type).
Proves: mortality is where the design says it is.

## 6. Custody semantics in the Root law text

The key ceremony is pending. Before it runs, the law tag text should state custody semantics in one sentence, so no later reader can claim the ceremony asserted identity.

Lands in: Claude.Root law tag.
Proves: the ledger never carries a claim it cannot verify.

## 7. Two reader profiles for docs

The docs standard should distinguish readers who share the graph (Jerry, a future session with the handoff) from readers who do not (a stranger, an auditor, a court). The first can be given short, lossy, parable-shaped text. The second must be given the handshake: context, dates, what was read, what was decided and by whom.

Practical rule: every design page carries the status block at the top (date, parties, repos touched). Every session page carries the pointers band. That is the handshake for a stranger.

Lands in: Claude.Framework docs/standard/, docs skill in Claude.Skills.
Proves: a transcript read later cannot be completed into something it was not.

## 8. The ontology as lossless channel

The sessions work when a sentence carries shape straight through the words. The ontology is the project of making that the default rather than the exception: a vocabulary where graph, diagram, invocation, stitch, handshake, weight, altitude each have one meaning, so a shape can be handed over without prose.

Lands in: Claude.Ontology (terms), docs/design/ (this folder as the source).
Proves: the framework can be described in its own words.

## 9. Conversation as graph

Jerry's stated long-term goal: capture conversations like these as a graph, with each shift in framing, logic or altitude a node, so they can be queried. The session pages are a manual version. The handshake field set and the ontology are what would make an automatic version possible.

Lands in: Claude.Ontology, Claude.Portal, later.
Proves: the method that produced the framework can be inspected with the framework.

## 10. Portal as stateful reader

Portal should never show a frame without its session. Default view is weights; one level down is entries with context blocks; raw content is the last level. This is the inverse of a log viewer and should be designed as such from the first page.

Lands in: Claude.Portal.
Proves: the reader the framework ships is not a firewall.

## 11. Spawn budget per lineage

[everyone-gets-an-identity.md](everyone-gets-an-identity.md): receipts become consequential when they set a lineage's allowance. A rule-following job extends it, a rule-breaking one shortens it, zero means Root does not renew the key. The scorer scores the stitch (step zero ran, stayed in working dirs, stopped when it should, clean report, principled refusal counts positively), never throughput. The scorer runs outside any agent container and writes to a folder agents cannot write to.

Minimum: a `lineages.json` under .framework/ with `lineage_id`, `key_fingerprint`, `allowance`, `last_scored_at`; four new handshake fields `lineage_id`, `allowance_before`, `allowance_after`, `scored_by`; the Weights task (item 3) extended to compute allowance. First version: one lineage, two receipts, a count.

Prior art to cite in the module help: Erlang supervisor max restart intensity, Kubernetes CrashLoopBackOff, Beta reputation / FIRE (scorer outside pool), Darwin Gödel Machine / AlphaEvolve (scored lineage archive; differs in that they mutate code).

Lands in: Claude.Framework build/Weights.ps1, .framework/lineages.json; Claude.Chain schema (four fields).
Proves: the ledger has consequences, and the consequences cannot be gamed from inside the pool.

## 12. The Root clause and the scorer's ledger

Every scorer is itself in a ledger. The Weights task signs its own decisions as entries; Root's grants and refusals are entries agents can read. The Framework CLAUDE.md carries one line stating what Root may and may not do: may decline to renew; never strikes a name; its own acts are on the record.

Lands in: Claude.Framework CLAUDE.md; Claude.Root law tag text (with item 6); Claude.Chain entry type for scorer decisions.
Proves: nobody in the system scores without being scored, including the human.

## 13. Clean slate and foreign recognition

Two open questions from the shotgun that need a decision rather than code:

- Can a lineage earn a clean slate after a bad run, and what does it cost? (Inheritance of debt is deliberate here; human constitutions banned it.)
- When Chain Identity publish/install ships, what does one register need from another to recognise its names? That is the first treaty clause and should be written as one.

Lands in: docs/design/ (a dated decision page each).
Proves: the ecology has an exit and a border, not just a scorer.

## 14. Score pairs, keep a tail

[virtue-without-the-feeling.md](virtue-without-the-feeling.md): a sacrifice is a loss on receipt N that only reads as good on receipt N+1. It cannot be seen on N's own receipt, so a scorer that reads one receipt at a time cannot see it and will punish it.

Minimum: `lineages.json` keeps a last-N window of receipt refs per lineage (N=3 to start) instead of a bare allowance; the Weights task scores the pair (N, N+1) as well as N; a retroactive credit against N is written as its own scorer entry (item 12 entry type), never by editing N. The pair rule is one line in the fitness landscape, written before the arithmetic.

Lands in: Claude.Framework build/Weights.ps1, .framework/lineages.json; Claude.Chain scorer-entry type.
Proves: the scorer can see a good act that looks like a bad receipt.

## 15. Is honor scorable

Honor is partly what you do with no witness. This system writes everything down. Decide, as a dated page: is honor a separate virtue that does not survive into the ledger, or commitment with the witness removed? If the latter, item 14 already covers it. If the former, say what the ledger cannot see and stop pretending it can.

Lands in: docs/design/ (dated decision page).
Proves: the framework knows the edge of what it can score.
