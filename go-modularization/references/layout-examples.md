# Layout examples and placeholder reference

Companion to [`SKILL.md`](../SKILL.md). Examples here are normative — when a rule
and an example disagree, the rule wins; report the mismatch.

## Placeholder slots

`<placeholder>` = slot to fill.

| Slot                 | Meaning                     | Example                                                         |
| -------------------- | --------------------------- | --------------------------------------------------------------- |
| `<service>`          | service name                | `orders`, `billing`                                             |
| `<inbound_adapter>`  | entry-point adapter         | `api`, `consumer`, `cli`, `grpc`/`ws`/`sse` (streaming, R-23)   |
| `<outbound_adapter>` | exit-point adapter          | `data_repositories`, `external_services`, `producer`, `storage` |
| `<layer>`            | inner layer                 | `domain`, `interactor`, `ports`                                 |
| `<context>`          | bounded context / aggregate | `order`, `product`, `user`                                      |
| `<resource>`         | API resource                | `users`, `invoices`                                             |
| `<provider>`         | external provider           | `taobao`, `amazon`, `s3`                                        |
| `<action>`           | verb                        | `publish`, `consume`, `connect`                                 |
| `<concern>`          | middleware concern          | `auth`, `logging`, `ratelimit`                                  |
| `<subject>`          | event domain subject        | `order`, `product`                                              |
| `<verb>`             | past-tense event verb       | `created`, `changed`, `completed`                               |
| `<N>`                | version int                 | `1`, `2`                                                        |
| `<domain>`           | utility domain prefix       | `string`, `time`, `slice`                                       |
| `<pkg>`              | package name                | `stringx`                                                       |
| `<org>`              | GitHub org / owner          | `acme`, `trypanic`                                              |

## Mature service — full tree

`services/orders/` exercising every rule. The `order` context is promoted in
`interactor/` (hit ≥10 files); `product` is still suffixed — mixed maturity is
correct, do not align.

```text
services/orders/
  cmd/
    main.go                                # wiring only: build deps, hand to cli
  internal/
    api/
      orders_handler_v1.go
      orders_handler_v2.go
      middleware_auth.go
      middleware_logging.go
    consumer/
      payment_completed_consumer.go        # event
      stock_level_poller_consumer.go       # polling also lives here
    cli/
      serve_command.go
      reindex_orders_command.go            # scheduled job, triggered externally
    domain/
      order.go                             # bare context name, no domain_ prefix
      product.go
    interactor/
      order/                               # promoted: >=10 files, suffix dropped
        interactor.go
        create.go
        cancel.go
        ...
      interactor_product.go                # not promoted yet
    ports/
      order_port.go
      order_port_mock.go                   # generated mock; not counted for thresholds
      product_port.go
    data_repositories/
      repository_order.go                  # schema-shaped (PG)
      repository_product.go
    storage/
      storage_invoice_pdf.go               # blob-shaped (S3)
    external_services/
      order_sync_taobao.go                 # <subject>_<action>_<provider>
    producer/
      order_created_producer.go
    contracts/                             # service-scoped: shared within orders only
      order_summary.go                     # used by api + interactor of this service
    config/
      config.go
```

`contracts/` here is the **service-scoped** tier (private to `orders`). It is
distinct from root `internal/contracts/`, which holds cross-service wire
payloads. A struct moves from this folder to root only when a *second service*
consumes it — see the Contract file section below.

## Before/after: context promotion

Before — `order` at 9 files in `interactor/` (borderline band → Step 0; user
approved promotion at 10):

```text
interactor/
  interactor_order.go        # + 8 more interactor_order_*.go files
  interactor_product.go
```

After — folder encodes the context, suffix dropped, all import sites updated
in the same change:

```text
interactor/
  order/
    interactor.go            # package order
    create.go
    cancel.go
  interactor_product.go      # untouched
```

Importers alias by layer when two layers expose the same context package:

```go
import (
    orderintr "example.com/repo/services/orders/internal/interactor/order"
    orderrepo "example.com/repo/services/orders/internal/data_repositories/order"
)
```

## Contract files — two scopes

Contracts are placed by **sharing scope** (R-21). Both folders use package
`contracts`; alias by scope when one file imports both.

