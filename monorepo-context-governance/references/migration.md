# Migration

## Reading Map

TL;DR: Do not copy old `docs/*` mechanically. Classify each document or section by fact type, resolve conflicts, then move only normalized knowledge into the governed model.

Read:

- "Classification vocabulary" before reviewing old docs.
- "Migration rules" while assigning target artifacts.
- "Conflict classification" when sources disagree.
- "Migration output" before final review.

## Migration Principle

Every existing document or section must be classified by fact type before it is moved.

Use `assets/migration-classification.template.md` as the worksheet.

## Classification Vocabulary

Allowed classifications:

```text
identity
responsibility
non_responsibility
boundary
dependency
published_contract
consumed_contract
workflow
runbook
playbook
ADR
contractual_signal
non_contractual_signal
reference
duplicate
obsolete
unknown
conflict
```

## Migration Rules

1. If a section declares ownership, migrate it to `manifest.identity.owner`.
2. If a section declares responsibility, migrate it to `manifest.responsibilities`.
3. If a section declares non-responsibility, migrate it to `manifest.non_responsibilities`.
4. If a section declares a boundary, migrate it to `manifest.boundaries`.
5. If a section declares dependency, migrate it to `manifest.boundaries.dependencies`.
6. If a section defines stable cross-context shape or semantics, migrate it to `contracts/published`.
7. If a section references an external owned contract, migrate it to `manifest.contracts.consumed` or `contracts/consumed` as a reference.
8. If a section describes behavior, migrate it to `workflows/`.
9. If a section describes diagnosis or mitigation, migrate it to `runbooks/`.
10. If a section describes a deliberate repeated change, migrate it to `playbooks/`.
11. If a section explains why a decision was made, migrate it to an ADR.
12. If a section is unresolved, migrate it to `open-questions.md`.
13. If a section is only supporting material, migrate it to `references/` and link it from a canonical artifact.
14. If a section duplicates an authoritative fact, delete it and replace it with a reference.
15. If a section is obsolete, delete it or archive it outside the canonical tree.
16. If a section is ambiguous, mark it as `unknown` and resolve it before treating it as source of truth.
17. If a section contradicts code or another document, classify the conflict before changing either side.

## Conflict Classification

When existing docs conflict with code or each other, do not resolve by recency alone.

Classify the conflict:

```text
1. Code is correct, docs are stale.
2. Docs are correct, code is wrong.
3. Both are partially correct.
4. The source of truth is missing.
5. The boundary is unclear.
6. The contract is insufficient.
7. The behavior changed without a decision.
8. The conflict requires owner decision.
```

Each conflict must produce one of:

- manifest update;
- contract update;
- workflow update;
- ADR;
- open question;
- code issue;
- deletion of obsolete material.

## Migration Workflow

1. Inventory current docs and group by likely context.
2. Split long pages into sections before classification.
3. Classify each section with the allowed vocabulary.
4. Identify duplicates, obsolete material, unknowns, and conflicts before moving files.
5. Create or update context `manifest.yaml`.
6. Move owned contracts into `contracts/published/**`.
7. Convert consumed contracts into references.
8. Split behavior, failure response, deliberate change procedures, and decisions into workflows, runbooks, playbooks, and ADRs.
9. Create `guide.md` as the human route through the new package.
10. Create `context-map.yaml` for agent-relevant tasks.
11. Delete or archive obsolete material outside the canonical tree.
12. Validate the result and record unresolved decisions in `open-questions.md`.

## Migration Output

A complete migration should produce:

- one manifest per context;
- one guide per context;
- published contracts moved to canonical folders;
- consumed contracts declared as references;
- workflows separated from runbooks and playbooks;
- decisions extracted into ADRs;
- duplicated facts removed;
- obsolete docs deleted or archived;
- unknowns listed in `open-questions.md`;
- conflicts classified;
- `context-map.yaml` routes for agent-relevant tasks;
- generated index passing without manual edits.
