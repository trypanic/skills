# Run output structure

The deliverable of a council run is a directory, never a single file. It has
a human layer (markdown, one concern per file) and a machine layer (raw JSON
envelopes + a manifest). Both must stay consistent; `scripts/validate.py run`
audits exactly that.

## Location and naming

```
<project-root>/.llmcouncil/<run_id>/
```

- `run_id` = `<YYYYMMDD-HHMMSS>-<slug>`; slug = 3–5 lowercase hyphenated
  words summarizing the question (e.g. `20260828-153000-rest-vs-grpc-migration`).
- If the working directory is not a project, use the current directory.
- Whether `.llmcouncil/` is committed or gitignored is the user's call;
  suggest committing runs that document real decisions.

## Layout

```
.llmcouncil/<run_id>/
├── README.md                        # how to read this run (assets/run-readme.md)
├── manifest.json                    # machine-readable run record (schemas/manifest.schema.json)
├── 00-question.md                   # verbatim question, context, roster (assets/question.md)
├── 01-opinions/
│   ├── A-council-skeptic.md         # one per successful seat (assets/opinion.md)
│   ├── B-council-analyst.md
│   └── ...
├── 02-reviews/
│   ├── review-by-council-analyst.md # one per successful reviewer (assets/review.md)
│   ├── ...
│   └── rankings.md                  # aggregate + label reveal (assets/rankings.md)
├── 03-synthesis/
│   └── final-answer.md              # the deliverable (assets/final-answer.md)
└── envelopes/
    ├── opinion-<seat>.json          # one per seat that produced a valid opinion
    ├── review-<seat>.json           # one per seat that produced a valid review
    └── synthesis.json
```

Naming rules:

- Opinion files: `<label>-<seat>.md` — label first so the directory sorts in
  review order. Labels are single uppercase letters `A`..`N`, consecutive,
  assigned in shuffled seat order.
- Review files: `review-by-<seat>.md`.
- Envelope files: stage-prefixed, seat-suffixed, exact JSON as received
  (post-gate). Failed attempts are NOT stored; failure is recorded only as a
  manifest status.
- Failed seats have no files in `01-opinions/` / `02-reviews/`; they exist
  only in the manifest with `status: "failed"`.

## `manifest.json` field-by-field

Normative schema: `schemas/manifest.schema.json`. Example:

```json
{
  "protocol": "llmcouncil/v1",
  "run_id": "20260828-153000-rest-vs-grpc-migration",
  "created_at": "2026-08-28T15:30:00-05:00",
  "question": "…verbatim…",
  "provider": { "harness": "claude-code", "model": "inherit" },
  "seats": ["council-analyst", "council-skeptic", "council-pragmatist", "council-explorer"],
  "chairman": "council-chairman",
  "label_map": { "A": "council-skeptic", "B": "council-analyst", "C": "council-pragmatist" },
  "stages": {
    "opinions": [
      { "member": "council-analyst", "label": "B", "status": "ok",
        "envelope": "envelopes/opinion-council-analyst.json" },
      { "member": "council-explorer", "label": null, "status": "failed", "envelope": null }
    ],
    "reviews": [
      { "reviewer": "council-analyst", "status": "retried",
        "envelope": "envelopes/review-council-analyst.json" }
    ],
    "aggregate_ranking": [
      { "label": "B", "member": "council-analyst", "mean_rank": 1.33,
        "first_places": 2, "rankings_count": 3 }
    ],
    "synthesis": { "chairman": "council-chairman", "status": "ok",
                   "envelope": "envelopes/synthesis.json" }
  },
  "validation": {
    "gate_tool": "scripts/validate.py",
    "final_run_check": "pass",
    "notes": []
  }
}
```

| Field | Rules |
|---|---|
| `protocol` | literal `llmcouncil/v1` |
| `run_id` | matches the directory name |
| `created_at` | ISO-8601 with offset |
| `question` | verbatim, untrimmed |
| `provider.harness` | `claude-code` \| `opencode` \| `codex` \| other |
| `provider.model` | model identifier or `inherit` |
| `seats` | configured member seats (order = dispatch order, ≥ 2) |
| `chairman` | chairman seat name |
| `label_map` | label → seat, bijective, labels consecutive from `A`; only successful Stage 1 seats appear |
| `stages.opinions[]` | one entry per configured seat; `label`/`envelope` null iff `failed` |
| `stages.reviews[]` | one entry per configured seat (Stage 1 failures still review) |
| `stages.aggregate_ranking[]` | sorted best→worst per `references/evaluation.md`; `[]` in degraded runs |
| `stages.synthesis` | single object; `envelope` null iff `failed` |
| `validation.final_run_check` | `pending` (before Stage 4) \| `pass` \| `fail` \| `manual` (gates run by checklist, no python) |
| `validation.notes` | residual findings or degradation notes, verbatim strings |

## Write points

| Moment | Files written |
|---|---|
| Stage 0 | run dir + subdirs, `00-question.md`, initial `manifest.json` |
| Stage 1 (post-gate) | `envelopes/opinion-*.json`, `01-opinions/*.md`, manifest update |
| Stage 2 (post-gate) | `envelopes/review-*.json`, `02-reviews/*.md`, `rankings.md`, manifest update |
| Stage 3 (post-gate) | `envelopes/synthesis.json`, `03-synthesis/final-answer.md`, manifest update |
| Stage 4 | `README.md`, final manifest (`validation` block) |

The manifest is updated at every stage boundary so an interrupted run is
still a coherent, auditable artifact.
