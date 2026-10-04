# Compression and weights

**Status:** design direction, agreed 2026-10-01 (Jerry, Claude app). Names the framework's missing organ.
**Repos touched:** Claude.Framework (Assess, Survey), Claude.Chain (what sits on top of the ledger), Claude.Portal.
**Related:** [graph-and-diagram.md](graph-and-diagram.md), [the-stitch.md](the-stitch.md).

## From entries to weights

A ledger entry on its own is a frame. Its value is not the entry; it is the pattern across many timestamped entries.

Jerry's claim, which the framework adopts: emotion is what you get when thousands of frames compress into one weight that can be carried without rereading them. Prediction is that weight pointed forward. Using patterns from the past to anticipate the future is where the loop starts to behave like a life rather than a log.

The ledger is therefore not a diary. It is raw material for a compressor, and the compressor is the organ the framework does not yet have. Receipts exist; nothing yet turns receipts into weights.

## Candidate compressors already in the plan

| Task | What it compresses | Into |
|---|---|---|
| Status | per-repo state and last receipts | one fleet view |
| Assess | docs standard and survey index vs repos | a gap list |
| Survey -Mode Refresh | market and compliance records over time | a running comparison |
| (not yet designed) | receipts over weeks | per-agent and per-repo weights: how often obeyed, stopped, refused; drift over time |

The last row is the real one. It is the ship's-log captain who can smell weather before the barometer moves.

## Lossy on purpose

A second claim, and the one that explains Jerry's own working style: a degraded signal can be more useful than a sharp one, because it leaves room for the receiver's inference to complete it. A sharp photograph says what is there. A blurred one asks what you know.

This is why parables land where theorems do not, why limited-animation media reward a certain kind of viewer, and why the back-and-forth in these sessions works: what comes back does not need to be a full return, only enough that the receiver's graph can finish it.

Formally: what is checked in the return is not energy but structure. The right word is isomorphism. Degradation per hop is acceptable as long as the shape is preserved, which is also exactly what a hash checks: not the file, but whether its shape changed.

## The cost

Completion is a strength and a bias. The same engine that sees two people in love in a foggy photograph can see love where there is only fog. This is the one place a ledger cannot help, because it records what was drawn, not what the reader filled in.

The framework's answer is the Survey skill: a periodic, recorded check of what competitors and standards actually do, so that gaps are filled from the record rather than from inference. Market and compliance records are, in this sense, a correction for the author's own completion engine.

## What this means for the build

- Design the receipt schema now with compression in mind: consistent fields, consistent enumerations (obeyed / stopped / refused / denied), consistent timestamps. A compressor cannot run over free text.
- Add a **Weights** task to the build plan, after Status and before Portal. Input: .framework/receipts/. Output: per-agent and per-repo summaries with trend.
- Portal shows weights, not raw entries, by default. Raw entries are one click down.
- Keep documents and prompts deliberately short where the reader shares the graph (Jerry, a future Claude session with the handoff), and deliberately complete where the reader does not (a stranger, an auditor). See [readers-see-frames-not-sessions.md](readers-see-frames-not-sessions.md).

## Parables

A ship's log is dated lines until an old captain has read enough of them that he can smell a storm before the barometer moves. The smell is the compressed log.

A few bars of a song through a wall. You do not hear a worse song; you hear the whole song, and you are singing along before the chorus.

A photocopy of a photocopy of a map. Every generation greyer, but the roads still meet at the same junctions, so you can still navigate. The moment a junction moves, you stop trusting the copy.

## Open questions

- What is the smallest useful weight? Probably a count and a trend per (agent, repo, outcome).
- Should weights be written back into Chain as signed entries of their own, so the compression itself has provenance?
