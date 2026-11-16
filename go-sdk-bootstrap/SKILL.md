---
name: go-sdk-bootstrap
description: Scaffold or extend a Go service that imports github.com/trypanic/go-sdk/v2, or migrate a v1 service to v2. Gives the canonical v2 wiring (signal-aware run(ctx), bounded startup and shutdown, logger/otlp, telemetry, httpclient, httprequest, postgres, messaging). Gives the tracing constructor triplet, its exceptions, and the errorkit.As and HasCode rules. Lists the v1 to v2 renames (/v2 module path, postgres and mongo identifiers, slices to batch). Triggers are "new service using trypanic", "bootstrap a trypanic go service", "wire up trypanic go-sdk", "scaffold service with go-sdk". More triggers are "set up logger and tracer from trypanic", "wire postgres/messaging/httpclient from go-sdk", "migrate to go-sdk v2". Also use it for any request to start, wire, or upgrade a service around the SDK. Auto-trigger when a Go file first imports github.com/trypanic/go-sdk/v2 or go.mod adds it, or when a project still imports the v1 path without /v2. Do NOT trigger for unrelated Go projects or inside the go-sdk repo.
---

# go-sdk-bootstrap

Use this skill to scaffold, extend, or migrate a Go service that depends on `github.com/trypanic/go-sdk/v2`. The skill gives the rules that `go doc` alone does not show:

- Which constructor gives which tracing behavior.
- Which constructors read the environment.
- The order to wire and close the OTLP provider, logger, instrumenter, and pools.
- Which v1 names no longer exist.

The skill targets **go-sdk v2.0.0**. The module path is `github.com/trypanic/go-sdk/v2`. The repository URL stays `https://github.com/trypanic/go-sdk`, because `/v2` is part of the Go module path only.