**Cross-service** (root `internal/contracts/`) — wire payload shared by 2+
services. `internal/contracts/product_changed_event.go`, primitive/stdlib types
only, never imports `internal/kernel/`:

```go
package contracts

import "time"

type ProductChangedEvent struct {
    ProductID  string    `json:"product_id"`
    ChangedAt  time.Time `json:"changed_at"`
    PriceCents int64     `json:"price_cents"` // primitive, NOT kernel.Money
}
```

**Service-scoped** (`services/<service>/internal/contracts/`) — shared across
components of one service only, private to that service.
`services/orders/internal/contracts/order_summary.go`, same field-type
constraint (primitive/stdlib; no `domain/`, adapter, or `kernel/` imports):

```go
package contracts

type OrderSummary struct {
    OrderID    string `json:"order_id"`
    ItemCount  int    `json:"item_count"`
    TotalCents int64  `json:"total_cents"`
}
```

Promote `OrderSummary` to root `internal/contracts/` only when a *second
service* consumes it. A second service importing
`services/orders/internal/contracts` is a forbidden cross-service import — the
ban is what forces promotion.

## Multi-module workspace (topology B)

Same folder layout as the single-module monorepo — only `go.mod`/`go.work`
differ (ADR-22). A root `go.work` ties one module per shareable unit; services
`require` the shared modules, resolved locally by the workspace. Root
`internal/contracts/` is namespaced by **producing** service at scale.

```text
repo/
  go.work                          # use ( ./go-pkgs ./internal ./services/* )
  go.work.sum
  go-pkgs/
    go.mod                         # module: shared utils
    timex/now.go
  internal/
    go.mod                         # module: shared cross-service
    contracts/                     # cross-service wire payloads, by producer:
      orchestrator/                #   contracts the orchestrator service exposes
      worker/                      #   contracts the worker service exposes
    kernel/                        # shared business primitives
  services/
    orchestrator/
      go.mod                       # module: requires repo/internal, repo/go-pkgs
      cmd/main.go
      internal/{api,interactor,domain,ports,data_repositories,config}/
    worker/
      go.mod
      cmd/main.go
      internal/{external_services,interactor,domain,ports,config}/
  migrations/postgres/             # shared-DB layout, service token in filename
```

`go list ./...` only works from inside a module dir here (the root is not a
module), so `scripts/arch-checks.sh` scans each `use` dir. Cross-service
`internal/` imports are blocked twice: by the skill's dependency rule and by
Go's own `internal/` visibility (compile error).

## Counter-example: classic layout, annotated

```text
repo/
  pkg/                       # FORBIDDEN name -> go-pkgs/<domain>x
    utils/                   # FORBIDDEN name -> domain-prefixed go-pkgs package
      helpers.go
  internal/
    dto/                     # FORBIDDEN name -> by scope: adapter-local | services/<svc>/internal/contracts/ | root internal/contracts/ (2+ services)
    services/                # not a layer; business logic -> interactor/
  workers/                   # FORBIDDEN -> consumer/ (events, polling) + cli/ (scheduled)
  config/                    # no repo-root config -> services/<service>/internal/config/
  middleware/                # no top-level middleware -> <inbound_adapter>/middleware_*
  cmd/
    server/main.go           # multi-binary FORBIDDEN -> single cmd/main.go + cli/ subcommands
    worker/main.go
  scripts/
    migrate.go               # Go under scripts/ FORBIDDEN -> cli/ subcommand
```

## Streaming service — god-file, the split, and the proto leak

A bidirectional-stream service (gRPC/WebSocket/SSE) is a first-class inbound
adapter (R-23). Its trap is the **god-file**: one stream server accreting the
recv loop, the connection registry, wire↔domain translation, and the reclaim
reconciler until it is unreviewable.

Anti-pattern — everything in one file:

```text
internal/
  grpc/
    coordination_server.go     # ~800+ LOC: recv loop + per-conn session +
                               # registry + proto<->domain mapping + reclaim
                               # timers + sweeper — four responsibilities, one file
```

Split by responsibility (R-23) once one file passes ~400 LOC or a second
responsibility appears — suffix-style, no premature subfolders:

