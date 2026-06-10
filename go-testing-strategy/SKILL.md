---
name: go-testing-strategy
description: Test strategy for Go services complementing samber/cc-skills-golang@golang-testing (no duplication of unit-test idioms). Defines the test pyramid per layer — unit at the interactor/domain level, integration with mocks at port boundaries, contract tests against JSON Schemas, real-infrastructure tests for stored-procedure repositories, and minimal end-to-end smoke — plus workflow gates (every spec slice must pass its tests before the next starts), schema-validated HTTP mocks, build-tag conventions, and concurrency/atomicity test patterns. Use when asked "how do I test this service", "write integration tests", "mock the orchestrator/API", "test this workflow", "set up e2e", "are mocks drifting from the contract", "test this stored procedure", "test this race/lease atomicity". Auto-trigger when creating *_test.go files that touch HTTP clients, repositories, or message producers; when a spec/change defines acceptance criteria; or when mocks of external services are introduced. Out of scope — unit-test idioms like table-driven tests/subtests/helpers/cmp.Diff (samber golang-testing), static analysis gates (go-code-quality-check), folder layout (go-modularization). Skip non-Go projects.
version: 1.0.0
---

# Go Testing Strategy

How to layer, gate, and isolate tests in a Go service. This skill decides **what kind of test to write where and when it must pass**; samber's `golang-testing` decides **how to write the test code**.

## Defers To (Do Not Duplicate)

| Topic | Authoritative skill |
|---|---|
| Table-driven tests, subtests, `t.Parallel`, helpers (`t.Helper`), test doubles construction, `cmp.Diff` assertions, golden-file mechanics | `samber/cc-skills-golang@golang-testing` |
| Goroutine/channel correctness in test code | `samber/cc-skills-golang@golang-concurrency` |
| Static analysis / security gates before commit | `go-code-quality-check` |
| Where test fixtures and packages live | `go-modularization` |

## Critical Rules

🚨 **Mock only at port boundaries.** In a hexagonal layout, fakes replace **outbound ports** (HTTP clients, repositories, producers) and tests drive **inbound ports** (handlers, consumers). Never mock your own internal functions or domain types — if you feel the need, the design is wrong (see `go-design-principles`).

🚨 **Every HTTP mock payload validates against its JSON Schema.** When a service's wire contracts are authored as JSON Schemas, every fake response served by `httptest.Server` (and every request the fake asserts on) MUST be validated against the schema **inside the test**. A mock that drifts from the contract is a red test, not a silent lie.

