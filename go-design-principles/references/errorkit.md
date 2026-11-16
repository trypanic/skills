# trypanic/go-sdk Projects — `errorkit`

Apply this file **only** when the project imports `github.com/trypanic/go-sdk/v2`. A project that still uses the v1 path `github.com/trypanic/go-sdk` must migrate first (see the `go-sdk-bootstrap` skill). In SDK-based services, errors flow through `*errorkit.AppError`. It carries a code, an HTTP status, retriability and a wrapped cause.

For service code in trypanic/go-sdk projects, `errorkit` **replaces** the idiomatic-Go error mechanics from `samber/cc-skills-golang@golang-error-handling`. The principles still hold (return `error`, fail fast, wrap once). The mechanism changes.

**Return `error`, carrying an `*AppError`.** Do not pin the signature to `*errorkit.AppError`. For expected input rejection, `errorkit.NewWithoutStack(code)` skips the stack capture that `NewError` performs.

```go
func (s *BillingService) Charge(ctx context.Context, in ChargeInput) (Receipt, error) {
    if in.Amount <= 0 {
        return Receipt{}, errorkit.NewError(errorkit.ERR_VALIDATION).
            With(errorkit.WithReason("amount must be positive"))
    }
    // ...
}
```

**Wrap once at the boundary, preserve existing `*AppError`.** Re-wrapping with `ERR_INTERNAL` destroys the original code, HTTP status, and retriability. Find the existing `*AppError` with `errorkit.As`, which walks wrapped and joined chains. Match codes with `errorkit.HasCode(err, code)`, not with error text.

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

**Sealed-transition codes.** The sealed-transition example under "Type-Driven Design" in [`SKILL.md`](../SKILL.md) returns `errorkit.NewError("ERR_ORDER_EMPTY")` and `errorkit.NewError("ERR_ORDER_TRACKING_REQUIRED")`. Register both codes once at startup:

```go
func init() {
    errorkit.MustRegister(errorkit.Metadata{
        Code: "ERR_ORDER_EMPTY", Type: errorkit.ErrorTypeInternal,
        Group: errorkit.GroupData, Category: "orders",
        Description: "Cannot confirm an order with no items",
        HTTPStatus: 422, Retriable: false,
    })
    errorkit.MustRegister(errorkit.Metadata{
        Code: "ERR_ORDER_TRACKING_REQUIRED", Type: errorkit.ErrorTypeInternal,
        Group: errorkit.GroupData, Category: "orders",
        Description: "Tracking number required to ship",
        HTTPStatus: 422, Retriable: false,
    })
}
```

**Forbidden in errorkit-using service code:**

- `errors.New` / `fmt.Errorf` as the final return. Use `errorkit.NewError(code)`.
- Re-wrapping an `*AppError` (double-wrap).
- Detecting an `*AppError` with a direct type assertion `err.(*errorkit.AppError)`. Use `errorkit.As(err)`.
- Exposing `*errorkit.AppError` in a function signature.

For background on the SDK's wrapping rules and project setup, see the `go-sdk-bootstrap` skill.
