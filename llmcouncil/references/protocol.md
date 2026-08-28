# llmcouncil communication protocol (v1)

Normative definition of every message exchanged between the Clerk and the
subagents. The JSON Schemas in `schemas/` are the machine-readable law for
response envelopes; this file adds the request shapes, the dispatch wrapper,
and the retry format.

Protocol identifier: the literal string `llmcouncil/v1`. It appears in every
request, every response, and the manifest. A mismatch anywhere is a gate
failure.

---

## General rules

1. One request envelope per subagent invocation. Requests are delivered as a
   fenced ```json block inside the subagent prompt.
2. Responses are markdown; the LAST fenced ```json block of the reply is the
   response envelope. Everything before it is working material and is never
   parsed.
3. Response envelopes are saved verbatim to `envelopes/` and gated with
   `scripts/validate.py envelope --stage <stage> <file>` before use.
4. Every request carries `expected_envelope`: a skeleton of the required
   response with type hints as values. This makes fallback mode (seats not
   installed) work with any general-purpose subagent.
5. `answer_md` and all free-text fields follow the language of the question;
   keys, labels, seat names, and enums are always English.

## Dispatch wrapper

Installed seats already know the protocol, so the prompt is minimal:

```
You are seat <seat-name> of the LLM Council (run <run_id>).
Process this llmcouncil request envelope and reply per your response contract:

```json
{ ...request envelope... }
```
```

Harness notes:

- **Claude Code**: `Agent` tool, `subagent_type: <seat-name>`; batch all
  same-stage calls in one message so they run in parallel.
- **OpenCode**: task tool / `@<seat-name>` subagent invocation.
- **Codex CLI**: "spawn agent <seat-name>" with the wrapper as the task.
- **Kimi Code**: sub-agent delegation by name (agents discovered in
  `.kimi-code/agents/`).
- **Fallback mode** (seats not installed): general-purpose subagent; prompt =
  full body of `adapters/claude/<seat-name>.md` + blank line + the wrapper
  above.

---

## Stage 1 — `opinion`

### Request

```json
{
  "protocol": "llmcouncil/v1",
  "stage": "opinion",
  "run_id": "20260828-153000-rest-vs-grpc-migration",
  "seat": "council-analyst",
  "question": "…the user's question, verbatim…",
  "context": {
    "notes": "…optional background provided by the user, or empty string…",
    "files": ["docs/api-overview.md"]
  },
  "constraints": { "max_words": 600 },
  "expected_envelope": {
    "protocol": "llmcouncil/v1",
    "stage": "opinion",
    "member": "council-analyst",
    "answer_md": "string — full markdown answer in the question's language",
    "key_points": ["1 to 7 strings"],
    "assumptions": ["strings; [] if none"],
    "limitations": ["strings; [] if none"],
    "confidence": "number 0..1"
  }
}
```

- `context.files` holds PATHS only; seats read them with their own tools.
  Never inline large file bodies.
- `constraints` is optional; when present, `max_words` bounds `answer_md`.
  Default request omits it.

### Response (normative: `schemas/opinion.schema.json`)

```json
{
  "protocol": "llmcouncil/v1",
  "stage": "opinion",
  "member": "council-analyst",
  "answer_md": "…",
  "key_points": ["…"],
  "assumptions": [],
  "limitations": ["…"],
  "confidence": 0.7
}
```

Gate: schema conformance; `member` must equal the requested `seat`.

---

## Stage 2 — `review`

### Request

Sent to EVERY configured seat (including Stage 1 failures). `responses` is
the anonymized bundle: labels in shuffled order, `answer_md` only — no seat
names, no key points, no confidence.

