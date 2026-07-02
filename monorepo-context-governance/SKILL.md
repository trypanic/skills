---
name: monorepo-context-governance
description: Use this skill when the user needs to design, create, migrate, audit, or maintain a governed knowledge bundle for any repository — monorepo, single service, or docs-only project, greenfield or existing docs. Trigger for requests about docs/contexts, context packages, context.md, knowledge bundles, OKF or YAML-frontmatter document types, contract ownership/versioning (published/consumed contracts), consumed-contract references, contract registries, ADR requirements, shared kernels, adoption tiers, agent routing/read boundaries, organizing docs for AI agents, or migrating ad hoc docs/* into governed context documentation. Do not use for ordinary code-only changes or generic documentation edits that do not involve context boundaries, contracts, or knowledge governance.
---

# Context Knowledge Governance (OKF-aligned)

Use this skill to create, migrate, review, or maintain governed knowledge bundles: bounded contexts as self-contained knowledge packages, organized as an OKF v0.1 bundle (markdown + YAML frontmatter with a `type` field), with contracts as the only cross-context boundary.

Keep the always-loaded context small. Read only the reference files that match the user's task.

## Operating Model

1. Detect the mode:
   - `greenfield`: no governed docs exist yet — scaffold a bundle and the first context.
   - `migration`: ad hoc docs exist — classify by `type` and migrate per context, incrementally.
   - `maintenance`: a bundle exists — change, review, or extend it.
2. Classify the task before editing anything:
   - `implementation_defect`: code violates an existing contract, workflow, context.md fact, or ADR. Fix code/tests; touch knowledge only if stale.
   - `knowledge_defect`: source of truth is missing, stale, ambiguous, or contradictory. Fix knowledge first or in the same change set.
   - `contract_or_boundary_change`: the request changes a published contract, consumed dependency, ownership, dependency, or entrypoint. Follow versioning, impact, and ADR rules before implementation.
   - `ambiguous_case`: code and knowledge conflict and the correct side is unclear. Surface the conflict; never resolve silently.
3. Resolve the target context via `docs/registry.yaml`, `docs/index.md`, or the user-provided path.
4. Load the minimal reference set from the routing table.
5. Copy templates from `assets/` for new artifacts; never invent alternative layouts.
6. Validate with `scripts/validate_bundle.py` whenever a bundle or context exists on disk.

## Routing Table

| User task | Read |
| --- | --- |
| Understand the model, principles, OKF conformance, or bundle layout | `references/model-overview.md` |
| Author or review `context.md` (frontmatter facts + human guide body) | `references/context-file.md` and `assets/context.template.md` |
| Classify, publish, consume, version, or deprecate contracts; shared kernel questions | `references/contract-governance.md` and `assets/contract.template.md` |
| Decide which rules are enforced vs advisory; design CI checks; registry consistency | `references/governance-rules.md` |
| Scaffold a new project/context or migrate existing `docs/*` | `references/adoption-migration.md` |
| Set up agent instructions, task routing, or optional `context-map.yaml` | `references/agent-consumption.md` and `assets/agents-instructions.template.md` |
| Decide whether an ADR is required or draft one | `references/adr-policy.md` and `assets/adr.template.md` |
| Review completeness or audit a bundle | `references/validation-checklists.md` |

## Core Rules (always apply)

- One `context.md` per context: frontmatter holds only lintable, governable facts (id, owner, status, contracts, dependencies, contractual signals, entrypoints); the body is the human guide in prose. Never create `manifest.yaml`, `guide.md`, or a separate `README.md` for a context — those are v1 artifacts this model replaced.
- Every non-reserved `.md` in the bundle carries YAML frontmatter with a non-empty `type`. `index.md` and `log.md` are reserved and carry no `type` (root `index.md` may declare `okf_version` only).
- Contracts are classified by ownership: `published` (owned here, versioned here) or `consumed` (owned elsewhere, referenced here by **id + version only** — never by relative path, never as a copied schema body).
- The published schema file is the source of truth. Prose explains; it never redefines.
- Accepted ADRs are immutable. Supersede, never edit.
- Adoption is incremental (tiers 0–3). A repo with two governed contexts and ten legacy docs is a valid state. Never demand full migration up front.
- Rules are enforced (a check exists) or advisory (listed as pending). Never cite an advisory rule as blocking in a review.
- Strict production, permissive consumption: producers must pass lints; readers (human or agent) tolerate missing optional fields, unknown types, and broken links.

## Gotchas

- Consumed contract with a `ref:` path into the owner's folder tree = coupling to the owner's internals. Declare id + version; resolution goes through the generated `docs/registry.yaml`.
- `contracts/consumed/` folder is optional and holds only non-authoritative notes. Any schema body found there is an error.
- An exposed operation is declared exactly once: standalone `event`/`command`/`query` contract **or** part of an `api` contract, never both.
- Responsibilities and boundaries are prose in the `context.md` body, not YAML — no lint can verify a responsibility string, so machine-readability buys nothing there.
- `context-map.yaml` is optional (Tier 3). There is no closed intent vocabulary. Never require it or block on its absence.
- Generated files (`index.md` listings, `registry.yaml`) are never hand-edited.
- Do not version internal signals or internal docs. Only contractual definitions (depended on across a boundary) get versions.

## Available Scripts

- `scripts/validate_bundle.py`: validates an OKF knowledge bundle (`docs/` root) or a single context directory. Run `python3 scripts/validate_bundle.py <path>`; add `--repo-root <path>` to also check that entrypoints resolve, `--format json` for parseable output. Exit codes: 0 clean, 1 errors found, 2 usage error.

## Workflows

### Create (greenfield project or new context)

1. Read `references/adoption-migration.md` (Tier 0 section) and `references/context-file.md`.
2. Scaffold `docs/index.md` (with `okf_version: "0.1"`), `docs/OWNERS`, and `docs/contexts/<id>/`.
3. Create `context.md` from `assets/context.template.md`; fill frontmatter facts and prose body.
4. Add contracts, workflows, runbooks, playbooks, ADRs only when they have a real consumer — use `assets/contract.template.md`, `assets/concept.template.md`, `assets/adr.template.md`.
5. Run `python3 scripts/validate_bundle.py docs/`.

### Migrate (existing docs)

1. Read `references/adoption-migration.md` (migration section).
2. Inventory existing docs; assign each an OKF `type` (or `duplicate` / `obsolete` / `unknown` / `conflict`) before moving anything.
3. Migrate one context at a time to Tier 0; extract contracts at Tier 1. Classify doc↔code conflicts with the conflict taxonomy; never resolve by recency.
4. Run the validator after each context.

### Review (audit a bundle)

1. Read `references/validation-checklists.md`.
2. Run `python3 scripts/validate_bundle.py <path> --format json`; report errors before warnings.
3. Check contract governance (`references/contract-governance.md`) for any published/consumed/deprecated contract change; check ADR requirements (`references/adr-policy.md`) for boundary/ownership/dependency changes.
4. Distinguish enforced-rule violations (blocking) from advisory findings (recommendations).

## Evaluation

Use `evals/evals.json` for eval-driven iteration and `evals/trigger_*_queries.json` to test description activation. Run each output-quality test with the skill and against a baseline, grade assertions with concrete evidence, and update the skill only when failures generalize beyond one test case.
