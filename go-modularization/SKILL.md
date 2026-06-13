---
name: go-modularization
description: Use when placing, naming, moving, or promoting code in a Go monorepo or single-service repo, or reviewing folder layout — even when the user doesn't say "architecture". Decides which folder a new file, adapter, migration, handler, repository, or shared package belongs in, and whether to promote a file suffix to a subfolder. Covers flat hexagonal layers (api/consumer/cli → interactor → domain/ports ← data_repositories/storage/external_services/producer), the go-pkgs (never pkg/) convention, internal/contracts and internal/kernel, migration filenames with a closed verb set, and a forbidden folder-name list. Triggers on "new Go service", "where does this file go", "promote to subfolder", "add adapter", "set up migrations", "is this folder name allowed", or any new folder under services/<service>/, file under go-pkgs/ or internal/, or new migration. Not for non-Go projects or lint/observability config.
---

# go-modularization

Opinionated folder/package layout for Go projects. Monorepos (primary), single-service repos (secondary). Consult before placing new code, modularizing a feature, or doing folder-shape refactors.

Out of scope: observability conventions (logging, metrics, tracing), Go file-splitting style, formatting, lint, test framework, build tooling.

---

## How to use this skill

This file holds the routing flowcharts and the invariants that apply to **every** invocation (dependency rules, forbidden names, thresholds, Step 0). Task detail lives in `references/`. **Read the matching file BEFORE acting — the summaries in this file are for routing, not for executing:**

| Your task                                                    | Read first                                                       |
| ------------------------------------------------------------ | ---------------------------------------------------------------- | -------------------------------------------------------- |
| Scaffold a service or repo; place config or scripts          | [`references/scaffolding.md`](references/scaffolding.md)         |
| Place, name, or promote source files; add/extend an adapter  | [`references/placement-rules.md`](references/placement-rules.md) |
| Create or rename a migration                                 | [`references/migrations.md`](references/migrations.md)           |
| Add shared code (`go-pkgs/`, `internal/kernel                | contracts/`, SDK repos)                                          | [`references/shared-code.md`](references/shared-code.md) |
| Need a worked example, full service tree, or counter-example | [`references/layout-examples.md`](references/layout-examples.md) |
| Verify after scaffolding or restructuring                    | run [`scripts/arch-checks.sh`](scripts/arch-checks.sh)           |
| Explain why a rule exists                                    | [`references/adr-cheatsheet.md`](references/adr-cheatsheet.md)   |

Exception — no extra read needed when the flowchart below already gives the full canonical path for a single new file and no promotion threshold is near. For anything touching 2+ files, a rename, a promotion, or a new folder: read the task file first.

If a rule in this file and a reference file disagree, this file wins; report the mismatch.

---

## Step 0 — Hard rule: ask when unclear

Before placing or moving code, check this skill against the case at hand. If **any** of the following is true, stop and start a discussion with the user:

- No rule in this skill cleanly covers the situation.
- Two or more rules could plausibly apply and the choice changes the layout.
- A promotion threshold count is in the borderline band (within 2 below the threshold — see Counting rule below).
- The user proposes a forbidden folder name and the canonical alternative is not obvious in context.
- A new kind of inbound or outbound adapter is being introduced.
- Cross-cutting code candidate: unclear whether it belongs in `go-pkgs/`, `go-pkgs/infra/`, `internal/kernel/`, service-scoped `services/<service>/internal/contracts/`, root `internal/contracts/`, or a shared SDK repo.

Present 2–3 concrete options with trade-offs. Do **not** silently pick one. Once aligned, proceed.

**Non-interactive runs** (CI, headless, no user to ask): do not block and do not silently improvise. Take the most conservative option — no new folders, no renames, no moves — proceed with it, and list every deferred decision in the final report under a "Deferred (Step 0)" heading.

---

## When to use

Trigger phrases:

- "new Go service" / "scaffold service folders"
- "where does this file go" / "which folder for X"
- "promote to subfolder" / "split this package"
- "add an adapter" / "new inbound/outbound adapter"
- "set up migrations folder" / "name this migration"
- "review folder layout" / "is folder X allowed"
- "refactor this into …" / "move code from … to …"