```json
{
  "protocol": "llmcouncil/v1",
  "stage": "review",
  "run_id": "20260828-153000-rest-vs-grpc-migration",
  "seat": "council-analyst",
  "question": "…the user's question, verbatim…",
  "responses": [
    { "label": "A", "answer_md": "…" },
    { "label": "B", "answer_md": "…" },
    { "label": "C", "answer_md": "…" }
  ],
  "rubric": {
    "accuracy": "1 = materially wrong claims … 5 = no detectable factual errors, well-calibrated",
    "insight": "1 = restates the obvious … 5 = reframes or deepens understanding beyond any other response",
    "completeness": "1 = misses the core of the question … 5 = core plus material edge cases within budget"
  },
  "expected_envelope": {
    "protocol": "llmcouncil/v1",
    "stage": "review",
    "reviewer": "council-analyst",
    "evaluations": [
      {
        "label": "one of the provided labels",
        "strengths": ["1+ concrete strings"],
        "weaknesses": ["1+ concrete strings"],
        "scores": { "accuracy": "int 1..5", "insight": "int 1..5", "completeness": "int 1..5" }
      }
    ],
    "final_ranking": ["every provided label exactly once, best first"]
  }
}
```

Full rubric anchors live in `references/evaluation.md`; the request carries
the one-line versions above.

### Response (normative: `schemas/review.schema.json`)

Gate, beyond schema conformance:

- `reviewer` equals the requested `seat`;
- `evaluations[*].label` covers each provided label exactly once (E-REV-001);
- `final_ranking` is an exact permutation of the provided labels (E-REV-002).

This replaces the original's `FINAL RANKING:` regex parsing: a ranking that
does not validate is not partially salvaged, it is retried.

---

## Stage 3 — `synthesis`

### Request

Single dispatch to `council-chairman`. Everything is DE-anonymized: the
chairman sees seat names, exactly like the original's chairman prompt.

```json
{
  "protocol": "llmcouncil/v1",
  "stage": "synthesis",
  "run_id": "20260828-153000-rest-vs-grpc-migration",
  "seat": "council-chairman",
  "question": "…the user's question, verbatim…",
  "opinions": [
    {
      "member": "council-analyst",
      "label": "B",
      "answer_md": "…",
      "key_points": ["…"],
      "confidence": 0.7
    }
  ],
  "reviews": [
    {
      "reviewer": "council-skeptic",
      "evaluations": [ { "label": "B", "strengths": ["…"], "weaknesses": ["…"],
                         "scores": { "accuracy": 4, "insight": 3, "completeness": 4 } } ],
      "final_ranking": ["B", "A", "C"]
    }
  ],
  "aggregate_ranking": [
    { "label": "B", "member": "council-analyst", "mean_rank": 1.33,
      "first_places": 2, "rankings_count": 3 }
  ],
  "expected_envelope": {
    "protocol": "llmcouncil/v1",
    "stage": "synthesis",
    "chairman": "council-chairman",
    "answer_md": "string — the final answer, markdown, question's language",
    "consensus": ["points the council agreed on; [] if none"],
    "disputes": [ { "topic": "string", "positions": "string describing the sides" } ],
    "dissent_note": "string; empty if no material minority view was overridden",
    "confidence": "number 0..1"
  }
}
```

In a degraded run (zero valid reviews), `reviews` and `aggregate_ranking`
are `[]` and the chairman synthesizes from opinions alone.

### Response (normative: `schemas/synthesis.schema.json`)

Gate: schema conformance; `chairman` equals `council-chairman`.

---

## Retry format

On a gate failure, resend ONE time:

```
Your previous reply's envelope failed validation.

VALIDATION FINDINGS:
ERROR E-ENV-001 opinion.key_points: missing required key
ERROR E-ENV-002 opinion.confidence: expected number in [0,1], got "high"

Re-send your COMPLETE reply (markdown + trailing envelope) with these
findings fixed. Original request follows:

```json
{ ...original request envelope, unchanged... }
```
```

Findings are copied verbatim from `validate.py` output. A second failure sets
the seat's `status: "failed"` for that stage in the manifest; the run
continues under the quorum and degradation rules in `SKILL.md`.

---

## Statuses

Per seat, per stage, recorded in the manifest:

| Status | Meaning |
|---|---|
| `ok` | valid envelope on first attempt |
| `retried` | valid envelope on the single retry |
| `failed` | no valid envelope after retry; excluded from the stage |
