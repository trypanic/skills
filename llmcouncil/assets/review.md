<!-- Template: 02-reviews/review-by-{{member}}.md — one per successful
     reviewer, filled from the gated review envelope. Repeat the
     "### Response {{label}}" block once per evaluation, in label order. -->
# Peer review by {{member}}

- Run: {{run_id}}
- Stage: 2 (anonymized peer review)
- Status: {{ok|retried}}

Reviewed {{n}} anonymized responses. The reviewer saw labels only; authorship
is revealed in [`rankings.md`](rankings.md).

## Evaluations

### Response {{label}}

Scores: accuracy {{a}}/5 · insight {{i}}/5 · completeness {{c}}/5

**Strengths**

- {{strength}}

**Weaknesses**

- {{weakness}}

## Final ranking (best → worst)

1. Response {{label}}

---
Machine envelope: [`envelopes/review-{{member}}.json`](../envelopes/review-{{member}}.json)
