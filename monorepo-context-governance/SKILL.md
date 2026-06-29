---
name: monorepo-context-governance
description: Use this skill when the user needs to design, create, migrate, audit, or maintain bounded-context knowledge packages for a microservices monorepo. Trigger for requests about docs/contexts, context packages, manifest.yaml, context-map.yaml, contract ownership/versioning, published or consumed contracts, ADR requirements, shared kernels, agent routing/read boundaries, or migrating ad hoc docs into governed context documentation. Do not use for ordinary code-only changes or generic documentation edits that do not involve context boundaries, contracts, or governance.
---

# Monorepo Context Governance

Use this skill to create, migrate, review, or maintain governed knowledge packages for bounded contexts in a microservices monorepo.

Keep the always-loaded context small. Read only the reference files that match the user's task.

## Operating Model

1. Classify the task before editing:
   - `implementation_defect`: code violates an existing contract, workflow, manifest, ADR, or spec.
   - `knowledge_defect`: the source of truth is missing, stale, ambiguous, or contradictory.
   - `contract_or_boundary_change`: the request changes a published contract, consumed dependency, ownership, responsibility, workflow, entrypoint, event, command, query, or cross-context dependency.
   - `ambiguous_case`: code and knowledge conflict and the correct source of truth is unclear.
2. Resolve the target context by id, alias, service, module, entrypoint, or user-provided path.
3. Load the minimal reference set from the routing table below.
4. Prefer copyable templates from `assets/` for new artifacts.
5. Validate the result with `scripts/validate_context_package.py` when a context package exists on disk.

## Routing Table

| User task                                                                                        | Read                                                                        |
| ------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------- |
| Understand the model, choose where facts live, or explain bounded contexts                       | `references/overview.md`                                                    |
| Create folder structure or decide document type boundaries                                       | `references/artifact-responsibilities.md`                                   |
| Author or review `manifest.yaml`                                                                 | `references/manifest-model.md` and `assets/manifest.template.yaml`          |
| Author or review `context-map.yaml` or agent read routing                                        | `references/context-map-routing.md` and `assets/context-map.template.yaml`  |
| Classify published/consumed contracts, version changes, operational contracts, or shared kernels | `references/contract-governance.md`                                         |
| Migrate existing `docs/*` into context packages                                                  | `references/migration.md` and `assets/migration-classification.template.md` |
| Decide whether an ADR is required or draft one                                                   | `references/adr-policy.md` and `assets/adr.template.md`                     |
| Review completeness, governance, or readiness                                                    | `references/validation-checklists.md`                                       |

## Guardrails

- Treat each bounded context as a stable knowledge package, not a code folder.
- Keep one authoritative source for each fact. Everything else is a link, generated view, evidence, or obsolete material.
- Store governable facts in `manifest.yaml`; do not bury ownership, dependencies, contracts, or entrypoints in prose only.
- Use `context-map.yaml` for agent routing; do not make agents read all docs by default.
- Publish contracts under the owning context. Consume contracts by reference only; never copy schema bodies into `contracts/consumed/`.
- Do not depend on another context's internals. Cross-context dependencies must go through published contracts or approved integration documents.
- Require ADRs for context creation, retirement, split, merge, identity change, ownership change, new dependency, shared kernel, contract architecture change, breaking semantic contract change, or major technology strategy change.
- Keep code governance in `AGENTS.md`, `CLAUDE.md`, or equivalent agent instructions, but update declared knowledge in the same change set when code changes affect it.

## Available Scripts

- `scripts/validate_context_package.py`: Validates the structure of a bounded-context package. Run from the skill root with `python3 scripts/validate_context_package.py <path-to-context>`. Use `--format json` when another tool or agent needs parseable output.

## Evaluation

Use `evals/evals.json` for eval-driven iteration. Use `evals/trigger_train_queries.json` and `evals/trigger_validation_queries.json` to test whether the description activates on the right prompts. Run each output-quality test once with this skill and once against a baseline or previous version, save outputs in a separate workspace directory, grade the assertions with concrete evidence, then update the skill only when failures generalize beyond one test case.

## Creation Workflow

1. Identify the bounded context and owner.
2. Create the context package shape from `references/artifact-responsibilities.md`.
3. Create `manifest.yaml` from `assets/manifest.template.yaml`.
4. Create `guide.md` from `assets/guide.template.md`.
5. Create `context-map.yaml` from `assets/context-map.template.yaml` when agents or loaders will depend on it.
6. Add contracts, workflows, runbooks, playbooks, observability notes, ADRs, and references only when they have a clear consumer.
7. Run `python3 scripts/validate_context_package.py <path-to-context>`.

## Review Workflow

1. Read `references/validation-checklists.md`.
2. Inspect the context package, starting with `manifest.yaml`, `guide.md`, and `context-map.yaml`.
3. Check contracts with `references/contract-governance.md` if any contract is published, consumed, deprecated, or changed.
4. Check ADR requirements with `references/adr-policy.md` for boundary, ownership, dependency, shared-kernel, or breaking-contract changes.
5. Run the validator and report errors before warnings.
