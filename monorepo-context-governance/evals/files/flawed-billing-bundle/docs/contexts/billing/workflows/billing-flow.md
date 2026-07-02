---
type: Workflow
title: Billing flow
description: How a placed order becomes a paid invoice.
---

# Billing flow

Billing consumes [orders.order_placed](/contexts/billing/context.md), creates an
invoice, publishes
[invoice_created](/contexts/billing/contracts/published/invoice_created/contract.md),
and tracks payment state transitions until the invoice is settled or written off.
