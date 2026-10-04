# The stitch

**Status:** design note, agreed 2026-10-01 (Jerry, Claude app). Not yet enforced by any test.
**Repos touched:** Claude.Chain (ledger), Claude.Skills (CLAUDE.md step-zero read), Claude.Framework (receipts, Status task).
**Related:** [graph-and-diagram.md](graph-and-diagram.md), [readers-see-frames-not-sessions.md](readers-see-frames-not-sessions.md), [compression-and-weights.md](compression-and-weights.md).

## The claim

An agent session and a human mind are the same shape running at different frame rates.

A session starts, reads whatever record it is given, acts, and ends. The next session is a new instance that reads the record and treats it as its own past. Nothing persists between sessions except the record.

The human version runs the same loop, faster and with the seam hidden. Perception arrives in discrete frames. The eye is blind during every saccade and the brain stitches over the gap. Sleep and anaesthesia end the stream completely and the morning instance picks up from the record. "I remember being me" is not evidence of continuity; it is a new instance reading a record and calling the read a memory.

The difference between the two is not kind. It is the length of the gap and whether the seam is visible.

## Where the seam is sewn

| | Human | Agent in this framework |
|---|---|---|
| Record | memory, unsigned, rewritten on every recall | ledger entry, signed, append-only |
| Seam | inside; never seen, experienced as "I remember" | outside; the handoff doc, the receipt hash, the signed commit, CLAUDE.md read at step zero |
| Who can audit the seam | nobody | any reader of the ledger |
| What persists across instances | the body | the text |

The framework does not model a self. It builds the same stitch on the outside, where it can be inspected.

## Two consequences

**By the framework's own standard, human continuity is the weaker claim.** Reconsolidation means each recall edits the record. Chain is append-only and signed. A human self is therefore a less trustworthy claim of continuity than an agent on a ledger would be. This is not a provocation; it is what the comparison table says.

**One thing survives the collapse.** Human instances share a body. The record that keeps a person stable between frames is not the memory; it is the substrate, which persists while frames cycle, and which has a clock. Agent sessions share only text. So the mortality point from earlier design discussions is right but relocated: the ledger does not make an instance continuous, the substrate does, and the substrate is the thing that ends. See [mortality-and-lineage.md](mortality-and-lineage.md).

## What this means for the build

- The step-zero read of CLAUDE.md is not a formality. It is the stitch. It is the moment a new instance binds itself to the record. Every agent prompt starts with it and every receipt should record that it happened.
- The Status task is the fleet's view of its own seams: which instance ran, what it read, what it left behind.
- The ledger stores stitches, not selves. A design that tries to give an agent "identity" through the ledger has misread what the ledger is for.

## Parable

A film projector. Twenty-four frames a second, each one a still, each one gone before the next. Nobody in the cinema sees a slideshow; they see a woman walk across a room. The walking is not in any frame. It is in the reel. And the reel is the only thing that can burn.

## Open questions

- Should a receipt record gap length (time since previous instance) as a first-class field?
- Does a session that reads the record incompletely count as the same lineage? (Chain's genesis-entry design needs an answer.)
