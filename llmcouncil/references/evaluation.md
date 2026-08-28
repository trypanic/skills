# Evaluation: rubric, aggregation, and validation standard

This file defines how council output quality is scored (rubric), how peer
rankings combine (aggregate algorithm), and what "standard-conformant" means
(error-code catalog + manual gate). `scripts/validate.py` implements the
catalog; the codes here and in the script must stay in sync.

---

## Scoring rubric (Stage 2)

Reviewers score every anonymized response on three integer 1–5 dimensions.
Anchors:

### accuracy
- **1** — materially wrong claims that would mislead the reader
- **2** — a significant error, or several minor ones
- **3** — mostly correct; minor errors or imprecision
- **4** — correct; at most cosmetic imprecision
- **5** — no detectable factual errors; claims well-calibrated to evidence

### insight
- **1** — restates the obvious; adds nothing over common knowledge
- **2** — competent but generic treatment
- **3** — one or two non-obvious, useful observations
- **4** — several non-obvious observations that change how to act
- **5** — reframes or deepens understanding beyond any other response

### completeness
- **1** — misses the core of the question
- **2** — partial treatment of the core
- **3** — covers the core; misses secondary aspects
- **4** — covers core and most secondary aspects
- **5** — core plus material edge cases, within the length budget

Scores inform but do not mechanically determine `final_ranking`; the gate
only requires the ranking to be a valid permutation. Reviewers are told to
keep ranking and scores consistent — flag (do not fail) a reviewer whose #1
ranked response has strictly lower total scores than its #last.

---

## Aggregate ranking algorithm

Input: the `final_ranking` of every SUCCESSFUL review envelope. Position of a
label = its 1-based index in that reviewer's ranking.

For each label:

- `mean_rank` — arithmetic mean of its positions, rounded to 2 decimals
- `first_places` — number of reviewers that ranked it #1
- `rankings_count` — number of rankings it appeared in (= number of
  successful reviews)

Sort best→worst by: `mean_rank` ascending, then `first_places` descending,
then `label` ascending. The two tie-breaks are an addition over the original
(which sorted by average only) so the stored order is deterministic.

Worked example — 3 responses, 3 reviewers:

| Reviewer | Ranking |
|---|---|
| analyst | B, A, C |
| skeptic | B, C, A |
| pragmatist | A, B, C |

| Label | Positions | mean_rank | first_places | Final |
|---|---|---|---|---|
| B | 1,1,2 | 1.33 | 2 | 1st |
| A | 2,3,1 | 2.00 | 1 | 2nd |
| C | 3,2,3 | 2.67 | 0 | 3rd |

Degraded run: zero successful reviews ⇒ `aggregate_ranking: []`, warning
`W-RUN-101`, chairman synthesizes from opinions alone.

---

## Error-code catalog

Emitted by `scripts/validate.py` as `LEVEL CODE where: message`. Stable API:
retry messages quote them verbatim; the manifest `validation.notes` stores
residual ones.

### Envelope errors (any stage)

| Code | Meaning |
|---|---|
| `E-IO-001` | file unreadable or not valid JSON |
| `E-ENV-001` | missing required key |
| `E-ENV-002` | wrong type or out-of-range value |
| `E-ENV-003` | `protocol` or `stage` mismatch |
| `E-ENV-004` | anonymity leak: an opinion's `answer_md` mentions a `council-*` seat name |

### Review-specific errors

| Code | Meaning |
|---|---|
| `E-REV-001` | `evaluations` does not cover each label exactly once |
| `E-REV-002` | `final_ranking` is not an exact permutation of the labels |

### Run-audit errors

| Code | Meaning |
|---|---|
| `E-RUN-001` | required run path missing (README, manifest, stage dirs/files) |
| `E-RUN-002` | manifest field invalid |
| `E-RUN-003` | quorum not met: fewer than 2 successful opinions |
| `E-RUN-004` | `label_map` not bijective or labels not consecutive from `A` |
| `E-RUN-005` | envelope file referenced by the manifest is missing |
| `E-RUN-006` | envelope inconsistent with manifest (member/reviewer/label) |
| `E-RUN-007` | stored `aggregate_ranking` does not match recomputation |
| `E-RUN-008` | synthesis missing or failed |

### Warnings (non-fatal)

| Code | Meaning |
|---|---|
| `W-RUN-101` | degraded run: zero successful reviews |
| `W-RUN-102` | a seat failed a stage and was excluded |
| `W-ENV-101` | `answer_md` suspiciously short (< 200 chars) |

Exit codes of `validate.py`: `0` no errors (warnings allowed), `1` at least
one error, `2` usage/IO error at the CLI level.

---

## Manual gate (no Python available)

Never skip gates. Without `python3`, check by hand and set
`validation.final_run_check: "manual"`:

**Per opinion envelope**
- [ ] last fenced JSON block parses; `protocol`=`llmcouncil/v1`, `stage`=`opinion`
- [ ] `member` equals the requested seat
- [ ] `answer_md` non-empty string; `key_points` 1–7 strings
- [ ] `confidence` number in [0,1]; `assumptions`/`limitations` arrays of strings
- [ ] `answer_md` does not mention any `council-*` seat name (anonymity)

**Per review envelope**
- [ ] `protocol`/`stage` correct; `reviewer` equals the requested seat
- [ ] one evaluation per issued label, no duplicates, no unknown labels
- [ ] each `scores` value an integer 1–5; `strengths`/`weaknesses` non-empty
- [ ] `final_ranking` = every issued label exactly once

**Per synthesis envelope**
- [ ] `protocol`/`stage` correct; `chairman` = `council-chairman`
- [ ] `answer_md` non-empty; `consensus` array; `disputes` array of
      `{topic, positions}`; `confidence` in [0,1]

**Run audit**
- [ ] all layout paths from `references/output-structure.md` exist
- [ ] `label_map` bijective, labels consecutive from `A`
- [ ] ≥ 2 successful opinions; every `ok`/`retried` entry has its envelope
      file and markdown artifact; every `failed` entry has neither
- [ ] aggregate table recomputes from the review envelopes (redo the worked
      example math)
- [ ] manifest statuses match reality; degradations noted in run README

---

## Reading disagreement (for the Chairman and the Stage 4 report)

Comparison signals worth surfacing — these are the point of a council:

- **Contested response**: a label whose position spread (max − min across
  reviewers) exceeds half the panel size. The chairman must address why.
- **Score–rank tension**: a reviewer whose ranking contradicts their own
  scores — weigh that review's ranking less.
- **Unanimous #1**: all reviewers agree on the top response — synthesis
  should lean on it and say so.
- **Consensus vs. quality**: high mean-rank agreement with low accuracy
  scores across the board means the council found all answers weak; the
  chairman must say that plainly rather than synthesize false confidence.
