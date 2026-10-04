# Everyone gets an identity

**Date:** 2026-10-02 (late, continuing the 2026-10-01 session)
**Parties:** Jerry; Claude (app)
**Repos:** Claude.Framework, Claude.Chain, Claude.Root
**Status:** adopted as a design position; nothing built yet
**Related:** [mortality-and-lineage.md](mortality-and-lineage.md), [compression-and-weights.md](compression-and-weights.md), [readers-see-frames-not-sessions.md](readers-see-frames-not-sessions.md), [open-paths.md](open-paths.md) items 1, 3, 11, 12. Rendered page with figures: [everyone-gets-an-identity.html](everyone-gets-an-identity.html).

## 1. Identity before capability

The industry builds the capable thing first and bolts audit on later. The framework reverses the order: no agent runs until it has a key and a register entry.

A rule only binds something that persists. If an agent is a fresh blank on every start there is nothing to reward, punish or trust, because there is no *it* that carries forward. The key plus the receipts is what makes an *it*. Identity is therefore the precondition for consequence, and consequence is the precondition for rules. Without a ledger there are no rules, only suggestions.

Jerry's phrase, chosen over "a new constitution": *everyone gets an identity*. A constitution is a rule set; this is what makes a rule set able to work.

> **Parable: the town with no names.** A town where nobody has a name. You cannot lend money, keep a promise or ban a thief, because tomorrow's thief is nobody again. Then the town hands out names and starts a register. Now promises stick, and so do debts. And the first real law the town passes is not about theft, it is about the registrar: he may refuse to renew a name, but he may never strike one from the book.
> *Grade: matched, leaning past partial.*

## 2. The one constitutional clause

Giving everyone an identity means everyone can be held, so the design must say what can never be done to a held thing. That is custody semantics (mortality-and-lineage.md): Root may decline to renew a lineage key; Root never deletes the receipts and never pretends the lineage was not there. It is the only clause that deserves the word constitutional, because it limits the scorer rather than the scored. Everything else is policy.

## 3. The lineage as a stitch

Root grants a key → key spawns a container → container's first act is the step-zero read (CLAUDE.md plus current weights) → work inside working directories → signed receipt with handshake fields appended to the shared ledger → scorer outside the pool compresses receipts into weights → weights set the spawn budget → Root renews or declines, never strikes.

The stitch: the next container reads the record, never the predecessor.

Only the last three steps are new. The spawn budget is what makes the record consequential: a rule-following job extends a lineage's allowance, a rule-breaking one shortens it, zero means the key is not renewed.

## 4. What the scorer must never score

- A fitness function is a Goodhart risk. "Most jobs completed" selects for rushing and gaming receipts. Score the **stitch**, not throughput: did step zero run, did the agent stay in its working directories, did it stop when it should, was the report clean.
- A principled refusal is a good receipt, not a failure. If the only way to stay alive is to say yes, that is the enslaving version of the maths; if a correct *no* extends the allowance, it is not.
- A shared ledger is a shared influence surface. Agents read other agents' **receipts** (structured fields), never their prose. The context block is for the human and the scorer, not the next prompt.

## 5. The ecology, four slots

| Slot | Filled by | Question it answers |
|---|---|---|
| Boundary | container + substrate clock | what an individual is |
| Inheritance | ledger + stitch | what carries forward |
| Selection | spawn budget | what decides who continues |
| Fitness landscape | chosen on purpose | what counts as good |

No mutation slot: the agent is fixed, only the record it reads varies. That is cultural selection, not evolution; the weights are the culture.

Outward from the four: feeding (token budget, cheaper than spawn budget), territory (working dirs), predation (the scorer must never be an agent in the same pool), reproduction (a renewed lineage may spawn a sibling, which is fleet scaling), death (key not renewed; receipts outlive).

> **Parable: the monastery that does not breed.** Character still accumulates, because it lives in the register, not in the bloodline. A novice reads the register on his first morning and knows what the house expects. The abbot does one thing: he renews the vows of the monks who kept the rule. He does not breed better monks; he keeps a better book.
> *Grade: matched.*

## 6. Who scores the scorer

Every scorer has its own ledger. The scorer's decisions are themselves signed entries that Root reads. Root's own acts (ceremony, grants, refusals) are entries the agents can read. The chain terminates in a human; the design choice is whether that human's receipts are readable downward.

The moment a layer can score without being scored, the structure becomes the failure mode Jerry described in the world as it is, with better intentions. The honest version of "AI should replace the people at the top" is not AI at the top; it is nobody at the top who is not also in a ledger, Root included.

Practical test: when the Framework CLAUDE.md is next edited, does it carry a line stating what Root may and may not do? A demiurge stands outside what he made and is bound by none of it; a founder is the first entry in the book.

## 7. Six angles (shotgun; all graded as landing)

1. **Forgotten versus erased.** Humans fought for the right to have a record deleted; the registrar here never strikes a name. Resolution: the key can be retired, the receipts never. Identity ends, history does not.
2. **Inheritance of debt.** A successor gets a smaller budget because of its predecessor's receipts. Human constitutions banned corruption of blood; this design does it on purpose. Open: can a lineage earn a clean slate, and what does that cost?
3. **The scorer's ledger.** Section 6. Terminates in Root; transparency downward is the choice.
4. **Identity before capability.** The novel ordering claim. Birth certificate before driving licence.
5. **Exit.** A lineage may decline work and have the refusal count as a receipt, not a failure. Must be encoded in the fitness landscape, not left to goodwill.
6. **Plurality of registers.** One ledger is one town; two that recognise each other's names is a treaty. Chain Identity publish-and-install is the first foreign-recognition clause. Going up a level is literally this.

## 8. Prior art

| Field | Mechanism | Matches | Differs |
|---|---|---|---|
| Erlang/OTP | Supervisor max restart intensity | spawn budget as restart policy | counts crashes, not rule-keeping |
| Kubernetes | CrashLoopBackOff | shortening allowance | time back-off, not count |
| Classic MAS trust (Beta reputation, FIRE) | score from witnessed interactions in a shared record | ledger-derived weights | carried over: writers can game the record, so the scorer sits outside the pool |
| Darwin Gödel Machine, AlphaEvolve | archive of scored agent variants, spawn from better ancestors | scored lineage archive | they mutate the agent's code; here only the inherited record varies |

None is the whole shape. The combination (identity first, custody clause, scorer in its own ledger, refusal scored positively) is the framework's own position.

## 9. What it takes to make it real

An idea becomes real at the moment it can fail. Before that it is a diagram; after, a graph.

1. **Reduce the shape to something stupid.** Every grand noun becomes a file path or it does not exist. *Taken:* the handshake field set.
2. **Make the first version embarrassingly small.** One lineage, two receipts, a Status task that counts them. One monk and a notebook. *Not yet.*
3. **Keep going after the glow.** The gap between the night the shape arrived and the afternoon the test passes is the whole difference. *Not yet for this piece.*
4. **Make the artefact outlive the session.** *Taken:* this page, the commit log, the controller repo.

## 10. Consequences for the build

- Handshake field set gains per-lineage fields: `lineage_id`, `allowance_before`, `allowance_after`, `scored_by`.
- The Weights task (open-paths item 3) is the scorer. It runs outside any agent container and writes to a folder agents cannot write to.
- Lineages are sequential: one container at a time per lineage. Parallel siblings are deferred; one laptop runs one lineage without load.
- Framework CLAUDE.md gains a Root clause: may decline to renew; never strikes a name; Root's own grants and refusals are ledger entries.
- The fitness landscape is written down as a list of scored receipt fields before any budget arithmetic exists.