Auto-trigger on:

- New top-level folder under `services/<service>/`.
- New file under `go-pkgs/`, `internal/contracts/`, `internal/kernel/`.
- New migration file under `migrations/`.
- Refactor that moves code across packages or layers.
- PR diff that adds, renames, or moves a folder.

Skip for:

- Non-Go projects.
- Library/framework repos (no service binary) — out of scope.
- Runtime config: logging, metrics, tracing, lint, formatters, test frameworks (out of scope).

Placeholders: `<placeholder>` = slot to fill, e.g. `<service>` = `orders`, `<context>` = `order`, `<provider>` = `s3`, `<subject>_<verb>` = `order_created`. Full slot table: [`references/layout-examples.md`](references/layout-examples.md).

---

## Invariant — layers and dependency direction

Applies to every invocation; never lazy-load this.

Inner layers (abstract, no IO): `domain/` (entities, value objects, invariants), `interactor/` (use cases), `ports/` (interfaces consumed by interactor, implemented by adapters).
Outer layers (concrete, IO): inbound `api/`, `consumer/`, `cli/`; outbound `data_repositories/`, `external_services/`, `producer/`, `storage/`.

```
cmd                  → all (wiring only)
<inbound_adapter>    → interactor
interactor           → domain, ports
<outbound_adapter>   → ports, domain
```

**Forbidden imports:**

- `domain` / `ports` / `interactor` importing any adapter.
- `services/<A>/internal` importing `services/<B>/internal`.
- `internal/kernel/` importing `internal/contracts/`, or `internal/contracts/` importing `internal/kernel/` — wire payloads use primitive/stdlib types only.
- `go-pkgs/` importing `internal/` or `services/`.
- Adapter A importing adapter B directly — go through `interactor/` or shared `ports/`.
- Anything importing `cmd/`.

**Module topology** (two co-equal shapes, pick by scale — folder/layer/dep rules identical in both): **A — single-module:** one `go.mod` at repo root. **B — multi-module workspace:** root `go.work` (no root `go.mod`) + one `go.mod` per `go-pkgs/`, `internal/`, and each `services/<service>/`; services `require` the shared modules via the workspace. Multi-module **requires** a root `go.work`; per-service `go.mod` without one (orphan modules) is forbidden.

---

## Invariant — promotion thresholds and counting rule

**Counting rule:** count non-test, non-generated `.go` files — exclude `_test.go`, `*.pb.go`, `*_gen.go`, and other generated output. At/above threshold → promote. Within 2 below → borderline band → Step 0. Below the band → stay flat.

| What                       | Threshold                                                             | Promote to (suffix dropped)     |
| -------------------------- | --------------------------------------------------------------------- | ------------------------------- |
| Bounded context in a layer | ≥10 files                                                             | `<layer>/<context>/`            |
| API version                | ≥5 files                                                              | `api/v<N>/`                     |
| Middleware for one adapter | ≥4 files                                                              | `<inbound_adapter>/middleware/` |
| External provider          | ≥10 files, or ≥3 provider-specific infra files, or distinct lifecycle | `external_services/<provider>/` |

Promotion updates all import sites in the same change; mechanics, breaking-change escalation, and per-service maturity rules: read [`references/placement-rules.md`](references/placement-rules.md) before promoting.

---

## Gotchas

Concrete corrections to defaults that are wrong here. Read before acting — each defies a reasonable Go assumption:

