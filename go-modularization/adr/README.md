# Architecture Decision Record — Go Modularization

> **History only.** The canonical reference for the `go-modularization` skill is [`../references/adr-cheatsheet.md`](../references/adr-cheatsheet.md). This document is preserved for the historical decision record; the cheatsheet supersedes it for day-to-day use.

Go service folder/module structure in monorepos (primary) and single-service repositories (secondary).

**Placeholder convention:** `<placeholder>` denotes a slot to fill in. Common slots:

- `<service>` — service name (e.g. `orders`, `billing`)
- `<inbound_adapter>` — entry-point adapter (`api`, `consumer`, `cli`, …)
- `<outbound_adapter>` — exit-point adapter (`data_repositories`, `external_services`, `producer`, `storage`, …)
- `<layer>` — inner-layer name (`domain`, `interactor`, `ports`)
- `<context>` — bounded context / aggregate (`order`, `product`, `user`)
- `<resource>` — API resource (`users`, `invoices`)
- `<provider>` — external provider (`taobao`, `amazon`, `s3`)
- `<action>` — verb describing the operation (`publish`, `consume`, `connect`)
- `<concern>` — middleware concern (`auth`, `logging`, `ratelimit`)
- `<subject>` — domain subject of an event (`order`, `product`)
- `<verb>` — past-tense event verb (`created`, `changed`, `completed`)
- `<N>` — version integer (`1`, `2`, …)
- `<domain>` — utility domain prefix (`string`, `time`, `slice`)
- `<pkg>` — package name (folder-level)

---

## ADR-01: Pragmatic flat hexagonal architecture

Adopt a pragmatic flat hexagonal architecture for every Go service. Inner layers (`<layer>` ∈ {`domain`, `interactor`, `ports`}) are abstract and free of infrastructure. Outer layers (all adapter folders) are concrete. Inbound adapters (`<inbound_adapter>`, e.g. `api`, `consumer`, `cli`) are entry points; outbound adapters (`<outbound_adapter>`, e.g. `data_repositories`, `external_services`, `producer`, `storage`) are exit points.

## ADR-02: Scope is folder layout and file placement only

This spec defines where files go. Out of scope: observability conventions (logging, metrics, tracing setup), Go file-splitting style (per-file size, intra-package symbol grouping), formatting rules, lint configuration, test framework choice, build tooling.

## ADR-03: Middleware lives inside the adapter package it serves

Middleware lives inside the inbound or outbound adapter package it belongs to.

- File form: `<inbound_adapter>/middleware_<concern>.go` (e.g. `api/middleware_auth.go`).
- Promotion: when 4+ middleware files exist for one adapter, promote to `<inbound_adapter>/middleware/` subfolder, with files named `<concern>.go` (e.g. `api/middleware/auth.go`).
- No top-level `middleware/` folder.

## ADR-04: API versioning uses suffix-then-folder promotion

Default to file-name suffix:

- File form: `<resource>_handler_v<N>.go` (e.g. `users_handler_v1.go`, `users_handler_v2.go`).
- Promotion: when one version exceeds approximately 5 files, promote to `api/v<N>/` subfolder (e.g. `api/v1/`, `api/v2/`).
- Inside a version subfolder, drop the version suffix: `<resource>_handler.go` (e.g. `api/v1/users_handler.go`).

## ADR-05: Bounded context uses suffix; promote to folder at scale

Prefer in-folder suffix:

- File form: `<layer>_<context>.go` (e.g. `repository_product.go`, `interactor_order.go`).
- Promotion: when one context reaches roughly 10+ files within a layer, promote to per-context subfolder `<layer>/<context>/`.
- Inside a context subfolder, drop the context suffix: `<layer>.go` (e.g. `interactor/order/interactor.go`).
- Suffixes do not combine: `<contextA>_<contextB>.go` is forbidden (e.g. `order_product.go`).

## ADR-06: Monorepo is the primary target; single-service repos are supported

