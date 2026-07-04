# Shared code: go-pkgs/, internal/kernel/, internal/contracts/, SDK repos

Read this file before adding or moving code under `go-pkgs/` or root
`internal/`, or extracting shared/reusable code of any kind.

## go-pkgs/ (monorepo, never `pkg/`)

- Generic, reusable Go utilities, domain-organized.
- One subfolder per package: `go-pkgs/<pkg>/<action>.go`.
- Package form: `<domain>x` when extending a stdlib package of the same name
  (`stringx` → `strings`, `timex` → `time`, `mathx`, `randx`, `slicex`);
  `<domain>kit` when there is no stdlib counterpart (`errorkit`, `urlkit`).
- File form: `<action>.go` (`publish.go`, `parse.go`, `format.go`).
- Stdlib-only ideal. No business logic. No IO.
- Must never contain business types, service config shapes, or imports from
  `services/...` or root `internal/`.
- **Never shadow a stdlib name.** A shared package (any shared tier: `go-pkgs/`,
  root `internal/`) must not take a Go standard-library package's name
  (`slices`, `maps`, `strings`, `errors`, `time`, ...). A shadowing name reads
  as stdlib at every call site and forces aliasing on import — use the
  `<domain>x`/`<domain>kit` forms above (`slicex`, never `slices`). Enforced by
  `scripts/arch-checks.sh` as `stdlib-shadow-name`.
- **Generic-utility names only.** A `go-pkgs/` package name must be a
  generic-utility name, never a business/domain noun. A business noun in
  `go-pkgs/` is mis-tiered, not mis-named: the code belongs in
  `internal/kernel/` (if it is a shared business primitive meeting the kernel
  admission criteria below) or inside the owning service.

## Reusable infrastructure — placement precedence

(DB clients, HTTP servers/clients, brokers, observability, blob, migration
runners.)

1. **Primary: `go-pkgs/infra/<pkg>/`.** Default placement. Keeps the infra code
   in-repo, shareable across services in this monorepo, and avoids premature
   extraction. One infra concern per package — a package mixing two concerns
   (e.g. http + retry) must split.
2. **Secondary: contribute to an existing community SDK repo** if one already
   covers the concern (e.g. `github.com/trypanic/go-sdk`). Use when the piece
   is generic enough to benefit other consumers. Before recommending, verify
   the repo exists and covers the concern (read its README) — do not assume it
   from this example.
3. **Tertiary: create a dedicated org-owned SDK repo**
   (`github.com/<org>/go-sdk` or similar) when the infra surface is large
   enough to justify its own release lifecycle, versioning, and CI. Consume via
   `go.mod`. The SDK repo never imports from this repo.

No one is forced to use any particular SDK repo. The default for new infra is
always `go-pkgs/infra/`.

## Root internal/ (monorepo, two folders only)

Root `internal/` is for **cross-service** sharing and admits **exactly two
children**: `contracts/` and `kernel/`. Anything else is a violation
regardless of content — this is a hard occupancy rule, not a judgment call.
Route a would-be third child by its nature: a generic utility goes to
`go-pkgs/`; a shared business primitive meeting the kernel admission criteria
goes to `internal/kernel/`; single-consumer code moves into the owning
service. Enforced by `scripts/arch-checks.sh` as `root-internal-occupancy`.

- `internal/contracts/` — **cross-service** event/message wire payloads (shared
  by 2+ services). File form: `<subject>_<verb>_event.go` (e.g.
  `product_changed_event.go`). Structs use primitive/stdlib types only; never
  import `internal/kernel/`.
- `internal/kernel/` — shared business primitives (`Money`, IDs, value
  objects). Promote here only when 2+ services already consume the type, the
  contract is stable, and changes are rare. Until then, duplicate per-service.
  Kernel is cross-service by definition — no per-service tier.

Forbidden names for cross-service shared payloads: `internal/messages/`,
`internal/events/`, `internal/dto/`.

## Shared-tier admission: ≥2 verified importers

Code enters a shared tier (root `internal/`, `go-pkgs/`) only with **at least
two actual importing services today, verified by import listing** — "will be
shared someday" does not qualify. A shared package with a single importing
service is demoted: move it into its one consumer. `scripts/arch-checks.sh`
reports the importer count of every shared-tier package as
`shared-tier-importer-count` (report-only warning; a zero-importer shared
package is flagged as possible dead shared code).

## Contract scope — three tiers (not just root)

Contracts/DTOs are placed by **sharing scope**, not by being a DTO. A struct
climbs this ladder only when a real consumer crosses the next boundary — never
speculatively:

1. **Adapter-local** — used by one adapter only → stays in that adapter
   package. No shared folder.
2. **Service-scoped** — shared across 2+ components *within one service* (e.g.
   an interactor and two of its adapters) → `services/<service>/internal/contracts/`
   (monorepo) or `internal/contracts/` (single-service repo). Package
   `contracts`. **Private to its owning service** — service B must never import
   service A's contracts (cross-service import ban). Same field-type constraint
   as root: primitive/stdlib only; no `domain/`, `interactor/`, adapter, or
   `kernel/` imports.
3. **Cross-service** — shared by 2+ services → root `internal/contracts/`
   (above). Monorepo only.

A struct does not move to root `internal/contracts/` until a *second service*
consumes it. Naming collision: both the service-scoped folder and root use
package `contracts`; alias by scope when one file imports both.

## Decision: which destination?

- Pure stdlib helper, no business meaning → `go-pkgs/<domain>x/` or
  `go-pkgs/<domain>kit/`.
- Reusable infra → `go-pkgs/infra/<pkg>/` (tiers above).
- Business primitive shared by 2+ services, stable contract → `internal/kernel/`.
- Wire payload shared by 2+ services → root `internal/contracts/`.
- Contract shared across components within one service → that service's
  `services/<service>/internal/contracts/` (single-service: `internal/contracts/`).
- DTO used by one adapter only → keep it local to that adapter package.
- Unclear tier → Step 0.