- Shared utilities go in `go-pkgs/`, **never `pkg/`**. The idiomatic-Go `pkg/` is forbidden here.
- A monorepo picks **one of two module topologies**: single root `go.mod` (simple), **or** a root `go.work` with one `go.mod` per module (`go-pkgs/`, `internal/`, each service) for scaled repos. Per-service `go.mod` is fine **with** a `go.work`; without one it's an orphan module that breaks `internal/` sharing. The "one root `go.mod`" assumption is wrong for workspace repos.
- One `cmd/main.go` per service. **No `cmd/server/`, `cmd/worker/`** — every subcommand lives in `cli/` as a subcommand, `cmd/` only wires.
- Scheduled jobs and background work do **not** get a `workers/` folder: events/polling → `consumer/`, scheduled → `cli/` subcommand.
- `data_repositories/` vs `storage/` splits **by data shape, not by SQL/NoSQL**. Redis can land in either; a Mongo blob store is `storage/`.
- Migration verbs are a **closed set** (`create add drop alter rename backfill fix refactor seed`). `update`, `misc`, `change` are rejected — pick the closest allowed verb.
- `domain/` files use the **bare context name** (`order.go`), no `domain_` prefix — unlike every other layer, which prefixes (`interactor_`, `repository_`).
- Promoting a suffix to a subfolder **drops the suffix** (`interactor_order.go` → `order/interactor.go`), and you must update every import site in the same change.
- Thresholds are not "promote ASAP": below the band, **stay flat**; in the borderline band, **Step 0**. Promotion is a one-way ratchet.

## Decision flowcharts

### Where does a new file go?

1. Is it a CLI subcommand? → `cli/<action>_command.go`.
2. Is it an HTTP handler? → `api/<resource>_handler_v<N>.go`. (`api/` is HTTP only; gRPC/GraphQL/WebSocket = new adapter kind → Step 0.)
3. Is it an event/poll handler? → `consumer/<subject>_<verb>_consumer.go`.
4. Is it a use case? → `interactor/interactor_<context>.go`.
5. Is it an entity, value object, or business invariant? → `domain/<context>.go` (bare context name, no `domain_` prefix).
6. Is it a repository (schema-shaped: query language, typed fields, indexes)? → `data_repositories/repository_<context>.go`.
7. Is it blob storage (opaque bytes by key/path)? → `storage/storage_<context>.go`.
8. Is it a third-party API call? → `external_services/<subject>_<action>_<provider>.go`.
9. Is it an outbound event? → `producer/<subject>_<verb>_producer.go`.
10. Is it a port interface? → `ports/<context>_port.go`.
11. Is it middleware? → `<inbound_adapter>/middleware_<concern>.go`.

If none clearly apply → Step 0. Naming detail, context identification, edge cases (Redis split, background work routing, tests/mocks): [`references/placement-rules.md`](references/placement-rules.md).

### Shared code: which destination?

- Pure stdlib helper, no business meaning → `go-pkgs/<domain>x/` or `go-pkgs/<domain>kit/`.
- Reusable infra → `go-pkgs/infra/<pkg>/` (default; SDK repos are opt-in tiers).
- Business primitive, 2+ services, stable → `internal/kernel/`.
- Wire payload shared by 2+ services → root `internal/contracts/`.
- Contract shared across components of one service → `services/<service>/internal/contracts/` (single-service: `internal/contracts/`); private to that service.
- DTO used by one adapter only → keep local to that adapter package.

Contract scope is a ladder (adapter-local → service-scoped → root); promote only when a real consumer crosses the next boundary. Read [`references/shared-code.md`](references/shared-code.md) before creating anything under `go-pkgs/` or root `internal/`.

### Migration filename?

Shared DB → `<seq>_<service|shared>_<verb>_<desc>`; per-service DB → `<seq>_<verb>_<desc>`. Verb closed set: `create|add|drop|alter|rename|backfill|fix|refactor|seed`. SQL → `.up.sql` + `.down.sql` pair; forward-only → single native ext.

Read [`references/migrations.md`](references/migrations.md) before creating or renaming any migration file.

---

## Invariant — forbidden folder names

Reject these names anywhere in the repo:

```
pkg, shared, common, lib, utils, application, infrastructure,
interfaces, helpers, mapper, dto, gateway, workers, misc
```

If user proposes one, push back, cite the rule, suggest the canonical alternative (`pkg` → `go-pkgs/<domain>x`, `workers` → `consumer/` + `cli/`, `utils` → domain-prefixed package under `go-pkgs/`). If none clearly fits → Step 0.