Monorepo is primary. Single-service repos use the same internal service shape, with the optional `services/` wrapper omitted and root-level monorepo concerns (`go-pkgs/`, `internal/contracts/`, `migrations/<service>/`) collapsed.

## ADR-07: Use `go-pkgs/` (not `pkg/`) for shared Go code in monorepos

The monorepo-root folder for shared Go code is named `go-pkgs/`, not `pkg/`. The `pkg` folder name is forbidden. Language-prefixed names scale to other languages: `<lang>-pkgs/` (e.g. `ts-pkgs/`, `py-pkgs/`).

## ADR-08: `go-pkgs/` is for reusable Go utilities organized by domain; reusable infrastructure defaults to `go-pkgs/infra/`

`go-pkgs/` holds generic, reusable Go utilities organized by domain — pure helpers with no business logic and no IO, ideally stdlib-only dependencies.

- Package form: `<domain>x` or `<domain>kit` (e.g. `stringx`, `timex`, `mathx`, `randx`, `slicex`, `errorkit`, `urlkit`).
- Domain-prefixed package names only; the generic names `utils`, `helpers`, `common`, `shared`, `lib`, `misc` are forbidden.

Reusable infrastructure (database clients, HTTP servers and clients, message brokers, observability glue, blob storage wrappers, migration runners) follows a placement precedence:

1. **Primary — `go-pkgs/infra/<pkg>/`.** Default destination. Keeps infra in-repo, shareable across services in this monorepo, no premature extraction. The skill is agnostic and open-source-friendly: no project is forced to use any specific external SDK repo.
2. **Secondary — contribute to an existing community SDK repo** (e.g. `github.com/trypanic/go-sdk`) when the concern is already covered there and upstreaming benefits other consumers.
3. **Tertiary — dedicated org-owned SDK repo** (`github.com/<org>/go-sdk` or named alternative) when the infra surface is large enough to justify its own release lifecycle, versioning, and CI. Consumed via `go.mod`; never imports from the consumer repo.

`go-pkgs/` must never contain business types, service-specific configuration shapes, or imports from `services/...` or root `internal/`.

## ADR-09: Cross-service shared business code lives under monorepo `internal/`

Cross-service business sharing lives in monorepo-root `internal/`, with two folders only:

- `internal/contracts/` — cross-service event/message wire payloads.
- `internal/kernel/` — shared business primitives (e.g. `Money`, IDs, common value objects).

Admission criteria for `internal/kernel/`, all required: 2+ services already consume it; stable contract (changes are rare); no service-specific logic.

## ADR-10: `go-pkgs/` uses one subfolder per package with action-based file names

Each package under `go-pkgs/` (and `go-pkgs/infra/` when used) gets a dedicated subfolder.

- Folder form: `go-pkgs/<pkg>/` (e.g. `go-pkgs/stringx/`).
- File form: `<action>.go` (e.g. `publish.go`, `consume.go`, `connect.go`, `format.go`, `parse.go`).
- Technology suffixes (`_<provider>`, e.g. `_rmq`, `_pg`, `_s3`) used in service outbound adapters do not apply here — the folder name already encodes the concern.

## ADR-11: Cross-service event payloads live in `internal/contracts/`

The folder under monorepo `internal/` that holds shared event/message wire payloads is named `internal/contracts/`. One file per event or message contract.

- File form: `<subject>_<verb>_event.go` (e.g. `product_changed_event.go`, `order_completed_event.go`).
- The names `internal/messages/`, `internal/events/`, `internal/dto/` are not used.

## ADR-12: Migrations live at repository root; layout depends on DB topology

Two layouts, picked by DB topology. A repository (or service) declares which it uses; mixing within one DB instance is forbidden.

**Shared DB across services** — sequence is global per technology instance, so technology is the primary axis:

- Monorepo: `migrations/<technology>/` at repo root (e.g. `migrations/postgres/`, `migrations/mysql/`, `migrations/mongo/`).
- Single-service repo: same shape; `migrations/<technology>/`.

