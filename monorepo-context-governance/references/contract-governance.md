# Contract Governance

## Reading Map

TL;DR: An artifact is a contract iff it crosses a context boundary and another party depends on its stable shape, meaning, or presence. Ownership (published/consumed) is the primary axis. The schema file is the source of truth. Consumed = id + version reference, never a copy.

Read:

- "Definition and taxonomy" when classifying an artifact.
- "Published contracts" when creating or changing an owned contract.
- "Consumed contracts" when depending on another context.
- "Versioning" for any shape or semantic change.
- "Operational contracts" for metrics/logs/spans.
- "Shared kernel" when someone proposes shared models.

## Definition and Taxonomy

An artifact is a contract iff:

1. it crosses a context boundary; and
2. another context, team, external system, operator, automation, or agent depends on its stable shape, meaning, or presence.

Internal-only definitions are never contracts.

| Concept | Contract? | Note |
| --- | ---: | --- |
| Published contract | Yes | Owned and versioned by this context. |
| Consumed contract | Yes | Owned elsewhere; referenced here by id + pinned version. |
| Event | Yes, if published | Fact that happened, emitted for consumers. |
| Command | Yes, if exposed | Intent directed at the owning context. |
| Query | Yes, if exposed | Read operation directed at the owning context. |
| API | Yes | Set of exposed commands/queries over a transport. |
| DTO crossing the wire | Part of contract | Serialization shape. |
| Internal DTO | No | Implementation detail. |
| Domain model | No | Never exposed as a cross-context dependency. |
| Port / adapter | No | Code interface / technology binding; may realize a contract, is not one. |
| Workflow | Usually no | Contractual only if another party depends on its stable semantics — then publish it with `kind: workflow` and a versioned behavioral spec as its schema artifact. |
| Runbook | Usually no | Contractual only if automation/operators depend on stable inputs/outputs. |
| Metric/log/span | Only if declared contractual | See "Operational contracts". |
| Reference | No | Supporting material, never authoritative. |

An exposed operation is declared exactly once: either as a standalone `event`/`command`/`query` contract or as part of an `api` contract, never both. The registry generator fails on duplicate operation declarations.

## Ownership Is the Primary Axis

```text
published = owned here, versioned here, source of truth here
consumed  = owned elsewhere, referenced here by id, never copied here
```

Ownership governs versioning, deprecation, impact analysis, migration responsibility, and approval. Direction (inbound/outbound) is descriptive metadata only.

## Published Contracts

Location: `contexts/<id>/contracts/published/<contract-name>/` containing `contract.md` (type: Contract) plus the versioned schema family (`v1.schema.<ext>`, `v2.schema.<ext>`, …).

Rules:

- One contract = one `contract.md` + one authoritative schema family, versioned side by side.
- The schema file is the source of truth. The `contract.md` body explains (`# Schema` notes, `# Examples` per OKF conventions) but must not redefine.
- Every published contract is declared in `context.md` frontmatter (`contracts.published`) with id, kind, version, stability.
- Examples are non-authoritative unless explicitly declared contract tests.
- Deprecated contracts require a non-null `replacement` and a retirement target.
- The schema format (JSON Schema, protobuf, Avro, OpenAPI, …) is a repo-level ADR made at Tier 1. Version-bump checking is implemented per chosen format — do not pretend a generic cross-format differ exists.

## Consumed Contracts

- Declared in `context.md` frontmatter by id + version. Nothing else is required.
- Never declare a path to the owner's schema. Resolution goes through the generated `docs/registry.yaml`; a path couples the consumer to the owner's folder layout, which violates the internals rule.
- `contracts/consumed/` is optional and holds only non-authoritative notes: local usage constraints, field-name mapping to local language, accepted-version examples, migration notes. Any schema body found there is an error (enforced rule E4).
- If local usage contradicts the published schema, either the contract is insufficient or the consumer is wrong. File an open question or an ADR with the owner. Never patch locally.

## Versioning

SemVer per published contract:

```text
MAJOR = breaking change
MINOR = backward-compatible addition
PATCH = clarification with no shape or semantic change
```

Breaking: removing/renaming a field, changing a type, tightening validation, changing requiredness, changing semantics, changing ordering guarantees consumers depend on, changing idempotency meaning, changing compatibility expectations.

Backward-compatible: adding an optional field, loosening validation, adding a compatible event type under an existing envelope, adding optional metadata, documentation clarifications.

A breaking change requires an impact declaration:

```yaml
contract: orders.order_placed
from: 1.4.0
to: 2.0.0
breaking: true
reason: "field 'legacyId' is removed"
affected_consumers: []   # GENERATED from all contexts' contracts.consumed via registry.yaml
migration: "use 'orderId'; legacyId retired after 90 days"
deprecation_window: "90d"
adr: ADR-0042
```

`affected_consumers` is generated from consumed declarations across contexts — never hand-maintained. This is buildable because consumption is declared by id in a fixed frontmatter location.

## Operational Contracts

A signal (metric/log/span) is contractual only if at least one holds:

- used by shared alerts;
- used by cross-context runbooks;
- consumed by another team or context;
- part of an SLO/SLA;
- consumed by automation or agents;
- required for cross-context diagnosis.

Contractual signals are declared in `context.md` frontmatter (`signals`) with name, kind, version, and `used_by`. Everything else is an internal observability detail: it lives in `observability.md` without a version and must not be treated as a stable dependency (advisory rule A6).

## Shared Kernel

Default: **no shared kernel**. Prefer contracts — ownership is clear, versioning explicit, consumers pin versions, internals stay private.

A shared kernel is allowed only when all hold:

- identical semantics across contexts that must move in lockstep;
- duplication would create semantic corruption;
- owners agree to co-own it;
- an ADR justifies it, approved by at least two affected owners.

Allowed examples: `Money`, `Currency`, shared identifier formats, common error/message envelopes. Forbidden: domain policy, business rules, convenience utilities, framework helpers, adapters, anything shared merely because it is textually similar.

Model it as its own bounded context (`docs/contexts/shared-kernel/` with `context.md` + published contracts).
