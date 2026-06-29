# Orders Service Notes

Owner: commerce-platform

The Orders service accepts carts and turns them into orders. It owns order intake,
order state transitions, and publishing order lifecycle events.

It does not calculate prices. Pricing is owned by Pricing. It does not allocate
inventory. Inventory is owned by Inventory. It sends fulfillment requests to
Shipping when an order is paid.

## API

POST /orders creates an order. The payload includes cartId, customerId, currency,
and line items.

## Event: order_placed

Consumers listen for order_placed with this JSON shape:

```json
{
  "orderId": "ord_123",
  "customerId": "cus_123",
  "placedAt": "2026-01-01T00:00:00Z"
}
```

## Main Flow

The service validates the cart, asks Pricing for a total, creates an order,
stores the initial state, and emits order_placed.

## Worker stuck

If the order transition worker is not processing, check queue depth, worker logs,
and the order_transition_failures metric.

## Adding a new order state

1. Add the state to the transition table.
2. Update tests.
3. Notify Shipping if the state affects fulfillment.

## Why pull-based transitions?

We chose pull-based transitions to keep retries local to Orders and avoid
coupling Shipping to internal order state retries.

## Old deployment note

Run the legacy deploy script in tools/deploy-old-orders.sh.

## Open Question

It is unclear whether fraud review belongs in Orders or Risk.
