---
name: go-design-principles
description: Go design judgement that complements samber/cc-skills-golang and defers to it for naming, structs/interfaces mechanics, DI, context, concurrency, nil-safety, style. Covers SOLID (SRP by actor, OCP by composition, LSP contract honesty, ISP small interfaces, DIP consumer-owned direction) and interface placement. Covers KISS, DRY (rule-of-three), YAGNI, immutability, object calisthenics and type-driven design (sealed sum types, primitive wrappers). Errors use github.com/trypanic/go-sdk/v2/errorkit, or samber stdlib mechanics in non-SDK Go. Use for "is this design idiomatic", "should this be an interface", "apply SOLID", "model this state machine", "wrap this primitive", "spot feature envy", "apply KISS/DRY/SRP". Auto-trigger on primitive obsession, status-string state machines, feature envy, forbidden package names (util/common/helpers/shared/manager/handler/processor/data) or speculative interfaces. Out of scope — folder layout (go-modularization), go-sdk wiring (go-sdk-bootstrap). Skip non-Go projects.
version: 1.0.0
---

# Go Design Principles

This skill gives higher-level design judgement for idiomatic Go. It adapts [NTCoding/claude-skillz](https://github.com/NTCoding/claude-skillz/blob/main/software-design-principles/SKILL.md), Scott Wlaschin's type-driven design and Jeff Bay's object calisthenics to Go.

This skill is **complementary**, not standalone. It assumes an installed and active [`samber/cc-skills-golang`](https://github.com/samber/cc-skills-golang). It does **not** repeat any topic that samber covers.

## Defers To (Do Not Duplicate)

| Topic | Authoritative skill |
|---|---|
| Error mechanics **for non-SDK Go only** (`%w`, `errors.Is` / `errors.As`, sentinel/typed errors, `panic` discipline, `slog`, `samber/oops`). trypanic/go-sdk projects use `errorkit` to create errors instead — see Critical Rules and [`references/errorkit.md`](references/errorkit.md) | `samber/cc-skills-golang@golang-error-handling` |
| Identifier naming (`Err` prefix, `New` constructors, receivers, MixedCaps, boolean prefixes, error string casing) | `samber/cc-skills-golang@golang-naming` |
| Accept-interfaces-return-structs, small interfaces, embedding, type assertions, pointer vs value receivers | `samber/cc-skills-golang@golang-structs-interfaces` |
| Constructor injection, no globals / no service `init()`, container at composition root | `samber/cc-skills-golang@golang-dependency-injection` |
| `context.Context` propagation, first parameter, never in struct, cancellation | `samber/cc-skills-golang@golang-context` |
| Goroutine ownership, channel ownership, leak prevention, `select` with `ctx.Done()` | `samber/cc-skills-golang@golang-concurrency` |
| Nil-interface trap, comma-ok type assertion, append aliasing, defensive copies, useful zero values, `defer` in loops | `samber/cc-skills-golang@golang-safety` |
| Indentation, early returns, line breaking, variable declaration form | `samber/cc-skills-golang@golang-code-style` |
| Functional options, constructor patterns, `init()` avoidance | `samber/cc-skills-golang@golang-design-patterns` |

If this skill and a samber skill conflict, the samber skill wins for its topic.

## Critical Rules

🚨 **Make illegal states unrepresentable.** Use sealed sum-type interfaces (unexported sealing method) and distinct types per state. Never represent state with a free-form `string`.

🚨 **Wrap primitives in named types.** `type UserID string`, `type Cents int64`, `type Email string`. Validate in a constructor when validation matters. The compiler catches argument-order bugs that bare `string` and `int64` cannot catch.

🚨 **Forbidden generic package names.** Never use `util`, `utils`, `common`, `shared`, `helpers`, `manager`, `handler` (except `http.Handler`), `processor`, `data` or `service` as a package name. Pick a domain noun.

🚨 **Feature envy is a refactor signal.** A method that uses another type's fields more than its own fields belongs on that other type.

🚨 **No explanatory comments.** Keep doc comments on exported identifiers (Go convention), and keep them terse and behavioral. An inline `// this does X` comment is a smell. Refactor the code instead.

🚨 **Default to immutability.** Return new values. Do not mutate parameters. If you must mutate, the method name and the pointer receiver must make the mutation obvious.

🚨 **Errors flow through `errorkit`, not stdlib.** In trypanic/go-sdk projects:

- Create every error with `errorkit.NewError(code)`. **Never** use `errors.New` or `fmt.Errorf` as a final return.
- Remove stdlib error definitions, so that nothing competes with the `*errorkit.AppError` flow.
- Wrap once at the boundary with `errorkit.NewError(code).With(errorkit.WithWrapped(err))`.
- Use `errorkit.As(err)` to find an existing `*AppError` anywhere in the chain, and preserve it. Never re-wrap it. Never use a direct type assertion to find it, because a direct type assertion misses wrapped errors.
- Register service-specific codes with `errorkit.MustRegister` in `init()`.

Use stdlib error mechanics (`samber/cc-skills-golang@golang-error-handling`) **only** when the project does not import `github.com/trypanic/go-sdk/v2`. See [`references/errorkit.md`](references/errorkit.md).

## When This Applies

- Designing a new type, package, or domain model
- Refactoring for clarity or to remove primitive obsession
- Code review, design review, TDD REFACTOR phase
- Modelling a state machine or workflow
- Spotting feature envy, speculative abstraction, or generic naming

## Core Philosophy

- **Clarity over cleverness**
- **Explicit over implicit**
- **Intention-revealing over generic**
- **Boring code over clever code**
- **Make wrong code look wrong (in the type system, not at runtime)**

## KISS — Keep It Simple, Stupid

Build the simplest thing that solves the current problem.

- No interface for a single implementation **unless it is a consumer-owned port (layer boundary) or a required test seam**. Never export a speculative interface that a producer guessed at. See "Interfaces in Go".
- No generics until the second concrete use forces them.
- No premature abstraction layer. A struct with three fields is better than a `Builder` + `Options` + `Factory`.
- No reflection unless the standard library or a codec demands it.
- A function that reads top-to-bottom is better than a chain of one-liners.

```go
// ❌ Over-engineered
type UserFetcher interface {
    Fetch(ctx context.Context, id UserID) (*User, error)
}
type DefaultUserFetcher struct{ db *database.Pool }
func NewDefaultUserFetcher(db *database.Pool) UserFetcher { return &DefaultUserFetcher{db: db} }

// ✓ Simple
type UserRepository struct{ db *database.Pool }
func NewUserRepository(db *database.Pool) *UserRepository { return &UserRepository{db: db} }
```

## DRY — Don't Repeat Yourself (with Go restraint)

Duplicated *knowledge* is the bug. Duplicated *code* is sometimes the right choice.

- **Rule of three.** Extract on the third repetition, not the second. Two similar blocks may diverge.
- **A little copying is better than a little dependency** (Go proverb). Copying ten lines is better than coupling two packages.
- Distinguish *coincidental* duplication (same shape, different reason to change) from *essential* duplication (same business rule in two places).
- Extract because both call sites must change together when the rule changes. Never extract because shapes look alike.

## SOLID in Go

SOLID is not OO ceremony. It is dependency and change management (Uncle Bob, *Solid Relevance*). In Go, its cornerstone is the **small interface** (Dave Cheney, *SOLID Go Design*). Go expresses SOLID through **packages, composition, and tiny consumer-owned interfaces**, not class hierarchies.

| Principle | Go reframing |
|---|---|
| SRP | One actor / one reason to change per type, function, package |
| OCP | Extend via composition + interface satisfaction. Do not change callers |
| LSP | Every interface implementation honors the interface's *behavioral* contract |
| ISP | Interfaces are tiny (1–3 methods). The consumer declares only what it needs |
| DIP | High-level code owns the abstraction. Adapters depend inward |

## SRP — Single Responsibility Principle

Each type, function, or package has one reason to change. A "reason to change" means **one actor/stakeholder**. Report *content* (owned by finance) and report *format* (owned by ops) are two responsibilities, even inside one struct.

- A function name that contains "and" is two functions. Split it.
- A package that mixes HTTP transport, business logic, and persistence is three packages.
- A struct with two unrelated method clusters (one mutates `cache`, one talks to `db`) is two structs.
- A doc comment that needs a list to describe one identifier signals two responsibilities.

```go
// ❌ Two responsibilities
func (s *OrderService) ValidateAndSubmit(ctx context.Context, o Order) error { /* ... */ }

// ✓ One each
func (s *OrderService) Validate(o Order) error { /* ... */ }
func (s *OrderService) Submit(ctx context.Context, o Order) error { /* ... */ }
```

## OCP — Open/Closed Principle

Open for extension, closed for modification. Go has no inheritance. Extend through **composition and interface satisfaction**. Never extend by changing existing callers.

- New behavior = a new type that satisfies an existing small interface. The dispatcher that ranges over that interface never changes.
- Functional options, middleware/decorator chains, and `io.Writer` wrappers are Go's OCP.

```go
// ✓ Add a SlackNotifier without touching Dispatcher
type Notifier interface{ Notify(ctx context.Context, msg Message) error }

type Dispatcher struct{ targets []Notifier }            // closed
func (d Dispatcher) Send(ctx context.Context, m Message) error {
    for _, n := range d.targets { /* ... */ }
    return nil
}

type SlackNotifier struct{ /* ... */ }                  // open: new impl, no edits upstream
func (SlackNotifier) Notify(ctx context.Context, m Message) error { /* ... */ }
```

A growing `switch` over a type tag that must gain a `case` for every new variant is the OCP smell. Replace it with interface dispatch. Exception: a *sealed* sum type (see Type-Driven Design) closes its cases deliberately. It trades OCP for compiler-enforced exhaustiveness on purpose.

## LSP — Liskov Substitution Principle

Go has no subclassing, so LSP is about **interface contract honesty**. Every implementation must honor the documented behavior of the interface, not only its signature. Structural typing makes an accidental signature match easy and makes contract violations silent.

- Document behavioral contracts on the interface: error semantics, nil handling, idempotency, ordering. An implementation that weakens them is not substitutable.
- A `Reader` that returns `n > 0` *and* `io.EOF` inconsistently breaks substitutability, even though it compiles.

```go
// ❌ LSP violation: the Store contract says "returns ErrNotFound when absent";
//    this impl returns (nil, nil) — callers relying on the contract break.
func (m memStore) Get(id ID) (*User, error) { return m.users[id], nil }

// ✓ Honors the contract every Store implementation must keep
func (m memStore) Get(id ID) (*User, error) {
    u, ok := m.users[id]
    if !ok {
        return nil, ErrNotFound
    }
    return u, nil
}
```

## ISP — Interface Segregation Principle

**The smaller the interface, the more powerful it is** (Cheney). Split fat interfaces by *consumer need*, not by producer convenience.

- Prefer 1–3 method interfaces. `io.Reader` / `io.Writer` (one method) are the gold standard.
- A **God interface** (`Repository` with 20 methods) forces every consumer and every fake to depend on methods it never calls. Split it so that each consumer sees only what it uses.
- Interface mechanics (embedding, composing small interfaces into larger ones) → `samber/cc-skills-golang@golang-structs-interfaces`. This section governs interface *size and shape*.

```go
// ❌ God interface — every caller and mock carries all six methods
type UserStore interface {
    Create(...); Update(...); Delete(...); Get(...); List(...); Search(...)
}

// ✓ Segregated by what each consumer actually needs
type UserReader interface{ Get(ctx context.Context, id UserID) (*User, error) }
type UserWriter interface{ Create(ctx context.Context, u *User) error }
// A read-only handler depends on UserReader alone.
```

## DIP — Dependency Inversion Principle

High-level policy must not depend on low-level detail. Both depend on an abstraction. In Go, **the abstraction belongs with the high-level consumer**, and this inverts the source-code dependency.

- The interactor (high-level) defines the port interface it needs. The Postgres adapter (low-level) imports the port and satisfies it. The interactor never imports the adapter.
- **go-modularization** enforces the same import-direction invariant (`domain` / `ports` / `interactor` never import adapters). For concrete folder rules and the verifier, see that skill.

```go
// billing package (high-level) OWNS the abstraction it depends on
package billing

type ChargeStore interface{ Save(ctx context.Context, r Receipt) error }

type Charger struct{ store ChargeStore }   // depends on its own abstraction, not on postgres

// postgres package (low-level) depends inward — imports billing, satisfies ChargeStore
```

## Interfaces in Go

**Consumer-owned interfaces.** Define an interface in the package that *uses* it. List only the methods that the consumer calls. Do **not** ship a producer-side interface "for flexibility" next to its single implementation. That is interface pollution. Accept interfaces and return concrete structs.

**Decision tree — should this be an interface?**

```text
Is there a 2nd concrete implementation today?            → yes → interface
Is it a port crossing a layer boundary (adapter seam)?   → yes → interface (consumer-owned, ≤3 methods)
Is it required to inject a test double at a boundary?     → yes → interface (consumer-owned)
Otherwise                                                → NO  → use the concrete struct
```

The middle two cases make "no interface for a single implementation" a guideline, not a law. Ports and test seams legitimately have one production implementation. The justification is decoupling/testability (DIP), never speculation. For test-double placement at port boundaries, see `go-testing-strategy`.

## Object Calisthenics — Adapted for Go

This section adapts Jeff Bay's calisthenics. It drops the two rules that samber already covers: rule 6 "no abbreviations" (see `golang-naming`) and rule 8 "no getters/setters" (see `golang-naming` and `golang-structs-interfaces`).

### The Six Remaining Rules

1. **One level of indentation per method.** This rule tolerates up to two levels. Three levels are a smell, so extract code. For indentation and early-return mechanics, see `golang-code-style`.
2. **Don't use `else`.** Use early returns and guard clauses.
3. **Wrap all primitives and IDs in named types.** `type UserID string`, `type Cents int64`. Validate in a constructor when validation matters.
4. **First-class collections.** A struct whose only field is a slice or map should contain nothing else. Operations live on the collection type.
5. **One dot per line.** This rule honors the Law of Demeter. Use what you know, not the friend of a friend. Fluent builders are the exception.
6. **Keep all entities small.** Keep files under ~500 lines, functions under ~50 lines and packages under ~10 source files. A struct with more than seven fields deserves a second look.

### When to Apply

- Designing a new type or package
- Refactoring
- Code review
- When you read existing code aloud and it feels noisy

## Feature Envy Detection

A method that uses another type's data more than its own data belongs on that other type.

```go
// ❌ FEATURE ENVY — InvoiceGenerator obsesses over Order's internals
type InvoiceGenerator struct{}

func (g *InvoiceGenerator) Generate(o Order) Invoice {
    var total Cents
    for _, item := range o.Items {
        total += item.Price * Cents(item.Quantity)
    }
    total += total*o.TaxRate/100 + o.ShippingCost
    return Invoice{Total: total}
}

// ✓ Move the logic to the type it envies
type Order struct { /* ... */ }

func (o Order) Total() Cents { /* uses o.Items, o.TaxRate, o.ShippingCost */ }

type InvoiceGenerator struct{}

func (g *InvoiceGenerator) Generate(o Order) Invoice {
    return Invoice{Total: o.Total()}
}
```

**Detection heuristic:** count the receiver-field references and the argument-field references. If there are more argument references, the method has feature envy.

## Forbidden Generic Package and Type Names

`golang-naming` covers identifier naming in general. This skill adds a stricter, project-wide ban on generic placeholders. For **packages, types, and exported functions**, never use:

- `data`, `util` / `utils`, `helper` / `helpers`, `common`, `shared`, `manager`, `processor`
- `handler` (allowed only where Go's HTTP convention demands it: `http.Handler`)
- `service` *as a package name* (acceptable as a type suffix when the domain noun is clear, e.g. `BillingService`)

These names tell the reader nothing about what the code does. Pick a domain noun.

```go
// ❌ Generic
package utils
type DataProcessor struct{}
func (p *DataProcessor) Process(d any) any { /* ... */ }

// ✓ Domain-revealing
package billing
type InvoiceCalculator struct{ taxRates TaxRateTable }
func (c *InvoiceCalculator) Calculate(o Order) Invoice { /* ... */ }
```

**Package-name checklist:**

- Is it a single, lowercase domain noun?
- Does it describe what is inside, not where it sits?
- Does `package X` make the call site read like English (`billing.InvoiceCalculator`, not `utils.DataProcessor`)?

## Type-Driven Design

Express domain rules in the type system, so that the compiler enforces them.

### Make Illegal States Unrepresentable

```go
// ❌ Primitive obsession — illegal combinations possible
type Order struct {
    Status      string    // any string at all
    ShippedAt   time.Time // could be set when Status != "shipped"
    TrackingNum string    // could be set when Status == "unconfirmed"
}

// ✓ Sealed sum type — illegal states impossible
type Order interface {
    isOrder()
}

type UnconfirmedOrder struct{ Items []Item }
type ConfirmedOrder struct {
    Items              []Item
    ConfirmationNumber string
}
type ShippedOrder struct {
    Items              []Item
    ConfirmationNumber string
    TrackingNumber     string
    ShippedAt          time.Time
}

func (UnconfirmedOrder) isOrder() {}
func (ConfirmedOrder) isOrder()   {}
func (ShippedOrder) isOrder()     {}
```

The unexported `isOrder()` method seals the union. Only types in this package can implement it. Dispatch with a type switch:

```go
switch o := order.(type) {
case UnconfirmedOrder:
    // o has Items only
case ConfirmedOrder:
    // o has ConfirmationNumber
case ShippedOrder:
    // o has TrackingNumber and ShippedAt
}
```

### Transitions Are Methods on the Source State

Each legal state change is a method on the source state. The API does not contain illegal transitions. `UnconfirmedOrder` has no `Ship` method, so a call to it is a compile error, not a runtime validation. Validation that survives the type system returns an `error`. By default, that error is an `errorkit` error. Register its codes once with `errorkit.MustRegister` in `init()` (see [`references/errorkit.md`](references/errorkit.md)).

```go
// Codes ERR_ORDER_EMPTY / ERR_ORDER_TRACKING_REQUIRED registered in init() — see appendix.
func (o UnconfirmedOrder) Confirm(confirmationNumber string) (ConfirmedOrder, error) {
    if len(o.Items) == 0 {
        return ConfirmedOrder{}, errorkit.NewError("ERR_ORDER_EMPTY")
    }
    if confirmationNumber == "" {
        return ConfirmedOrder{}, errorkit.NewError(errorkit.ERR_VALIDATION).
            With(errorkit.WithReason("order: confirmationNumber is required"))
    }
    return ConfirmedOrder{
        Items:              append([]Item(nil), o.Items...),
        ConfirmationNumber: confirmationNumber,
    }, nil
}

func (o ConfirmedOrder) Ship(trackingNumber string, at time.Time) (ShippedOrder, error) {
    if trackingNumber == "" {
        return ShippedOrder{}, errorkit.NewError("ERR_ORDER_TRACKING_REQUIRED")
    }
    return ShippedOrder{
        Items:              append([]Item(nil), o.Items...),
        ConfirmationNumber: o.ConfirmationNumber,
        TrackingNumber:     trackingNumber,
        ShippedAt:          at,
    }, nil
}
```

Non-SDK Go: replace each `errorkit.NewError(...)` with a sentinel error, for example `var ErrOrderEmpty = errors.New("order: cannot confirm with no items")`. Compare with `errors.Is` (see `samber/cc-skills-golang@golang-error-handling`).

### Wrap Primitives in Named Types

```go
// ❌ Easy to swap arguments by accident
func Transfer(fromID string, toID string, amount int64) error

// ✓ Compiler catches the swap
type AccountID string
type Cents int64

func Transfer(from AccountID, to AccountID, amount Cents) error
```

Add a constructor when validation matters:

```go
type Email string

func NewEmail(s string) (Email, error) {
    if !strings.Contains(s, "@") {
        return "", errorkit.NewError(errorkit.ERR_VALIDATION).
            With(errorkit.WithReason("email: invalid address %q", s))
    }
    return Email(s), nil
}
```

Non-SDK Go: return `fmt.Errorf("email: invalid address %q", s)` instead (see `samber/cc-skills-golang@golang-error-handling`).

## Prefer Immutability

Default to immutable data. Mutation causes aliasing bugs and races, and it surprises callers.

```go
// ❌ Mutates the caller's Order
func Process(o *Order) {
    o.Status = StatusProcessing
    o.Items = append(o.Items, freeGift)
}

// ✓ Caller controls what happens
func Process(o Order) Order {
    next := o
    next.Status = StatusProcessing
    next.Items = append(append([]Item(nil), o.Items...), freeGift)
    return next
}
```

### Application Rules

- Prefer value receivers when the method does not mutate state.
- Prefer to return a new struct, not to mutate a parameter.
- Copy slices and maps before you store them in a struct field. Slices share backing arrays. For append-aliasing details, see `golang-safety`.
- In `for _, x := range items`, `x` is a copy, and a mutation of `x` does nothing. Use the index form when you intend to mutate.
- If you must mutate, the function name should make the mutation obvious (`AppendItem`, `SetStatus`). The receiver must be a pointer.

## YAGNI — You Aren't Gonna Need It

Do not build features until you actually need them. Speculative code costs time to write and time to maintain. It is usually wrong by the time the real requirement arrives.

```go
// ❌ Over-engineered for hypothetical futures
type PaymentProcessor interface {
    Process(ctx context.Context, p Payment) (Result, error)
    Refund(ctx context.Context, p Payment) (Result, error)
    PartialRefund(ctx context.Context, p Payment, amount Cents) (Result, error)
    Schedule(ctx context.Context, p Payment, at time.Time) (Result, error)
    Recurring(ctx context.Context, p Payment, sched Schedule) (Result, error)
    // ... seven more "we might need them"
}
// One method is actually called today.
```

### Application Rules

- Build the simplest thing that works today.
- Add capabilities when a real requirement demands them.
- "We might need it" is not a requirement.
- Generics, options structs, and interfaces all qualify as features. Defer them too.

## Anti-Patterns Cheat Sheet

Stop if you are about to:

- Represent state with a free-form `string` → sealed sum-type interface.
- Pass raw `string` / `int64` IDs and amounts → wrap in named types (`UserID`, `Cents`).
- Move logic out of the type whose data it uses → keep it on the envied type.
- Name a package `util`, `common`, `helpers`, `shared`, `manager`, `handler`, `processor`, `data`, or `service` → use a domain noun.
- Write a `// this does X` comment → make the code self-explanatory. Keep only doc comments.
- Mutate a parameter without a pointer receiver and an explicit method name → return a new value.
- Build "for later" → build for now.
- Add a speculative single-implementation interface → wait for the second use, or justify it as a consumer-owned port / test seam.
- Export a fat "God interface" (15+ methods) → segregate by consumer need (ISP), with 1–3 methods each.
- Use `errors.New` / `fmt.Errorf` in a trypanic/go-sdk project → use `errorkit.NewError(code)`.
- Extract a helper after only two repetitions → wait for the third.
- Use "and" in a function or method name → split it.

Defer to the corresponding samber skill for broader anti-patterns. Examples: `%v` instead of `%w`, missing `errors.Is`, ignoring `error`, comma-ok, nil-interface trap, goroutine leaks, `init()` for service setup, getter/setter `Get*` prefix, deep indentation.

## Appendix: trypanic/go-sdk Projects — `errorkit`

This appendix is in [`references/errorkit.md`](references/errorkit.md). Apply it **only** when the project imports `github.com/trypanic/go-sdk/v2`.
