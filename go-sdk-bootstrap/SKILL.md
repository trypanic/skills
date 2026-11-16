---
name: go-sdk-bootstrap
description: Scaffold, extend, or migrate to v2 a Go service that imports github.com/trypanic/go-sdk/v2. Encodes the canonical v2 wiring (signal-aware run(ctx), bounded startup/shutdown, logger/otlp + logger + telemetry + httpclient + httprequest + postgres + messaging), the tracing constructor triplet and its exceptions, errorkit.As/HasCode wrapping, and the v1→v2 renames (/v2 module path, postgres/mongo identifiers, slices→batch). Use when the user says "new service using trypanic", "bootstrap a trypanic go service", "wire up trypanic go-sdk", "scaffold service with go-sdk", "set up logger and tracer from trypanic", "wire postgres/messaging/httpclient from go-sdk", "migrate to go-sdk v2", or asks to start, wire, or upgrade a Go service around github.com/trypanic/go-sdk. Auto-trigger when a Go file first imports github.com/trypanic/go-sdk/v2, when go.mod adds it, or when a project still imports the v1 path (no /v2). Do NOT trigger for unrelated Go projects or inside the go-sdk repo.
---

# go-sdk-bootstrap

Scaffold, extend, or migrate a Go service that depends on `github.com/trypanic/go-sdk/v2`. The skill encodes the conventions an agent cannot derive from `go doc` alone: which constructor produces which tracing behavior, which constructors read the environment, the order in which the OTLP provider, logger, instrumenter, and pools are wired and torn down, and which v1 names no longer exist.

Targets **go-sdk v2.0.0**. The module path is `github.com/trypanic/go-sdk/v2`; the repository URL stays `https://github.com/trypanic/go-sdk`, because `/v2` belongs only to the Go module path.

