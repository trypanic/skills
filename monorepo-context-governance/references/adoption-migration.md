# Adoption and Migration

## Reading Map

TL;DR: Adoption is incremental via tiers 0–3, per context. Greenfield projects scaffold Tier 0 in minutes. Existing docs migrate by assigning each document an OKF `type` — one context at a time, never all at once. Mixed maturity is a valid repo state.

Read:

- "Adoption tiers" to pick the right scope.
- "Greenfield path" for a new project or new context.
- "Migration path" for existing ad hoc docs.
- "Conflict taxonomy" when docs and code disagree.

## Adoption Tiers

Each context climbs independently.

| Tier | Adds | Gate to next tier |
| --- | --- | --- |
| 0 | `context.md` with valid frontmatter + generated `index.md`. Legacy docs stay where they are, linked from the body. | Contracts identified. |
| 1 | Published schemas extracted to `contracts/published/`; consumed declarations added; schema-format ADR exists. | CI capacity. |
| 2 | Enforced rules E1–E10 active for this context. | Agent workflow demand. |
| 3 | `context-map.yaml` + agent routing instructions. | — |

Tiers are valuable standalone: Tier 0 alone pays for itself in navigation. Never demand full migration or Tier 2 tooling before a context can exist.

## Greenfield Path (new project or new context)

1. If no bundle exists: create `docs/index.md` (frontmatter `okf_version: "0.1"` only), `docs/OWNERS` (one team id per line), `docs/log.md`.
2. Decide the context boundaries. For a small project, one context covering the whole system is fine; split later when a real ownership or language boundary appears (splitting requires an ADR once contexts are governed).
3. For each context: create `docs/contexts/<id>/context.md` from `assets/context.template.md`. Fill frontmatter facts (id = directory name, owner, status, entrypoints) and the prose body (owns / does not own / start here).
4. Add contracts only when another party actually depends on something (Tier 1). Add workflows/runbooks/playbooks/ADRs only when they have a real consumer.
5. Record the first decisions as ADRs (`assets/adr.template.md`) — at minimum the schema-format ADR when the first contract appears.
6. Run `python3 scripts/validate_bundle.py docs/`.

## Migration Path (existing docs)

Migration is normalization, not copying. Never move a document without classifying it.

Per document (or per section of a mixed document), assign one classification:

```text
An OKF type:  BoundedContext fact | Contract | Workflow | Runbook | Playbook | ADR | SignalCatalog | Reference
Or a disposition: duplicate | obsolete | unknown | conflict
```

Then act:

| Classification | Action |
| --- | --- |
| Ownership, responsibility, boundary, dependency, entrypoint fact | Into `context.md` (frontmatter if lintable, body prose otherwise). |
| Stable cross-context shape or semantics | `contracts/published/<name>/` with `contract.md` + schema; declare in frontmatter. |
| Reference to a contract owned elsewhere | `contracts.consumed` declaration (id + version); notes optionally in `contracts/consumed/`. |
| Behavior description | `workflows/` with `type: Workflow`. |
| Diagnosis/mitigation | `runbooks/` with `type: Runbook`. |
| Deliberate repeated change procedure | `playbooks/` with `type: Playbook`. |
| Decision rationale | `decisions/ADR-*.md`; accepted ADRs immutable from then on. |
| Signal meanings | `observability.md`; contractual signals also into frontmatter `signals`. |
| Supporting material | `references/` with `type: Reference`, linked from a canonical doc. |
| duplicate | Delete; replace with a link to the authoritative source. |
| obsolete | Delete, or archive outside `docs/`. |
| unknown | List in the `## Open questions` section of `context.md`; resolve before treating as source of truth. |
| conflict | Classify with the conflict taxonomy below before changing either side. |

Sequencing:

1. Inventory the existing docs tree; map documents to candidate contexts. If the tree is organized type-first (`decisions/<ctx>`, `domain/<ctx>`), the migration is a transpose to context-first.
2. Migrate one context to Tier 0: write `context.md`, link legacy docs from its body. The repo is valid in this mixed state.
3. Assign `type` frontmatter to that context's docs as they move; rewrite relative links to bundle-absolute.
4. Extract contracts (Tier 1): schemas to `contracts/published/`, initial version baseline (e.g. `1.0.0`) via one ADR, consumed declarations by id.
5. Preserve history: move files with `git mv`.
6. Validate after each context; repeat for the next context.

## Conflict Taxonomy

When existing docs conflict with code or each other, never resolve by preference or recency. Classify first:

```text
1. Code is correct, docs are stale.
2. Docs are correct, code is wrong.
3. Both are partially correct.
4. The source of truth is missing.
5. The boundary is unclear.
6. The contract is insufficient.
7. The behavior changed without a decision.
8. The conflict requires an owner decision.
```

Each conflict produces exactly one output: frontmatter update, contract update, workflow update, ADR, open question, code issue, or deletion of obsolete material.

## Migration Output (per context)

- one `context.md` with valid frontmatter;
- published contracts in canonical folders, declared in frontmatter;
- consumed contracts declared by id + version;
- workflows separated from runbooks and playbooks;
- decisions extracted into ADRs;
- duplicates removed, obsolete material deleted or archived;
- unknowns in `## Open questions`;
- generated `index.md` passing without manual edits;
- validator clean at the context's declared tier.
