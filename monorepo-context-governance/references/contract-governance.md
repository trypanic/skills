# Contract Governance

## Reading Map

TL;DR: A contract crosses a context boundary and is depended on for stable shape, meaning, or presence. Publish owned schemas; consume foreign contracts by reference only.

Read:

- "Definition" when deciding if something is contractual.
- "Published contracts" and "Consumed contracts" when editing contract artifacts.
- "Versioning" before changing a schema.
- "Shared kernel" before adding common models.

## Definition

An artifact is a contract only if:

1. it crosses a context boundary; and
2. another context, team, external system, operator, automation, or agent depends on its stable shape, meaning, or presence.

If it is internal to one context, it is not a contract.

## Taxonomy

| Concept | Contract? | Rule |
| --- | ---: | --- |
| Published contract | Yes | Owned and versioned by this context. |
| Consumed contract | Yes | Owned elsewhere and referenced here with a pinned version. |
| Event | Yes, if published | Fact that already happened and is emitted for consumers. |
| Command | Yes, if exposed | Intent directed at the owning context. |
| Query | Yes, if exposed | Read operation directed at the owning context. |
| API | Yes | Exposed commands/queries over a transport. |
| Schema | Yes | Machine-readable artifact defining structure and relevant semantics. |
| DTO crossing the wire | Part of contract | Serialization shape of a contract. |
| Internal DTO | No | Internal implementation detail. |
| Domain model | No | Internal model. Never expose as a cross-context dependency. |
| Port | No | Code interface that may realize or consume a contract. |
| Adapter | No | Technology binding. Never a contract. |
| Workflow | Usually no | Contractual only when another party depends on stable semantics. |
| Runbook | Usually no | Contractual only when automation/operators depend on stable inputs/outputs. |
| Metric/log/span | Only if declared contractual | Stable only when depended on externally or by automation. |
| Reference | No | Supporting material. Not authoritative. |

## Ownership Axis

Classify contracts by ownership first:

```text
published = owned here, versioned here, source of truth here
consumed  = owned elsewhere, referenced here, never copied here
```

Use direction only as a secondary axis:

```text
inbound  = received or served by this context
outbound = emitted or invoked by this context
```

Ownership governs versioning, deprecation, impact analysis, migration responsibility, approval, and source-of-truth location.

## Published Contracts

Published contracts live under:

```text
docs/contexts/<context>/contracts/published/
```

Recommended organization:

```text
contracts/
  published/
    events/
      <event-name>/
        v1.schema.<ext>
        v2.schema.<ext>
    commands/
      <command-name>/
        v1.schema.<ext>
    queries/
      <query-name>/
        v1.schema.<ext>
    apis/
      <api-name>/
        v1.schema.<ext>
```

Rules:

- Keep one contract as one authoritative schema family.
- Treat the schema as source of truth.
- Let prose explain but never redefine.
- Treat examples as non-authoritative unless explicitly declared as contract tests.
- Register published contracts in `manifest.contracts.published`.
- Require a new major version for breaking changes.
- Require deprecated versions to declare replacement and retirement target.

## Consumed Contracts

Consumed contracts are references to contracts owned by another context.

Declare them in `manifest.yaml`:

```yaml
contracts:
  consumed:
    - id: pricing.price_calculated
      version: "1.x"
      from: pricing
      usage: "Update the estimated order total."
      ref: ../pricing/contracts/published/events/price_calculated/v1.schema.json
```

Use `contracts/consumed/` only for non-authoritative notes such as local usage constraints, compatibility notes, accepted version examples, migration notes, or field-name mappings.

Rules:

- Do not put schema bodies in consumed contracts.
- Do not redefine fields.
- Point to the owner's published schema.
- Do not let local notes override the owner schema.
- If local usage contradicts the published schema, treat the contract as insufficient or the consumer as wrong.

## Versioning

Use SemVer for published contracts:

```text
MAJOR = breaking change
MINOR = backward-compatible addition
PATCH = clarification with no shape or semantic change
```

Breaking changes include removing fields, renaming fields, changing types, tightening validation, changing requiredness, changing semantics, changing ordering guarantees consumers depend on, changing idempotency meaning, or changing compatibility expectations.

Backward-compatible changes include adding optional fields, loosening validation, adding a compatible event type under an existing envelope, adding optional metadata, or clarifying docs without behavior change.

For a breaking change, produce an impact declaration like:

```yaml
contract: orders.order_placed
from: v1.4.0
to: v2.0.0
breaking: true
reason: "field 'legacyId' is removed"
affected_consumers:
  - context: invoicing
    current_version: "1.x"
    required_action: "migrate to orderId"
migration: "use 'orderId'; legacyId retired after 90 days"
deprecation_window: "90d"
adr: ADR-0042
```

Derive `affected_consumers` from declared `manifest.contracts.consumed` across contexts, not from hand-maintained notes only.

## Contractual vs Non-Contractual

A definition is contractual when another context, team, external system, operator, automation, or agent depends on its stable shape, meaning, or presence.

Contractual examples:

- event schema consumed by another context;
- command payload exposed by a context;
- query response consumed by another context;
- public API schema;
- operational signal used by a shared alert;
- metric used by an SLO;
- log/span field used by incident automation;
- error envelope consumed across contexts;
- shared identifier format.

Non-contractual examples:

- local workflow explanation;
- local implementation note;
- internal DTO;
- private domain model;
- internal metric not used by another party;
- debugging note;
- exploratory reference;
- illustrative diagram;
- local code interface;
- adapter details.

## Operational Contracts

Make a signal contractual only when at least one condition is true:

- It is used by shared alerts.
- It is used by cross-context runbooks.
- It is consumed by another team or context.
- It is part of an SLO/SLA.
- It is consumed by automation or agents.
- It is required for cross-context diagnosis.

Contractual signal:

```yaml
observability:
  signals:
    - name: "orders.task.claimed.total"
      type: metric
      meaning: "Number of tasks successfully claimed by workers."
      contractual: true
      version: "1.0.0"
      stability: stable
      used_by:
        - context: operations
          purpose: "worker assignment alert"
```

Non-contractual signal:

```yaml
observability:
  signals:
    - name: "orders.debug.selector_attempts"
      type: log
      meaning: "Debug information for selector fallback attempts."
      contractual: false
      stability: internal
```

## Shared Kernel

Default to no shared kernel. Prefer shared contracts over shared kernels.

A shared kernel is allowed only when:

- the concept has identical semantics across contexts;
- it must remain in lockstep;
- duplication would create semantic corruption;
- owners agree to co-own it;
- an ADR justifies it.

Allowed examples: `Money`, `Currency`, shared identifier format, common error envelope, cross-context message envelope.

Forbidden examples: domain policy, business rules, convenience utilities, framework helpers, technology adapters, or anything used in two places merely because it is textually similar.

Treat shared kernel as its own bounded context:

```text
docs/contexts/shared-kernel/
  manifest.yaml
  contracts/
  decisions/
```

Require ADR and approval from at least two affected owners for additions.
