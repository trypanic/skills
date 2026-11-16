---
name: go-modularization
description: Use when you place, name, move or promote code in a Go monorepo or single-service repo, or review folder layout. Use even if the user does not say "architecture". Decides the folder for a new file, adapter, migration, handler, repository or shared package, and whether to promote a file suffix to a subfolder. Covers flat hexagonal layers (api/consumer/cli → interactor → domain/ports ← data_repositories/storage/external_services/producer) and the go-pkgs (never pkg/) convention. Also covers internal/contracts and internal/kernel, migration filenames with a closed verb set, forbidden folder names and cross-service boundary rules. Triggers on "new Go service", "where does this file go", "promote to subfolder", "add adapter", "set up migrations" or "is this folder name allowed". Also triggers on "shared collection/table name", "peer service enum", "config mirror", any new folder under services/<service>/, file under go-pkgs/ or internal/, or new migration. Not for non-Go projects or lint/observability config.
---

# go-modularization

Opinionated folder/package layout for Go projects. Primary target: monorepos. Secondary target: single-service repos. Use it before you place new code, modularize a feature or refactor folder shape.

Out of scope: observability conventions (logging, metrics, tracing), Go file-splitting style, formatting, lint, test framework, build tooling.

---

## How to use this skill

This file holds the routing flowcharts and the invariants for **every** invocation (dependency rules, forbidden names, thresholds, Step 0). Task detail is in `references/`. **Read the matching file BEFORE you act. The summaries in this file are for routing, not for execution:**

| Your task | Read first |
| --- | --- |
| Scaffold a service or repo. Place config or scripts | [`references/scaffolding.md`](references/scaffolding.md) |
| Place, name or promote source files. Add or extend an adapter | [`references/placement-rules.md`](references/placement-rules.md) |
| Create or rename a migration | [`references/migrations.md`](references/migrations.md) |
| Add shared code (`go-pkgs/`, `internal/kernel` or `contracts/`, SDK repos) | [`references/shared-code.md`](references/shared-code.md) |
| Need a worked example, full service tree, or counter-example | [`references/layout-examples.md`](references/layout-examples.md) |
| Verify after you scaffold or restructure | run [`scripts/arch-checks.sh`](scripts/arch-checks.sh) |
| Explain why a rule exists | [`references/adr-cheatsheet.md`](references/adr-cheatsheet.md) |
| Service-boundary questions — peer datastores, shared values/enums/config, contract versions | [`references/service-boundaries.md`](references/service-boundaries.md) |
| Adopt the convention in an existing codebase / migrate a legacy layout | [`references/migration.md`](references/migration.md) |

Exception: a single new file needs no extra read when the flowchart below gives its full canonical path and no promotion threshold is near. For a change to 2+ files, a rename, a promotion or a new folder, read the task file first.

If a rule in this file and a reference file disagree, this file wins. Report the mismatch.

---

## Step 0 — Hard rule: ask when unclear

Before you place or move code, compare the case with this skill. If **any** of these conditions is true, stop and discuss the case with the user:

- No rule in this skill cleanly covers the case.
- Two or more rules could plausibly apply and the choice changes the layout.
- A promotion threshold count is in the borderline band (within 2 below the threshold — see Counting rule below).
- The user proposes a forbidden folder name and the canonical alternative is not obvious in context.
- The change adds a new kind of inbound or outbound adapter.
- It is not clear where a cross-cutting code candidate belongs: `go-pkgs/`, `go-pkgs/infra/`, `internal/kernel/`, service-scoped `services/<service>/internal/contracts/`, root `internal/contracts/`, or a shared SDK repo.

Present 2–3 concrete options with trade-offs. Do **not** silently pick one. When you and the user agree, continue.

**Non-interactive runs** (CI, headless, no user to ask): do not block and do not silently improvise. Instead:

1. Take the most conservative option: no new folders, no renames, no moves.
2. Continue with that option.
3. List every deferred decision in the final report under a "Deferred (Step 0)" heading.

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

Skip for (out of scope):

- Non-Go projects.
- Library/framework repos (no service binary).
- Runtime config: logging, metrics, tracing, lint, formatters, test frameworks.

