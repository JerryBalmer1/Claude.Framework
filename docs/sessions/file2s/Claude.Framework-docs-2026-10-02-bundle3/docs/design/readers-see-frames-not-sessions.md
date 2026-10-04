# Readers see frames, not sessions

**Status:** design principle, agreed 2026-10-01 (Jerry, Claude app). Shapes the receipt format and the Portal.
**Repos touched:** Claude.Chain (entry schema), Claude.Framework (Invoke-Agent receipts), Claude.Portal (reader).
**Related:** [graph-and-diagram.md](graph-and-diagram.md), [the-stitch.md](the-stitch.md).

## The networking version

A firewall never sees intent. It sees packets: headers, ports, a payload, a timestamp. It decides on that frame and only that frame. It has no access to the session that produced the packet, the state at either end, or the reason the packet exists.

The history of false positives in security is the history of that limitation. A port scan that was a monitoring tool. A flood that was a backup job. An exfiltration alert that was a sync. Legitimate structure, read frame by frame, looks like an attack, because the reader fills the gaps with its own threat model instead of the sender's.

Stateful inspection was the industry admitting the problem: a packet cannot be judged alone; the connection it belongs to is needed. Deep packet inspection went further and still did not arrive, because every byte of a payload can be read without learning whether the sender was venting or planning. Content is not intent.

The firewall reads diagrams because diagrams are all that ever cross the wire.

## The framework version

Every reviewer of an agent is a firewall. A human, an auditor, a court, a future model. Each sees the agent's output frame by frame: this file changed, this command ran, this commit landed. Diagrams. Each fills the gaps with its own model.

An accountability ledger that records only what happened is a very good packet capture, and packet captures convict backup jobs.

What the ledger must record is **connection state**:

- what the agent was told (the prompt, hashed)
- what it read at step zero (CLAUDE.md, the working directories it listed)
- what it was allowed and what it refused
- whether it stopped on its own or was stopped

Intent is not a field that can be stored. The stitch that produced the frame can be, and that is the closest a reader without the author's graph can ever get.

This is why the step-zero read matters more than the diff. The diff is the packet. The step-zero read is the handshake that proves which session the packet belongs to.

## The inverse

It applies to the author too. A person's memory is a stateless firewall on their own past: it reads the diagram of what they did and completes it with how they feel now. This is why people rewrite their history honestly. They are inspecting packets without the session.

And it applies to any transcript. A conversation read later by someone without the speaker's graph is a foggy photocopy; the reader completes it with their own inference, and the same engine that sees two people in love in a blurred photograph can see a threat in a man thinking out loud. That is not a reason to write less. It is the reason the record must carry the handshake.

## What this means for the build

- **Invoke-Agent receipts** carry the full handshake, not just prompt hash and exit code: prompt, step-zero output (directories listed, CLAUDE.md hash), refusals, self-stops, output hash. The build script observes; it does not infer.
- **Chain's entry schema** gets a `context` block for the same fields. An entry with content and no context is accepted but marked as frame-only.
- **Portal** never renders an entry without its context block beside it. A reader is shown the session, not the packet.
- **Assess** should flag any child repo whose agent flow produces frames without handshakes.

## Parable

A security guard watching camera footage of a man climbing through a window at midnight. That is the frame. The log entry that says he locked himself out and rang the landlord at 11:50 is the state. Same footage, different verdict, and the only thing that changed is whether the reader had the handshake.

## Open questions

- How much of the step-zero output should be stored verbatim versus hashed? Verbatim is readable; hashed is cheap. Probably both, with verbatim capped.
- Should a frame-only entry be allowed into Chain at all, or quarantined to candidates/ until a context block is attached?