**Per-service DB** — sequence scoped per service, so service is primary:

- Monorepo: `migrations/<service>/<technology>/` at repo root (e.g. `migrations/orders/postgres/`).
- Single-service repo: `migrations/<technology>/` (service folder collapsed).

Common rules:

- Migrations never live inside `data_repositories/` or under `services/<service>/`.
- Forward-only technologies (e.g. Mongo) produce one file per migration; no `down` companion.
- Declarative infra config is not a migration. RabbitMQ topology, queue/exchange definitions, and similar declarative configs live outside `migrations/` — at `infra/<technology>/` at repo root (e.g. `infra/rabbit/topology.json`).
- Sequence collisions in the shared-DB layout are resolved at PR/rebase time; no automated reservation.
- Cross-service writes are forbidden in shared DB. Truly cross-cutting migrations (e.g. an `auto_set_updated_at` trigger applied to all tables, an extension install) use the reserved `shared` token — see ADR-20.
- Tool-agnostic: this ADR does not mandate a specific migration runner. The `.up.sql` / `.down.sql` convention is chosen because common SQL migration tools consume it; non-SQL technologies use their native script extension.

## ADR-20: Migration filename grammar

**Shared DB layout**:

```
<seq>_<service|shared>_<verb>_<desc>.<up|down>.sql
<seq>_<service|shared>_<verb>_<desc>.<ext>      # forward-only (e.g. mongo .js)
```

**Per-service DB layout**:

```
<seq>_<verb>_<desc>.<up|down>.sql
<seq>_<verb>_<desc>.<ext>                       # forward-only
```

Slots:

- `<seq>` — zero-padded integer (`001`, `002`, …). Sequence is per-technology in the shared layout, per-service-per-technology in the per-service layout.
- `<service>` — service name (shared layout only); identifies the owning service of a service-scoped migration.
- `shared` — reserved literal token for cross-cutting migrations affecting all services in the shared-DB layout. Must not combine with a service name.
- `<verb>` — closed set: `create`, `add`, `drop`, `alter`, `rename`, `backfill`, `fix`, `refactor`, `seed`. Free-form verbs are forbidden.
- `<desc>` — snake_case noun phrase describing the target.
- `<up|down>` — required for SQL technologies (`.up.sql`, `.down.sql`). Forbidden for forward-only technologies.
- `<ext>` — `.sql` for SQL; the native script extension for forward-only technologies (e.g. `.js` for Mongo).

Examples (shared DB):

```
migrations/postgres/001_shared_create_auto_set_updated_at.up.sql
migrations/postgres/001_shared_create_auto_set_updated_at.down.sql
migrations/postgres/002_taobao_create_orders_table.up.sql
migrations/postgres/002_taobao_create_orders_table.down.sql
migrations/postgres/015_external_auth_fix_integration_lock.up.sql
migrations/postgres/015_external_auth_fix_integration_lock.down.sql
migrations/mongo/003_amazon_scraping_collections.js
infra/rabbit/topology.json
```

Examples (per-service DB):

```
migrations/orders/postgres/001_create_orders_table.up.sql
migrations/orders/postgres/001_create_orders_table.down.sql
migrations/orders/mongo/003_scraping_collections.js
```

Forbidden:

- Free-form verbs outside the closed set (e.g. `_misc`, `_stuff`, bare `_update`).
- Combining the `shared` token with a service name (e.g. `001_shared_taobao_...`).
- Verb as suffix or dotted action segment (e.g. `_lock_fix`, `.fix.down.sql`).
- Multiple verbs in one filename.

## ADR-13: Per-service config; never at monorepo root

Configuration lives within each service:

- Monorepo: `services/<service>/config/` or `services/<service>/internal/config/`.
- Single-service: `internal/config/`.

There is no monorepo-root `config/` folder.

