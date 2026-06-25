---
name: go-design-principles
description: Go design judgement complementing samber/cc-skills-golang. Encodes the five SOLID principles framed for Go (SRP by actor/reason-to-change, OCP by composition, LSP by interface contract honesty, ISP small interfaces, DIP consumer-owned dependency direction), interface placement (consumer-owned, define where used, decision tree), KISS, DRY (rule-of-three), object calisthenics for Go (one indent, no else, named-type wrappers, first-class collections, one dot per line), feature-envy detection, forbidden generic package names (util/common/helpers/shared/manager/handler/processor/data), type-driven design (sealed sum-type interfaces, wrapped primitives with validating constructors), immutability, YAGNI. Errors flow through github.com/trypanic/go-sdk/errorkit by default (non-SDK Go falls back to samber stdlib mechanics). Use when asked "is this design idiomatic", "should this be an interface", "apply SOLID", "model this state machine", "wrap this primitive", "spot feature envy", "apply KISS/DRY/SRP". Auto-trigger on primitive obsession, status-string state machines, feature envy, forbidden package names, or speculative interfaces. Defers to samber/cc-skills-golang for naming, structs/interfaces mechanics, DI, context, concurrency, nil-safety, style. Out of scope — folder layout (go-modularization), go-sdk wiring (go-sdk-bootstrap). Skip non-Go projects.
version: 1.0.0
---

# Go Design Principles