🚨 **Never mock the database when behavior lives in it.** Repositories that call stored procedures, rely on transactional locking (`FOR UPDATE SKIP LOCKED`, advisory locks), or enforce uniqueness/atomicity are tested against **real** infrastructure (testcontainers or the repo's compose stack). Mocking SQL here tests nothing. Mock the repository *interface* one layer up instead.

🚨 **Workflow gate: no slice advances with red or missing tests.** When work is sliced by spec/change/workflow, each slice ships with its unit + integration tests passing and its acceptance criteria verified before the next slice starts. An unverified acceptance criterion stays unchecked with a note — never marked done.

🚨 **No time.Sleep synchronization.** Tests await conditions via channels, `context` deadlines, or bounded polling helpers. A sleep-based test is flaky by construction.

🚨 **Hermetic integration tests.** Each test owns its state: fresh schema, per-test transaction rolled back, or unique key-space. No ordering dependencies between tests; everything safe under `go test -count=2 -shuffle=on`.

## The Pyramid

| Layer | Subject under test | Doubles | Infra | Volume |
|---|---|---|---|---|
| **Contract** | Wire types ↔ JSON Schemas | none | none | one per message type |
| **Unit** | Domain + interactor logic, one workflow case per table row | hand-written fakes of ports | none | the bulk |
| **Integration (mocked deps)** | Service wired end-to-end, external HTTP deps faked | `httptest.Server` per external actor | none | one per workflow |
| **Integration (real infra)** | Outbound adapters: SP repositories, messaging producers | none | Postgres/Mongo/broker via testcontainers or compose | one per adapter method group |
| **E2E smoke** | Full stack via compose | none | full compose stack | few: happy path + one failure path per service |

Coverage percentage is not a goal. **Case coverage is**: every documented workflow case, error reason, and invariant maps to at least one test.

## Contract Tests

For every wire message that has a JSON Schema:

1. Marshal the Go type from a fully populated value → validate the JSON against the schema.
2. Unmarshal a golden sample (checked-in JSON that the schema accepts) → assert round-trip equality.
3. Negative: a sample violating the schema (extra field, bad enum) must fail validation — proves `additionalProperties: false` and enums are actually enforced.

Wire types and their contract tests are **slice zero** of any spec-driven build: they exist before the first workflow is implemented, so every later mock can lean on them.

## Integration With Mocked Dependencies

One fake per external actor, not per endpoint:

```go
// fake orchestrator: one httptest.Server, route table per endpoint,
// programmable per-test scenario, schema validation on every exchange.
type fakeOrchestrator struct {
    t         *testing.T
    mux       *http.ServeMux
    scenarios map[string][]json.RawMessage // endpoint -> queued responses
}

func (f *fakeOrchestrator) respond(w http.ResponseWriter, endpoint string) {
    body := f.next(endpoint)
    mustValidate(f.t, responseSchemaFor(endpoint), body) // 🚨 schema-validated mock
    w.Write(body)
}
```

- Scenario = the sequence of responses for one test case (e.g. `SYNC_ACK`, then `SESSION_ASSIGNED`, then `QUOTA_EXHAUSTED`).
- The fake also **asserts inbound requests** against the request schema — both directions of the contract are enforced.
- State-machine tests assert observable behavior (which endpoint was called next, what was persisted), never internal fields.

## Real-Infrastructure Tests

- Spin Postgres (or the repo's compose stack) once per package via `TestMain`; apply migrations; hand each test an isolated schema or a rolled-back transaction.
- Stored-procedure repositories: call the public repository method, assert rows/state — the SP body is part of the unit.
- **Atomicity pattern** (leases, pins, queue claims): N goroutines compete for one resource; exactly one wins, N-1 receive the documented contention outcome, and the invariant (no double assignment) holds afterwards. Run with `-race`.

```go
winners := int32(0)
var wg sync.WaitGroup
for range workers {
    wg.Go(func() {
        if _, err := repo.LeaseSession(ctx, workerID()); err == nil {
            atomic.AddInt32(&winners, 1)
        }
    })
}
wg.Wait()
if winners != 1 { t.Fatalf("lease atomicity broken: %d winners", winners) }
```

## Build Tags and Naming

| Kind | File / location | Tag | Default `go test` run |
|---|---|---|---|
| Unit + contract | `*_test.go` next to the code | none | yes |
| Integration (mocked or real infra) | `*_integration_test.go` next to the adapter | `//go:build integration` | no |
| E2E smoke | `<service>/e2e/` | `//go:build e2e` | no |

Task-runner wiring (when the repo uses one — e.g. moon): unit tests run in the default `test`/`test-all` task; add `test-integration` (`-tags integration`) and `test-e2e` (`-tags e2e`) tasks at the shared task file level rather than per project. Never bypass the runner by calling `go test` directly in repos that mandate it.

## Workflow Gate Checklist

Before a spec slice / workflow is declared done:

- [ ] Every documented case of the workflow has a test row (unit or integration).
- [ ] Every rejection reason and error path is exercised, not just the happy path.
- [ ] Mocks validated against schemas in both directions.
- [ ] Atomicity/concurrency invariants tested with `-race` where the slice introduces shared state.
- [ ] `test-all` + `test-integration` green; static gates per `go-code-quality-check`.
- [ ] Acceptance criteria checked off only with passing proof; unverified ones stay open with a note.

## Anti-Patterns

- ❌ Mocking the repository *and* the SP — pick the boundary: fake the interface in unit tests, hit real Postgres in adapter tests.
- ❌ Hand-rolled JSON strings in mocks ("it looked right") — build from wire types or validate against the schema.
- ❌ One mega e2e covering all workflows — failures become undiagnosable; pyramid layers exist to localize.
- ❌ Asserting on log output or internal struct fields — assert on contract-visible behavior.
- ❌ Skipping integration tests because "unit tests cover it" — unit tests never catch contract drift or SQL/SP regressions.
