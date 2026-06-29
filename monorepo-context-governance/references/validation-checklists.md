# Validation Checklists

## Reading Map

TL;DR: Review package integrity, contract integrity, documentation purpose, agent readiness, code synchronization, and migration quality. Treat errors before warnings.

Read:

- "Governance rules" when reviewing enforceability.
- "Evaluation checklist" before finalizing a package or migration.
- "Validator" when checking files on disk.

## Governance Rules

Each governance rule needs a check. If no automated check exists, mark it advisory until lint, CI, CODEOWNERS, or review enforcement exists.

| Rule | Check |
| --- | --- |
| Every context has a manifest. | Lint. |
| Every manifest owner resolves in `docs/OWNERS`. | Lint. |
| Context identity is immutable unless ADR plus migration plan exist. | Field-change lint. |
| No cross-context dependency except via contracts. | Dependency graph lint. |
| No cross-context links to internals as authoritative references. | Link-graph lint. |
| Consumed contracts are references only. | Schema-body detector. |
| Published contract shape changes require SemVer bump. | Schema diff plus version check. |
| Breaking contract changes require impact declaration. | Contract CI. |
| Deprecated contracts require replacement and retirement target. | Manifest/schema lint. |
| Boundary, ownership, or dependency changes require ADR. | Changed-path rule. |
| Accepted ADRs are immutable. | ADR state lint. |
| `entrypoints.source` resolves. | Path lint. |
| Every document is reachable from `guide.md` or `context-map.yaml`. | Reachability lint. |
| References are not orphaned. | Link lint. |
| Generated indexes are not manually edited. | CI generation diff. |
| Shared kernel additions require ADR and multi-owner approval. | CODEOWNERS plus ADR check. |
| Contractual observability signals require owner/version/stability. | Signal lint. |
| Non-contractual signals are not treated as stable dependencies. | Review rule or lint. |
| Code changes affecting declared knowledge update source of truth or declare no impact. | PR checklist, agent rule, or CI policy. |
| Existing docs migration classifies source material before moving. | Migration checklist. |

## Evaluation Checklist

### Context Integrity

- [ ] Every context has a `manifest.yaml`.
- [ ] Every context has a stable `identity.name`.
- [ ] Every owner resolves in `docs/OWNERS`.
- [ ] Every context has clear responsibilities.
- [ ] Every context has explicit non-responsibilities for common ambiguity areas.
- [ ] Every dependency is declared.
- [ ] Every dependency is via contract.
- [ ] No context depends on another context's internals.

### Contract Integrity

- [ ] Every published contract has an owner.
- [ ] Every published contract has a version.
- [ ] Every published contract has a schema.
- [ ] Every consumed contract is a reference.
- [ ] No consumed contract duplicates a schema body.
- [ ] Breaking changes include impact.
- [ ] Deprecated contracts include replacement and retirement target.
- [ ] Affected consumers can be derived from manifests.

### Documentation Integrity

- [ ] Every document has one primary purpose.
- [ ] Every document is reachable from `guide.md` or `context-map.yaml`.
- [ ] No reference is orphaned.
- [ ] No generated index is manually edited.
- [ ] No source-of-truth fact appears authoritatively in two places.
- [ ] Long documents include a reading map.
- [ ] Workflows do not inline schemas.
- [ ] Runbooks are not mixed with playbooks.
- [ ] ADRs explain decisions, not current state.

### Agent Readiness

- [ ] Every mature context has a usable `context-map.yaml`.
- [ ] Intents use the closed vocabulary.
- [ ] Symptoms are context-specific.
- [ ] Guardrails are explicit.
- [ ] Fix/change/refactor flows define minimum read sets.
- [ ] Contract-changing tasks route to versioning rules.
- [ ] Incident tasks route to runbooks and observability.
- [ ] Agent execution rules exist in `AGENTS.md`, `CLAUDE.md`, or equivalent.

### Code Synchronization

- [ ] Code entrypoints resolve.
- [ ] Test entrypoints resolve.
- [ ] PR process asks whether declared knowledge is affected.
- [ ] Contract changes update schemas.
- [ ] Workflow changes update workflow docs.
- [ ] Ownership, boundary, and dependency changes update manifest and ADR if needed.
- [ ] Ambiguities are surfaced instead of silently resolved.

### Migration Quality

- [ ] Existing docs were classified before moving.
- [ ] Duplicates were removed.
- [ ] Obsolete docs were deleted or archived.
- [ ] Unknowns were captured in `open-questions.md`.
- [ ] Conflicts were classified.
- [ ] Migration did not copy old structure into new folders without normalization.

## Cross-Context Reading Rule

There are two kinds of cross-context reading:

```text
Normative reading:
Using another context's knowledge as source of truth or dependency.

Investigative reading:
Temporarily inspecting another context to understand a problem.
```

Rules:

- Forbid normative reading of another context's internals.
- Base dependencies only on published contracts or integration docs.
- Allow investigative reading when useful, but do not let it create an architectural dependency.
- If a consumer needs stable knowledge from another context, require the provider to publish a contract or integration document.

## Validator

Run:

```bash
python3 scripts/validate_context_package.py docs/contexts/<context-id>
```

Use structured output for automation:

```bash
python3 scripts/validate_context_package.py --format json docs/contexts/<context-id>
```

The validator catches structural errors and common warnings. It is intentionally lightweight and dependency-free; use it as a first pass, then apply the checklists above for governance judgment.