Higher-level design judgement for idiomatic Go. Adapted from [NTCoding/claude-skillz](https://github.com/NTCoding/claude-skillz/blob/main/software-design-principles/SKILL.md), Scott Wlaschin's type-driven design, and Jeff Bay's object calisthenics — reframed for Go.

This skill is **complementary**, not standalone. It assumes [`samber/cc-skills-golang`](https://github.com/samber/cc-skills-golang) is installed and active. Anything covered there is **not** repeated here.

## Defers To (Do Not Duplicate)

| Topic | Authoritative skill |
|---|---|
| Error mechanics **for non-SDK Go only** (`%w`, `errors.Is` / `errors.As`, sentinel/typed errors, `panic` discipline, `slog`, `samber/oops`). trypanic/go-sdk projects create errors with `errorkit` instead — see Critical Rules + appendix | `samber/cc-skills-golang@golang-error-handling` |
| Identifier naming (`Err` prefix, `New` constructors, receivers, MixedCaps, boolean prefixes, error string casing) | `samber/cc-skills-golang@golang-naming` |
| Accept-interfaces-return-structs, small interfaces, embedding, type assertions, pointer vs value receivers | `samber/cc-skills-golang@golang-structs-interfaces` |
| Constructor injection, no globals / no service `init()`, container at composition root | `samber/cc-skills-golang@golang-dependency-injection` |
| `context.Context` propagation, first parameter, never in struct, cancellation | `samber/cc-skills-golang@golang-context` |
| Goroutine ownership, channel ownership, leak prevention, `select` with `ctx.Done()` | `samber/cc-skills-golang@golang-concurrency` |
| Nil-interface trap, comma-ok type assertion, append aliasing, defensive copies, useful zero values, `defer` in loops | `samber/cc-skills-golang@golang-safety` |
| Indentation, early returns, line breaking, variable declaration form | `samber/cc-skills-golang@golang-code-style` |
| Functional options, constructor patterns, `init()` avoidance | `samber/cc-skills-golang@golang-design-patterns` |

When this skill and a samber skill conflict, the samber skill wins for its topic. This skill only adds principles samber does not cover.

## Critical Rules

🚨 **Make illegal states unrepresentable.** Use sealed sum-type interfaces (unexported sealing method) and distinct types per state. Never represent state with a free-form `string`.

🚨 **Wrap primitives in named types.** `type UserID string`, `type Cents int64`, `type Email string`. Validate in a constructor when validation matters. The compiler catches argument-order bugs that bare `string` and `int64` cannot.

🚨 **Forbidden generic package names.** Never `util`, `utils`, `common`, `shared`, `helpers`, `manager`, `handler` (except `http.Handler`), `processor`, `data`. Also forbidden as a package name: `service`. Pick a domain noun.

🚨 **Feature envy is a refactor signal.** A method that touches another type's fields more than its own belongs on that other type.

🚨 **No explanatory comments.** Doc comments on exported identifiers (Go convention) stay — terse and behavioral. Inline `// this does X` comments are a smell — refactor the code instead.

🚨 **Default to immutability.** Return new values; do not mutate parameters. If you must mutate, the method name and pointer receiver must make it obvious.

🚨 **Errors flow through `errorkit`, not stdlib.** In trypanic/go-sdk projects, create every error with `errorkit.NewError(code)` — **never** `errors.New` or `fmt.Errorf` as a final return; remove stdlib error definitions so nothing competes with the `*errorkit.AppError` flow. Wrap once at the boundary with `errorkit.NewError(code).With(errorkit.WithWrapped(err))`. Type-switch to preserve an existing `*AppError` — never re-wrap. Register service-specific codes via `errorkit.MustRegister` in `init()`. **Only** when the project does not import `github.com/trypanic/go-sdk` do you fall back to stdlib error mechanics (`samber/cc-skills-golang@golang-error-handling`). See the appendix.

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

Build the simplest thing that solves the problem in front of you.

- No interface for a single implementation **unless it is a consumer-owned port (layer boundary) or a required test seam** — see "Interfaces in Go" below. Multiplicity is not the only valid reason; decoupling and testability (DIP) are. Never export a speculative interface a producer guessed at.
- No generics until the second concrete use forces them.
- No premature abstraction layer. A struct with three fields beats a `Builder` + `Options` + `Factory`.
- No reflection unless the standard library or a codec demands it.
- A function that reads top-to-bottom beats a chain of one-liners.

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

Duplicated *knowledge* is the bug. Duplicated *code* is sometimes the right call.

- **Rule of three.** Extract on the third repetition, not the second. Two similar blocks may diverge.
- **A little copying is better than a little dependency** (Go proverb). Copying ten lines beats coupling two packages.
- Distinguish *coincidental* duplication (same shape, different reason to change) from *essential* duplication (same business rule in two places).
- Extract because both call sites must change together when the rule changes — never because shapes look alike.

## SOLID in Go

SOLID is not OO ceremony — it is dependency and change management (Uncle Bob, *Solid Relevance*), and in Go its cornerstone is the **small interface** (Dave Cheney, *SOLID Go Design*). Go expresses SOLID through **packages, composition, and tiny consumer-owned interfaces**, not class hierarchies.

| Principle | Go reframing |
|---|---|
| SRP | One actor / one reason to change per type, function, package |
| OCP | Extend via composition + interface satisfaction; don't modify callers |
| LSP | Every interface implementation honors the interface's *behavioral* contract |
| ISP | Interfaces are tiny (1–3 methods); the consumer declares only what it needs |
| DIP | High-level code owns the abstraction; adapters depend inward |

## SRP — Single Responsibility Principle

One reason to change per type, function, or package — where "reason to change" means **one actor/stakeholder**. Report *content* (owned by finance) and report *format* (owned by ops) are two responsibilities even inside one struct.

- A function name with "and" in it is two functions. Split.
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

Open for extension, closed for modification. Go has no inheritance — extend through **composition and interface satisfaction**, never by editing existing callers.

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

A growing `switch` over a type tag that must gain a `case` for every new variant is the OCP smell — replace with interface dispatch. Exception: a *sealed* sum type whose cases are deliberately closed (see Type-Driven Design) trades OCP for compiler-checked exhaustiveness on purpose.

## LSP — Liskov Substitution Principle

Go has no subclassing, so LSP is about **interface contract honesty**: every implementation must honor the documented behavior of the interface, not merely its signature. Structural typing makes accidental signature-match easy and contract violations silent.

- Document behavioral contracts on the interface: error semantics, nil handling, idempotency, ordering. An implementation that weakens them is not substitutable.
- A `Reader` that returns `n > 0` *and* `io.EOF` inconsistently breaks substitutability even though it compiles.

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

The cornerstone of SOLID in Go: **the smaller the interface, the more powerful it is** (Cheney). Split fat interfaces by *consumer need*, not producer convenience.

- Prefer 1–3 method interfaces. `io.Reader` / `io.Writer` (one method) are the gold standard.
- A **God interface** (`Repository` with 20 methods) forces every consumer and every fake to depend on methods it never calls. Split it so each consumer sees only what it uses.
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

High-level policy must not depend on low-level detail; both depend on an abstraction — and in Go **the abstraction belongs with the high-level consumer**, which inverts the source-code dependency.

- The interactor (high-level) defines the port interface it needs. The Postgres adapter (low-level) imports the port and satisfies it. The interactor never imports the adapter.
- This is the same import-direction invariant enforced by **go-modularization** (`domain` / `ports` / `interactor` never import adapters). For concrete folder rules and the verifier, see that skill.

```go
// billing package (high-level) OWNS the abstraction it depends on
package billing

type ChargeStore interface{ Save(ctx context.Context, r Receipt) error }

type Charger struct{ store ChargeStore }   // depends on its own abstraction, not on postgres

// postgres package (low-level) depends inward — imports billing, satisfies ChargeStore
```

## Interfaces in Go

Where interfaces come from, and whether one should exist at all.

**Consumer-owned interfaces.** Define an interface in the package that *uses* it, listing only the methods that consumer calls. Do **not** ship a producer-side interface "for flexibility" next to its single implementation — that is interface pollution. Accept interfaces; return concrete structs.

**Decision tree — should this be an interface?**

```text
Is there a 2nd concrete implementation today?            → yes → interface
Is it a port crossing a layer boundary (adapter seam)?   → yes → interface (consumer-owned, ≤3 methods)
Is it required to inject a test double at a boundary?     → yes → interface (consumer-owned)
Otherwise                                                → NO  → use the concrete struct
```

The middle two cases are why "no interface for a single implementation" is a guideline, not a law: ports and test seams legitimately have one production implementation. The justification is decoupling/testability (DIP), never speculation. Test-double placement at port boundaries: see `go-testing-strategy`.

## Object Calisthenics — Adapted for Go

Jeff Bay's calisthenics, with the two rules already covered by samber dropped (rule 6 "no abbreviations" → see `golang-naming`; rule 8 "no getters/setters" → see `golang-naming` and `golang-structs-interfaces`).

### The Six Remaining Rules

1. **One level of indentation per method.** Up to two tolerated. Three indents is a smell — extract. (Indentation/early-return mechanics: see `golang-code-style`.)
2. **Don't use `else`.** Use early returns and guard clauses.
3. **Wrap all primitives and IDs in named types.** `type UserID string`, `type Cents int64`. Validate in a constructor when validation matters.
4. **First-class collections.** A struct whose only field is a slice or map should contain nothing else. Operations live on the collection type.
5. **One dot per line.** Honors the Law of Demeter. Reach for what you know, not for the friend of a friend. Fluent builders are the exception.
6. **Keep all entities small.** Files under ~500 lines. Functions under ~50. Packages under ~10 source files. Structs over seven fields deserve a second look.

### When to Apply

- Designing a new type or package
- Refactoring
- Code review
- When reading existing code aloud feels noisy

## Feature Envy Detection

A method that uses another type's data more than its own belongs on that other type.

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

**Detection heuristic:** count receiver-field references vs argument-field references. More argument references? Feature envy.

## Forbidden Generic Package and Type Names

`golang-naming` covers identifier naming in general. This skill adds a sharper, project-wide ban on generic placeholders.

For **packages, types, and exported functions**, never use:

- `data`
- `util` / `utils`
- `helper` / `helpers`
- `common`
- `shared`
- `manager`
- `handler` (allowed only where Go's HTTP convention demands it: `http.Handler`)
- `processor`
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

**Package-name checklist:** is it a single, lowercase domain noun? Does it describe what's inside, not where it sits? Does `package X` make the call site read like English (`billing.InvoiceCalculator`, not `utils.DataProcessor`)?

## Type-Driven Design

Express domain rules in the type system so the compiler enforces them.

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

The unexported `isOrder()` method seals the union — only types in this package can implement it. Dispatch with a type switch:

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

Each legal state change is a method on the source state. Illegal transitions are simply absent from the API — `UnconfirmedOrder` has no `Ship` method, so calling it is a compile error, not a runtime check. Validation that survives the type system returns an `error`.

Validation that survives the type system returns an error. By default that error is `errorkit` (codes registered once via `errorkit.MustRegister` in `init()` — see appendix); non-SDK Go falls back to sentinel errors + `errors.Is` (`samber/cc-skills-golang@golang-error-handling`).

```go
// Codes ERR_ORDER_EMPTY / ERR_ORDER_TRACKING_REQUIRED registered in init() — see appendix.
func (o UnconfirmedOrder) Confirm(confirmationNumber string) (ConfirmedOrder, error) {
    if len(o.Items) == 0 {
        return ConfirmedOrder{}, errorkit.NewError("ERR_ORDER_EMPTY")
    }
    if confirmationNumber == "" {
        return ConfirmedOrder{}, errorkit.NewError(errorkit.ERR_VALIDATION).
            With(errorkit.WithMessage("order: confirmationNumber is required"))
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

Non-SDK Go: replace each `errorkit.NewError(...)` with a sentinel (`var ErrOrderEmpty = errors.New("order: cannot confirm with no items")`) and compare with `errors.Is`. Code registration for the SDK variant: see the appendix.

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
            With(errorkit.WithMessage(fmt.Sprintf("email: invalid address %q", s)))
    }
    return Email(s), nil
}
```

Non-SDK Go: return `fmt.Errorf("email: invalid address %q", s)` instead — see `samber/cc-skills-golang@golang-error-handling`.

## Prefer Immutability

Default to immutable data. Mutation breeds aliasing bugs, races, and surprising callers.

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
- Prefer returning a new struct over mutating a parameter.
- Copy slices and maps before storing them in a struct field — slices share backing arrays. (Append-aliasing details: `golang-safety`.)
- `for _, x := range items` — `x` is a copy; mutating it does nothing. Use the index form when you mean to mutate.
- If you must mutate, the function name should make it obvious (`AppendItem`, `SetStatus`), and the receiver must be a pointer.

## YAGNI — You Aren't Gonna Need It

Don't build features until they're actually needed. Speculative code costs time to write, time to maintain, and is usually wrong by the time the real requirement arrives.

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

Stop if you're about to:

- Represent state with a free-form `string` → sealed sum-type interface.
- Pass raw `string` / `int64` IDs and amounts → wrap in named types (`UserID`, `Cents`).
- Move logic out of the type whose data it touches → keep it on the envied type.
- Name a package `util`, `common`, `helpers`, `shared`, `manager`, `handler`, `processor`, `data`, or `service` → use a domain noun.
- Write a `// this does X` comment → make the code self-explanatory; keep doc comments only.
- Mutate a parameter without a pointer receiver and an explicit method name → return a new value.
- Build "for later" → build for now.
- Add a speculative interface for a single implementation → wait for the second use, or justify it as a consumer-owned port / test seam.
- Export a fat "God interface" (15+ methods) → segregate by consumer need (ISP); 1–3 methods each.
- Reach for `errors.New` / `fmt.Errorf` in a trypanic/go-sdk project → use `errorkit.NewError(code)`.
- Extract a helper after only two repetitions → wait for the third.
- Use "and" in a function or method name → split it.

For broader anti-patterns (`%v` instead of `%w`, missing `errors.Is`, ignoring `error`, comma-ok, nil-interface trap, goroutine leaks, `init()` for service setup, getter/setter `Get*` prefix, deep indentation), defer to the corresponding samber skill.

---

## Appendix: trypanic/go-sdk Projects — `errorkit`

Apply this section **only** when the project imports `github.com/trypanic/go-sdk`. In SDK-based services, errors flow through `*errorkit.AppError`, which carries a code, HTTP status, retriability, and a wrapped cause.

`errorkit` **replaces** the idiomatic-Go error mechanics from `samber/cc-skills-golang@golang-error-handling` for service code in trypanic/go-sdk projects. The principles still hold (return `error`, fail fast, wrap once); the mechanism changes.

**Return `error`, dynamic type `*AppError`.** Do not pin the signature to `*errorkit.AppError`.

```go
func (s *BillingService) Charge(ctx context.Context, in ChargeInput) (Receipt, error) {
    if in.Amount <= 0 {
        return Receipt{}, errorkit.NewError(errorkit.ERR_VALIDATION).
            With(errorkit.WithMessage("amount must be positive"))
    }
    // ...
}
```

**Wrap once at the boundary, preserve existing `*AppError`.** Re-wrapping with `ERR_INTERNAL` destroys the original code, HTTP status, and retriability.

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

**Register service-specific codes in `init()`.**

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

**Sealed-transition codes.** The sealed-transition example under "Type-Driven Design" returns `errorkit.NewError("ERR_ORDER_EMPTY")` and `errorkit.NewError("ERR_ORDER_TRACKING_REQUIRED")`. Register both codes once at startup:

```go
func init() {
    errorkit.MustRegister(errorkit.Metadata{
        Code: "ERR_ORDER_EMPTY", Type: errorkit.ErrorTypeValidation,
        Group: errorkit.GroupUnknown, Category: "orders",
        Description: "Cannot confirm an order with no items",
        HTTPStatus: 422, Retriable: false,
    })
    errorkit.MustRegister(errorkit.Metadata{
        Code: "ERR_ORDER_TRACKING_REQUIRED", Type: errorkit.ErrorTypeValidation,
        Group: errorkit.GroupUnknown, Category: "orders",
        Description: "Tracking number required to ship",
        HTTPStatus: 422, Retriable: false,
    })
}
```

**Forbidden in errorkit-using service code:**

- `errors.New` / `fmt.Errorf` as the final return — use `errorkit.NewError(code)`.
- Re-wrapping an `*AppError` (double-wrap).
- Exposing `*errorkit.AppError` in a function signature.

For background on the SDK's wrapping rules and project setup, see the `go-sdk-bootstrap` skill.
