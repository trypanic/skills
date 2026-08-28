<!-- Template: 02-reviews/rankings.md — aggregate computed by the Clerk per
     references/evaluation.md. One table row per label, best first. In a
     degraded run (zero valid reviews) state that explicitly instead of the
     table. -->
# Aggregate ranking

Method: mean position across all valid peer rankings; ties broken by
first-place votes (descending), then label (ascending). Lower mean rank is
better. See the skill's `references/evaluation.md` for the algorithm and a
worked example.

| Rank | Label | Seat (revealed) | Mean rank | 1st places | Rankings counted |
|---|---|---|---|---|---|
| 1 | {{label}} | {{member}} | {{mean_rank}} | {{first_places}} | {{rankings_count}} |

## Label reveal

During Stage 2 reviewers saw labels only:

| Label | Seat |
|---|---|
| A | {{member}} |

## Disagreement signals

<!-- Per references/evaluation.md §Reading disagreement: contested responses
     (position spread > half the panel), score–rank tension, unanimous #1.
     Write "none observed" if clean. -->

{{signals_or_"none observed"}}
