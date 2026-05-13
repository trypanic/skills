# Domain MAP

Topology of areas and their dependencies. Read this before opening
any area folder.

## Areas

| Area | Folder | Status | One-line description |
|------|--------|--------|----------------------|
| `go-code-quality-check` | [`go-code-quality-check/`](go-code-quality-check/) | drafting | Static-analysis + security gates for Go projects (`go vet` + `staticcheck` + `semgrep`). |
| `go-modularization` | [`go-modularization/`](go-modularization/) | drafting | Folder/package layout rules for Go monorepos and single-service repos. |
| `go-design-principles` | [`go-design-principles/`](go-design-principles/) | drafting | Project-agnostic Go design judgement (KISS, DRY, SRP, calisthenics, type-driven). |
| `go-sdk-bootstrap` | [`go-sdk-bootstrap/`](go-sdk-bootstrap/) | drafting | Scaffolding for Go services importing `github.com/trypanic/go-sdk`. |
| `traceflow` | [`traceflow/`](traceflow/) | drafting | Lifecycle-driven documentation skill (this skill, dogfooded). |

## Dependencies

```yaml
dependencies: []
```

No cross-area runtime/contract/data/policy edges declared. Each skill is
self-contained. If a future ADR formalizes that `go-sdk-bootstrap` depends
on `go-modularization` rules (or similar), register the edge here with
the ratifying ADR.

## Promotion criteria

A new area gets its own subfolder when at least one is true:

- More than one rules-equivalent file is needed (rules diverge in topic).
- Three or more strongly related entities exist that no other area touches.
- A separate state-machine surface exists (different lifecycles).
- A distinct anti-pattern or constraint set applies.

Promotion is registered HERE in MAP.md and accompanied by an ADR
of type `structure` in `decisions/_shared/`.

## Notes

- Per-skill area chosen at init (2026-05-13). Each existing skill is its own area.
- Skeleton-only init: domain folders empty; first domain content arrives via `/traceflow:domain` after a brainstorm or directly from a spec.
