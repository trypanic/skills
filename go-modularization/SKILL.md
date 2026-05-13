---
name: go-modularization
description: Opinionated folder/package layout for Go monorepos and single-service repos. Encodes flat hexagonal architecture (inbound adapters → interactor → domain/ports ← outbound adapters), suffix-then-folder promotion for API versions and bounded contexts, `go-pkgs/` (never `pkg/`) convention, `data_repositories/` vs `storage/` split, migrations grammar with closed verb set, and forbidden folder-name list. Consult before placing new code or restructuring. Use when asked "new Go service", "where does this file go", "promote to subfolder", "add adapter", "structure monorepo", "set up migrations", "review folder layout", "is this folder name allowed", or to create/place/rename/restructure code under `services/<service>/`, `go-pkgs/`, `internal/`, or `migrations/`. Auto-trigger on new top-level folder under `services/<service>/`, new file under `go-pkgs/` or `internal/`, new migration, cross-package refactor, or PR review touching folder layout. Do NOT trigger for non-Go projects or runtime/observability/lint config.
---

# go-modularization

Opinionated folder/package layout for Go projects. Applies to monorepos (primary) and single-service repos (secondary). Agent-and-user-facing — both must consult this skill before placing new code, modularizing a feature, or doing folder-shape refactors.

Out of scope: observability conventions (logging, metrics, tracing), Go file-splitting style, formatting, lint, test framework, build tooling.

Reference: [`references/adr-cheatsheet.md`](references/adr-cheatsheet.md).

---

## Step 0 — Hard rule: ask when unclear

Before placing or moving code, the agent must check this skill against the case at hand. If **any** of the following is true, stop and start a discussion with the user:

- No rule in this skill cleanly covers the situation.
- Two or more rules could plausibly apply and the choice changes the layout.
- A promotion threshold is borderline (around the ~5 / ~10 / ~3 marks).
- The user proposes a forbidden folder name and the canonical alternative is not obvious in context.
- A new kind of inbound or outbound adapter is being introduced.
- Cross-cutting code candidate: unclear whether it belongs in `go-pkgs/`, `go-pkgs/infra/`, `internal/kernel/`, `internal/contracts/`, or a shared SDK repo.

Present 2–3 concrete options with trade-offs. Do **not** silently pick one. Once aligned, proceed.

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
- Runtime config: logging, metrics, tracing, lint, formatters, test frameworks (out of scope).

---

## Placeholder convention

`<placeholder>` = slot to fill. Common slots:

| Slot                  | Meaning                                  | Example                                  |
|-----------------------|------------------------------------------|------------------------------------------|
| `<service>`           | service name                             | `orders`, `billing`                      |
| `<inbound_adapter>`   | entry-point adapter                      | `api`, `consumer`, `cli`                 |
| `<outbound_adapter>`  | exit-point adapter                       | `data_repositories`, `external_services`, `producer`, `storage` |
| `<layer>`             | inner layer                              | `domain`, `interactor`, `ports`          |
| `<context>`           | bounded context / aggregate              | `order`, `product`, `user`               |
| `<resource>`          | API resource                             | `users`, `invoices`                      |
| `<provider>`          | external provider                        | `taobao`, `amazon`, `s3`                 |
| `<action>`            | verb                                     | `publish`, `consume`, `connect`          |
| `<concern>`           | middleware concern                       | `auth`, `logging`, `ratelimit`           |
| `<subject>`           | event domain subject                     | `order`, `product`                       |
| `<verb>`              | past-tense event verb                    | `created`, `changed`, `completed`        |
| `<N>`                 | version int                              | `1`, `2`                                 |
| `<domain>`            | utility domain prefix                    | `string`, `time`, `slice`                |
| `<pkg>`               | package name                             | `stringx`                                |
| `<org>`               | GitHub org / owner                       | `acme`, `trypanic`                       |

---

## Step 1 — Pick repo shape

Two shapes. Same internal service skeleton.

**Monorepo (primary):**

