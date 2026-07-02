---
type: Contract
id: <context-id>.<contract_name>   # globally unique; must match the frontmatter declaration in context.md
kind: event                        # event | command | query | api | workflow
version: 1.0.0
stability: draft                   # draft | stable | deprecated
schema: v1.schema.<ext>            # authoritative schema file in this directory; format per repo-level ADR
description: <one-sentence summary for indexes and search>
---

# <Contract name>

<What this contract promises and to whom. The schema file is the source of truth; this document explains, it never redefines.>

# Schema

<Notes on the authoritative schema: field semantics, ordering/idempotency guarantees, compatibility expectations. No field definitions here — those live in the schema file.>

# Examples

<Concrete payload examples in fenced code blocks. Non-authoritative unless explicitly declared contract tests.>

# Citations

<Optional: numbered links to supporting sources or related ADRs.>