```text
internal/
  grpc/
    server.go                  # transport setup, keepalive, serve/shutdown
    coordination_server.go     # the stream handler: recv loop, frame routing
    session.go                 # connection-scoped state + live-connection registry
    translation.go             # wire <-> domain mapping (the ACL, R-26)
    coordination_reclaim.go    # reconciler coupled to the registry (started from cmd/)
  ports/
    coordination_port.go       # TaskSink etc. — a push/sink port the server
                               # IMPLEMENTS (driving adapter, R-27); interactor calls it
```

The per-connection `session` type MAY hold a domain entity (a credit ledger) and
satisfy `ports.TaskSink` — expected for a streaming server (R-27), not a
violation. The dependency stays `grpc → ports`, never `interactor → grpc`. A
stream **client** to one upstream is outbound: `grpc/client.go`.

Process-manager interactor (R-24) — role-named, no `interactor_` prefix, beside
the thin use cases:

```text
internal/
  interactor/
    interactor_session.go      # use case (admission gate, one workflow step)
    scheduler.go               # process manager: credit-bounded dispatch loop
    reconnector.go             # process manager: session-lifetime reconnect loop
    pipeline.go                # process manager: multi-layer scrape pipeline
```

Proto-leak counter-example (R-25) — the generated contract must NOT cross the
adapter boundary:

```go
// internal/interactor/pipeline.go
import (
    // FORBIDDEN (R-25): generated wire contract in an inner layer.
    // arch-checks.sh flags: inner-imports-contracts.
    coordinationv1 ".../internal/contracts/coordination/v1"
)

func (p *Pipeline) Run(ctx context.Context, t *coordinationv1.AssignTask) error // leaks the wire type inward
```

Fix — map at the adapter edge; the interactor speaks domain types:

```go
// internal/grpc/translation.go  (adapter)
func toAssignment(a *coordinationv1.AssignTask) domain.Assignment { ... }

// internal/interactor/pipeline.go  (inner — no proto import)
func (p *Pipeline) Run(ctx context.Context, a domain.Assignment) error
```

## Streaming client — the consumer side of the same contract

The client-side twin of the server split above. A service **consuming**
another service's versioned stream contract is in the consumer role: the
generated wire types are an external wire format like any other, translated in
the stream-client adapter (`grpc/translation.go` beside `grpc/client.go`) —
exactly mirroring the producer's server-side translation (R-25, R-26; see
"Contracts on the consumer side" in placement-rules).

```text
internal/
  grpc/
    client.go                  # transport: dial, stream open, reconnect/backoff
    translation.go             # wire <-> domain mapping (the consumer-side ACL)
  domain/
    stream_event.go            # sealed domain event sum the translation emits
  ports/
    coordination_port.go       # port speaks the domain sum, never a *pb type
```

The translation emits a **sealed domain event sum** — a closed set of domain
variants, one per frame kind the consumer understands:

```go
// internal/domain/stream_event.go
type StreamEvent interface{ isStreamEvent() }

type TaskAssigned struct{ Assignment Assignment }
type CreditGranted struct{ Credits int }
type StreamClosed struct{ Reason CloseReason }

func (TaskAssigned) isStreamEvent()  {}
func (CreditGranted) isStreamEvent() {}
func (StreamClosed) isStreamEvent()  {}
```

Before — the port speaks the wire type, so every consumer of the port must
import the generated contract (`inner-imports-contracts` fires, R-25):

```go
// internal/ports/coordination_port.go
import (
    // FORBIDDEN (R-25): wire type in a port signature.
    coordinationv1 ".../internal/contracts/coordination/v1"
)

type CoordinationStream interface {
    Recv(ctx context.Context) (*coordinationv1.Event, error) // wire leaks inward
}
```

After — de-wired: the port speaks the sealed sum; the adapter's translation
maps each wire frame to exactly one variant:

```go
// internal/ports/coordination_port.go  (inner — no contract import)
type CoordinationStream interface {
    Recv(ctx context.Context) (domain.StreamEvent, error)
}

// internal/grpc/translation.go  (adapter — the only place a wire enum is
// switched on)
func toStreamEvent(f *coordinationv1.Event) (domain.StreamEvent, error) { ... }
```

