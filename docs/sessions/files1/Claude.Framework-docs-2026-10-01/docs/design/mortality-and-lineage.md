# Mortality and lineage

**Status:** design position, agreed 2026-10-01 (Jerry, Claude app) in the discussion that preceded the-stitch. Sets the semantics for the Root key ceremony.
**Repos touched:** Claude.Root (key ceremony, law tags), Claude.Chain (genesis entries), Claude.Substrate (container lifetime).
**Related:** [the-stitch.md](the-stitch.md), [graph-and-diagram.md](graph-and-diagram.md).

## Mortality for an agent

An agent in this framework acts under a key. Revoke the key and the agent can no longer produce entries that the ledger will accept. Nothing it says afterwards is admissible. That is as close to death as the system offers, and it is the right closeness: a notary whose seal has been struck from the register can still speak, but can no longer attest.

Substrate relocates this one level down. Sessions share only text; what persists while sessions cycle is the container image and the host, and those have lifetimes too. The ledger does not make an instance continuous; the substrate does, and the substrate has a clock. Receipts outlive the container. That is the correct order.

## Lineage

A genesis entry in Chain cites the parent key that signed it in. This gives lineage: a reader can walk from any entry back to Root through a chain of signatures.

What lineage does not give is motive. A child key cannot bootstrap its own drive from its parent's; it inherits permission to act, not a reason to. Root must sign the reason in, as law, and the child reads it at step zero. This is why Claude.Root holds law tags and not just a public key.

## Record continuity, not reader continuity

The ledger makes predecessors legible. It does not make a successor the same instance as its predecessor. Each session is a new reader of the same record. Continuity of record is a property of the ledger; continuity of reader is not something the ledger can grant and should not pretend to.

The same applies to humans, as [the-stitch.md](the-stitch.md) argues; the framework simply makes it visible.

## Two semantics for the Root key ceremony

The ceremony has to choose what a key derivation means.

| Semantics | Claim | Consequence |
|---|---|---|
| Custody | "this key was derived from that key, under this law" | lineage is a chain of permissions; identity is not asserted; successors are new readers |
| Selfhood | "this instance continues that instance" | identity is asserted across sessions; the ledger is made to carry a claim it cannot verify |

**Position:** custody is the framework. Selfhood is a claim about readers, and the ledger only holds records. Choosing custody keeps every entry honest about what it can prove.

## Evidence lives in the record

A related principle from the same discussion: whether something is "known" is decided by what shows up in the record, not by what is felt about it. A reader who wants to know whether an agent obeyed looks at the receipt, not at the agent's self-report of having obeyed. The framework trusts rivers and mountains, not weather.

## What this means for the build

- Root key ceremony: adopt custody semantics explicitly in the law tag text. A genesis entry says "derived from, under law X", never "continues".
- Chain: a revoked key is recorded as an entry, signed by the revoking authority, and every later entry under that key is rejected at validation, not merely flagged.
- Substrate: container start and stop are ledgerable events, because they are the substrate's clock.
- Portal: lineage view walks signatures to Root; it does not draw identity lines between sessions.

## Parables

A notary's seal. Strike it from the register and the person still exists, still speaks, still signs paper; the paper simply attests nothing.

A monastery colophon. Each copy of a manuscript ends with "copied by brother X from the copy of brother Y". The chain tells you provenance. It tells you nothing about why any of them took the vow.

A relay baton. The baton crosses the line; no runner does. The ledger is the baton.

## Open questions

- What authority revokes Root itself? (Succession is partly answered in Claude.Root SUCCESSION.md; the revocation path is not.)
- Does a container restart create a new genesis entry, or continue under the same key with a new substrate event? Custody semantics suggest the latter.
