# Scaffolding: repo shapes, config, scripts

Read this file before creating a service or repo skeleton, placing config, or
placing scripts. Routing and invariants live in [`SKILL.md`](../SKILL.md) — the
forbidden-name and dependency rules there always apply.

## Pick repo shape

Two shapes. Same internal service skeleton.

**Monorepo (primary):**

```text
<repo-root>/
  services/<service>/
    cmd/main.go
    internal/
      <inbound_adapter>/         # api, consumer, cli
      <outbound_adapter>/        # data_repositories, external_services, producer, storage
      <layer>/                   # domain, interactor, ports
      contracts/                 # optional: service-scoped contracts (this service only)
      config/
    scripts/                     # optional, per-service
  go-pkgs/<pkg>/                 # shared Go utils, domain-prefixed
  internal/
    contracts/                   # cross-service event payloads (2+ services)
    kernel/                      # shared business primitives
  migrations/                    # see references/migrations.md
  infra/<technology>/            # declarative infra config (e.g. rabbit topology)
  scripts/                       # repo-root bash/python/sql
```

**Single-service repo (secondary):**

```text
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

Drop `services/`, `go-pkgs/`, `internal/contracts/`, `internal/kernel/`,
`migrations/<service>/` for single-service.

**Module topology:** two co-equal shapes, picked by scale. Folder layout, layer
rules, and dependency direction are identical in both — topology only governs
`go.mod`/`go.work`.

- **A — single-module** (simple default): one `go.mod` at the repo root; the
  whole repo is one module. Good for small monorepos and all single-service
  repos.
- **B — multi-module workspace** (scaled): a root `go.work` (no root `go.mod`)
  plus one `go.mod` per module — `go-pkgs/`, `internal/`, and each
  `services/<service>/`. `go.work` `use`s every module; each service `require`s
  the `internal/` and `go-pkgs/` module paths, resolved locally by the
  workspace. Better for per-service dependency sets, independent build/test, and
  smaller blast radius.

Multi-module **requires** a root `go.work`. Per-service `go.mod` without one
(orphan modules) is forbidden — it breaks local sharing of `internal/` and
`go-pkgs/`.

Topology B skeleton (same folders as the monorepo tree above, plus module
files):

```text
<repo-root>/
  go.work                        # use ( ./go-pkgs ./internal ./services/* )
  go-pkgs/go.mod
  internal/
    go.mod                       # shared cross-service module
    contracts/                   # cross-service; namespace by producer at scale: contracts/<service>/
    kernel/
  services/<service>/
    go.mod                       # one module per service; requires internal + go-pkgs
    cmd/main.go
    internal/ ...
```

**Two `contracts/` folders, different scopes** (see R-21 / `shared-code.md`):
`services/<service>/internal/contracts/` holds contracts shared within that one
service (private to it); root `internal/contracts/` holds wire payloads shared
across 2+ services. Both are created on first need, never empty. In a
single-service repo there is no cross-service tier, so the lone
`internal/contracts/` carries the service-scoped meaning.

## Scaffolding is need-based

Create only `cmd/`, `internal/domain/`, `internal/interactor/`,
`internal/ports/`, `internal/config/`, plus the adapters the user named.
Other adapter folders are created on first need — never empty.

## Config

Per-service only, always under `internal/`:

- Monorepo: `services/<service>/internal/config/`.
- Single-service: `internal/config/`.

**No monorepo-root `config/` folder.**

## Scripts

`scripts/` holds **bash, Python, SQL only**. Never Go.

- Monorepo: `scripts/` at root + optional `services/<service>/scripts/`.
- Single-service: `scripts/` at root.

Go-runtime tasks → CLI subcommand under `cli/` (see
[`placement-rules.md`](placement-rules.md)).
