<!-- Template: README.md at the root of a run directory. Written at Stage 4.
     Replace every {{placeholder}}; drop the degradation section if empty. -->
# LLM Council run — {{run_id}}

**Question:** {{question_one_line}}
**Convened:** {{created_at}} · **Protocol:** llmcouncil/v1 · **Validation:** {{pass|fail|manual}}

This directory is the full record of a 3-stage council deliberation
(single-provider replica of [karpathy/llm-council](https://github.com/karpathy/llm-council)).

## Read it in this order

1. **`03-synthesis/final-answer.md`** — the deliverable: the Chairman's
   synthesized answer. Start (and, if in a hurry, stop) here.
2. **`02-reviews/rankings.md`** — how the anonymized responses scored against
   each other, plus the label → seat reveal.
3. **`01-opinions/`** — the independent first opinions, one file per seat
   (`<label>-<seat>.md`).
4. **`02-reviews/review-by-<seat>.md`** — each seat's full anonymized
   evaluation, if you want the reasoning behind the ranking.
5. **`00-question.md`** — the verbatim question, context, and roster.

## Structure

| Path | Contents |
|---|---|
| `00-question.md` | Verbatim question, context, roster, run config |
| `01-opinions/` | Stage 1 — independent opinions (human-readable) |
| `02-reviews/` | Stage 2 — anonymized peer reviews + `rankings.md` aggregate |
| `03-synthesis/` | Stage 3 — Chairman's final answer (the deliverable) |
| `envelopes/` | Machine layer — raw JSON envelopes for every exchange |
| `manifest.json` | Machine-readable run record (statuses, label map, aggregate) |

## How it was produced

Stage 1: the question went to every seat in parallel; each returned a
schema-validated `opinion` envelope. Stage 2: each seat received all opinions
anonymized (labels {{labels}}) — including, unknowingly, its own — and
returned a validated `review` envelope with scores and a full ranking.
Stage 3: the Chairman received everything de-anonymized and synthesized the
final answer. Seats marked `failed` in `manifest.json` produced no valid
envelope after one retry and were excluded from that stage.

## Re-validate this run

```bash
python3 <path-to-skill>/llmcouncil/scripts/validate.py run .
```

Exit 0 = standard-conformant. Error codes are documented in the skill's
`references/evaluation.md`.

## Degradations in this run

{{degradation_notes_or_delete_this_section}}
