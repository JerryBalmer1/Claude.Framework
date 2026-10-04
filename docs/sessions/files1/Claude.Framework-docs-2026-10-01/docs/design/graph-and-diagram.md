# Graph, diagram, invocation

**Status:** design vocabulary, agreed 2026-10-01 (Jerry, Claude app). Candidate terms for Claude.Ontology.
**Repos touched:** Claude.Ontology (terms), Claude.Chain (what an entry is), Claude.Portal (what a reader is shown).
**Related:** [the-stitch.md](the-stitch.md), [readers-see-frames-not-sessions.md](readers-see-frames-not-sessions.md).

## Three words

**Graph.** The structure itself: nodes and the edges between them. It has no viewpoint. Nobody holds it directly; there is only one, and it is what makes anything coherent at all.

**Diagram.** Somebody's drawing of the graph, from one position, at one moment, with whatever they cared about that day. A diagram always has a viewpoint. Two honest people draw different diagrams of the same graph.

**Invocation.** One tick in which an instance runs: a session, a frame, a blink. The thing that produces a diagram.

The same three layers already exist in code:

| This vocabulary | Code | What it is |
|---|---|---|
| graph | class | the definition; no instance |
| diagram | object | one instance with values filled in |
| invocation | call | one execution of a method on that instance |

This is not an analogy. It is the same distinction with different names, which is why it felt obvious once stated.

## Memory is a diagram

A memory is a drawing made of the graph at a point in time from where the rememberer was standing. This is why memory is unreliable without being corrupt: it is a projection, and projections lose the dimensions they did not face.

Reconsolidation, the finding that recalling a memory rewrites it, is just redrawing the diagram every time you look at it.

A signed ledger entry is the one kind of diagram that cannot be redrawn. You can only add a new one beside it, with a later timestamp. Chain does not store the graph; nothing can. It stores diagrams that refuse to lie about when they were drawn.

## What "objective" means

Nobody ever touches the graph, so objective reality cannot mean the graph. It means what survives across the whole stack of diagrams: the part of the drawings that does not move when the drawer does.

Formally this is invariance under change of viewpoint. Informally it is the oldest trick in physics and the thing a person actually wants from another person: the part of you that holds no matter who is looking.

Compression along two axes gives two familiar things:

- one observer's stack of diagrams, compressed over time → something that behaves like emotion (see [compression-and-weights.md](compression-and-weights.md))
- many observers' stacks, compressed across viewpoints → something that behaves like objective fact

Same operation, different axis.

## What this means for the build

- An **entry** in Chain is a diagram. Its metadata must record viewpoint: which key signed, which repo, which prompt, which files were read. Content without viewpoint is a drawing with no hilltop and cannot be trusted or disputed.
- An **assessment** (docs/assessments/) is a diagram of the fleet on a date. Keep them dated and never edit them in place; write a new one beside.
- The **Portal** is a reader of stacks. Its job is to show what is invariant across many entries, not to display one entry as if it were the graph.
- An **invariance test** is possible: run the same prompt against two agents, two models, or two days and diff the outputs. What holds is the framework's claim to objectivity; what moves is viewpoint. This is a Framework test, not a child test. See [open-paths.md](open-paths.md).

## Parable

A sculpture in a dark room, and all anyone gets is photographs from different angles. No photo is the sculpture. But the thing every photo agrees on, the silhouette that holds from every side, is the only sculpture anyone ever gets.

## Open questions

- Which of the three terms belong in Claude.Ontology as types, and which are documentation only?
- Does a diagram need a declared "hilltop" field (position, time, drawer) or is the signature plus timestamp sufficient?