Placeholders: `<placeholder>` = slot to fill, e.g. `<service>` = `orders`, `<context>` = `order`, `<provider>` = `s3`, `<subject>_<verb>` = `order_created`. Full slot table: [`references/layout-examples.md`](references/layout-examples.md).

---

## Invariant — layers and dependency direction

This applies to every invocation. Never lazy-load it.

**Inner layers** (abstract, no IO):

- `domain/`: entities, value objects, invariants, stateless domain services.
- `interactor/`: **use cases only**. These are Clean Architecture interactors: application-specific business rules, one workflow step each.
- `coordinator/`: long-running process managers. These are loops/goroutines that coordinate ports and use cases over time. See "Use cases and coordinators" in `references/placement-rules.md`.
- `ports/`: interfaces that interactor and coordinator consume and adapters implement.

**Outer layers** (concrete, IO):

- Inbound: `api/`, `consumer/`, `cli/`, and streaming servers `grpc/` | `ws/` | `sse/`.
- Outbound: `data_repositories/`, `external_services/`, `producer/`, `storage/`, and a streaming client (`grpc/client.go`).

```text
cmd                  → all (wiring only)
<inbound_adapter>    → coordinator, interactor   (api, consumer, cli, and grpc/ws/sse stream server)
coordinator          → interactor, domain, ports
interactor           → domain, ports
<outbound_adapter>   → ports, domain       (repos, external_services, producer, storage, stream client)
```

A streaming server is a driving (inbound) adapter. It MAY also implement a push/sink port that the interactor calls (a driven port on a driving adapter, e.g. a per-connection task sink). This is expected for streaming, not a layering violation: the dependency is still `grpc → ports`, never `interactor → grpc`.

**Forbidden imports:**

- `domain` / `ports` / `interactor` / `coordinator` importing any adapter.
- `domain` / `ports` / `interactor` / `coordinator` importing a **generated wire contract** — a versioned `internal/contracts/**/v<N>` package or any `*.pb.go` package. Generated contracts are adapter-only. Map wire↔domain at the adapter edge.
- `interactor` (or `domain`/`ports`) importing `coordinator` — the dependency points use-case-ward, never back.
- `services/<A>/internal` importing `services/<B>/internal`.
- `internal/kernel/` importing `internal/contracts/`, or `internal/contracts/` importing `internal/kernel/` — wire payloads use primitive/stdlib types only.
- `go-pkgs/` importing `internal/` or `services/`.
- Adapter A importing adapter B directly — go through `interactor/` or shared `ports/`.
- Anything importing `cmd/`.

**Module topology:** two co-equal shapes. Pick by scale. Folder/layer/dependency rules are identical in both.

- **A — single-module:** one `go.mod` at repo root.
- **B — multi-module workspace:** root `go.work` (no root `go.mod`) + one `go.mod` per `go-pkgs/`, `internal/`, and each `services/<service>/`. Services `require` the shared modules through the workspace.

Multi-module **requires** a root `go.work`. A per-service `go.mod` without one (orphan modules) is forbidden.

## Invariant — adapters decide nothing

Adapters are technical edges. They may **observe, extract, encode, decode, transport, and persist**. They may not **decide**. If a rule answers "what is true about the business object" or "what should happen next", it is a business decision. Examples: a status derivation, price/quantity policy, credit movement, retry disposition. Such a rule belongs in `domain/` (pure rules), `interactor/` (use-case policy), or `coordinator/` (long-running coordination policy), even when its inputs come from adapter-side mechanics.

Adapters return raw signals: booleans, counts, raw strings, presence flags, wire frames, and storage rows. Inner layers interpret them. If one function interleaves mechanics and interpretation, split it at the signal. Extraction stays in the adapter. Interpretation moves inward. Sequencing that must interleave with transport I/O may stay adapter-side only when each decision point delegates to an inner-layer function.

---

## Invariant — promotion thresholds and counting rule

**Counting rule:** count non-test, non-generated `.go` files. Exclude `_test.go`, `*.pb.go`, `*_gen.go`, and other generated output. At/above threshold → promote. Within 2 below → borderline band → Step 0. Below the band → stay flat.

