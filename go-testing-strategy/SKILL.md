---
name: go-testing-strategy
description: Test strategy for Go services. Defines the test pyramid per layer — unit, integration (port-boundary mocks), contract (JSON Schemas), real infrastructure (stored-procedure repositories), minimal e2e smoke. Also defines spec-slice workflow gates, schema-validated HTTP mocks, build-tag conventions and concurrency/atomicity test patterns. Use when asked "how do I test this service", "write integration tests", "mock the orchestrator/API" or "test this workflow". Also for "set up e2e", "are mocks drifting from the contract", "test this stored procedure" or "test this race/lease atomicity". Auto-trigger on new *_test.go files that touch HTTP clients, repositories or message producers. Also when new external-service mocks appear or a spec/change defines acceptance criteria. Out of scope — unit-test idioms like table-driven tests/subtests/helpers/cmp.Diff (samber/cc-skills-golang@golang-testing), static analysis gates (go-code-quality-check), folder layout (go-modularization). Skip non-Go projects.
version: 1.0.0
---

# Go Testing Strategy

How to layer, gate and isolate tests in a Go service. This skill decides **what kind of test to write where and when it must pass**. samber's `golang-testing` decides **how to write the test code**.

## Defers To (Do Not Duplicate)

| Topic | Authoritative skill |
|---|---|
| Table-driven tests, subtests, `t.Parallel`, helpers (`t.Helper`), test doubles construction, `cmp.Diff` assertions, golden-file mechanics | `samber/cc-skills-golang@golang-testing` |
| Goroutine/channel correctness in test code | `samber/cc-skills-golang@golang-concurrency` |
| Static analysis / security gates before commit | `go-code-quality-check` |
| Where test fixtures and packages live | `go-modularization` |

## Critical Rules

🚨 **Mock only at port boundaries.** In a hexagonal layout, fakes replace **outbound ports** (HTTP clients, repositories, producers) and tests drive **inbound ports** (handlers, consumers). Never mock your own internal functions or domain types. If you need to, the design is wrong (see `go-design-principles`).

🚨 **Every HTTP mock payload validates against its JSON Schema.** If a service's wire contracts are JSON Schemas, every fake response from `httptest.Server` MUST pass schema validation **inside the test**. Every request that the fake asserts on MUST pass the same validation. A mock that drifts from the contract is a red test, not a silent lie.

🚨 **Never mock the database when behavior lives in it.** Test against **real** infrastructure (testcontainers or the repo's compose stack) each repository that does any of these:

- Calls stored procedures.
- Relies on transactional locking (`FOR UPDATE SKIP LOCKED`, advisory locks).
- Enforces uniqueness/atomicity.

Mocking SQL here tests nothing. Mock the repository *interface* one layer up instead.

🚨 **Workflow gate: no slice advances with red or missing tests.** When you slice work by spec/change/workflow, each slice ships with passing unit + integration tests and verified acceptance criteria before the next slice starts. An unverified acceptance criterion stays open with a note. Never mark it done.

🚨 **No time.Sleep synchronization.** Tests await conditions via channels, `context` deadlines or bounded polling helpers. A sleep-based test is flaky by construction.

🚨 **Hermetic integration tests.** Each test owns its state: a fresh schema, a per-test transaction that rolls back, or a unique key-space. Tests have no ordering dependencies. Everything is safe under `go test -count=2 -shuffle=on`.

## The Pyramid

| Layer | Subject under test | Doubles | Infra | Volume |
|---|---|---|---|---|
| **Contract** | Wire types ↔ JSON Schemas | none | none | one per message type |
| **Unit** | Domain + interactor logic, one workflow case per table row | hand-written fakes of ports | none | the bulk |
| **Integration (mocked deps)** | Service wired end-to-end, external HTTP deps faked | `httptest.Server` per external actor | none | one per workflow |
| **Integration (real infra)** | Outbound adapters: SP repositories, messaging producers | none | Postgres/Mongo/broker via testcontainers or compose | one per adapter method group |
| **E2E smoke** | Full stack via compose | none | full compose stack | few: happy path + one failure path per service |

Coverage percentage is not a goal. **Case coverage is**: every documented workflow case, error reason and invariant maps to at least one test.

## Contract Tests

For every wire message that has a JSON Schema:

1. Marshal the Go type from a fully populated value → validate the JSON against the schema.
2. Unmarshal a golden sample (committed JSON that the schema accepts) → assert round-trip equality.
3. Negative: a sample that violates the schema (extra field, bad enum) must fail validation. This proves that validation enforces `additionalProperties: false` and the enums.

Wire types and their contract tests are **slice zero** of any spec-driven build. They exist before you implement the first workflow, so every later mock can use them.

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
- The fake also **asserts inbound requests** against the request schema. This enforces both directions of the contract.
- State-machine tests assert observable behavior (which endpoint the code called next, what it persisted), never internal fields.

## Real-Infrastructure Tests

- Per package:
  1. Start Postgres (or the repo's compose stack) once via `TestMain`.
  2. Apply migrations.
  3. Give each test an isolated schema or a rolled-back transaction.
- Stored-procedure repositories: call the public repository method and assert rows/state. The SP body is part of the unit.
- **Atomicity pattern** (leases, pins, queue claims): N goroutines compete for one resource. Run with `-race`. The test asserts that:
  - exactly one goroutine wins.
  - N-1 receive the documented contention outcome.
  - the invariant (no double assignment) holds afterwards.

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

Task-runner wiring (when the repo uses one, e.g. moon):

- Unit tests run in the default `test`/`test-all` task.
- Add `test-integration` (`-tags integration`) and `test-e2e` (`-tags e2e`) tasks at the shared task file level, not per project.
- In repos that mandate the runner, never bypass it with a direct `go test` call.

## Workflow Gate Checklist

Before you declare a spec slice / workflow done:

- [ ] Every documented case of the workflow has a test row (unit or integration).
- [ ] Tests exercise every rejection reason and error path, not only the happy path.
- [ ] Tests validate mocks against schemas in both directions.
- [ ] Where the slice introduces shared state, tests with `-race` cover the atomicity/concurrency invariants.
- [ ] `test-all` + `test-integration` are green. Static gates per `go-code-quality-check` pass.
- [ ] Each acceptance criterion marked done has passing proof. Unverified ones stay open with a note.

## Anti-Patterns

- ❌ Mocking the repository *and* the SP. Pick the boundary: fake the interface in unit tests, use real Postgres in adapter tests.
- ❌ Hand-rolled JSON strings in mocks ("it looked right"). Build them from wire types or validate them against the schema.
- ❌ One mega e2e test that covers all workflows. Its failures become undiagnosable. Pyramid layers exist to localize failures.
- ❌ Asserting on log output or internal struct fields. Assert on contract-visible behavior.
- ❌ Skipping integration tests because "unit tests cover it". Unit tests never catch contract drift or SQL/SP regressions.