## ADR-14: Single binary per service: `cmd/main.go` plus Cobra subcommands

Every service has exactly one binary: `cmd/main.go`. All subcommands (server, scheduled jobs, one-off tasks, migrations as a Go-runtime fallback) are Cobra subcommands implemented inside the `cli/` inbound adapter. No multi-binary services.

## ADR-15: `cli/` is an inbound adapter, parallel to `api/` and `consumer/`

`cli/` is structurally parallel to `api/` and `consumer/`.

- File form: `<action>_command.go` (e.g. `seed_command.go`, `migrate_command.go`).
- Cobra commands defined here delegate to `interactor/` like any other inbound adapter.
- Command logic does not live in `cmd/`; `cmd/` is wiring only.

## ADR-16: `data_repositories/` vs `storage/` split is schema-shaped vs blob-shaped

- `data_repositories/` — schema-shaped persistence (e.g. PostgreSQL, MongoDB, Redis, DynamoDB, Elasticsearch).
- `storage/` — blob-shaped persistence (e.g. S3, GCS, Azure Blob, persistent local filesystem).

The split is by data shape, not by SQL/NoSQL or by in-memory/persisted.

## ADR-17: `external_services/<provider>/` subfolder at promotion threshold

`external_services/` is flat by default.

- File form: `<subject>_<action>_<provider>.go` (e.g. `payment_charge_taobao.go`, `email_send_amazon.go`).
- Promotion: when one provider reaches roughly 10+ files, has 3+ provider-specific infra files, or has a distinct lifecycle, promote to `external_services/<provider>/`.
- Inside a provider subfolder, drop the provider name from filenames; keep the transport suffix: `<subject>_<action>.go` (e.g. `external_services/taobao/payment_charge.go`).

## ADR-18: Background work routes by trigger; no `workers/` folder

Route background work by trigger type:

- Events → `consumer/`.
- Scheduled work → a Cobra subcommand under `cli/`, triggered by an external scheduler.
- Polling → `consumer/`.

There is no `workers/` folder. The name `workers` is forbidden.

## ADR-19: `scripts/` holds bash, Python, and SQL only — never Go

`scripts/` holds bash, Python, and SQL files only. Go-runtime tasks become Cobra subcommands inside `cli/`.

- Monorepo: `scripts/` at the root, plus optional per-service `services/<service>/scripts/`.
- Single-service repo: `scripts/` at root.



---

## Dependency direction

### Service-internal

```
cmd                                    → all (wiring only)
<inbound_adapter>                      → interactor
  e.g. api / consumer / cli
interactor                             → domain, ports
<outbound_adapter>                     → ports, domain
  e.g. external_services /
       data_repositories /
       producer / storage
```

### Monorepo-level

```
services/<service>/internal  → internal/contracts, internal/kernel, go-pkgs, external SDK (if used)
internal/contracts           → internal/kernel, go-pkgs
internal/kernel              → go-pkgs
go-pkgs                      → (stdlib only; ideally no third-party)
go-pkgs/infra                → stdlib + necessary third-party (default home for reusable infra)
external SDK repo            → (stdlib and third-party; never imports from this repo)
```

### Disallowed

- `<layer>` (`domain`, `ports`, `interactor`) importing any adapter folder.
- One service's `internal/` importing another service's `internal/` — i.e. `services/<A>/internal` ⇸ `services/<B>/internal`.
- `internal/kernel/` importing `internal/contracts/`.
- `go-pkgs/` importing anything from `internal/` or `services/`.
- An external SDK repo importing anything from this repo.
- Adapter A's package importing adapter B's package directly — cross-adapter coordination goes through `interactor/` or shared `ports/`.
- `cmd/` being imported by anything else.

---

## Forbidden folder names

`pkg`, `shared`, `common`, `lib`, `utils`, `application`, `infrastructure`, `interfaces`, `helpers`, `mapper`, `dto`, `gateway`, `workers`, `misc`.
