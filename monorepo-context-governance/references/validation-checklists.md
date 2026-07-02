# Validation Checklists

Run `python3 scripts/validate_bundle.py <path>` first; it covers the statically checkable subset. These checklists cover what the script cannot see. Report errors before warnings; distinguish enforced-rule violations (blocking) from advisory findings (recommendations). Check only up to the context's declared tier — do not fail a Tier 0 context on Tier 2 expectations.

## Tier 0 — Context Integrity

- [ ] Every context directory has a `context.md` with `type: BoundedContext`.
- [ ] `id` matches the directory name and is stable.
- [ ] `owner.team` resolves in `docs/OWNERS`.
- [ ] `status` is one of proposed/active/deprecated/retired.
- [ ] Body has real prose for "owns" / "does not own" (not YAML restated).
- [ ] Bundle root `docs/index.md` declares `okf_version`.
- [ ] Every non-reserved `.md` has frontmatter with a non-empty `type`.
- [ ] No v1 artifacts (`manifest.yaml`, `guide.md`, context `README.md`).

## Tier 1 — Contract Integrity

- [ ] Every published contract: declared in frontmatter, has `contract.md` + schema file, has kind/version/stability.
- [ ] Contract ids are globally unique; no operation declared both standalone and inside an `api`.
- [ ] Every consumed contract is id + version only — no `ref` paths, no schema bodies anywhere under `contracts/consumed/`.
- [ ] Every consumed id resolves to a publisher in the bundle.
- [ ] Deprecated contracts declare `replacement` and a retirement target.
- [ ] Breaking changes include a generated `affected_consumers` impact declaration and an ADR.
- [ ] Schema-format ADR exists.
- [ ] Domain models, ports, and adapters are not exposed as contracts.

## Tier 2 — Enforcement

- [ ] E1–E10 wired in CI for this context (or explicitly listed as pending).
- [ ] `registry.yaml` and `index.md` files are generated and CI-diffed, never hand-edited.
- [ ] Accepted ADRs immutable in CI (E8).
- [ ] E10 anti-drift gate active: code changes under `entrypoints.source` require a docs diff or a `Knowledge-Impact: none` trailer.
- [ ] `entrypoints.source` / `entrypoints.tests` resolve (`--repo-root`).

## Tier 3 — Agent Readiness

- [ ] `AGENTS.md` / `CLAUDE.md` contains the resolution + classification procedure (see `assets/agents-instructions.template.md`).
- [ ] `context-map.yaml` (if present): free-string task patterns, read allowlists, symptom → runbook routes, guardrails. No closed intent vocabulary, no do-not-read lists.
- [ ] Contract-changing tasks route to versioning rules; incident tasks route to runbooks and observability.

## Documentation Quality (advisory)

- [ ] One primary purpose per document; diagnosis in runbooks, deliberate change in playbooks, rationale in ADRs.
- [ ] Long documents (>~300 lines) start with a reading map.
- [ ] Workflows reference contracts; they never inline schema bodies.
- [ ] References are linked from canonical docs, not free-floating.
- [ ] No source-of-truth fact appears authoritatively in two places.
- [ ] `log.md` entries exist for meaningful knowledge changes.

## Migration Quality

- [ ] Every migrated document was classified (type or disposition) before moving.
- [ ] Duplicates replaced with links; obsolete material deleted or archived outside `docs/`.
- [ ] Unknowns captured in `## Open questions`.
- [ ] Conflicts classified with the taxonomy (never resolved by recency).
- [ ] Old structure not copied mechanically into new folders.
- [ ] Files moved with `git mv` (history preserved).
