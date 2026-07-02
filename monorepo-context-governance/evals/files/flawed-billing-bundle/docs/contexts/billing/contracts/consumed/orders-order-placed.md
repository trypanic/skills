---
type: Reference
title: orders.order_placed (local copy)
description: Local copy of the order_placed schema so we do not depend on Orders docs.
---

# orders.order_placed

We keep a local copy of the schema for convenience:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "order_placed",
  "type": "object",
  "properties": {
    "orderId": { "type": "string" },
    "customerId": { "type": "string" },
    "placedAt": { "type": "string", "format": "date-time" }
  },
  "required": ["orderId", "customerId", "placedAt"]
}
```