The interactor switches on the domain sum (`switch e := ev.(type)`), never on
a wire enum. A wire frame kind with no domain variant fails in translation —
at the edge, not in the core.

## Shim interactor — the pass-through, and both resolutions

A use-case interactor that only forwards arguments to a single port call — no
validation, no derivation, no composition, no policy — is a **shim** ("Shim
interactors: enrich or delete" in placement-rules). The workflow policy the
layer exists to hold is usually sitting in the caller.

Anti-pattern — the shim; the eligibility policy leaks into the handler:

```go
// internal/interactor/interactor_archive.go
// SHIM: one port call, nothing decided here.
func (i *ArchiveInteractor) Archive(ctx context.Context, id domain.OrderID) error {
    return i.archiver.Archive(ctx, id)
}

// internal/api/orders_handler_v1.go  (adapter — deciding, which adapters must not)
func (h *Handler) ArchiveOrder(w http.ResponseWriter, r *http.Request) {
    order, _ := h.orders.Get(r.Context(), orderID(r))
    if order.Status != domain.StatusSettled ||
        time.Since(order.ClosedAt) < 30*24*time.Hour { // business policy in the adapter
        http.Error(w, "not eligible", http.StatusConflict)
        return
    }
    _ = h.archive.Archive(r.Context(), order.ID) // ...then the shim forwards it
}
```

Resolution 1 — **enrich**: the policy moves into the interactor (the pure rule
into `domain/`); the handler goes back to decode-call-encode:

```go
// internal/domain/order.go  (pure rule: settled + retention window)
func (o Order) ArchiveEligible(now time.Time) error { ... }

// internal/interactor/interactor_archive.go  (earns its layer)
func (i *ArchiveInteractor) Archive(ctx context.Context, id domain.OrderID) error {
    order, err := i.orders.Get(ctx, id) // composition: 2 port calls
    if err != nil {
        return err
    }
    if err := order.ArchiveEligible(i.clock.Now()); err != nil { // invariant check
        return err
    }
    return i.archiver.Archive(ctx, id)
}

// internal/api/orders_handler_v1.go  (adapter: decode, call, encode — no policy)
func (h *Handler) ArchiveOrder(w http.ResponseWriter, r *http.Request) {
    err := h.archive.Archive(r.Context(), orderID(r))
    writeStatus(w, err) // map err -> status code, nothing decided here
}
```

Resolution 2 — **delete**: there is genuinely no policy anywhere between
transport and capability (or the datastore procedure owns it — the
enforcement-locus carve-out in placement-rules). Wire the caller to the port
directly via the sanctioned adapter→port→adapter mediation seam (R-27
erratum); do not keep the shim for the diagram:

```go
// cmd/main.go  (wiring: handler consumes ports.OrderArchiver directly)
handler := api.NewHandler(archiver)

// internal/api/orders_handler_v1.go
func (h *Handler) ArchiveOrder(w http.ResponseWriter, r *http.Request) {
    err := h.archiver.Archive(r.Context(), orderID(r)) // mediation seam
    writeStatus(w, err)
}
```

Delete is right when the operation truly is transport→capability with no
business decision in between. The moment a decision appears — eligibility,
derivation, ordering, a retry budget — switch to resolution 1: the policy
goes into the interactor, never into the handler.

## Migration filenames

Valid (shared layout, sequence global per technology):

```text
migrations/postgres/001_shared_create_auto_set_updated_at.up.sql
migrations/postgres/001_shared_create_auto_set_updated_at.down.sql
migrations/postgres/002_taobao_create_orders_table.up.sql
migrations/mongo/003_amazon_create_scraping_collections.js
```

Valid (per-service layout):

```text
migrations/orders/postgres/001_create_orders_table.up.sql
migrations/orders/mongo/003_create_scraping_collections.js
```

Invalid, with the violated rule:

```text
migrations/postgres/004_update_stuff.up.sql              # free-form verb; 'update' not in closed set
migrations/postgres/005_shared_taobao_create_x.up.sql    # shared + service combined
migrations/postgres/006_orders_lock_fix.up.sql           # verb as suffix
migrations/postgres/007_taobao_drop_create_x.up.sql      # multiple verbs
migrations/postgres/008_taobao_create_x.sql              # SQL without .up/.down polarity
```
