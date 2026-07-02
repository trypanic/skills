# Model Overview

## Reading Map

TL;DR: Each bounded context is a self-contained knowledge package rooted in one `context.md`. The whole knowledge tree is an OKF v0.1 bundle: markdown + YAML frontmatter with a `type` field, generated `index.md` listings, and contracts as the only cross-context boundary.

Read:

- "Core model" before creating or reviewing anything.
- "OKF conformance" when authoring or linting documents.
- "Bundle layout" when placing a new artifact.
- "Principles" when arbitrating a design disagreement.

## Core Model

A bounded context is a knowledge package: a stable unit of ownership, domain language, responsibility, contracts, decisions, and operational meaning. It is not a code folder. Code may move, split, merge, or change language while the context identity stays stable. The stable id changes only when the domain or ownership boundary changes, and that requires an ADR plus a migration plan.

The only valid architectural relation between contexts is a contract: a versioned, machine-readable artifact owned by exactly one context and depended on by another context, team, external system, operator, automation, or agent.

Single guiding principle:

> A fact must have one authoritative source. Everything else is a reference, a generated view, operational evidence, or obsolete material.

This model works for any repository: a microservices monorepo, a single service, or a docs-only knowledge base. A "context" in a small project may simply be the whole system; the format is the same.

## Principles

| # | Principle | Reason |
| --- | --- | --- |
| P1 | One source per fact. | Prevents contradictions and drift. |
| P2 | Machine-readable only where a check exists. | YAML precision without a lint is authoring cost with no payoff. Owner, contracts, entrypoints are lintable; a responsibility string is not — it stays prose. |
| P3 | Contracts are the only architectural boundary between contexts. | No context depends on another's internals — including its folder layout. |
| P4 | Ownership governs versioning and impact. | The owner versions, migrates, deprecates, approves. Direction (inbound/outbound) is descriptive only. |
| P5 | Knowledge identity is stable; code location is mutable. | Identity changes only with the domain boundary. |
| P6 | Every rule is enforced or explicitly advisory. | A rule ships with its check or ships labeled advisory. No third state. |
| P7 | Permissive consumption, strict production. | Producers must satisfy lints; consumers tolerate missing fields, unknown types, broken links. Strictness lives in CI, not in the reader. |
| P8 | Only contractual definitions are versioned. | A definition is contractual when another party depends on its stable shape, meaning, or presence. |
| P9 | Generic knowledge lives once, at repo level. | Generic procedures are not duplicated per context. |
| P10 | Adoption is incremental. | Contexts climb tiers independently; mixed maturity is a valid repo state. |

## OKF Conformance

The knowledge tree under `docs/` is an OKF v0.1 bundle:

- Every non-reserved `.md` file carries YAML frontmatter with a non-empty `type` field.
- `index.md` and `log.md` are reserved filenames:
  - `index.md` lists a directory's documents for progressive disclosure (`* [Title](url) - description` under headings). Generated — never hand-edited. The bundle root `docs/index.md` declares `okf_version: "0.1"` in its frontmatter; that is the only frontmatter permitted in any index file.
  - `log.md` records change history, newest first, under ISO-date headings (`## 2026-07-02` with `**Update**:` / `**Creation**:` / `**Deprecation**:` bullets).
- Cross-links are standard markdown links, bundle-absolute preferred (`/contexts/pricing/context.md`). Links are untyped edges; relationship semantics live in prose. Broken links are tolerated by consumers (they may mark not-yet-written knowledge) but reported by the advisory link lint.
- Consumers must preserve unknown frontmatter keys and must not reject documents over unrecognized fields.
- Recommended optional frontmatter beyond `type`: `title`, `description` (one sentence, used in indexes and search), `tags`, `timestamp`.

## Document Types

| `type` | Meaning | Location |
| --- | --- | --- |
| `BoundedContext` | Context root: governable facts + human guide | `contexts/<id>/context.md` |
| `Contract` | Published contract concept doc | `contexts/<id>/contracts/published/<name>/contract.md` |
| `Workflow` | What the system does | `contexts/<id>/workflows/` |
| `Runbook` | How to diagnose/mitigate a failure | `contexts/<id>/runbooks/` |
| `Playbook` | How to execute a deliberate repeated change | `contexts/<id>/playbooks/` |
| `ADR` | Why a decision was made (append-only) | `contexts/<id>/decisions/`, `docs/decisions/` |
| `SignalCatalog` | Observability signals and meanings | `contexts/<id>/observability.md` |
| `Reference` | Supporting, non-authoritative material | `contexts/<id>/references/` |

Types are strings, not a closed registry: the lint checks presence, not membership. Introduce a new type with a repo-level ADR only when it needs tooling support.

Type disambiguation:

```text
workflow = what the system does
runbook  = how to diagnose/mitigate when it fails
playbook = how to execute a deliberate repeated change
ADR      = why a decision was made
contract = what stable boundary is promised
```

## Bundle Layout

```text
docs/
  index.md                     # bundle root; okf_version; generated context listing
  log.md                       # repo-level knowledge change history
  registry.yaml                # GENERATED: context ids, aliases, contract ids -> paths
  OWNERS                       # team registry used by frontmatter + CODEOWNERS

  contexts/
    <context-id>/
      context.md               # type: BoundedContext — the only mandatory file
      index.md                 # generated listing of this context's docs
      log.md                   # context-level change history
      contracts/
        published/
          <contract-name>/
            contract.md        # type: Contract
            v1.schema.<ext>    # authoritative schema, format chosen by ADR
        consumed/              # OPTIONAL: non-authoritative notes only
      workflows/
      runbooks/
      playbooks/
      observability.md         # optional signal catalog
      decisions/
      references/
      context-map.yaml         # Tier 3, optional

  decisions/                   # repo-level ADRs (incl. the schema-format ADR)
  playbooks/                   # generic procedures
  runbooks/                    # generic procedures
  contracts/
    shared-kernel/             # only if an ADR creates it
```

Only `context.md` is mandatory for a context to exist. Every other file and folder is created on demand, when it has a real consumer.

## What Does Not Belong in a Context Package

- implementation code (the package points to code via `entrypoints`, never contains it);
- build/test/framework rules;
- internals of another context, or links to them presented as authoritative;
- copied contracts from another context;
- generic procedures duplicated from repo level;
- domain models, ports, or adapters exposed as contracts;
- hand-edited generated indexes;
- v1 artifacts: `manifest.yaml`, `guide.md`, standalone `README.md`, `open-questions.md`, `glossary.md` as mandatory files — open questions and glossary live as sections in `context.md` until they outgrow it, then become typed docs linked from the body.

## Code ↔ Knowledge Synchronization

Any code change affecting a declared knowledge fact (contracts, dependencies, entrypoints, contractual signals, ownership, status) must update the source of truth in the same change set or carry an explicit machine-readable waiver (`Knowledge-Impact: none` PR trailer). The enforcement mechanics are rule E10 in `references/governance-rules.md`; the agent-side task classification lives in `references/agent-consumption.md`.
