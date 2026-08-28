<!-- Template: 01-opinions/{{label}}-{{member}}.md — one per successful seat,
     filled from the gated opinion envelope. Bullets come from the envelope
     arrays; write "none" under a heading whose array is empty. -->
# Response {{label}} — {{member}}

- Run: {{run_id}}
- Stage: 1 (first opinion)
- Status: {{ok|retried}}
- Confidence: {{confidence}}

## Answer

{{answer_md}}

## Key points

- {{key_point}}

## Assumptions

- {{assumption_or_"none"}}

## Limitations

- {{limitation_or_"none"}}

---
Machine envelope: [`envelopes/opinion-{{member}}.json`](../envelopes/opinion-{{member}}.json)
