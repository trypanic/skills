# Placement rules: contexts, versions, middleware, adapters, promotion

Read this file before placing, naming, or promoting source files, or adding an
adapter. Routing flowcharts, thresholds, and the dependency/forbidden-name
invariants live in [`SKILL.md`](../SKILL.md).

## Bounded context: suffix, then promote

Default in-folder suffix:

```text
domain/
  order.go
  product.go
interactor/
  interactor_order.go
  interactor_product.go
data_repositories/
  repository_order.go
  repository_product.go
```

`domain/` files take the bare context name — `domain/<context>.go`, no
`domain_` prefix. All other layers and adapters prefix the layer noun
(`interactor_`, `repository_`, `storage_`).

Promote to subfolder when one context reaches ≥10 files in that layer
(Counting rule, SKILL.md):

```text
interactor/
  order/interactor.go            # context suffix dropped
  order/<more files>.go
  product/interactor.go
```

**Forbidden:** combined-context suffix `<contextA>_<contextB>.go`
(e.g. `order_product.go`).

**Identifying a context:** a noun that owns its invariants and lifecycle. Two
candidates that always change in the same PR are one context. A use case that
writes the state of 2+ contexts → Step 0.

**Promotion mechanics:** promotion updates all import sites in the same change.
In a repo with external consumers, promoting an exported package changes import
paths — breaking change → Step 0. Promotion state is per-layer per-service;
mixed maturity across services (one promoted, another still suffixed) is
correct — do not align. Promoted package name = context (`package order`);
importers alias by layer when two layers expose the same context package
(`orderintr`, `orderrepo`).

## API versioning: suffix, then promote

```text
api/
  users_handler_v1.go
  users_handler_v2.go
```

Promote when one version reaches ≥5 files:

```text
api/
  v1/users_handler.go            # version suffix dropped
  v2/users_handler.go
```

## Middleware lives with its adapter

```text
api/
  middleware_auth.go
  middleware_logging.go
```

Promote when ≥4 middleware files for one adapter:

```text
api/
  middleware/
    auth.go                      # concern suffix dropped
    logging.go
```

**No top-level `middleware/` folder.**

## Outbound adapter rules

| Adapter              | Shape                                | File form (flat)                   | Promotion                                                                                                                                   |
| -------------------- | ------------------------------------ | ---------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| `data_repositories/` | schema-shaped (PG, Mongo, Redis, ES) | `repository_<context>.go`          | per-context subfolder at ≥10 files                                                                                                          |
| `storage/`           | blob-shaped (S3, GCS, local FS)      | `storage_<context>.go`             | per-context subfolder at ≥10 files                                                                                                          |
| `external_services/` | third-party APIs                     | `<subject>_<action>_<provider>.go` | `external_services/<provider>/` at ≥10 files, ≥3 provider-specific infra files, or distinct lifecycle — drop provider from filenames inside |
| `producer/`          | outbound events                      | `<subject>_<verb>_producer.go`     | per-context subfolder                                                                                                                       |

`data_repositories/` vs `storage/` split is **by data shape**, not SQL/NoSQL or
in-memory/persisted. Decision test: accessed through a query language, typed
fields, or indexes → `data_repositories/`; opaque bytes addressed by key/path →
`storage/`. Redis with hashes/sets/typed structures → `data_repositories/`;
Redis as byte-blob cache → `storage/`.

Distinct lifecycle (promotion trigger above) = provider needs its own
client/auth/session init or its own retry/rate-limit infra files.

## Inbound adapter rules

| Adapter     | Files                          | Notes                                           |
| ----------- | ------------------------------ | ----------------------------------------------- |
| `api/`      | `<resource>_handler_v<N>.go`   | promote to `api/v<N>/` at ≥5 files              |
| `consumer/` | `<subject>_<verb>_consumer.go` | events + polling go here                        |
| `cli/`      | `<action>_command.go`          | CLI subcommands, parallel to `api/`/`consumer/` |

`api/` is HTTP only. gRPC, GraphQL, WebSocket = new inbound adapter kind →
Step 0 (candidate names: `grpc/`, `graphql/`, `ws/`).

**Single binary per service**: `cmd/main.go` only. All subcommands (server,
scheduled jobs, one-off tasks, Go-runtime migrations) live inside `cli/`.
Cobra is the default for new services; if the service already uses another CLI
framework, keep it — folder rules unchanged. `cmd/` is wiring only.

**Background work routing**: events → `consumer/`. Scheduled → CLI subcommand
under `cli/`, triggered externally. Polling → `consumer/`. **No `workers/`
folder.**

## Ports, tests, mocks

`ports/` file form: `<context>_port.go`. One port per outbound dependency the
interactor uses; no ports for inbound adapters; no port without an interactor
consumer.

`_test.go` lives next to the code under test; `testdata/` allowed anywhere (Go
convention). Mocks of ports: `ports/<context>_port_mock.go`. Test and generated
files never count toward promotion thresholds.