Read these references when you are not sure. The package READMEs are the authoritative contracts:
- [AGENTS.md](https://github.com/trypanic/go-sdk/blob/main/AGENTS.md)
- [llms.txt](https://github.com/trypanic/go-sdk/blob/main/llms.txt)
- [v2 API migration](https://github.com/trypanic/go-sdk/blob/main/docs/v2-api-migration.md)
- [CHANGELOG](https://github.com/trypanic/go-sdk/blob/main/CHANGELOG.md) (breaking behavior changes in 2.0.0)

---

## When to use

Trigger on requests like these:
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
- Go projects that do not import `trypanic/go-sdk`.
- Changes inside the `go-sdk` repository itself. Use the SDK's own `AGENTS.md` there.

---

## Step 1 — Check the Go module and toolchain

The SDK needs Go `1.26.1` or later. Use a patched Go 1.26 (`1.26.10` or later) or Go 1.27. The `go` directive in the service's `go.mod` must be `1.26.1` or later.

If the project has no `go.mod`, create one first:

```bash
go mod init github.com/<org>/<service>
```

Add the SDK:

```bash
go get github.com/trypanic/go-sdk/v2@latest
```

> ⚠️ `go get github.com/trypanic/go-sdk@latest` (without `/v2`) installs **v1.0.1** and gives no warning. Go treats each major version from v2 on as a different module path. Never mix both major versions in one module.

---

## Step 2 — Select the packages

Find the import for each task. In v2, each package identifier matches its directory name.

| You need to… | Import path | Package identifier |
| --- | --- | --- |
| Classified errors and client-safe serialization | `github.com/trypanic/go-sdk/v2/errorkit` | `errorkit` |
| Structured logging and trace correlation | `github.com/trypanic/go-sdk/v2/logger` | `logger` |
| OTLP log export and provider lifecycle | `github.com/trypanic/go-sdk/v2/logger/otlp` | `otlp` |
| Span factory (`Instrumenter`) | `github.com/trypanic/go-sdk/v2/telemetry` | `telemetry` |
| Outbound HTTP client (pool, timeouts, TLS) | `github.com/trypanic/go-sdk/v2/httpclient` | `httpclient` |
| Outbound HTTP requests (bounded retries, classification) | `github.com/trypanic/go-sdk/v2/httprequest` | `httprequest` |
| HTTP routing contracts and replies | `github.com/trypanic/go-sdk/v2/httpserver` | `httpserver` |
| HTTP server (Hertz) | `github.com/trypanic/go-sdk/v2/httpserver/hertz` | `hertz` |
| gRPC server + client (4 call modes) | `github.com/trypanic/go-sdk/v2/grpc` | `grpc` (alias `sdkgrpc`) |
| PostgreSQL pool and stored procedures | `github.com/trypanic/go-sdk/v2/postgres` | `postgres` |
| MongoDB | `github.com/trypanic/go-sdk/v2/mongo` | `mongo` |
| RabbitMQ pub/sub | `github.com/trypanic/go-sdk/v2/messaging` | `messaging` |
| KV / append-only storage | `github.com/trypanic/go-sdk/v2/storage` | `storage` |
| OpenAI-compatible chat (non-streaming) | `github.com/trypanic/go-sdk/v2/llmclient` | `llmclient` |
| Typed env loading | `github.com/trypanic/go-sdk/v2/envs` | `envs` |
| Test doubles | `.../v2/httpserver/httpservertest`, `.../v2/mongo/mongotest`, `.../v2/messaging/messagingtest` | directory name |
| JSON encoding without HTML escaping | `github.com/trypanic/go-sdk/v2/marshal` | `marshal` |
| String normalization / markdown stripping | `github.com/trypanic/go-sdk/v2/stringutils` | `stringutils` |
| URL building / path joining | `github.com/trypanic/go-sdk/v2/urlkit` | `urlkit` |
| Input validation (dates, alphanumeric strings, ranges) | `github.com/trypanic/go-sdk/v2/validators` | `validators` |
| Bounded chunks and stable deduplication | `github.com/trypanic/go-sdk/v2/batch` | `batch` |
| Exponential backoff for custom retry loops | `github.com/trypanic/go-sdk/v2/algorithms` | `algorithms` |

Aliases:
- Use `sdkgrpc` for the SDK `grpc` package when the file also imports `google.golang.org/grpc`.
- Use `mongodriver` for the upstream MongoDB driver when the file also imports the SDK `mongo` package.

v2 removes the v1 identifiers `database` (for `postgres/`) and `mongodb` (for `mongo/`), and the `slices` package. No compatibility alias exists. A compiler error such as `undefined: database` means v1 code. See [Migrating a v1 service](#migrating-a-v1-service).

The last six rows (`marshal` to `algorithms`) are utility helpers. They have no constructor triplet, no instrumenter, and no tracing. Import them and call them directly.

---

## Step 3 — Apply the canonical bootstrap

Copy [`references/canonical-bootstrap.go.tmpl`](references/canonical-bootstrap.go.tmpl) to `cmd/main.go` (single-service repo) or `services/<service>/cmd/main.go` (monorepo). The template comes from the SDK's `AGENTS.md` §3. `go build` and `go vet` pass against `v2.0.0`. The template obeys these invariants:

1. `main` owns only the root context (`signal.NotifyContext`) and the exit code. All wiring is in `run(ctx) error`, so all deferred cleanups run.
2. A startup context limits network setup. Pass it to the `*Context` constructors (`postgres.NewFromEnvContext`, `messaging.NewPubSubFromEnvContext`, `otlp.NewProvider`). Shutdown uses a new context with its own timeout (`context.WithoutCancel` + timeout). If a signal cancels the root context, the flush still runs.
3. Call `otlp.NewProvider` **before** `logger.Init`, and pass `otlp.NewWriter(serviceName)` to `logger.Init`. The caller owns the provider and closes it last.
4. Pass the same `serviceName` string to the OTLP provider, the logger, and the telemetry instrumenter. Logs and traces correlate by service name.
5. Create one `*telemetry.Instrumenter`. Pass it to each package that accepts one: `httprequest.NewWithInstrumenter`, `llmclient.NewWithInstrumenter`, `mongo.NewWithInstrumenter`, `postgres.WrapWithInstrumenter[T]`, `messaging.WithInstrumenter`, `grpc.WithServerInstrumenter` / `WithClientInstrumenter`.
6. Create clients and pools (`*http.Client`, `*pgxpool.Pool`, `*messaging.PubSub`) once, in `run`, and share them across handlers. **Never** create them per request.
7. Defer all `Close` / `Shutdown` calls in `run`, in reverse order of construction. Log their errors. Do not discard them.

In v2, each environment read is an explicit API choice:

| Source | Reads |
| --- | --- |
| `envs.Load[T]()` / `envs.LoadInto(&cfg)` | The service's own typed config (struct `env` tags) |
| `postgres.NewFromEnv` / `NewFromEnvContext` | `POSTGRES_DSN` (`postgres.DSNEnvVar`) |
| `messaging.NewPubSubFromEnv` / `NewPubSubFromEnvContext` | `RABBITMQ_TOPOLOGY_FILE` |
| `llmclient.ConfigFromEnv()` | `LLM_API_KEY`, optional `LLM_ENDPOINT` |
| `logger.Init` / `logger.DetectEnv` | `ENVIRONMENT` (unset → Prod: JSON, Info. `development`/`dev`/`local` → console) |

Plain `messaging.NewPubSub` never reads the environment. It requires `WithTopology` or `WithTopologyFile`. Without them, it fails with `ERR_SYSTEM_CONFIG_INVALID`.

The SDK does **not** install an OpenTelemetry `TracerProvider`. Without one, every span is a no-op. Install the service's trace provider (for example, an OTLP trace exporter) before `telemetry.NewInstrumenter`, or pass it as `InstrumenterConfig.TracerProvider`.

---

## Step 4 — Tracing constructor triplet (and exceptions)

These packages produce spans through integrated tracing:

| Package | `New` (global OTel provider) | `NewWithoutTracing` (no spans) | `NewWithInstrumenter` (caller's instrumenter, `nil` disables) |
| --- | --- | --- | --- |
| `httprequest` | `New(client)` | `NewWithoutTracing(client)` | `NewWithInstrumenter(client, instr)` |
| `llmclient` | `New(requester, cfg)` | `NewWithoutTracing(requester, cfg)` | `NewWithInstrumenter(requester, cfg, instr)` |
| `mongo` | `New(ctx, cfg, opts...)` | `NewWithoutTracing(ctx, cfg, opts...)` | `NewWithInstrumenter(ctx, cfg, instr, opts...)` |

Use `NewWithInstrumenter` in production. Notes:

- These constructors return **concrete adapters** (`*httprequest.Request`, `*llmclient.Client`, `*mongo.Client`). At consumer boundaries, accept narrow interfaces (`httprequest.Requester`, `llmclient.Provider`, `messaging.Broker`).
- `httprequest.NewWithOptions(client, opts...)` starts **without tracing**. Add `httprequest.WithInstrumenter(instr)` next to `WithRetryConfig` / `WithAuditLog`.
- `WrapWithInstrumenter` (in `httprequest`, `llmclient`, `mongo`, `postgres`) adds a span layer. Do not wrap a client that already traces, unless you want nested spans. The `llmclient` span `external.llm.execute` is the parent of the HTTP span of a traced requester. This nesting is intentional.
- `mongo.NewFromClient(driverClient, database, instr)` **borrows** the driver. The driver's owner calls `Disconnect`. The adapter's `Close` does not disconnect it.

**Exceptions:**

- `postgres`: the pool constructors (`New`, `NewContext`, `NewFromEnv`, `NewFromEnvContext`) add no spans. The caller configures pgx driver tracing. `NewStoredProcedure[T](pool)` returns a `*TracedProcedure[T]` that **already traces** with the global provider. Do not wrap it again, or each call makes two spans. To use the shared instrumenter, wrap an untraced value: `postgres.WrapWithInstrumenter[T](postgres.StoredProcedure[T]{Pool: pool}, instr)`. `Unwrap` returns the inner procedure.
- `messaging`: pass `messaging.WithInstrumenter(instr)`. A `nil` instrumenter disables tracing. `messaging.WithTracer(tracer)` is still available. With neither option, `messaging` uses the global OTel provider.
- `grpc`: **no triplet.** The server (`grpc.New(cfg, opts...)`) and the client (`grpc.Dial(cfg, opts...)`) take functional options. Tracing is on by default through the `otelgrpc` stats handler, for all four call modes. To control tracing, use one of these option pairs:
  - `grpc.WithServerInstrumenter(instr)` / `grpc.WithClientInstrumenter(instr)`. A `nil` instrumenter disables tracing.
  - `WithServerTracing(bool)` / `WithClientTracing(bool)`.
  - `WithServerTracerProvider(tp)` / `WithClientTracerProvider(tp)`.

  **Transport credentials are mandatory.** Set `ServerConfig.Creds` / `ClientConfig.Creds`, or pass `grpc.WithServerInsecure()` / `grpc.WithClientInsecure()` explicitly. Otherwise, construction fails with `ERR_SYSTEM_CONFIG_INVALID`. Register generated services on `srv.Registrar()`. `ListenAndServe()` (it uses `ServerConfig.Address`) and `Serve(lis)` block. `Shutdown(ctx)` drains the server.
- `httpserver/hertz`: it uses the global OTel provider. You cannot inject an instrumenter. `Run` does **not** handle `SIGINT` / `SIGTERM`, and it returns an error when it cannot listen. Stop the server with `Shutdown(ctx)` after the root context ends. Keep `ServerOptions.EnableRecovery` true (the default). With the default `EnableAudit=true`, the server logs one redacted info line for each inbound request.

**Span names:** create spans with the instrumenter methods `instr.Job`, `instr.Batch`, `instr.External`, `instr.Messaging`, `instr.DB`. The package-level functions (`telemetry.Job` and the others) are compatibility wrappers over a global instrumenter. End client spans with `telemetry.End(span, err)`, so that failures carry the classified error status. Do not invent ad hoc span names. Never put payloads, credentials, private reasons, or resource IDs in a span name.

SDK span names in v2. Update the dashboards and alerts that use v1 names:

| Source | Span name |
| --- | --- |
| HTTP | `external.http.<host>.<METHOD>` (path is an attribute) |
| LLM | `external.llm.execute` (model is an attribute) |
| PostgreSQL | `postgres.<routine>.query` |
| MongoDB | `mongo.<collection>.<operation>`, `mongo.client.<operation>` |
| Messaging | `messaging.<op>.<queue>` |

---

## Step 5 — Errors

SDK-classified operation failures usually return an `error` that contains an `*errorkit.AppError` (code, HTTP status, retriability). Do **not** assume that every error has that dynamic type. These sources can return raw errors:

- Upstream escape hatches: `*http.Client`, pgx pools, the Mongo driver, and gRPC connections.
- User handlers and callbacks, and generated gRPC clients.
- Hertz `Shutdown` and OTLP provider cleanup.

Rules:

- **Wrap once**, at the boundary between your code and an external library.
- **Keep an existing `*AppError` from anywhere in the chain.** Find it with `errorkit.As(err)`. Never use a direct type assertion `err.(*errorkit.AppError)`, because it misses wrapped and joined errors. If you wrap an `*AppError` again with `ERR_INTERNAL`, you lose its code, HTTP status, and retriability.
- **Match on codes, not on text.** Use `errorkit.HasCode(err, code)` or `Metadata.Retriable`. For example, `messaging` `Publish` now returns the specific `ERR_MQ_*` cause, not always `ERR_MQ_PUBLISH_FAILED`.

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

- Register service-specific codes once at service initialization, for example in `init()`:

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

- `errorkit.NewError(code)` captures a stack. `errorkit.NewWithoutStack(code)` does not capture a stack. It is for expected input rejection.
- Responses to clients:
  - In HTTP handlers, use `httpserver.ReplyError(c, err)`. As an alternative, serialize `appErr.PublicJSON()` with the status from `httpserver.StatusFor(err)`.
  - In gRPC handlers, return `sdkgrpc.ToStatus(err)`. Classify received statuses with `sdkgrpc.FromStatus(err)`.
  - Never send `PrettyJSON`, stack traces, or wrapped driver diagnostics to a client.

Do **not** patch the SDK's `codes.go` from outside the SDK repo.

---

## Step 6 — Anti-patterns to refuse

Do **not** generate any of this code (based on `AGENTS.md` §5):

- An import of `github.com/trypanic/go-sdk/...` without `/v2`, or v1 and v2 in one module.
- A removed v1 name: `database.*`, `mongodb.*`, `slices.*`, `logger.SetupOTLP`, `NewPostgresClient*`, `NewHTTPRequestWithRetry`, `HTTPRequester`, `Messager`, `LLMProvider`, `envs.NewLoader`.
- A new `*http.Client`, pgx pool, or messaging connection per request. This defeats the connection pool.
- A generic `ERR_INTERNAL` in place of a classified error, or a direct type assertion to find an `*AppError`.
- A log line in each retry attempt plus one more at the caller. `httprequest` does not log the errors that it returns. For one line per attempt, use `httprequest.WithAuditLog()`.
- A retry of POST / PATCH after uncertain delivery without an idempotency contract. The contract is an `Idempotency-Key` header, or `RetryConfig.RetryNonIdempotent` with explicit acceptance of duplicate side effects.
- Implicit or ad hoc environment reads at SDK call sites. Read the service config once with `envs.Load[T]()`. Use the documented `*FromEnv` constructors for SDK-owned variables.
- `httprequest.WithRawBodies()` or `import "github.com/trypanic/go-sdk/v2/ioutils"` on a production data path. Both are for development only.
- An import of `httpserver/hertz` (or `grpc`) from non-server code. It adds Hertz / `google.golang.org/grpc` to the binary.
- An import of `logger/otlp` only for base logging.
- A wrapper `Close` that closes a borrowed Mongo driver client.
- A second wrapper around the result of `postgres.NewStoredProcedure[T]` (two spans per call).
- `telemetry.InitTracer(...)` in new code. It is a compatibility API only. Use `telemetry.NewInstrumenter`.

If the user asks for one of these, object, cite the rule, and offer the correct alternative.

---

## Step 7 — Check the result

After you scaffold, do these steps:

1. Run `go build ./...` to check that the imports resolve.
2. Run `go vet ./...`.
3. Run `go test -short ./...`. It must not contact external services.
4. Check that no v1 import remains: `grep -rn '"github.com/trypanic/go-sdk/' --include='*.go' . | grep -v '/go-sdk/v2/'` prints nothing, and `go.mod` requires only `github.com/trypanic/go-sdk/v2`.
5. If the project has the static-analysis stack, run the `go-code-quality-check` skill.
6. Check that all `defer Close()` / `defer Shutdown()` calls are in `run`, not in the caller of a constructor.

Report:
- The files that you created.
- The imports that you added.
- Each value that the user must still set: `OTEL_COLLECTOR_ENDPOINT`, `RABBITMQ_URL`, `RABBITMQ_TOPOLOGY_FILE`, `POSTGRES_DSN`, `ENVIRONMENT` (`development` for console logs), and `LLM_API_KEY` / `LLM_ENDPOINT` when the service uses `llmclient`.
- Whether the service still needs its own OTel trace provider.

---

## Migrating a v1 service

1. **Module and imports.** Run `go get github.com/trypanic/go-sdk/v2@latest`. Rewrite every SDK import, including tests, test doubles, and `logger/otlp`. Then run `go mod tidy` to remove the v1 requirement. This mechanical rewrite is safe, and it is idempotent on imports that already have `/v2`. It uses GNU `sed`. On macOS, use `sed -i ''`:

   ```bash
   grep -rl '"github.com/trypanic/go-sdk/' --include='*.go' . | xargs sed -i \
     -e 's#"github.com/trypanic/go-sdk/#"github.com/trypanic/go-sdk/v2/#' \
     -e 's#/go-sdk/v2/v2/#/go-sdk/v2/#' \
     -e 's#"github.com/trypanic/go-sdk/v2/slices"#"github.com/trypanic/go-sdk/v2/batch"#'
   ```

2. **Renamed APIs.** No compatibility aliases remain:

   | v1 | v2 |
   | --- | --- |
   | `database.NewPostgresClient`, `NewPostgresClientFromEnv` | `postgres.New`, `NewFromEnv` (plus `NewContext`, `NewFromEnvContext`) |
   | `database.PostgresEnvVar` | `postgres.DSNEnvVar` |
   | `mongodb.*` | `mongo.*` (alias the upstream driver as `mongodriver`) |
   | `slices.Chunk`, `slices.MergeUniqueStrings` | `batch.Chunk`, `batch.MergeUniqueStrings` |
   | `logger.SetupOTLP`, `logger.InitLogProvider` | `otlp.Setup`, `otlp.InitProvider` (strict TLS: `otlp.NewProvider`) |
   | `logger.NewOTLPWriter`, `logger.OTLPWriter`, `logger.LogProviderHandle` | `otlp.NewWriter`, `otlp.Writer`, `otlp.Provider` |
   | `httprequest.HTTPRequest`, `HTTPRequester` | `httprequest.Request`, `Requester` |
   | `httprequest.NewHTTPRequestWithRetry(client, rc)` | `httprequest.NewWithOptions(client, WithRetryConfig(rc), WithInstrumenter(instr))` |
   | `httpserver.HTTPServer`, `HTTPContext` | `httpserver.Server`, `Context` |
   | `llmclient.LLMProvider`, `LLMRequest`, `LLMRequestConfig`, `LLMResponse` | `llmclient.Provider`, `Request`, `RequestConfig`, `Response` |
   | `storage.KVStorager`, `AppendLogStorager` | `storage.KVStore`, `AppendLog` |
   | `messaging.Messager`, `messagingtest.Messager` | `messaging.Broker`, `messagingtest.Broker` |
   | `envs.NewLoader(&cfg)` | `envs.LoadInto(&cfg)` or `cfg, err := envs.Load[T]()` |
   | `errorkit.MaxStackDepth`, `ColorsEnabled`, `GenerateID`, `ErrorRegistry` | `SetMaxStackDepth`, `EnableColors` / `DisableColors`, `SetIDGenerator`, `GetMetadata` / `RegisterMany` / `OverrideMetadata` |
   | `err.(*errorkit.AppError)` | `errorkit.As(err)` |

3. **Behavior changes that still compile.** Examine the changes that affect the service. The [CHANGELOG](https://github.com/trypanic/go-sdk/blob/main/CHANGELOG.md) has the full list:
   - `messaging`:
     - `NewPubSub` no longer reads `RABBITMQ_TOPOLOGY_FILE`. Use `NewPubSubFromEnv`.
     - Unroutable publishes now fail. Add `WithDeclareTopology()`.
     - The default prefetch is 1.
     - `Close` stops active `Subscribe` calls.
     - Topology validation now rejects unknown fields, more than one binding per queue, undeclared exchanges, and retry blocks without a valid `maxAttempts` or `backoffMultiplier`.
   - `logger`: the default is Prod (JSON) when `ENVIRONMENT` is not set. The `time` field is an RFC 3339 UTC string, not Unix seconds.
   - `grpc.New` / `grpc.Dial` require credentials or an explicit insecure option.
   - Hertz: `Run` no longer handles signals. The audit log is on by default. `Reply.Error` no longer contains `err.Error()`. Clients read the new `code` field.
   - `httprequest` no longer retries POST / PATCH without an `Idempotency-Key` after a 5xx, 429, or timeout. It no longer logs each non-2xx response. It limits successful responses to 32 MiB.
   - `llmclient` requires a non-empty `APIKey` and an `https://` endpoint. For local servers, set `AllowInsecureEndpoint`. `Timeout: 0` now means 5 minutes.
   - `postgres`, `mongo`, `storage`, and `messaging` return cause-specific error codes. `QueryRow` with no row returns `ERR_DB_POSTGRES_NOT_FOUND`.
   - Span names changed. See Step 4.

4. Do [Step 7](#step-7--check-the-result).

---

## Inputs

The skill accepts one optional argument:

- **No argument**: full bootstrap (logger + OTLP + telemetry + httpclient + httprequest + postgres + messaging).
- **`http`**: only logger + OTLP + telemetry + httpclient + httprequest.
- **`db`**: only logger + OTLP + telemetry + postgres.
- **`mq`**: only logger + OTLP + telemetry + messaging.
- **`migrate`**: migrate an existing v1 service. See [Migrating a v1 service](#migrating-a-v1-service).
- **`<custom comma-list>`**: select the components explicitly, for example `logger,telemetry,llmclient`.

---

## Boundaries

- Never change the `trypanic/go-sdk` source tree from this skill. SDK changes go in that repository, where its own quality stack checks them.
- Never invent SDK symbols, and never use v1 names from memory. If you are not sure of a signature, run `go doc github.com/trypanic/go-sdk/v2/<pkg>`. As an alternative, read [`AGENTS.md`](https://github.com/trypanic/go-sdk/blob/main/AGENTS.md) and the package `README.md` before you write code.
- Never enable `httprequest.WithRawBodies`, `InsecureSkipVerify`, `otlp.Config.Insecure`, `grpc.WithServerInsecure` / `WithClientInsecure`, or `llmclient.Config.AllowInsecureEndpoint` without an explicit user instruction for a development environment.
- Never set `RetryConfig.RetryNonIdempotent` unless the user explicitly accepts duplicate side effects.
- Call `logger.Init` once, at process startup in `run`. It configures zerolog process globals. In libraries and tests, prefer explicit `logger.New` instances.
