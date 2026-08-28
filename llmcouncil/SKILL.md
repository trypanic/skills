---
name: llmcouncil
description: 'Deliberative question-answering replicating the karpathy/llm-council 3-stage flow with a single LLM provider and custom persona subagents. The main agent acts as Clerk and never authors council content: Stage 1 collects independent first opinions from four council seats in parallel, Stage 2 has every seat rank the anonymized opinions, Stage 3 has a Chairman seat synthesize the final answer from opinions, peer reviews, and the aggregate ranking. All subagent traffic uses versioned JSON envelopes gated by bundled schemas and scripts/validate.py; the deliverable is a structured run directory (.llmcouncil/<run-id>/) with a README, per-stage folders, raw envelopes, and a manifest — never one flat file. Use when the user asks to "convene the council", "ask the llm council", "council answer", "panel review", "deliberate on this", "multi-perspective answer", or "second opinion with ranking". Out of scope: making code changes, running builds or tests, or any task requiring more than read-only research.'
license: MIT
compatibility: 'Agent-agnostic protocol. Canonical seat definitions live in agents/ (runtime-neutral); adapters/ holds generated agent files for Claude Code, OpenCode, Codex CLI, and Kimi Code (regenerate with scripts/generate_adapters.py). scripts/validate.py requires Python 3.8+ (stdlib only); references/evaluation.md includes a manual gate checklist for environments without Python.'
metadata:
  author: trypanic
  version: "0.1.0"
  homepage: "https://github.com/trypanic/skills/tree/main/llmcouncil"
  outcome-folder: ".llmcouncil"
  inspired-by: "https://github.com/karpathy/llm-council"
---

# llmcouncil

