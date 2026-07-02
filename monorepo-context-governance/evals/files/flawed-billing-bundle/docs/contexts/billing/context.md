---
type: BoundedContext

id: billing-context
title: Billing
status: live
owner:
  team: team-billing
  contact: "#billing"
last_reviewed: 2026-06-01

contracts:
  published:
    - id: billing.invoice_created
      kind: event
      version: 1.0.0
      stability: deprecated
      replacement: null
  consumed:
    - id: orders.order_placed
      version: "1.x"
      ref: ../orders/contracts/published/events/order_placed/v1.schema.json
      usage: "Create an invoice when an order is placed."

dependencies:
  allowed:
    - context: orders
      via: [orders.order_placed]
  forbidden: []

signals: []

entrypoints:
  source: [services/billing/]
  tests: [services/billing/tests/]
---

# Billing

Billing turns placed orders into invoices and tracks their payment state.

## What this context owns

Invoice creation, invoice numbering, and payment-state tracking.

## What this context does not own

Order intake and order state (owned by orders). Price computation (owned by pricing).

## Contracts

- [invoice_created](contracts/published/invoice_created/contract.md) — published event.
- orders.order_placed — consumed from orders.