Canonical references (read them directly when in doubt; package READMEs are the authoritative contracts):
- [AGENTS.md](https://github.com/trypanic/go-sdk/blob/main/AGENTS.md)
- [llms.txt](https://github.com/trypanic/go-sdk/blob/main/llms.txt)
- [v2 API migration](https://github.com/trypanic/go-sdk/blob/main/docs/v2-api-migration.md)
- [CHANGELOG](https://github.com/trypanic/go-sdk/blob/main/CHANGELOG.md) (behavioral breaking changes of 2.0.0)

---

## When to use

Trigger on natural-language phrases like:
- "new Go service using trypanic"
- "wire up `go-sdk` in a new project"
- "bootstrap a service with logger + tracer + postgres from `go-sdk`"
- "scaffold the `main.go` for a trypanic service"
- "add `messaging` / `httprequest` / `postgres` to my service"
- "set up OTLP + zerolog using `trypanic/go-sdk`"
- "migrate this service to `go-sdk` v2"

Auto-trigger when:
- A new Go file imports `github.com/trypanic/go-sdk/v2/...` for the first time.
- `go.mod` adds `github.com/trypanic/go-sdk/v2` as a dependency.
- A project still imports the v1 path `github.com/trypanic/go-sdk/...` (without `/v2`). Go to [Migrating a v1 service](#migrating-a-v1-service).

Do **not** trigger for:
- Unrelated Go projects that do not import `trypanic/go-sdk`.
- Internal SDK changes inside the `go-sdk` repository itself (use the SDK's own `AGENTS.md` directly there).

---

## Step 1 — Confirm Go module and toolchain

The SDK's language floor is Go `1.26.1`; use a patched Go 1.26 (at least `1.26.10`) or Go 1.27. The `go` directive in the service's `go.mod` must be at least `1.26.1`.

If the project has no `go.mod`, init one before adding the dependency:

```bash
go mod init github.com/<org>/<service>
```

Add the SDK:

```bash
go get github.com/trypanic/go-sdk/v2@latest
```

> ⚠️ `go get github.com/trypanic/go-sdk@latest` (without `/v2`) silently resolves to **v1.0.1**: Go treats every major version from v2 on as a separate module path. Never mix both majors in one module.

---

## Step 2 — Pick the right packages

Map task to import. In v2 every package identifier matches its directory.

| You need to…                                            | Import path                                          | Package identifier |
|---------------------------------------------------------|------------------------------------------------------|--------------------|
| Classified errors and client-safe serialization         | `github.com/trypanic/go-sdk/v2/errorkit`             | `errorkit`         |
| Structured logging and trace correlation                | `github.com/trypanic/go-sdk/v2/logger`               | `logger`           |
| OTLP log export and provider lifecycle                  | `github.com/trypanic/go-sdk/v2/logger/otlp`          | `otlp`             |
| Span factory (`Instrumenter`)                           | `github.com/trypanic/go-sdk/v2/telemetry`            | `telemetry`        |
| Outbound HTTP client (pool, timeouts, TLS)              | `github.com/trypanic/go-sdk/v2/httpclient`           | `httpclient`       |
| Outbound HTTP requests (bounded retries, classification)| `github.com/trypanic/go-sdk/v2/httprequest`          | `httprequest`      |
| HTTP routing contracts and replies                      | `github.com/trypanic/go-sdk/v2/httpserver`           | `httpserver`       |
| HTTP server (Hertz)                                     | `github.com/trypanic/go-sdk/v2/httpserver/hertz`     | `hertz`            |
| gRPC server + client (4 call modes)                     | `github.com/trypanic/go-sdk/v2/grpc`                 | `grpc` (alias `sdkgrpc`) |
| PostgreSQL pool and stored procedures                   | `github.com/trypanic/go-sdk/v2/postgres`             | `postgres`         |
| MongoDB                                                 | `github.com/trypanic/go-sdk/v2/mongo`                | `mongo`            |
| RabbitMQ pub/sub                                        | `github.com/trypanic/go-sdk/v2/messaging`            | `messaging`        |
| KV / append-only storage                                | `github.com/trypanic/go-sdk/v2/storage`              | `storage`          |
| OpenAI-compatible chat (non-streaming)                  | `github.com/trypanic/go-sdk/v2/llmclient`            | `llmclient`        |
| Typed env loading                                       | `github.com/trypanic/go-sdk/v2/envs`                 | `envs`             |
| Test doubles                                            | `.../v2/httpserver/httpservertest`, `.../v2/mongo/mongotest`, `.../v2/messaging/messagingtest` | directory name |
| JSON encoding without HTML escaping                     | `github.com/trypanic/go-sdk/v2/marshal`              | `marshal`          |
| String normalization / markdown stripping               | `github.com/trypanic/go-sdk/v2/stringutils`          | `stringutils`      |
| URL building / path joining                             | `github.com/trypanic/go-sdk/v2/urlkit`               | `urlkit`           |
| Input validation (dates, alphanumeric strings, ranges)  | `github.com/trypanic/go-sdk/v2/validators`           | `validators`       |
| Bounded chunks and stable deduplication                 | `github.com/trypanic/go-sdk/v2/batch`                | `batch`            |
| Exponential backoff for custom retry loops              | `github.com/trypanic/go-sdk/v2/algorithms`           | `algorithms`       |

Aliases:
- `sdkgrpc` for the SDK `grpc` package when the file also imports `google.golang.org/grpc`.
- `mongodriver` for the upstream MongoDB driver when the file also imports the SDK `mongo` package.

The v1 identifiers `database` (for `postgres/`) and `mongodb` (for `mongo/`) and the `slices` package are **removed** with no compatibility alias. A compiler error such as `undefined: database` means v1 code: see [Migrating a v1 service](#migrating-a-v1-service).

The last six rows (`marshal` … `algorithms`) are pure utility helpers: no constructor triplet, no instrumenter, no tracing — import and call directly.

---

## Step 3 — Apply the canonical bootstrap

Use [`references/canonical-bootstrap.go.tmpl`](references/canonical-bootstrap.go.tmpl) as `cmd/main.go` (single-service repo) or `services/<service>/cmd/main.go` (monorepo). It is derived from the SDK's `AGENTS.md` §3, verified with `go build` and `go vet` against `v2.0.0`, and follows these invariants:

1. `main` owns only the signal-aware root context (`signal.NotifyContext`) and the exit code. All wiring lives in `run(ctx) error`, so deferred cleanups always execute.
2. Network setup is bounded by a startup context passed to the `*Context` constructors (`postgres.NewFromEnvContext`, `messaging.NewPubSubFromEnvContext`, `otlp.NewProvider`). Shutdown uses a fresh bounded context (`context.WithoutCancel` + timeout), so a cancelled root context never skips flushing.
3. `otlp.NewProvider` runs **before** `logger.Init`, and `otlp.NewWriter(serviceName)` is passed to `logger.Init`. The caller owns the provider and closes it last.
4. `serviceName` is the same string passed to the OTLP provider, the logger, and the telemetry instrumenter — logs and traces correlate by service name.
5. One `*telemetry.Instrumenter` is constructed once and passed to every package that takes one (`httprequest.NewWithInstrumenter`, `llmclient.NewWithInstrumenter`, `mongo.NewWithInstrumenter`, `postgres.WrapWithInstrumenter[T]`, `messaging.WithInstrumenter`, `grpc.WithServerInstrumenter` / `WithClientInstrumenter`).
6. Clients and pools (`*http.Client`, `*pgxpool.Pool`, `*messaging.PubSub`) are constructed once at `run` scope and shared across handlers. **Never** per request.
7. All `Close` / `Shutdown` calls are deferred in `run`, in reverse construction order, and their errors are logged instead of dropped.

Environment reads are explicit API choices in v2:

| Source                                   | Reads                                               |
|------------------------------------------|-----------------------------------------------------|
| `envs.Load[T]()` / `envs.LoadInto(&cfg)` | The service's own typed config (struct `env` tags)  |
| `postgres.NewFromEnv` / `NewFromEnvContext` | `POSTGRES_DSN` (`postgres.DSNEnvVar`)            |
| `messaging.NewPubSubFromEnv` / `NewPubSubFromEnvContext` | `RABBITMQ_TOPOLOGY_FILE`            |
| `llmclient.ConfigFromEnv()`              | `LLM_API_KEY`, optional `LLM_ENDPOINT`              |
| `logger.Init` / `logger.DetectEnv`       | `ENVIRONMENT` (unset → Prod: JSON, Info; `development`/`dev`/`local` → console) |

Plain `messaging.NewPubSub` never reads the environment: it requires `WithTopology` or `WithTopologyFile` and otherwise fails with `ERR_SYSTEM_CONFIG_INVALID`.

The SDK does **not** install an OpenTelemetry `TracerProvider`. Without one, every span is a no-op. Install the service's trace provider (for example an OTLP trace exporter) before `telemetry.NewInstrumenter`, or pass it as `InstrumenterConfig.TracerProvider`.

---

## Step 4 — Tracing constructor triplet (and exceptions)

For packages that produce spans with integrated tracing:

| Package       | `New` (global OTel provider) | `NewWithoutTracing` (no spans) | `NewWithInstrumenter` (caller's instrumenter; `nil` disables) |
|---------------|------------------------------|--------------------------------|---------------------------------------------------------------|
| `httprequest` | `New(client)`                | `NewWithoutTracing(client)`    | `NewWithInstrumenter(client, instr)`                          |
| `llmclient`   | `New(requester, cfg)`        | `NewWithoutTracing(requester, cfg)` | `NewWithInstrumenter(requester, cfg, instr)`             |
| `mongo`       | `New(ctx, cfg, opts...)`     | `NewWithoutTracing(ctx, cfg, opts...)` | `NewWithInstrumenter(ctx, cfg, instr, opts...)`       |

`NewWithInstrumenter` is preferred in production. Notes:

- These constructors return **concrete adapters** (`*httprequest.Request`, `*llmclient.Client`, `*mongo.Client`). Accept narrow interfaces at consumer boundaries (`httprequest.Requester`, `llmclient.Provider`, `messaging.Broker`).
- `httprequest.NewWithOptions(client, opts...)` starts **untraced**: add `httprequest.WithInstrumenter(instr)` next to `WithRetryConfig` / `WithAuditLog`.
- `WrapWithInstrumenter` (in `httprequest`, `llmclient`, `mongo`, `postgres`) adds a span layer. Do not wrap an already traced client unless nested spans are intended. The `llmclient` span `external.llm.execute` is intentionally the parent of the traced requester's HTTP span.
- `mongo.NewFromClient(driverClient, database, instr)` **borrows** the driver: its owner calls `Disconnect`; the adapter's `Close` does not.

**Exceptions:**

- `postgres` — the pool constructors (`New`, `NewContext`, `NewFromEnv`, `NewFromEnvContext`) add no spans; pgx driver tracing is caller-configured. `NewStoredProcedure[T](pool)` returns a `*TracedProcedure[T]` that is **already traced** with the global provider — do not wrap it again (two spans per call). To use the shared instrumenter, wrap an untraced value: `postgres.WrapWithInstrumenter[T](postgres.StoredProcedure[T]{Pool: pool}, instr)`. `Unwrap` exposes the inner procedure.
- `messaging` — pass `messaging.WithInstrumenter(instr)` (`nil` disables tracing). `messaging.WithTracer(tracer)` remains available; with neither, the global OTel provider is used.
- `grpc` — **no triplet.** Server (`grpc.New(cfg, opts...)`) and client (`grpc.Dial(cfg, opts...)`) take functional options. Tracing is on by default via the `otelgrpc` stats handler (all four call modes); use `grpc.WithServerInstrumenter(instr)` / `grpc.WithClientInstrumenter(instr)` (`nil` disables), or `WithServerTracing(bool)` / `WithClientTracing(bool)` and `WithServerTracerProvider(tp)` / `WithClientTracerProvider(tp)`. **Transport credentials are required**: set `ServerConfig.Creds` / `ClientConfig.Creds`, or pass `grpc.WithServerInsecure()` / `grpc.WithClientInsecure()` explicitly — otherwise construction fails with `ERR_SYSTEM_CONFIG_INVALID`. Register generated services on `srv.Registrar()`; `ListenAndServe()` (uses `ServerConfig.Address`) and `Serve(lis)` block; `Shutdown(ctx)` drains.
- `httpserver/hertz` — uses the global OTel provider; there is no instrumenter injection. `Run` does **not** handle `SIGINT` / `SIGTERM` and returns an error when it cannot listen: stop the server with `Shutdown(ctx)` after the root context is done. Keep `ServerOptions.EnableRecovery` true (the default). The default `EnableAudit=true` logs one redacted info line per inbound request.

**Span naming:** create spans with the instrumenter methods `instr.Job`, `instr.Batch`, `instr.External`, `instr.Messaging`, `instr.DB` (the package-level `telemetry.Job` … functions are compatibility wrappers over a global instrumenter). End client spans with `telemetry.End(span, err)` so failures carry the classified error status. Do not invent ad-hoc span names, and never put payloads, credentials, private reasons, or resource IDs in a span name.

SDK span names in v2 (update dashboards and alerts built on v1 names):

| Source        | Span name                                                     |
|---------------|---------------------------------------------------------------|
| HTTP          | `external.http.<host>.<METHOD>` (path is an attribute)        |
| LLM           | `external.llm.execute` (model is an attribute)                |
| PostgreSQL    | `postgres.<routine>.query`                                    |
| MongoDB       | `mongo.<collection>.<operation>`, `mongo.client.<operation>`  |
| Messaging     | `messaging.<op>.<queue>`                                      |

---

## Step 5 — Errors

SDK-classified operation failures normally return an `error` containing an `*errorkit.AppError` (code, HTTP status, retriability). Do **not** assume every error has that dynamic type: upstream escape hatches (`*http.Client`, pgx pools, the Mongo driver, gRPC connections), user handlers and callbacks, generated gRPC clients, Hertz `Shutdown`, and OTLP provider cleanup can return raw errors. The rules:

- **Wrap once**, at the boundary between your code and an external library.
- **Preserve an existing `*AppError` anywhere in the chain.** Find it with `errorkit.As(err)`, never with a direct type assertion `err.(*errorkit.AppError)`, which misses wrapped and joined errors. Re-wrapping an `*AppError` with `ERR_INTERNAL` destroys its code, HTTP status, and retriability.
- **Match on codes, not text.** Use `errorkit.HasCode(err, code)` or `Metadata.Retriable`. For example, `messaging` `Publish` now returns the specific `ERR_MQ_*` cause instead of always `ERR_MQ_PUBLISH_FAILED`.

```go
result, err := svc.Do(ctx, input)
if err != nil {
    if appErr, ok := errorkit.As(err); ok {
        logger.ErrorCtx(ctx, appErr, "svc.Do failed")
        return appErr
    }
    wrapped := errorkit.NewError(errorkit.ERR_INTERNAL).
        With(errorkit.WithWrapped(err))
    logger.ErrorCtx(ctx, wrapped, "svc.Do failed")
    return wrapped
}
```

- For service-specific failure modes, register codes once during service initialization, for example in `init()`:

```go
func init() {
    errorkit.MustRegister(errorkit.Metadata{
        Code:        "ERR_BILLING_PROVIDER_DOWN",
        Type:        errorkit.ErrorTypeExternal,
        Group:       errorkit.GroupUnknown,
        Category:    "billing",
        Description: "Billing provider is unreachable",
        HTTPStatus:  503,
        Retriable:   true,
    })
}
```

- `errorkit.NewError(code)` captures a stack; `errorkit.NewWithoutStack(code)` omits it and is meant for expected input rejection.
- Responses to clients: in HTTP handlers use `httpserver.ReplyError(c, err)`, or serialize `appErr.PublicJSON()` with the status from `httpserver.StatusFor(err)`. In gRPC handlers return `sdkgrpc.ToStatus(err)`; classify received statuses with `sdkgrpc.FromStatus(err)`. Never send `PrettyJSON`, stack traces, or wrapped driver diagnostics to a client.

Do **not** patch the SDK's `codes.go` from outside the SDK repo.

---

## Step 6 — Anti-patterns to refuse

When generating code, **do not** produce any of the following (based on `AGENTS.md` §5):

- Importing `github.com/trypanic/go-sdk/...` without `/v2`, or mixing v1 and v2 in one module.
- Using removed v1 names: `database.*`, `mongodb.*`, `slices.*`, `logger.SetupOTLP`, `NewPostgresClient*`, `NewHTTPRequestWithRetry`, `HTTPRequester`, `Messager`, `LLMProvider`, `envs.NewLoader`.
- A new `*http.Client`, pgx pool, or messaging connection per request (defeats the connection pool).
- Replacing a classified error with generic `ERR_INTERNAL`, or detecting an `*AppError` with a direct type assertion.
- Logging inside every retry attempt and again at the caller. `httprequest` does not log the errors it returns; use `httprequest.WithAuditLog()` for one line per attempt.
- Retrying POST / PATCH after uncertain delivery without an idempotency contract (an `Idempotency-Key` header, or `RetryConfig.RetryNonIdempotent` with explicit acceptance of duplicate side effects).
- Reading environment variables implicitly or ad hoc at SDK call sites. Read service config once with `envs.Load[T]()` and use the documented `*FromEnv` constructors for SDK-owned variables.
- `httprequest.WithRawBodies()` or `import "github.com/trypanic/go-sdk/v2/ioutils"` on a production data path — both are dev-only.
- Importing `httpserver/hertz` (or `grpc`) from non-server code, which pulls Hertz / `google.golang.org/grpc` into the binary, or importing `logger/otlp` solely for base logging.
- Closing a borrowed Mongo driver client from its wrapper.
- Wrapping the result of `postgres.NewStoredProcedure[T]` again (two spans per call).
- `telemetry.InitTracer(...)` in new code — compatibility API only; use `telemetry.NewInstrumenter`.

If the user is asking for one of these, push back, cite the rule, and offer the correct alternative.

---

## Step 7 — Verify

After scaffolding, the agent should:

1. Run `go build ./...` to confirm imports resolve.
2. Run `go vet ./...`.
3. Run `go test -short ./...` — it must not contact external services.
4. Confirm no v1 import remains: `grep -rn '"github.com/trypanic/go-sdk/' --include='*.go' . | grep -v '/go-sdk/v2/'` prints nothing, and `go.mod` requires only `github.com/trypanic/go-sdk/v2`.
5. If the project sets up the static-analysis stack, run the `go-code-quality-check` skill.
6. Check that all `defer Close()` / `defer Shutdown()` calls are in `run`, not in the constructor's caller.

Report back: list of files created, list of imports added, and any place where the user must still fill in a value — `OTEL_COLLECTOR_ENDPOINT`, `RABBITMQ_URL`, `RABBITMQ_TOPOLOGY_FILE`, `POSTGRES_DSN`, `ENVIRONMENT` (`development` for console logs), `LLM_API_KEY` / `LLM_ENDPOINT` when `llmclient` is used — and whether the service still needs its own OTel trace provider.

---

## Migrating a v1 service

1. **Module and imports.** Run `go get github.com/trypanic/go-sdk/v2@latest`, rewrite every SDK import (tests, test doubles, and `logger/otlp` included), then `go mod tidy` to drop the v1 requirement. A safe mechanical rewrite (GNU `sed`; on macOS use `sed -i ''`), idempotent on imports that already carry `/v2`:

   ```bash
   grep -rl '"github.com/trypanic/go-sdk/' --include='*.go' . | xargs sed -i \
     -e 's#"github.com/trypanic/go-sdk/#"github.com/trypanic/go-sdk/v2/#' \
     -e 's#/go-sdk/v2/v2/#/go-sdk/v2/#' \
     -e 's#"github.com/trypanic/go-sdk/v2/slices"#"github.com/trypanic/go-sdk/v2/batch"#'
   ```

2. **Renamed APIs** (no compatibility aliases remain):

   | v1                                                              | v2                                                                    |
   |-----------------------------------------------------------------|-----------------------------------------------------------------------|
   | `database.NewPostgresClient`, `NewPostgresClientFromEnv`        | `postgres.New`, `NewFromEnv` (plus `NewContext`, `NewFromEnvContext`) |
   | `database.PostgresEnvVar`                                       | `postgres.DSNEnvVar`                                                  |
   | `mongodb.*`                                                     | `mongo.*` (alias the upstream driver as `mongodriver`)                |
   | `slices.Chunk`, `slices.MergeUniqueStrings`                     | `batch.Chunk`, `batch.MergeUniqueStrings`                             |
   | `logger.SetupOTLP`, `logger.InitLogProvider`                    | `otlp.Setup`, `otlp.InitProvider` (strict TLS: `otlp.NewProvider`)    |
   | `logger.NewOTLPWriter`, `logger.OTLPWriter`, `logger.LogProviderHandle` | `otlp.NewWriter`, `otlp.Writer`, `otlp.Provider`              |
   | `httprequest.HTTPRequest`, `HTTPRequester`                      | `httprequest.Request`, `Requester`                                    |
   | `httprequest.NewHTTPRequestWithRetry(client, rc)`               | `httprequest.NewWithOptions(client, WithRetryConfig(rc), WithInstrumenter(instr))` |
   | `httpserver.HTTPServer`, `HTTPContext`                          | `httpserver.Server`, `Context`                                        |
   | `llmclient.LLMProvider`, `LLMRequest`, `LLMRequestConfig`, `LLMResponse` | `llmclient.Provider`, `Request`, `RequestConfig`, `Response` |
   | `storage.KVStorager`, `AppendLogStorager`                       | `storage.KVStore`, `AppendLog`                                        |
   | `messaging.Messager`, `messagingtest.Messager`                  | `messaging.Broker`, `messagingtest.Broker`                            |
   | `envs.NewLoader(&cfg)`                                          | `envs.LoadInto(&cfg)` or `cfg, err := envs.Load[T]()`                 |
   | `errorkit.MaxStackDepth`, `ColorsEnabled`, `GenerateID`, `ErrorRegistry` | `SetMaxStackDepth`, `EnableColors` / `DisableColors`, `SetIDGenerator`, `GetMetadata` / `RegisterMany` / `OverrideMetadata` |
   | `err.(*errorkit.AppError)`                                      | `errorkit.As(err)`                                                    |

3. **Behavior changes that still compile.** Review the ones that touch the service (full list in the [CHANGELOG](https://github.com/trypanic/go-sdk/blob/main/CHANGELOG.md)):
   - `messaging.NewPubSub` no longer reads `RABBITMQ_TOPOLOGY_FILE` — use `NewPubSubFromEnv`. Unroutable publishes now fail (add `WithDeclareTopology()`), the default prefetch is 1, `Close` stops active `Subscribe` calls, and stricter topology validation rejects files that loaded before.
   - `logger` defaults to Prod (JSON) when `ENVIRONMENT` is unset, and the `time` field is an RFC 3339 UTC string instead of Unix seconds.
   - `grpc.New` / `grpc.Dial` require credentials or an explicit insecure option.
   - Hertz `Run` no longer handles signals; the audit log is on by default; `Reply.Error` no longer carries `err.Error()` — clients read the new `code` field.
   - `httprequest` no longer retries POST / PATCH without an `Idempotency-Key` after a 5xx, 429, or timeout, no longer logs each non-2xx response, and caps successful responses at 32 MiB.
   - `llmclient` requires a non-empty `APIKey` and an `https://` endpoint (`AllowInsecureEndpoint` for local servers); `Timeout: 0` now means 5 minutes.
   - `postgres`, `mongo`, `storage`, and `messaging` return cause-specific error codes; `QueryRow` with no row returns `ERR_DB_POSTGRES_NOT_FOUND`.
   - Span names changed (see Step 4).

4. Run [Step 7](#step-7--verify).

---

## Inputs

The skill accepts an optional argument:

- **No argument** — full bootstrap (logger + OTLP + telemetry + httpclient + httprequest + postgres + messaging).
- **`http`** — only logger + OTLP + telemetry + httpclient + httprequest.
- **`db`** — only logger + OTLP + telemetry + postgres.
- **`mq`** — only logger + OTLP + telemetry + messaging.
- **`migrate`** — migrate an existing v1 service (see [Migrating a v1 service](#migrating-a-v1-service)).
- **`<custom comma-list>`** — pick the components explicitly, e.g. `logger,telemetry,llmclient`.

---

## Boundaries

- Never modify the `trypanic/go-sdk` source tree from this skill. SDK changes belong in that repository, gated by its own quality stack.
- Never invent SDK symbols, and never reuse v1 names from memory. If unsure of a signature, run `go doc github.com/trypanic/go-sdk/v2/<pkg>` or read [`AGENTS.md`](https://github.com/trypanic/go-sdk/blob/main/AGENTS.md) and the package `README.md` before writing code.
- Never enable `httprequest.WithRawBodies`, `InsecureSkipVerify`, `otlp.Config.Insecure`, `grpc.WithServerInsecure` / `WithClientInsecure`, or `llmclient.Config.AllowInsecureEndpoint` without an explicit user instruction tied to a development environment. Never set `RetryConfig.RetryNonIdempotent` without the user explicitly accepting duplicate side effects.
- Call `logger.Init` once, at process startup in `run`: it configures zerolog process globals. Prefer explicit `logger.New` instances in libraries and tests.