| What | Threshold | Promote to (suffix dropped) |
| --- | --- | --- |
| Bounded context in a layer | ≥10 files | `<layer>/<context>/` |
| API version | ≥5 files | `api/v<N>/` |
| Middleware for one adapter | ≥4 files | `<inbound_adapter>/middleware/` |
| External provider | distinct resource lifecycle (primary), or ≥10 files / ≥3 provider-specific files | `external_services/<provider>/` |
| Streaming server adapter | one file >~400 LOC, or a 2nd responsibility appears (registry/translation/reconciler) | split `grpc/` (see placement-rules) |

A promotion updates all import sites in the same change. Before you promote, read [`references/placement-rules.md`](references/placement-rules.md) for the mechanics, breaking-change escalation, and per-service maturity rules.

---

## Gotchas

Corrections to defaults that are wrong here. Each one defies a reasonable Go assumption. Read them before you act:

- Shared utilities go in `go-pkgs/`, **never `pkg/`**. The idiomatic-Go `pkg/` is forbidden here.
- A monorepo picks **one of two module topologies**: a single root `go.mod` (simple), **or** a root `go.work` with one `go.mod` per module (`go-pkgs/`, `internal/`, each service) for scaled repos. A per-service `go.mod` is fine **with** a `go.work`. Without one, it is an orphan module that breaks `internal/` sharing. The "one root `go.mod`" assumption is wrong for workspace repos.
- One `cmd/main.go` per service. **No `cmd/server/`, `cmd/worker/`**. Every subcommand lives in `cli/` as a subcommand, and `cmd/` only wires.
- Scheduled jobs and background work do **not** get a `workers/` folder: events/polling → `consumer/`, scheduled → `cli/` subcommand.
- `data_repositories/` vs `storage/` splits **by data shape, not by SQL/NoSQL**. Redis can go in either. A Mongo blob store is `storage/`.
- Migration verbs are a **closed set** (`create add drop alter rename backfill fix refactor seed`). Reject `update`, `misc`, `change`. Pick the closest allowed verb.
- `domain/` files use the **bare context name** (`order.go`), with no `domain_` prefix. Every other layer uses a prefix (`interactor_`, `repository_`).
- Promoting a suffix to a subfolder **drops the suffix** (`interactor_order.go` → `order/interactor.go`). You must update every import site in the same change.
- Thresholds are not "promote ASAP". Below the band, **stay flat**. In the borderline band, use **Step 0**. Promotion is a one-way ratchet.
- `interactor/` holds **use cases only** (`interactor_<context>.go`): one workflow step, ~1–3 port calls, no spawned goroutines. Long-running or concurrent **process managers** live in their own inner layer, **`coordinator/`**. A process manager coordinates ports (and use cases) over time with a loop, goroutines, mutexes, timers, or retries. Name it by role with **no layer prefix** (`coordinator/scheduler.go`, never `coordinator_scheduler.go` or `interactor_scheduler.go`). Use one role-naming style per service. Both layers stay flat until the ≥10-file promotion. (ADR-34, which supersedes ADR-24.)
- **Generated wire contracts are adapter-only** (see Forbidden imports). A port speaks domain types. Translate wire↔domain at the adapter boundary.
- A **streaming server** (`grpc/` / `ws/` / `sse/`) is a driving adapter that owns connection-scoped state: a per-connection session object and a registry of live connections. Split it (server / session-registry / translation / reconciler) before one file exceeds ~400 LOC. The per-connection object MAY hold a domain entity (a credit ledger), mutate it as instructed, and implement a push/sink port. This is expected, not a violation. It may not decide **when or why** the entity moves. Decisions like release-on-settlement, reserve-on-reattach, or lifecycle branch on connection loss are interactor policy. The interactor exposes them as methods that the adapter calls at sequence points. The adapter keeps ordering. The interactor keeps policy. A reconciler that fixes adapter-owned registry state may decide over that registry. Durable transitions still go through an interactor.
- A **reconciler/sweeper coupled to one adapter's state** (a session registry, a lease table, a cache) lives **in that adapter's package** (`grpc/<name>_reclaim.go`), and `cmd/` starts it. It does NOT go in `cli/`/`consumer/`, because that would sever it from the state it fixes. Independent scheduled jobs still → `cli/`. Event/poll → `consumer/`.
- A **port may be a `func` type** for a single-method seam (`type Emit func(...) error`). Multi-method ports stay interfaces.
- **Translation / ACL** (domain↔external-wire mapping) lives with the adapter that owns that wire format: inline, `<adapter>_translation.go`, or a named cluster inside a promoted adapter folder. Never a top-level `mapper/` or `dto/` (both forbidden). The mapping is pure (no I/O). The HTTP/stream call is its sibling.
- A **state machine has exactly one enforcement locus**: domain-enforced or datastore-enforced, never both, never neither. Declare it at the transition table + service docs. Prove it with a `*_conformance_test.go` beside the table. Read "State machines: one enforcement locus" in [`references/placement-rules.md`](references/placement-rules.md) before you add a `Transition`/`CanTransitionTo` API.
- Anything that **two services must both hold** to behave correctly is a contract with one declared owner, never a convenience copy. Examples: a datastore identifier, an agreed value or timeout, a peer's enum, a contract version. Read [`references/service-boundaries.md`](references/service-boundaries.md) before you duplicate any of these across services.

