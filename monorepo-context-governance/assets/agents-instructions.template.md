<!--
Paste this block into the repo's AGENTS.md / CLAUDE.md (or equivalent agent
instruction file). It wires agents to the knowledge bundle without any custom
tooling. Adjust the docs/ path if the bundle lives elsewhere.
-->

## Knowledge bundle

Project knowledge lives in `docs/` as an OKF bundle: every document carries YAML
frontmatter with a `type`; each bounded context is a package under
`docs/contexts/<id>/` rooted in a `context.md`.

Before working on any task that touches a context:

1. **Resolve the context** via `docs/registry.yaml` or `docs/index.md` (by id,
   alias, service, module, or code path).
2. **Read its `context.md`.** Frontmatter (owner, status, contracts,
   dependencies, entrypoints) is authoritative fact. The body is the guide.
3. **Descend via links and `index.md` listings** — load task-relevant documents
   only, never the whole tree.
4. **Classify the task before editing:**
   - `implementation_defect` — code violates a contract/workflow/fact/ADR →
     fix code and tests; touch knowledge only if stale or incomplete.
   - `knowledge_defect` — source of truth missing/stale/ambiguous → fix the
     knowledge artifact first or in the same change set.
   - `contract_or_boundary_change` — follow versioning, impact, and ADR rules
     before changing implementation.
   - `ambiguous_case` — surface the conflicting artifacts; never resolve
     silently.
5. **Update knowledge in the same change set** when a code change affects
   declared facts (contracts, dependencies, entrypoints, contractual signals,
   ownership, status) — or add the PR trailer `Knowledge-Impact: none`.

Guardrails:

- Never redefine a consumed contract; consume by id + version only.
- Never modify a published contract without a version bump; the schema file is
  the source of truth.
- Never read another context's internals as source of truth; depend only on
  published contracts.
- Never edit an accepted ADR; supersede it.
- Never hand-edit generated files (`index.md` listings, `docs/registry.yaml`).
- Tolerate missing optional fields, unknown types, and broken links when
  reading; report them instead of failing.
