---
name: go-sdk-bootstrap
description: Scaffold or extend a Go service that imports github.com/trypanic/go-sdk. Encodes the canonical wiring for logger + telemetry + httpclient + httprequest + postgres + messaging, the directory-vs-package-name divergences (postgres/->database, mongo/->mongodb), the tracing constructor triplet (New / NewWithoutTracing / NewWithInstrumenter), and the errorkit wrapping rules. Use when the user says "new service using trypanic", "bootstrap a trypanic go service", "wire up trypanic go-sdk", "scaffold service with go-sdk", "set up logger and tracer from trypanic", "wire postgres/messaging/httpclient from go-sdk", or any phrase asking to start, wire, or compose a Go service around github.com/trypanic/go-sdk. Auto-trigger when a Go file imports github.com/trypanic/go-sdk for the first time in a project, or when go.mod adds the dependency. Do NOT trigger for unrelated Go projects.
---

# go-sdk-bootstrap

Scaffold or extend a Go service that depends on `github.com/trypanic/go-sdk`. The skill encodes the conventions an agent cannot derive from `go doc` alone: which constructor produces which behavior, which packages have a divergent identifier, and the order in which OTLP, logger, instrumenter, and pools must be wired.

Canonical reference (always prefer reading directly when in doubt):
- [AGENTS.md](https://github.com/trypanic/go-sdk/blob/main/AGENTS.md)
- [llms.txt](https://github.com/trypanic/go-sdk/blob/main/llms.txt)

---

## When to use

Trigger on natural-language phrases like:
- "new Go service using trypanic"
- "wire up `go-sdk` in a new project"
- "bootstrap a service with logger + tracer + postgres from `go-sdk`"
- "scaffold the `main.go` for a trypanic service"
- "add `messaging` / `httprequest` / `postgres` to my service"
- "set up OTLP + zerolog using `trypanic/go-sdk`"

Auto-trigger when:
- A new Go file imports `github.com/trypanic/go-sdk/...` for the first time.
- `go.mod` adds `github.com/trypanic/go-sdk` as a dependency.

Do **not** trigger for:
- Unrelated Go projects that do not import `trypanic/go-sdk`.
- Internal SDK changes inside the `go-sdk` repository itself (use the SDK's own `AGENTS.md` directly there).

---

## Step 1 — Confirm Go module

If the project has no `go.mod`, init one before adding the dependency:

```bash
go mod init github.com/<org>/<service>
```

Add the SDK:

```bash
go get github.com/trypanic/go-sdk@latest
```

---

## Step 2 — Pick the right packages

Map task to import. Most agents trip on the package-identifier divergence — handle this **before** writing any code.

| You need to…                                          | Import path                                | Package identifier |
|-------------------------------------------------------|--------------------------------------------|--------------------|
| Structured errors                                     | `github.com/trypanic/go-sdk/errorkit`      | `errorkit`         |
| Logging + OTLP                                        | `github.com/trypanic/go-sdk/logger`        | `logger`           |
| Span factory                                          | `github.com/trypanic/go-sdk/telemetry`     | `telemetry`        |
| Outbound HTTP (client)                                | `github.com/trypanic/go-sdk/httpclient`    | `httpclient`       |
| Outbound HTTP (retrying requester)                    | `github.com/trypanic/go-sdk/httprequest`   | `httprequest`      |
| HTTP server (Hertz)                                   | `github.com/trypanic/go-sdk/httpserver/hertz` | `hertz`         |
| Postgres pool                                         | `github.com/trypanic/go-sdk/postgres`      | **`database`**     |
| MongoDB                                               | `github.com/trypanic/go-sdk/mongo`         | **`mongodb`**      |
| RabbitMQ pub/sub                                      | `github.com/trypanic/go-sdk/messaging`     | `messaging`        |
| KV / append-only storage                              | `github.com/trypanic/go-sdk/storage`       | `storage`          |
| OpenAI-compatible chat (non-streaming)                | `github.com/trypanic/go-sdk/llmclient`     | `llmclient`        |
| Typed env loading                                     | `github.com/trypanic/go-sdk/envs`          | `envs`             |

Bold rows declare a package name that differs from the directory. The compiler will say `undefined: postgres` if the agent calls `postgres.NewPostgresClient(...)` instead of `database.NewPostgresClient(...)`. Same for `mongodb`.

---

## Step 3 — Apply the canonical bootstrap

Use [`references/canonical-bootstrap.go.tmpl`](references/canonical-bootstrap.go.tmpl) as `cmd/<service>/main.go`. It is verified against the SDK at `main` and follows these invariants:

1. `logger.SetupOTLP` is called **before** `logger.Init` so the OTLP writer is ready when the global logger is installed.
2. `serviceName` is the same string passed to the OTLP setup, the logger init, and the telemetry instrumenter — logs and traces correlate by service name.
3. One `*telemetry.Instrumenter` is constructed once and passed to every package that takes one (`httprequest.NewWithInstrumenter`, `database.WrapWithInstrumenter[T]`, `mongodb.NewWithInstrumenter`, `llmclient.NewWithInstrumenter`).
4. Pools (`*pgxpool.Pool`, `*messaging.PubSub`, `*http.Client`) are constructed once at `main` scope and shared across handlers. **Never** per-request.
5. All `Close` / `Shutdown` calls are deferred at `main` scope, in reverse construction order.

---

## Step 4 — Tracing constructor triplet (and exceptions)

For most SDK packages that produce spans:

| Constructor           | Behavior                                                                |
|-----------------------|-------------------------------------------------------------------------|
| `New(...)`            | Default; uses an instrumenter backed by the global OTel tracer.         |
| `NewWithoutTracing(...)` | Explicit no-op instrumenter; for tests or telemetry-free embeds.     |
| `NewWithInstrumenter(...)` | Caller-provided `*telemetry.Instrumenter`; preferred in production. |

Packages following the triplet: `httprequest`, `llmclient`, `mongo`.

**Exceptions:**

- `postgres` (package `database`) — the pool itself has no tracing parameter. Wrap each `StoredProcedure[T]` with `database.WrapWithInstrumenter[T](inner, instr)`.
- `messaging` — accepts a plain `trace.Tracer` via `messaging.WithTracer(tracer)` option, **not** an `*Instrumenter`. Pass `otel.Tracer(serviceName)` for explicit control, or omit and let the global OTel tracer be used.

Span naming: always go through `telemetry.Job`, `telemetry.Batch`, `telemetry.External`, `telemetry.Messaging`, `telemetry.DB`. Do not invent ad-hoc span names.

---

## Step 5 — Errors

Every SDK function that can fail returns `error` whose dynamic type is `*errorkit.AppError`. The wrapping rules are strict:

- **Wrap once**, at the boundary between your code and an external library.
- **Preserve `*AppError`.** If the SDK call already returned `*errorkit.AppError`, do not re-wrap it with `errorkit.NewError(errorkit.ERR_INTERNAL)` — that destroys the original code, HTTP status, and retriability.
- Type-switch on return:

```go
result, err := svc.Do(ctx, input)
if err != nil {
    if appErr, ok := err.(*errorkit.AppError); ok {
        logger.ErrorCtx(ctx, appErr, "svc.Do failed")
        return appErr
    }
    wrapped := errorkit.NewError(errorkit.ERR_INTERNAL).
        With(errorkit.WithWrapped(err))
    logger.ErrorCtx(ctx, wrapped, "svc.Do failed")
    return wrapped
}
```

- For service-specific failure modes, register codes at runtime in `init()`:

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

Do **not** patch the SDK's `codes.go` from outside the SDK repo.

---

## Step 6 — Anti-patterns to refuse

When generating code, **do not** produce any of the following — these are listed as anti-patterns in `AGENTS.md` §5:

- A new `*http.Client` per request (defeats the connection pool).
- `errorkit.NewError(errorkit.ERR_INTERNAL).With(WithWrapped(appErr))` where `appErr` is already an `*AppError`.
- `log.Println` / `fmt.Println` / `slog` for service logging — use `logger.*`.
- `os.Getenv` directly inside an SDK call site — use the matching `*FromEnv` constructor or `envs.Load[T]()`.
- `httprequest.WithRawBodies()` outside a development build.
- `import "github.com/trypanic/go-sdk/ioutils"` from a production code path — `ioutils` is dev-only.
- `telemetry.InitTracer(...)` in new code — compatibility shim only; use `telemetry.NewInstrumenter`.
- Reaching into `httpserver/hertz` from non-server code — pulls Hertz transitively into the binary.

If the user is asking for one of these, push back, cite the rule, and offer the correct alternative.

---

## Step 7 — Verify

After scaffolding, the agent should:

1. Run `go build ./...` to confirm imports resolve.
2. Run `go vet ./...`.
3. If the project sets up the static-analysis stack, run the `go-code-quality-check` skill.
4. Check that all `defer Close()` / `defer Shutdown()` calls are in `main`, not in the constructor's caller.

Report back: list of files created, list of imports added, and any place where the user must still fill in a value (`POSTGRES_DSN`, `RABBITMQ_URL`, OTLP collector address, etc.).

---

## Inputs

The skill accepts an optional argument:

- **No argument** — full bootstrap (logger + telemetry + httpclient + httprequest + postgres + messaging).
- **`http`** — only logger + telemetry + httpclient + httprequest.
- **`db`** — only logger + telemetry + postgres.
- **`mq`** — only logger + telemetry + messaging.
- **`<custom comma-list>`** — pick the components explicitly, e.g. `logger,telemetry,llmclient`.

---

## Boundaries

- Never modify the `trypanic/go-sdk` source tree from this skill. SDK changes belong in that repository, gated by its own quality stack.
- Never invent SDK symbols. If unsure of a constructor signature, fetch [`AGENTS.md`](https://github.com/trypanic/go-sdk/blob/main/AGENTS.md) or the relevant sub-`README.md` before writing code.
- Never enable `WithRawBodies` or `InsecureSkipVerify` without an explicit user instruction tied to a development environment.
- Never call `logger.Init` more than once in a process (it replaces the global logger and races with concurrent log writes).