## Decision flowcharts

### Where does a new file go?

1. Is it a CLI subcommand? → `cli/<action>_command.go`.
2. Is it an HTTP handler? → `api/<resource>_handler_v<N>.go`. (`api/` is HTTP only.)
2b. Is it a gRPC/WebSocket/SSE **stream server**? → `grpc/` (or `ws/`, `sse/`). Read "Streaming adapter structure" in placement-rules before you add files. Only a transport not in this list → Step 0.
2c. Is it a stream/gRPC **client** to one upstream? → `grpc/client.go` (or `external_services/<provider>/` when it is one provider among several).
3. Is it an event/poll handler? → `consumer/<subject>_<verb>_consumer.go`.
4. Is it a use case (one workflow step, ~1–3 port calls, no goroutines)? → `interactor/interactor_<context>.go`.
4b. Is it a **process manager** (loop, goroutines, mutexes, timers, retries — pipeline/processor/scheduler/reconnect)? → `coordinator/<role>.go` (own inner layer, role-named, no layer prefix).
5. Is it an entity, value object, business invariant, or stateless **domain service** (a pure operation over domain types)? → `domain/<context>.go` (bare context name, no `domain_` prefix).
6. Is it a repository (schema-shaped: query language, typed fields, indexes)? → `data_repositories/repository_<context>.go`.
7. Is it blob storage (opaque bytes by key/path)? → `storage/storage_<context>.go`.
8. Is it a third-party API call? → `external_services/<subject>_<action>_<provider>.go`.
8b. Is it domain↔wire **translation / ACL** for an external or wire format? → with the adapter that owns that format (`<adapter>_translation.go`, or a named cluster inside a promoted adapter folder). Never `mapper/`/`dto/`.
9. Is it an outbound event? → `producer/<subject>_<verb>_producer.go`.
10. Is it a port interface (or a single-method `func` port)? → `ports/<context>_port.go`.
11. Is it middleware? → `<inbound_adapter>/middleware_<concern>.go`.
12. Is it a reconciler/sweeper tied to one adapter's in-memory/durable state? → in that adapter's package (e.g. `grpc/<name>_reclaim.go`), started from `cmd/`.

If none clearly apply → Step 0. Naming detail, context identification, edge cases (Redis split, background work routing, streaming adapter structure, tests/mocks): [`references/placement-rules.md`](references/placement-rules.md).

### Shared code: which destination?

- Pure stdlib helper, no business meaning → `go-pkgs/<domain>x/` or `go-pkgs/<domain>kit/`.
- Reusable infra → `go-pkgs/infra/<pkg>/` (the default, with SDK repos as opt-in tiers).
- Business primitive, 2+ services, stable → `internal/kernel/`.
- Wire payload shared by 2+ services → root `internal/contracts/`.
- Contract shared across components of one service → `services/<service>/internal/contracts/` (single-service: `internal/contracts/`). It is private to that service.
- DTO used by one adapter only → keep local to that adapter package.
- Hard qualifier: root `internal/` admits **only** `contracts/` and `kernel/` — any third child is a violation (`root-internal-occupancy`).
- Hard qualifier: a shared tier (`go-pkgs/`, root `internal/`) requires **≥2 verified importers today** — single-importer code lives in its one consumer ([`references/shared-code.md`](references/shared-code.md)).