Single-provider replica of [karpathy/llm-council](https://github.com/karpathy/llm-council).
Instead of fanning a question out to multiple LLM providers over OpenRouter,
the question fans out to four **custom persona subagents** ("seats") running on
the SAME provider and model. The seats answer independently, then rank each
other's anonymized answers, and a Chairman subagent synthesizes the final
response. The orchestrating agent (you) is the **Clerk**: you run the
protocol; you never author council content.

Two deliberate upgrades over the original:

1. The original parsed rankings out of free text with a regex (`FINAL RANKING:`).
   Here every subagent exchange is a versioned JSON envelope (`llmcouncil/v1`)
   validated against bundled schemas — the communication standard is
   machine-checked in both directions.
2. The original stored runs as one opaque JSON conversation. Here the
   deliverable is a structured run directory with its own README explaining
   how to read it — never a single flat file.

---

## When to use

Activate when the user wants a deliberated, multi-perspective answer to a
question:

- "convene the council", "ask the llm council", "council answer"
- "panel review of this question", "deliberate on this"
- "multi-perspective answer", "second opinion with ranking"
- open-ended design, strategy, tradeoff, or judgment questions where
  independent perspectives + peer review beat a single-shot answer

## When NOT to use

- anything requiring code changes, builds, tests, or deployment — the council
  is strictly read-only
- trivial factual lookups where deliberation adds no value; answer directly
- tasks whose answer depends on tools the seats do not have (browsers,
  external APIs)

---

## Roles

| Role | Agent | Stance | Stages |
|---|---|---|---|
| Clerk | you (the main agent) | orchestrator, validator, archivist — no opinions | 0–4 |
| Seat | `council-analyst` | first-principles decomposition and rigor | 1, 2 |
| Seat | `council-skeptic` | adversarial stress-testing, failure modes | 1, 2 |
| Seat | `council-pragmatist` | actionability, constraints, tradeoffs | 1, 2 |
| Seat | `council-explorer` | reframing, alternatives, second-order effects | 1, 2 |
| Chairman | `council-chairman` | synthesis of the council's collective wisdom | 3 |

All seats run on the same provider and model as the session (`model: inherit`
or harness equivalent). Perspective diversity comes exclusively from the seat
system prompts — that is the single-provider adaptation of the original's
multi-provider council.

### Seat availability check (before Stage 0)

Verify the `council-*` subagents are registered in the current harness
(Claude Code: `.claude/agents/` or `~/.claude/agents/`; OpenCode:
`.opencode/agents/`; Codex: `.codex/agents/`; Kimi Code:
`.kimi-code/agents/`). Three outcomes:

1. **Registered** (under whatever naming the harness exposes): dispatch to
   them directly.
2. **Not registered — offer self-install.** The adapters ship with the skill
   (`adapters/<runtime>/`; copy commands in each `install.md`). Ask the user
   ONCE, one question, three options: install project-level, install
   user-level, or skip. On install: copy `adapters/<runtime>/council-*` into
   the chosen agents directory (create it if missing; if a target file
   exists with different content, say so and ask before overwriting),
   report exactly what was written, and remember that harnesses discover
   agents at session start — if the seats are not invocable in THIS session
   after copying, run the current council in fallback mode and note the
   installed seats take effect next session. This copy is the ONLY
   permitted write outside `.llmcouncil/` (the sole exception to Hard
   rule 10) and only ever happens with the user's explicit consent.
3. **Skipped or unavailable — fallback mode**: dispatch each request to a
   general-purpose subagent whose prompt is the full body of the
   corresponding generated file under `adapters/claude/` followed by the
   request envelope. Protocol, envelopes, and gates are identical in every
   mode.

---

## Hard rules (non-negotiable)

1. **The Clerk never authors council content.** No opinions, no reviews, no
   synthesis, no "fixing" a seat's answer. If the Chairman fails twice, the
   run is reported as failed with Stages 1–2 preserved — never ghost-write
   Stage 3.
2. **Single provider.** Never route seats to different models or providers.
3. **Every exchange is an envelope, and every envelope passes its gate.**
   Requests follow `references/protocol.md`; responses are validated with
   `scripts/validate.py envelope --stage <stage> <file>` BEFORE their content
   is used. No regex parsing of prose, ever.
4. **Stage 2 is anonymous.** Review payloads carry only `label` +
   `answer_md`. Labels are assigned in shuffled order. Reviewers rank ALL
   surviving responses, unknowingly including their own. Never tell a
   reviewer which response it authored.
5. **Quorum: 2.** Fewer than 2 valid Stage 1 opinions aborts the run with an
   explanation. Seats that failed Stage 1 still get invited to review in
   Stage 2 (mirrors the original).
6. **Retry policy: exactly one.** An invalid envelope gets one retry carrying
   the validator findings verbatim. A second failure marks the seat `failed`
   for that stage and excludes it.
7. **Output is the structured run directory** defined in
   `references/output-structure.md`, always including its README and
   `manifest.json`. Never collapse a run into a single file.
8. **Language split.** `answer_md` fields and human-readable artifacts follow
   the language of the question; all structural output (envelopes, manifest,
   file names, READMEs headings) stays in English.
9. **Parallel within a stage, strictly sequential across stages.** Dispatch
   all seat requests of a stage in one parallel batch; never start Stage N+1
   before Stage N is gated and archived.
10. **Read-only toward the user's project.** The council writes only under
    `.llmcouncil/` in the project root (or the working directory if not in a
    project). Sole exception: the one-time, user-approved seat installation
    copy described in "Seat availability check".

---

## Protocol

Read `references/protocol.md` before building the first envelope, and
`references/output-structure.md` before writing the first run file. Read
`references/evaluation.md` before computing the aggregate ranking.

### Stage 0 — Convene

1. Capture the question **verbatim**. Optional user-provided background goes
   to `context.notes`; referenced local files go to `context.files` (paths
   only — seats have read access).
2. Build `run_id`: `<YYYYMMDD-HHMMSS>-<slug>` where the slug is 3–5 lowercase
   hyphenated words summarizing the question (the original's title-generation
   step, done by the Clerk since it is metadata, not council content).
3. Create `.llmcouncil/<run_id>/` with subfolders `01-opinions/`,
   `02-reviews/`, `03-synthesis/`, `envelopes/`.
4. Write `00-question.md` from `assets/question.md` and initialize
   `manifest.json` per `references/output-structure.md`.

### Stage 1 — First opinions

1. Build one `opinion` request envelope per seat (`references/protocol.md`
   §Stage 1). Same question for all four; only `seat` differs.
2. Dispatch all four in ONE parallel batch to the seat subagents.
3. For each reply: extract the LAST fenced ```json block, save it to
   `envelopes/opinion-<seat>.json`, and gate it
   (`scripts/validate.py envelope --stage opinion --seat <seat> <file>`).
   Invalid → one retry with findings (Hard rule 6).
4. Enforce quorum (Hard rule 5).
5. Shuffle the surviving seats, assign labels `A`, `B`, `C`, … in shuffled
   order, and record `label_map` in the manifest.
6. Write one `01-opinions/<label>-<seat>.md` per survivor from
   `assets/opinion.md`. Update manifest (`stages.opinions`, statuses).

### Stage 2 — Peer review

1. Build one `review` request envelope per seat — every configured seat, even
   Stage 1 failures (Hard rule 5). The payload carries the question, the
   anonymized `responses` array (`label` + `answer_md` ONLY), the scoring
   rubric, and the expected envelope skeleton.
2. Dispatch all reviews in ONE parallel batch. Seats are stateless: each
   reviewer is a fresh instance with no memory of Stage 1.
3. Gate each reply with
   `scripts/validate.py envelope --stage review --seat <seat> --labels A,B,…`:
   schema + `final_ranking` must be an exact permutation of the issued labels
   and `evaluations` must cover each label exactly once. Invalid → one
   retry, then `failed`.
4. Compute the aggregate ranking per `references/evaluation.md` (mean
   position; ties by first-place votes, then label). If zero reviews survive,
   record a degraded run and continue — the Chairman then works from opinions
   alone.
5. Write `02-reviews/review-by-<seat>.md` per survivor from
   `assets/review.md`, and `02-reviews/rankings.md` (aggregate + label
   reveal) from `assets/rankings.md`. Update manifest (`stages.reviews`,
   `stages.aggregate_ranking`).

### Stage 3 — Synthesis

1. Build the single `synthesis` request envelope for `council-chairman`:
   question, DE-anonymized opinions, all peer reviews, aggregate ranking
   (`references/protocol.md` §Stage 3).
2. Dispatch, extract, save to `envelopes/synthesis.json`, gate with
   `--stage synthesis`. Invalid → one retry; second failure → run `failed`
   (Hard rule 1).
3. Write `03-synthesis/final-answer.md` from `assets/final-answer.md`.

### Stage 4 — Close and audit

1. Write the run `README.md` from `assets/run-readme.md` (reading order,
   structure map, provenance, degradation notes).
2. Finalize `manifest.json` (all statuses, `validation` block).
3. Run the full-run audit: `python3 <skill>/scripts/validate.py run
   .llmcouncil/<run_id>/`. Fix only structural findings (missing files,
   manifest drift) — never edit council content — and re-run until exit 0, or
   record remaining findings in the manifest and the run README.
4. Report to the user: the Chairman's answer (inline), the aggregate ranking
   table, any failed/degraded seats, the run directory path, and the audit
   verdict.

---

## Validation gates (summary)

| Gate | When | Check | On failure |
|---|---|---|---|
| Envelope gate | after every subagent reply | `validate.py envelope --stage <stage>` | 1 retry with findings, then seat `failed` |
| Quorum gate | end of Stage 1 | ≥ 2 successful opinions | abort run, report |
| Ranking gate | Stage 2 (inside envelope gate) | permutation + full label coverage | same as envelope gate |
| Aggregate gate | Stage 2 step 4 | recompute per `references/evaluation.md` | fix computation (Clerk math, not content) |
| Run audit | Stage 4 | `validate.py run <dir>` exit 0 | fix structure only; log residual findings |

If `python3` is unavailable, apply the manual checklist in
`references/evaluation.md` §Manual gate — gates are never skipped.

---

## Gotchas

- **Envelope extraction**: always the LAST fenced ```json block of a reply —
  seats may legitimately include other JSON examples earlier.
- **Do not "help" reviewers.** Sending a reviewer its own Stage 1 text with a
  hint, or excluding its own answer from the review set, breaks the
  protocol: the original ranks all responses anonymously, self included.
- **Persona style can leak identity** in Stage 2 (a skeptical-sounding
  response is probably the skeptic's). Accepted — the original has the same
  property across model styles. What is forbidden is explicit: seat names
  never appear inside `answer_md` — seat prompts enforce this and the
  envelope gate rejects violations (`E-ENV-004`), triggering the normal
  retry.
- **Failed seat ≠ failed run.** Mirror the original: drop and continue while
  quorum holds; record `failed` statuses honestly in manifest and README.
- **Do not summarize away disagreement.** If reviews conflict, the Chairman's
  `disputes`/`dissent_note` must carry it, and your Stage 4 report must
  mention it — consensus theater defeats the purpose of a council.
- **Long questions with attachments**: pass file PATHS in `context.files`,
  never inline large file bodies into envelopes; seats read files themselves.

---

## File references

- `references/protocol.md` — request/response envelopes for all stages,
  retry message format, dispatch notes per harness
- `references/output-structure.md` — run directory layout, naming rules,
  manifest field-by-field
- `references/evaluation.md` — scoring rubric, aggregate ranking algorithm,
  validation error-code catalog, manual gate checklist, disagreement signals
- `schemas/` — normative JSON Schemas: `opinion`, `review`, `synthesis`,
  `manifest`
- `scripts/validate.py` — stdlib-only gate + run auditor (`--help` for usage;
  exit 0 pass / 1 findings / 2 usage error)
- `agents/` — canonical, runtime-neutral seat definitions: `_protocol.md`
  (shared member contract) + one stance file per seat + `chairman.md`
- `adapters/claude/`, `adapters/opencode/`, `adapters/codex/`,
  `adapters/kimi/` — generated, self-contained agent files per runtime, each
  with an `install.md`; never edit by hand
- `scripts/generate_adapters.py` — projects `agents/` into `adapters/`
  (`--check` verifies they are in sync; exit 0/1/2)
- `assets/` — templates for every run artifact
- `README.md` — skill overview, install per harness, extension guide
