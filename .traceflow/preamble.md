# preamble

Reading map and hard rules. Capped at 60 lines.

## Read first (cold start)

1. `STATUS.md` — phase per area
2. This file — reading map + rules
3. `domain/MAP.md` — area topology + deps
4. `domain/glossary.md` — transversal terms

Stop. Do not pre-load any area until a task arrives.

## Task → files

Full table: `traceflow/references/tasks-to-files.md` in the skill repo.

- Fix bug in `<A>`: `specs/<A>/MAP.md` → owning spec `status.md` + `plan.md` → cited domain + ADRs.
- New ADR in `<A>`: `decisions/<A>/INDEX.md` + `decisions/_shared/INDEX.md` + relevant domain.
- New spec in `<A>`: `domain/<A>/`, `decisions/<A>/INDEX.md`, `specs/<A>/MAP.md` (conflict check), `specs/<A>/STATUS.md` (next S0NN).
- Promote idea: `ideas/<A>/<topic>/`, `domain/<A>/`, `domain/glossary.md`.

## Hard rules

1. Per-area isolation. Cross-area only via `_shared/`.
2. No duplicated rules. One file per rule.
3. ADRs append-only after acceptance. Body never edited; only Status.
4. ADR numbers globally unique across `_shared/` + per-area.
5. Domain = business knowledge only. Stack/infra → ADR.
6. Specs declare spec-deltas in `plan.md`. Empty deltas need typed `NONE`.
7. Three STATUS files stay in sync (global, area, spec).
8. Every action ends with an Update Manifest.
9. Read what the task needs. Do not pre-read other areas.
10. Idea folder existence IS state. No proposed→ready ceremony.

## Areas

- `go-code-quality-check` — static-analysis + security gates for Go.
- `go-modularization` — folder/package layout rules.
- `go-design-principles` — design judgement (KISS, DRY, SRP, calisthenics, type-driven).
- `go-sdk-bootstrap` — scaffolding for `github.com/trypanic/go-sdk` services.
- `traceflow` — this skill itself (lifecycle-driven docs).

## Commands

`/traceflow:idea`, `/traceflow:domain`, `/traceflow:adr`, `/traceflow:spec`,
`/traceflow:state set`, `/traceflow:archive`, `/traceflow:check`, `/traceflow:map`.