Contract scope is a ladder (adapter-local → service-scoped → root). Promote only when a real consumer crosses the next boundary. Read [`references/shared-code.md`](references/shared-code.md) before you create anything under `go-pkgs/` or root `internal/`.

### Migration filename?

Shared DB → `<seq>_<service|shared>_<verb>_<desc>`. Per-service DB → `<seq>_<verb>_<desc>`. Verb closed set: `create|add|drop|alter|rename|backfill|fix|refactor|seed`. SQL → `.up.sql` + `.down.sql` pair. Forward-only → single native ext.

Read [`references/migrations.md`](references/migrations.md) before you create or rename any migration file.

---

## Invariant — forbidden folder names

Reject these names anywhere in the repo:

```text
pkg, shared, common, lib, utils, application, infrastructure,
interfaces, helpers, mapper, dto, gateway, workers, misc
```

If the user proposes one:

1. Object to the name and cite the rule.
2. Suggest the canonical alternative:
   - `pkg` → `go-pkgs/<domain>x`.
   - `workers` → `consumer/` + `cli/` (or, for a reconciler coupled to an adapter, that adapter's package).
   - `utils` → domain-prefixed package under `go-pkgs/`.
   - `mapper`/`dto` → adapter-local translation file `<adapter>_translation.go`.
3. If none clearly fits → Step 0.

---

## Anti-patterns to refuse

When you generate or review layout, reject:

- Any forbidden folder name from the list above.
- Any forbidden import from the dependency invariant above.
- Combined-context filename (`order_product.go`).
- Migration errors:
  - Verb outside the closed set.
  - `shared` + service combined.
  - Verb as suffix or dotted segment.
  - Migrations under `data_repositories/` or `services/<service>/`.
  - Cross-service writes in shared DB without `shared`-token justification.
- Multi-binary services (more than one `main.go` per service).
- `cmd/` that contains logic instead of wiring.
- Per-service `go.mod` in a monorepo **without** a root `go.work` (orphan modules). With a `go.work`, multi-module is fine (topology B).
- Top-level `config/`, `middleware/`, `events/`, `messages/`, `dto/`.
- Go files under `scripts/`.
- Forcing infra into a remote SDK repo when `go-pkgs/infra/` is the better default.
- **Decorative state machine**: a transition table / `CanTransitionTo` in `domain/` that no production code path consults. The datastore or ad-hoc writes actually gate transitions. Declare one enforcement locus and add the conformance oracle (`*_conformance_test.go`), or delete the table. See "State machines: one enforcement locus" in [`references/placement-rules.md`](references/placement-rules.md).
- **Shim interactor layer**: an `interactor/` layer of one-line port forwarders, that is, pass-through use cases kept to satisfy the layer diagram. Enrich it (the policy that leaks into adapters/callers moves inward) or delete it (the caller uses the port directly). See "Shim interactors: enrich or delete" in [`references/placement-rules.md`](references/placement-rules.md).
- **Wire model in domain**: `domain/` types shaped by a wire/response contract (schema-mirroring tagged structs, envelope/version/status constants). Tell: a change to a response contract would edit `domain/`. See "Wire models do not belong in domain/" in [`references/placement-rules.md`](references/placement-rules.md).
- **Silent config mirror**: a cross-service agreed value duplicated across services' config with no declared owner, no in-band transmission, and no runtime comparison. It is the same tunable in each service, e.g. a lease window, heartbeat interval, a timeout that bounds a peer's. It is forbidden when the value feeds a correctness decision. See the agreed-values ladder in [`references/service-boundaries.md`](references/service-boundaries.md).
- **Peer-datastore reach-in**: a service reads (or writes) another service's tables/collections directly through re-declared string identifiers instead of the owner's API/contract. See "Durable-state privacy" in [`references/service-boundaries.md`](references/service-boundaries.md).
- **Peer-enum modeling**: a hand-copied mirror of another service's private enum or state machine in `domain/`, with no exhaustiveness test that binds the mirror to its source. See "Enum mirrors need exhaustiveness tests" in [`references/service-boundaries.md`](references/service-boundaries.md).

Cite the rule when you refuse. Offer the canonical alternative. If none fits cleanly → Step 0.

---

## Verify

[`scripts/arch-checks.sh`](scripts/arch-checks.sh) is a **gate, not a suggestion**:

- Wire it into CI (or the repo's task runner) so that it runs on every change that touches Go files.
- Run it before you end any change that adds, moves, or renames files.
- In `review` mode, always include the script's findings verbatim in the report.

A violation that the script already detects and that ships anyway is a process failure to raise, not a pre-existing condition to inherit. When you start work in a repo, run the script once. Report standing violations before you add to them. To adopt the gate in a codebase with standing violations, ratchet with `--baseline` against a committed JSON baseline. CI then fails only on new violations. Mechanism: [`references/migration.md`](references/migration.md).

Run it from the repo root (`bash scripts/arch-checks.sh`). Add `--json` for machine-readable output and `--help` for usage. It verifies:

- Forbidden folder names (vendor/.git pruned).
- `go build` + `go vet` (module dirs with zero `.go` files skipped).
- The nine import invariants through `go list`, incl. generated-contracts-adapter-only. The script groups `inner-imports-contracts` details per service and names the guilty layer.
- Module topology: a single root `go.mod`, or a `go.work` with every `go.mod` dir listed under `use`. The script flags orphan multi-module.
- One `cmd/main.go` per service. The script skips services with no non-test `.go` files (non-Go services).
- No Go under `scripts/`.
- `db:`/`bson:` struct tags under `ports/` or `domain/` (`tags-in-inner-layers`).
- Root-`internal/` occupancy (`root-internal-occupancy`): any child other than `contracts/`/`kernel/`.
- Stdlib-shadow names in shared tiers (`stdlib-shadow-name`).
- Migration filename grammar + up/down pairing. A non-migration script under `migrations/` gets `misplaced-script`, not `bad-migration-name`.

Report-only, never failing the run:

- Promotion-threshold counts grouped per context stem. This grouping is a heuristic: verify it before you promote.
- Streaming adapter files over ~400 LOC (`streaming-file-loc`).
- Dead domain transition tables (`decorative-state-machine`).
- Cross-service boundary heuristics (`boundary-review`).
- Shared-tier importer counts (`shared-tier-importer-count`).

Structured report on stdout, diagnostics on stderr. Exit 0 = clean, 1 = violations, 2 = bad usage, 3 = missing prerequisite. If the script is not available, run its individual commands manually.

Then report with this template (omit empty sections):

```text
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

- **No argument** — interactive: ask repo shape (mono/single) and service name, then scaffold. Read [`references/scaffolding.md`](references/scaffolding.md) first.
- **`monorepo <service>`** / **`single <module>`** — scaffold (need-based: only `cmd/`, `domain/`, `interactor/`, `ports/`, `config/` + named adapters, plus `coordinator/` only when a process manager exists — never empty folders). Read [`references/scaffolding.md`](references/scaffolding.md) first.
- **`review`** — first detect adoption: adopted iff service `internal/` contains ≥2 of `domain/`, `interactor/`, `ports/` (or single-service equivalent). Not adopted → report "convention not adopted" and ask whether to adopt. Do **not** flag individual violations or restructure. Adopted → audit and emit the report template from the Verify section (Violations + Promotion reached sections).
- **`place <description>`** — return the canonical path from the flowchart. Read [`references/placement-rules.md`](references/placement-rules.md) when the flowchart line alone does not settle it. Unclear → Step 0.
- **`migration <topology> <verb> <desc>`** — generate a migration filename. `<topology>` ∈ {`shared`, `per-service`}. Read [`references/migrations.md`](references/migrations.md) first.
- **`migrate`** — incremental adoption of the convention in an existing codebase. **Read-only first**: produce an assessment report (`arch-checks` output + root-cause classification + proposed context map) and an **ordered** migration plan (strangler order). Perform **no automatic file moves**. Execution happens later as separate reviewed changes. Read [`references/migration.md`](references/migration.md) first.

---

## Boundaries

- Do not invent new folder names. If something does not fit any rule, escalate through Step 0.
- Do not enforce observability, lint, formatter, or test framework. They are out of scope.
- When the promotion threshold is borderline, prefer not to promote. Promotion is a one-way ratchet that adds folders.
- Do not force the use of any specific external SDK repo. `go-pkgs/infra/` is the default. Remote SDK repos are opt-in.
- Violations that you notice during an unrelated task: report them. Do not fix them in the same change unless asked.
