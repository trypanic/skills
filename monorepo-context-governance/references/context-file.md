# `context.md` — the Context Root

## Reading Map

TL;DR: One file per context. Frontmatter = lintable, governable facts only. Body = the human guide in prose. Nothing else is mandatory.

Read:

- "Frontmatter schema" when authoring or linting facts.
- "Body sections" when writing the guide portion.
- "Authoring rules" before review.

## Frontmatter Schema

Frontmatter holds only facts a check can verify: identity, owner, status, contracts, dependencies, contractual signals, entrypoints. Everything a human needs to *understand* the context lives in the body.

```yaml
---
type: BoundedContext

id: orders                     # stable; must match the directory name; renaming requires ADR + migration plan
title: Orders
status: active                 # proposed | active | deprecated | retired
owner:
  team: team-orders            # must resolve in docs/OWNERS
  contact: "#orders-eng"
last_reviewed: 2026-07-02

contracts:
  published:
    - id: orders.order_placed  # globally unique; registry maps id -> schema path
      kind: event              # event | command | query | api | workflow
      version: 2.1.0
      stability: stable        # draft | stable | deprecated
      replacement: null        # required non-null when stability: deprecated
  consumed:
    - id: pricing.price_calculated
      version: "1.x"           # pinned version or range
      usage: "Update the estimated order total."

dependencies:
  allowed:
    - context: pricing
      via: [pricing.price_calculated]
  forbidden:
    - context: invoicing
      reason: "Billing rules must not leak into order acceptance."

signals:                       # contractual signals only; internal signals live in observability.md
  - name: orders.task.claimed.total
    kind: metric               # metric | log | span
    version: 1.0.0
    used_by:
      - context: operations
        purpose: "worker assignment alert"

entrypoints:
  source: [services/orders/, libs/orders-domain/]
  tests: [services/orders/tests/]
---
```

Field rules:

- `id` is the stable context identity. It never changes because a folder is renamed, code moves, a service splits internally, or a language migration happens. It changes only when the domain or ownership boundary changes (ADR required).
- `owner.team` must resolve in `docs/OWNERS`; a CODEOWNERS entry should cover the context directory.
- Consumed contracts are declared by **id + version only** — no `ref` paths, no `from` field, no schema bodies. Resolution goes through the generated `docs/registry.yaml`. A consumer never knows where the owner keeps the schema file.
- `signals` lists contractual signals only (depended on by another party). Internal signals belong in `observability.md` without versions.
- `entrypoints.source` / `entrypoints.tests` are the code pointers that keep knowledge decoupled from code location; they must resolve to existing paths (enforced rule E7) and drive the anti-drift gate (E10).

## Body Sections

```md
# <Context title>

One-paragraph purpose statement.

## What this context owns
Prose responsibilities. Written for humans; no lint can verify a responsibility string, so it is not YAML.

## What this context does not own
Prose, with links to the owning context (e.g. price computation → [pricing](/contexts/pricing/context.md)).

## Start here
Reading path for a newcomer.

## Main workflows
Links into workflows/ with one-line descriptions.

## Contracts
One line per contract linking to its contract.md. Summaries only — the frontmatter and schema files are authoritative; this section may be generated.

## Operational knowledge
Links to runbooks, playbooks, observability.md.

## Relevant decisions
Links to the ADRs that explain the current shape.

## Open questions
Unresolved decisions with owner and status. Move to a dedicated doc only when this outgrows the file.
```

Omit sections that would be empty. Add a `## Glossary` section when local terms need definition; extract it to a typed doc only when it outgrows the file.

## Authoring Rules

- The body must not restate frontmatter facts except as generated content or one-line link summaries.
- Frontmatter growing past ~80 lines means something is misplaced. Move it out:

| If it grows | Move to |
| --- | --- |
| glossary or open questions | dedicated typed doc linked from body |
| workflow explanation | `workflows/**` |
| troubleshooting | `runbooks/**` |
| change procedure | `playbooks/**` |
| decision rationale | `decisions/ADR-*.md` |
| contract body | `contracts/published/**` |
| internal signal descriptions | `observability.md` |

- Do not create `manifest.yaml`, `guide.md`, or a context `README.md`. Those are v1 artifacts; `context.md` replaces all three.
- Splitting documents: split by purpose, consumer, and change frequency — never by arbitrary size. One document, one primary purpose. Diagnosis goes to a runbook; deliberate change to a playbook; rationale to an ADR; current fact to frontmatter.
- Long documents (>~300 lines) start with a reading map: a TL;DR plus "read section X if doing Y" bullets (advisory rule A3).