```
<repo-root>/
  services/<service>/
    cmd/main.go
    internal/
      <inbound_adapter>/         # api, consumer, cli
      <outbound_adapter>/        # data_repositories, external_services, producer, storage
      <layer>/                   # domain, interactor, ports
      config/
    scripts/                     # optional, per-service
  go-pkgs/<pkg>/                 # shared Go utils, domain-prefixed
  internal/
    contracts/                   # cross-service event payloads
    kernel/                      # shared business primitives
  migrations/                    # see Step 8
  infra/<technology>/            # declarative infra config (e.g. rabbit topology)
  scripts/                       # repo-root bash/python/sql
```

**Single-service repo (secondary):**

```
<repo-root>/
  cmd/main.go
  internal/
    <inbound_adapter>/
    <outbound_adapter>/
    <layer>/
    config/
  migrations/<technology>/       # service folder collapsed
  scripts/
```

Drop `services/`, `go-pkgs/`, `internal/contracts/`, `internal/kernel/`, `migrations/<service>/` for single-service.

---

## Step 2 — Hexagonal layers

Inner layers (abstract, no IO):
- `domain/` — entities, value objects, business invariants.
- `interactor/` — use cases, orchestration.
- `ports/` — interfaces consumed by interactor, implemented by adapters.

Outer layers (concrete, IO):
- Inbound adapters (entry): `api/`, `consumer/`, `cli/`.
- Outbound adapters (exit): `data_repositories/`, `external_services/`, `producer/`, `storage/`.

Dependency direction:

```
cmd                  → all (wiring only)
<inbound_adapter>    → interactor
interactor           → domain, ports
<outbound_adapter>   → ports, domain
```

**Forbidden imports:**
- `domain` / `ports` / `interactor` importing any adapter.
- `services/<A>/internal` importing `services/<B>/internal`.
- `internal/kernel/` importing `internal/contracts/`.
- `go-pkgs/` importing `internal/` or `services/`.
- Adapter A importing adapter B directly — go through `interactor/` or shared `ports/`.
- Anything importing `cmd/`.

---

## Step 3 — Bounded context: suffix, then promote

Default in-folder suffix:

```
interactor/
  interactor_order.go
  interactor_product.go
data_repositories/
  repository_order.go
  repository_product.go
```

Promote to subfolder when one context hits ~10+ files in that layer:

```
interactor/
  order/interactor.go            # context suffix dropped
  order/<more files>.go
  product/interactor.go
```

**Forbidden:** combined-context suffix `<contextA>_<contextB>.go` (e.g. `order_product.go`).

---

## Step 4 — API versioning: suffix, then promote

Default file-name suffix:

```
api/
  users_handler_v1.go
  users_handler_v2.go
```

Promote when one version exceeds ~5 files:

```
api/
  v1/users_handler.go            # version suffix dropped
  v2/users_handler.go
```

---

## Step 5 — Middleware lives with its adapter

Inside the adapter package:

```
api/
  middleware_auth.go
  middleware_logging.go
```

Promote when 4+ middleware files for one adapter:

```
api/
  middleware/
    auth.go                      # concern suffix dropped
    logging.go
```

**No top-level `middleware/` folder.**

---

## Step 6 — Outbound adapter rules

| Adapter             | Shape                                  | File form (flat)                               | Promotion                                              |
|---------------------|----------------------------------------|------------------------------------------------|--------------------------------------------------------|
| `data_repositories/`| schema-shaped (PG, Mongo, Redis, ES)   | `repository_<context>.go`                      | per-context subfolder at ~10+ files                    |
| `storage/`          | blob-shaped (S3, GCS, local FS)        | `storage_<context>.go`                         | per-context subfolder                                  |
| `external_services/`| third-party APIs                       | `<subject>_<action>_<provider>.go`             | `external_services/<provider>/` at ~10+ files, 3+ provider-specific infra files, or distinct lifecycle — drop provider from filenames inside |
| `producer/`         | outbound events                        | `<subject>_<verb>_producer.go`                 | per-context subfolder                                  |

`data_repositories/` vs `storage/` split is **by data shape**, not SQL/NoSQL or in-memory/persisted.

