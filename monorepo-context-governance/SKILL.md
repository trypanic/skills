---
name: monorepo-context-governance
description: Use when the user needs to design, create, migrate, audit or maintain a governed knowledge bundle for any repository. This covers monorepos, single services and docs-only projects, greenfield or with existing docs. Trigger for requests about docs/contexts, context packages, context.md, knowledge bundles, and OKF or YAML-frontmatter document types. Also for contract ownership/versioning (published/consumed contracts), consumed-contract references, contract registries, ADR requirements, shared kernels and adoption tiers. Also for agent routing/read boundaries, organizing docs for AI agents, or migrating ad hoc docs/* into governed context documentation. Not for ordinary code-only changes or generic documentation edits that do not involve context boundaries, contracts or knowledge governance.
---

# Context Knowledge Governance (OKF-aligned)

A governed knowledge bundle holds bounded contexts as self-contained knowledge packages and follows OKF v0.1 (markdown + YAML frontmatter with a `type` field). Contracts are the only cross-context boundary.

Keep the always-loaded context small. Read only the reference files that match the user's task.

## Operating Model

1. Detect the mode:
   - `greenfield`: no governed docs exist yet. Scaffold a bundle and the first context.
   - `migration`: ad hoc docs exist. Classify by `type` and migrate per context, incrementally.
   - `maintenance`: a bundle exists. Change, review or extend it.
2. Classify the task before you edit anything:
   - `implementation_defect`: code violates an existing contract, workflow, context.md fact or ADR. Fix code/tests. Edit knowledge only if it is stale.
   - `knowledge_defect`: the source of truth is missing, stale, ambiguous or contradictory. Fix knowledge first or in the same change set.
   - `contract_or_boundary_change`: the request changes a published contract, consumed dependency, ownership, dependency or entrypoint. Follow the versioning, impact and ADR rules before you implement.
   - `ambiguous_case`: code and knowledge conflict and the right side is unclear. Report the conflict. Never resolve it silently.
3. Resolve the target context via `docs/registry.yaml`, `docs/index.md` or the user-provided path.
4. Load the minimal reference set from the routing table.
5. For new artifacts, copy templates from `assets/`. Never invent alternative layouts.
6. Run `scripts/validate_bundle.py` whenever a bundle or context exists on disk.

## Routing Table

| User task | Read |
|---|---|
| Understand the model, principles, OKF conformance or bundle layout | `references/model-overview.md` |
| Author or review `context.md` (frontmatter facts + human guide body) | `references/context-file.md` and `assets/context.template.md` |
| Classify, publish, consume, version or deprecate contracts. Shared kernel questions. | `references/contract-governance.md` and `assets/contract.template.md` |
| Classify rules as enforced or advisory. Design CI checks. Check registry consistency. | `references/governance-rules.md` |
| Scaffold a new project/context or migrate existing `docs/*` | `references/adoption-migration.md` |
| Set up agent instructions, task routing or optional `context-map.yaml` | `references/agent-consumption.md` and `assets/agents-instructions.template.md` |
| Decide whether an ADR is required or draft one | `references/adr-policy.md` and `assets/adr.template.md` |
| Review completeness or audit a bundle | `references/validation-checklists.md` |

## Core Rules (always apply)

- One `context.md` per context. Its frontmatter holds only lintable, governable facts (id, owner, status, contracts, dependencies, contractual signals, entrypoints). Its body is the human guide in prose. Never create `manifest.yaml`, `guide.md` or a separate `README.md` for a context. This model replaced those v1 artifacts.
- Every non-reserved `.md` in the bundle carries YAML frontmatter with a non-empty `type`. The reserved files `index.md` and `log.md` carry no `type` (root `index.md` may declare `okf_version` only).
- Ownership sets each contract's class: `published` (owned here, versioned here) or `consumed` (owned elsewhere). Reference a consumed contract here by **id + version only**, never by relative path and never as a copied schema body.
- The published schema file is the source of truth. Prose explains it and never redefines it.
- Accepted ADRs are immutable. Supersede, never edit.
- Adoption is incremental (tiers 0–3). A repo with two governed contexts and ten legacy docs is a valid state. Never demand full migration up front.
- Each rule is either enforced (a check exists) or advisory (listed as pending). Never cite an advisory rule as blocking in a review.
- Strict production, permissive consumption. Producers must pass lints. Readers (human or agent) tolerate missing optional fields, unknown types and broken links.

## Gotchas

- A consumed contract with a `ref:` path into the owner's folder tree couples to the owner's internals. Declare id + version. Resolution goes through the generated `docs/registry.yaml`.
- The `contracts/consumed/` folder is optional and holds only non-authoritative notes. Any schema body in it is an error.
- Declare an exposed operation exactly once: as a standalone `event`/`command`/`query` contract **or** as part of an `api` contract, never both.
- Responsibilities and boundaries are prose in the `context.md` body, not YAML. No lint can check a responsibility string, so machine-readability adds no value there.
- `context-map.yaml` is optional (Tier 3). There is no closed intent vocabulary. Never require it or block on its absence.
- Never hand-edit generated files (`index.md` listings, `registry.yaml`).
- Do not version internal signals or internal docs. Only contractual definitions (depended on across a boundary) get versions.

## Available Scripts

- `scripts/validate_bundle.py`: checks an OKF knowledge bundle (`docs/` root) or a single context directory. Run `python3 scripts/validate_bundle.py <path>`. Add `--repo-root <path>` to also check that entrypoints resolve. Add `--format json` for parseable output. Exit codes: 0 clean, 1 errors found, 2 usage error.

## Workflows

### Create (greenfield project or new context)

1. Read `references/adoption-migration.md` (Tier 0 section) and `references/context-file.md`.
2. Scaffold `docs/index.md` (with `okf_version: "0.1"`), `docs/OWNERS` and `docs/contexts/<id>/`.
3. Create `context.md` from `assets/context.template.md`. Fill frontmatter facts and prose body.
4. Add a contract, workflow, runbook, playbook or ADR only when it has a real consumer. Use `assets/contract.template.md`, `assets/concept.template.md` and `assets/adr.template.md`.
5. Run `python3 scripts/validate_bundle.py docs/`.

### Migrate (existing docs)

1. Read `references/adoption-migration.md` (migration section).
2. Inventory existing docs. Assign each an OKF `type` (or `duplicate` / `obsolete` / `unknown` / `conflict`) before you move anything.
3. Migrate one context at a time to Tier 0. Extract contracts at Tier 1. Classify doc↔code conflicts with the conflict taxonomy. Never resolve them by recency.
4. Run the validator after each context.

### Review (audit a bundle)

1. Read `references/validation-checklists.md`.
2. Run `python3 scripts/validate_bundle.py <path> --format json`. Report errors before warnings.
3. Check contract governance (`references/contract-governance.md`) for any published/consumed/deprecated contract change. Check ADR requirements (`references/adr-policy.md`) for boundary/ownership/dependency changes.
4. Distinguish enforced-rule violations (blocking) from advisory findings (recommendations).

## Evaluation

Use `evals/evals.json` for eval-driven iteration and `evals/trigger_*_queries.json` to test description activation.

1. Run each output-quality test with the skill and against a baseline.
2. Grade assertions with concrete evidence.
3. Update the skill only when failures generalize beyond one test case.
