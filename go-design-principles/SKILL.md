---
name: go-design-principles
description: Project-agnostic Go design principles that complement (and do not duplicate) the samber/cc-skills-golang skill set. Encodes KISS, DRY (with Go's rule-of-three restraint), SRP, object calisthenics adapted for Go (one indent, no else, named-type wrappers, first-class collections, one dot per line, small entities), feature-envy detection, a sharper forbidden-generic-package-name list (util, common, helpers, shared, manager, handler, processor, data, service-as-package), type-driven design (sealed sum-type interfaces with unexported method, state-transition methods, wrapped primitives like UserID/Cents/Email with validating constructors), immutability defaults, YAGNI, and an appendix that swaps idiomatic errors for *errorkit.AppError when the project imports github.com/trypanic/go-sdk. Use when the user or agent says "is this design idiomatic", "model this state machine", "wrap this primitive", "is this package name OK", "spot feature envy", "refactor this for clarity", "apply KISS/DRY/SRP", or any phrase asking for a design judgement that goes beyond style and naming. Auto-trigger when primitive obsession appears (string status fields, raw int IDs), when a state machine is being modelled with status strings, when a method touches argument fields more than receiver fields, when a package is named util/common/helpers/shared/manager/handler/processor/data, when a struct hides three or more knobs that should be states, or when speculative interfaces and abstractions are being added. Defers to samber/cc-skills-golang for error handling (golang-error-handling), naming (golang-naming), structs and interfaces including accept-interfaces-return-structs and small interfaces (golang-structs-interfaces), dependency injection (golang-dependency-injection), context discipline (golang-context), goroutines and channel ownership (golang-concurrency), nil/comma-ok/zero-value safety (golang-safety), code style and indentation (golang-code-style), and constructor / functional-options patterns (golang-design-patterns). Use the errorkit appendix only when the project imports github.com/trypanic/go-sdk; otherwise rely on samber/cc-skills-golang@golang-error-handling. Out of scope: folder layout (see go-modularization), trypanic go-sdk wiring (see go-sdk-bootstrap), lint/formatting/test-framework choice. Do NOT trigger for non-Go projects.
version: 1.0.0
---

# Go Design Principles

Higher-level design judgement for idiomatic Go. Adapted from [NTCoding/claude-skillz](https://github.com/NTCoding/claude-skillz/blob/main/software-design-principles/SKILL.md), Scott Wlaschin's type-driven design, and Jeff Bay's object calisthenics — reframed for Go.

This skill is **complementary**, not standalone. It assumes [`samber/cc-skills-golang`](https://github.com/samber/cc-skills-golang) is installed and active. Anything covered there is **not** repeated here.

## Defers To (Do Not Duplicate)

| Topic | Authoritative skill |
|---|---|
| Error creation, wrapping with `%w`, `errors.Is` / `errors.As`, sentinel and typed errors, `panic` discipline, `slog`, `samber/oops` | `samber/cc-skills-golang@golang-error-handling` |
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

🚨 **(trypanic/go-sdk projects only)** Errors flow through `*errorkit.AppError`. Wrap once at the boundary with `errorkit.NewError(code).With(errorkit.WithWrapped(err))`. Type-switch to preserve an existing `*AppError` — never re-wrap. Register service-specific codes via `errorkit.MustRegister` in `init()`. Skip this rule entirely if the project does not import `github.com/trypanic/go-sdk`. See the appendix.

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

- No interface for a single implementation. Add it when the second concrete type appears.
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

## SRP — Single Responsibility Principle

One reason to change per type, function, or package.

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

For the error mechanics (sentinels, `errors.Is`, `%w` wrapping), defer to `samber/cc-skills-golang@golang-error-handling`. The sealed-transition example just *uses* those mechanics:

```go
var (
    ErrOrderEmpty            = errors.New("order: cannot confirm with no items")
    ErrOrderTrackingRequired = errors.New("order: tracking number required to ship")
)

func (o UnconfirmedOrder) Confirm(confirmationNumber string) (ConfirmedOrder, error) {
    if len(o.Items) == 0 {
        return ConfirmedOrder{}, ErrOrderEmpty
    }
    if confirmationNumber == "" {
        return ConfirmedOrder{}, errors.New("order: confirmationNumber is required")
    }
    return ConfirmedOrder{
        Items:              append([]Item(nil), o.Items...),
        ConfirmationNumber: confirmationNumber,
    }, nil
}

func (o ConfirmedOrder) Ship(trackingNumber string, at time.Time) (ShippedOrder, error) {
    if trackingNumber == "" {
        return ShippedOrder{}, ErrOrderTrackingRequired
    }
    return ShippedOrder{
        Items:              append([]Item(nil), o.Items...),
        ConfirmationNumber: o.ConfirmationNumber,
        TrackingNumber:     trackingNumber,
        ShippedAt:          at,
    }, nil
}
```

For the trypanic/go-sdk variant (registered codes via `errorkit.MustRegister`), see the appendix.

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
        return "", fmt.Errorf("email: invalid address %q", s)
    }
    return Email(s), nil
}
```

For trypanic/go-sdk projects the constructor returns `errorkit.NewError(errorkit.ERR_VALIDATION).With(errorkit.WithMessage(...))` instead of `fmt.Errorf` — see appendix.

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
- Add an interface for a single implementation → wait for the second use.
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

**Sealed-transition variant.** When transitions in a sealed sum type need to fail, use registered codes instead of sentinel errors:

```go
func init() {
    errorkit.MustRegister(errorkit.Metadata{
        Code: "ERR_ORDER_EMPTY", Type: errorkit.ErrorTypeValidation,
        Group: errorkit.GroupUnknown, Category: "orders",
        Description: "Cannot confirm an order with no items",
        HTTPStatus: 422, Retriable: false,
    })
}

func (o UnconfirmedOrder) Confirm(confirmationNumber string) (ConfirmedOrder, error) {
    if len(o.Items) == 0 {
        return ConfirmedOrder{}, errorkit.NewError("ERR_ORDER_EMPTY")
    }
    // ...
}
```

**Forbidden in errorkit-using service code:**

- `errors.New` / `fmt.Errorf` as the final return — use `errorkit.NewError(code)`.
- Re-wrapping an `*AppError` (double-wrap).
- Exposing `*errorkit.AppError` in a function signature.

For background on the SDK's wrapping rules and project setup, see the `go-sdk-bootstrap` skill.