---

## Step 7 — Inbound adapter rules

| Adapter      | Files                                | Notes                                                |
|--------------|--------------------------------------|------------------------------------------------------|
| `api/`       | `<resource>_handler_v<N>.go`         | promote to `api/v<N>/` at ~5+ files                  |
| `consumer/`  | `<subject>_<verb>_consumer.go`       | events + polling go here                             |
| `cli/`       | `<action>_command.go`                | Cobra subcommands, parallel to `api/`/`consumer/`    |

**Single binary per service**: `cmd/main.go` only. All subcommands (server, scheduled jobs, one-off tasks, Go-runtime migrations) are Cobra subcommands inside `cli/`. `cmd/` is wiring only.

**Background work routing**: events → `consumer/`. Scheduled → Cobra subcommand under `cli/`, triggered externally. Polling → `consumer/`. **No `workers/` folder.**

---

## Step 8 — Migrations

Pick layout by DB topology. Mixing within one DB instance is **forbidden**.

**Shared DB (sequence global per technology):**

```
migrations/<technology>/<seq>_<service|shared>_<verb>_<desc>.<up|down>.sql
migrations/<technology>/<seq>_<service|shared>_<verb>_<desc>.<ext>     # forward-only (e.g. mongo .js)
```

Examples:
```
migrations/postgres/001_shared_create_auto_set_updated_at.up.sql
migrations/postgres/001_shared_create_auto_set_updated_at.down.sql
migrations/postgres/002_taobao_create_orders_table.up.sql
migrations/mongo/003_amazon_scraping_collections.js
```

**Per-service DB (sequence per service per technology):**

```
migrations/<service>/<technology>/<seq>_<verb>_<desc>.<up|down>.sql    # monorepo
migrations/<technology>/<seq>_<verb>_<desc>.<up|down>.sql              # single-service
```

Examples:
```
migrations/orders/postgres/001_create_orders_table.up.sql
migrations/orders/mongo/003_scraping_collections.js
```

**Filename grammar:**

| Slot       | Rule                                                                            |
|------------|---------------------------------------------------------------------------------|
| `<seq>`    | zero-padded int (`001`, `002`)                                                  |
| `<service>`| shared layout only; owner of service-scoped migration                           |
| `shared`   | reserved literal for cross-cutting migration in shared layout; never combine with service name |
| `<verb>`   | **closed set**: `create`, `add`, `drop`, `alter`, `rename`, `backfill`, `fix`, `refactor`, `seed` |
| `<desc>`   | snake_case noun phrase                                                          |
| `<up\|down>`| required for SQL; forbidden for forward-only                                   |
| `<ext>`    | `.sql` or native (e.g. `.js` for Mongo)                                         |

**Forbidden:**
- Free-form verbs (`_misc`, `_stuff`, bare `_update`).
- Combining `shared` token with a service name (`001_shared_taobao_...`).
- Verb as suffix or dotted segment (`_lock_fix`, `.fix.down.sql`).
- Multiple verbs in one filename.
- Migrations under `data_repositories/` or `services/<service>/`.
- Cross-service writes in shared DB (use `shared` token only for genuinely cross-cutting changes).

**Declarative infra config is not a migration.** RabbitMQ topology and similar live at `infra/<technology>/` (e.g. `infra/rabbit/topology.json`).

Sequence collisions resolved at PR/rebase time. No reservation system.

---

## Step 9 — Shared code: `go-pkgs/` and `internal/`

`go-pkgs/` (monorepo, never `pkg/`):
- Generic, reusable Go utilities, domain-organized.
- One subfolder per package: `go-pkgs/<pkg>/<action>.go`.
- Package form: `<domain>x` or `<domain>kit` (`stringx`, `timex`, `mathx`, `randx`, `slicex`, `errorkit`, `urlkit`).
- File form: `<action>.go` (`publish.go`, `parse.go`, `format.go`).
- Stdlib-only ideal. No business logic. No IO.
- Must never contain business types, service config shapes, or imports from `services/...` or root `internal/`.

