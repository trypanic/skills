# Overview

## Reading Map

TL;DR: Use bounded contexts as stable knowledge packages. Keep code location mutable, context identity stable, and every governable fact in one authoritative source.

Read:

- "Core model" before creating or reviewing a context package.
- "Fact ownership" when deciding where a fact belongs.
- "Synchronization" when a code change touches declared knowledge.

## Core Model

A bounded context is a knowledge package. It owns domain language, responsibility, non-responsibility, boundaries, dependencies, published contracts, consumed contracts, workflows, operational meaning, decisions, and task-specific context selection.

A bounded context is not a code folder. Code may move, split, merge, or change language while the context identity remains stable. Change the stable context id only when the domain or ownership boundary changes, and require an ADR plus migration plan.

The only valid architectural relation between bounded contexts is a contract: a versioned, machine-readable, authoritative artifact whose shape and semantics can be depended on by another context, team, operator, automation, external system, or agent.

## Design Principles

- Keep one source per fact.
- Use prose for intent, boundaries, language, workflows, rationale, and operational meaning; avoid restating obvious implementation.
- Treat contracts as the architectural boundary between contexts.
- Classify contracts by ownership first: `published` if owned here, `consumed` if owned elsewhere.
- Keep knowledge identity stable and code location mutable.
- Make governable facts machine-readable.
- Separate human navigation from agent routing.
- Version only contractual definitions.
- Mark unenforced governance as advisory until a lint, CI rule, CODEOWNERS rule, or review rule exists.
- Keep generic knowledge once at repo level.
- Keep context-specific knowledge inside the context.
- Classify existing docs before migration.
- Synchronize code and knowledge deliberately.
- Record concrete technology choices in ADRs.

## Fact Ownership

| Fact type | Authoritative source |
| --- | --- |
| Context identity, owner, status | `manifest.yaml` |
| Purpose | `manifest.yaml` brief statement plus `guide.md` explanation |
| Responsibility, non-responsibility, boundary, dependency | `manifest.yaml` |
| Published contract | `contracts/published/**` plus `manifest.contracts.published` |
| Consumed contract | `manifest.contracts.consumed` or `contracts/consumed` reference |
| Workflow | `workflows/**` |
| Runbook | `runbooks/**` |
| Playbook | `playbooks/**` |
| Architectural decision | `decisions/ADR-*.md` |
| Pending decision | `open-questions.md` |
| Contractual signal | `manifest.observability.signals` plus optional schema |
| Agent routing | `context-map.yaml` |
| Human navigation | `guide.md` |
| Code and test location | `manifest.entrypoints` |
| Generated document index | Generated from filesystem, never hand-maintained |

## What Does Not Belong In A Context Package

Do not put these inside a context package:

- implementation code;
- build rules;
- test framework rules;
- language-specific architecture rules;
- internals of another context;
- copied contracts from another context;
- generic procedures duplicated from repo-level docs;
- convenience notes without links to canonical artifacts;
- domain models exposed as contracts;
- ports or adapters as published contracts;
- generated indexes that are manually edited.

## Synchronization

Any code change that affects declared knowledge must update the corresponding source of truth in the same change set, or explicitly declare that no knowledge update is required.

Apply this when changing published contracts, consumed contracts, responsibilities, non-responsibilities, boundaries, dependencies, entrypoints, exposed commands, exposed queries, emitted events, consumed events, workflows, contractual operational signals, architectural decisions, ownership, or lifecycle status.

Classify task changes before editing:

| Classification | Meaning | Action |
| --- | --- | --- |
| `implementation_defect` | Code violates an existing source of truth. | Change code/tests. Do not alter source of truth unless stale or incomplete. |
| `knowledge_defect` | Implementation is reasonable but knowledge is missing, stale, ambiguous, or contradictory. | Update knowledge first or in the same change set. Align code if needed. |
| `contract_or_boundary_change` | Request changes a contract, ownership, dependency, responsibility, workflow, entrypoint, event, command, query, or boundary. | Follow versioning, impact, and ADR rules before implementation. |
| `ambiguous_case` | It is unclear whether code or knowledge is wrong. | Surface ambiguity and propose the smallest valid change path. |