---

## Anti-patterns to refuse

When generating or reviewing layout, reject:

- Top-level `pkg/`, `shared/`, `common/`, `lib/`, `utils/`, `helpers/`, `mapper/`, `dto/`, `gateway/`, `workers/`, `application/`, `infrastructure/`, `interfaces/`, `misc/`.
- Any forbidden import from the dependency invariant above.
- Combined-context filename (`order_product.go`).
- Migration verb outside the closed set; `shared` + service combined; verb as suffix or dotted segment; migrations under `data_repositories/` or `services/<service>/`; cross-service writes in shared DB without `shared`-token justification.
- Multi-binary services (more than one `main.go` per service); `cmd/` containing logic instead of wiring.
- Per-service `go.mod` in a monorepo **without** a root `go.work` (orphan modules). With a `go.work`, multi-module is allowed (topology B).
- Top-level `config/`, `middleware/`, `events/`, `messages/`, `dto/`.
- Go files under `scripts/`.
- Forcing infra into a remote SDK repo when `go-pkgs/infra/` is the better default.

Cite the rule when refusing. Offer the canonical alternative. If none fits cleanly → Step 0.

---

## Verify

After scaffolding or restructuring, run [`scripts/arch-checks.sh`](scripts/arch-checks.sh) from the repo root (`bash scripts/arch-checks.sh`; add `--json` for machine-readable output, `--help` for usage). It checks: forbidden folder names (vendor/.git pruned), `go build` + `go vet`, the eight import invariants via `go list`, module topology (single root `go.mod`, or a `go.work` with every `go.mod` dir listed under `use`; orphan multi-module flagged), one `cmd/main.go` per service, no Go under `scripts/`, migration filename grammar + up/down pairing, and promotion-threshold counts. Structured report on stdout, diagnostics on stderr; exit 0 = clean, 1 = violations, 2 = bad usage, 3 = missing prerequisite. If the script is unavailable, the per-check commands are inside it — run them manually.

Then report using this template (omit empty sections):

```
## go-modularization result
- Created/renamed: <folder or file paths>
- Placed: <file → path, one per line>
- Violations: <path: rule cited → canonical fix>   (none if clean)
- Promotion reached: <layer/context: count ≥ threshold>
- Deferred (Step 0): <decision + the 2–3 options>   (required heading in non-interactive runs)
```

---

## Inputs

Optional argument:

- **No argument** — interactive: ask repo shape (mono/single), service name, then scaffold. Read [`references/scaffolding.md`](references/scaffolding.md) first.
- **`monorepo <service>`** / **`single <module>`** — scaffold (need-based: only `cmd/`, `domain/`, `interactor/`, `ports/`, `config/` + named adapters — never empty folders). Read [`references/scaffolding.md`](references/scaffolding.md) first.
- **`review`** — first detect adoption: adopted iff service `internal/` contains ≥2 of `domain/`, `interactor/`, `ports/` (or single-service equivalent). Not adopted → report "convention not adopted", ask whether to adopt; do **not** flag individual violations or restructure. Adopted → audit and emit the report template from the Verify section (Violations + Promotion reached sections).
- **`place <description>`** — return the canonical path via the flowchart; read [`references/placement-rules.md`](references/placement-rules.md) when the flowchart line alone doesn't settle it. Unclear → Step 0.
- **`migration <topology> <verb> <desc>`** — generate a migration filename; `<topology>` ∈ {`shared`, `per-service`}. Read [`references/migrations.md`](references/migrations.md) first.

---

## Boundaries

- Do not invent new folder names. If something doesn't fit any rule, escalate via Step 0.
- Do not enforce observability, lint, formatter, or test framework — out of scope.
- When promotion threshold is borderline, prefer not promoting; promotion is a one-way ratchet that adds folders.
- Do not force the use of any specific external SDK repo. `go-pkgs/infra/` is the default; remote SDK repos are opt-in.
- Violations noticed during an unrelated task: report them; do not fix them in the same change unless asked.