**Reusable infrastructure** (DB clients, HTTP servers/clients, brokers, observability, blob, migration runners) — placement precedence:

1. **Primary: `go-pkgs/infra/<pkg>/`.** Default placement. Keeps the infra code in-repo, shareable across services in this monorepo, and avoids premature extraction.
2. **Secondary: contribute to an existing community SDK repo** if one already covers the concern (e.g. `github.com/trypanic/go-sdk`). Use this when the piece is generic enough to benefit other consumers.
3. **Tertiary: create a dedicated org-owned SDK repo** (`github.com/<org>/go-sdk` or similar) when the infra surface is large enough to justify its own release lifecycle, versioning, and CI. Consume via `go.mod`. The SDK repo never imports from this repo.

No one is forced to use any particular SDK repo. The default for new infra is always `go-pkgs/infra/`.

`internal/` (monorepo root, two folders only):
- `internal/contracts/` — cross-service event/message wire payloads. File form: `<subject>_<verb>_event.go` (e.g. `product_changed_event.go`).
- `internal/kernel/` — shared business primitives (`Money`, IDs, value objects). Promote here only when 2+ services already consume the type, the contract is stable, and changes are rare.

Forbidden names for cross-service shared payloads: `internal/messages/`, `internal/events/`, `internal/dto/`.

---

## Step 10 — Config

Per-service only:
- Monorepo: `services/<service>/config/` or `services/<service>/internal/config/`.
- Single-service: `internal/config/`.

**No monorepo-root `config/` folder.**

---

## Step 11 — Scripts

`scripts/` holds **bash, Python, SQL only**. Never Go.

- Monorepo: `scripts/` at root + optional `services/<service>/scripts/`.
- Single-service: `scripts/` at root.

Go-runtime tasks → Cobra subcommand under `cli/`.

---

## Forbidden folder names

Reject these names anywhere in the repo:

```
pkg, shared, common, lib, utils, application, infrastructure,
interfaces, helpers, mapper, dto, gateway, workers, misc
```

If user proposes one, push back, cite the rule, suggest the canonical alternative (e.g. `pkg` → `go-pkgs/<domain>x`, `workers` → `consumer/` + `cli/`, `utils` → domain-prefixed package under `go-pkgs/`). If none of the alternatives clearly fit, fall back to Step 0 and discuss with the user.

---

## Decision flowcharts

### Where does a new file go?

1. Is it a Cobra subcommand? → `cli/<action>_command.go`.
2. Is it an HTTP handler? → `api/<resource>_handler_v<N>.go`.
3. Is it an event/poll handler? → `consumer/<subject>_<verb>_consumer.go`.
4. Is it a use case? → `interactor/interactor_<context>.go`.
5. Is it a repository (schema-shaped DB)? → `data_repositories/repository_<context>.go`.
6. Is it blob storage? → `storage/storage_<context>.go`.
7. Is it a third-party API call? → `external_services/<subject>_<action>_<provider>.go`.
8. Is it an outbound event? → `producer/<subject>_<verb>_producer.go`.
9. Is it a port interface? → `ports/<context>_port.go`.
10. Is it middleware? → `<inbound_adapter>/middleware_<concern>.go`.

If none of the above clearly apply → Step 0 (ask the user).

### Promote to subfolder?

- Bounded context in a layer ≥ ~10 files → `<layer>/<context>/`.
- API version ≥ ~5 files → `api/v<N>/`.
- Middleware ≥ 4 files for one adapter → `<inbound_adapter>/middleware/`.
- External provider ≥ ~10 files, ≥ 3 provider-specific infra files, or distinct lifecycle → `external_services/<provider>/`.

When promoted, **drop the suffix that the folder now encodes**. Borderline counts → Step 0.

### Shared infrastructure: which destination?

1. `go-pkgs/infra/<pkg>/` — default for any reusable infra inside this repo.
2. Contribute to an existing community SDK repo (e.g. `github.com/trypanic/go-sdk`) — when the concern is already covered there and the user is willing to upstream.
3. Dedicated org SDK repo (`github.com/<org>/go-sdk` or named alternative) — only when the surface justifies its own release lifecycle.

If unclear which tier applies → Step 0.

### Shared utility: `go-pkgs/<domain>x/` or `internal/kernel/`?

- Pure stdlib helper, no business meaning → `go-pkgs/<domain>x/`.
- Business primitive shared by 2+ services, stable contract → `internal/kernel/`.
- One service only → keep it in that service's `internal/`.

### Migration filename?

1. Pick layout: shared DB → `<seq>_<service|shared>_<verb>_<desc>`. Per-service DB → `<seq>_<verb>_<desc>`.
2. Verb must be in closed set: `create|add|drop|alter|rename|backfill|fix|refactor|seed`.
3. SQL → `.up.sql` + `.down.sql`. Forward-only (Mongo) → single file, native ext.
4. Sequence is per-technology in shared layout, per-service-per-technology otherwise.

---

## Anti-patterns to refuse

When generating or reviewing layout, reject:

- Top-level `pkg/`, `shared/`, `common/`, `lib/`, `utils/`, `helpers/`, `mapper/`, `dto/`, `gateway/`, `workers/`, `application/`, `infrastructure/`, `interfaces/`, `misc/`.
- `domain` / `ports` / `interactor` importing an adapter.
- One service's `internal/` importing another service's `internal/`.
- `internal/kernel/` importing `internal/contracts/`.
- `go-pkgs/` importing `services/...` or root `internal/`.
- Cross-adapter direct import (adapter A → adapter B).
- Anything importing `cmd/`.
- Combined-context filename (`order_product.go`).
- Migration verb outside the closed set.
- `001_shared_<service>_...` (shared + service combined).
- Verb as filename suffix or dotted segment.
- Migrations under `data_repositories/` or `services/<service>/`.
- Cross-service writes in shared DB without the `shared` token justification.
- Multi-binary services (more than one `main.go` per service).
- `cmd/` containing logic instead of wiring.
- Top-level `config/`, `middleware/`, `events/`, `messages/`, `dto/`.
- Go files under `scripts/`.
- Forcing infra into a remote SDK repo when `go-pkgs/infra/` is the better default.

Cite the rule when refusing. Offer the canonical alternative. If none fits cleanly, fall back to Step 0.

---

## Verify

After scaffolding or restructuring:

1. `find . -type d \( -name pkg -o -name shared -o -name common -o -name lib -o -name utils -o -name helpers -o -name mapper -o -name dto -o -name gateway -o -name workers -o -name misc -o -name application -o -name infrastructure -o -name interfaces \)` — must return empty.
2. `go build ./...` — imports resolve.
3. `go vet ./...`.
4. Spot-check dependency direction: grep `domain/`, `ports/`, `interactor/` for adapter imports.
5. Verify single `cmd/main.go` per service; `cmd/` only wires.
6. Validate migration filenames against the grammar (verb in closed set, no combined service+shared, correct up/down pairing for SQL).

Report: list of folders created/renamed, list of files placed, any forbidden name detected, any promotion threshold reached, any case escalated to the user via Step 0.

---

## Inputs

Optional argument:

- **No argument** — interactive: ask repo shape (mono/single), service name, then scaffold the canonical skeleton.
- **`monorepo <service>`** — scaffold a service inside a monorepo at `services/<service>/`.
- **`single <module>`** — scaffold a single-service repo at root.
- **`review`** — audit current layout; report violations and promotion thresholds reached.
- **`place <description>`** — given a file description, return the canonical path. If unclear, escalate via Step 0.
- **`migration <topology> <verb> <desc>`** — generate a migration filename. `<topology>` ∈ {`shared`, `per-service`}.

---

## Boundaries

- Do not invent new folder names. If something doesn't fit any rule, escalate via Step 0.
- Do not enforce observability, lint, formatter, or test framework — out of scope.
- When promotion threshold is borderline, prefer not promoting; promotion is a one-way ratchet that adds folders.
- Do not force the use of any specific external SDK repo. `go-pkgs/infra/` is the default; remote SDK repos are opt-in.
