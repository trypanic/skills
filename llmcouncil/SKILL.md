---
name: llmcouncil
description: 'Deliberative question-answering that replicates the karpathy/llm-council 3-stage flow with a single LLM provider and custom persona subagents. The main agent acts as Clerk and never authors council content. Stage 1 collects independent first opinions from four council seats in parallel. In Stage 2, every seat ranks the anonymized opinions. In Stage 3, a Chairman seat synthesizes the final answer from opinions, peer reviews, and the aggregate ranking. All subagent traffic uses versioned JSON envelopes gated by bundled schemas and scripts/validate.py. The deliverable is a structured run directory (.llmcouncil/<run-id>/) with a README, per-stage folders, raw envelopes, and a manifest — never one flat file. Use when the user asks to "convene the council", "ask the llm council", "council answer" or "panel review". Also use for "deliberate on this", "multi-perspective answer" or "second opinion with ranking". Out of scope: code changes, builds or tests, or any task that requires more than read-only research.'
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
The original sends a question to multiple LLM providers over OpenRouter. Here
the question goes to four **custom persona subagents** ("seats") that run on
the SAME provider and model. The seats answer independently. Then they rank
each other's anonymized answers, and a Chairman subagent synthesizes the final
response. The orchestrating agent (you) is the **Clerk**: you run the
protocol but never author council content.

Two deliberate upgrades over the original:

1. The original parsed rankings from free text with a regex (`FINAL RANKING:`).
   Here every subagent exchange is a versioned JSON envelope (`llmcouncil/v1`),
   machine-validated against bundled schemas in both directions.
2. The original stored runs as one opaque JSON conversation. Here the
   deliverable is a structured run directory with a README that explains how
   to read it.

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

- anything that requires code changes, builds, tests, or deployment — the
  council is strictly read-only
- trivial factual lookups where deliberation adds no value (answer directly)
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
or harness equivalent). Perspective diversity comes only from the seat system
prompts. This is the single-provider adaptation of the original's
multi-provider council.

### Seat availability (before Stage 0)

Determine whether the current harness registers the `council-*` subagents:

- Claude Code: `.claude/agents/` or `~/.claude/agents/`
- OpenCode: `.opencode/agents/`
- Codex: `.codex/agents/`
- Kimi Code: `.kimi-code/agents/`

Three outcomes:

1. **Registered** (under whatever naming the harness exposes): dispatch to
   them directly.
2. **Not registered — offer self-install.** The adapters ship with the skill
   in `adapters/<runtime>/`. Each `install.md` has the copy commands. Ask the
   user ONCE, one question, three options: install project-level, install
   user-level, or skip. On install:
   1. Copy `adapters/<runtime>/council-*` into the chosen agents directory.
      Create the directory if it is missing.
   2. If a target file exists with different content, say so. Ask before you
      overwrite it.
   3. Report exactly what you wrote.
   4. Harnesses discover agents at session start. If the seats are not
      invocable in THIS session after the copy, run the current council in
      fallback mode. Note that the installed seats take effect next session.

   This copy is the ONLY permitted write outside `.llmcouncil/` (Hard rule
   10). It happens only with the user's explicit consent.
3. **Skipped or unavailable — fallback mode**: dispatch each request to a
   general-purpose subagent. Its prompt is the full body of the matching
   generated file under `adapters/claude/`, then the request envelope.
   Protocol, envelopes, and gates are identical in every mode.

---

## Hard rules (non-negotiable)

1. **The Clerk never authors council content.** No opinions, no reviews, no
   synthesis, no "fixing" a seat's answer. If the Chairman fails twice, report
   the run as failed, with Stages 1–2 preserved. Never ghost-write Stage 3.
2. **Single provider.** Never route seats to different models or providers.
3. **Every exchange is an envelope, and every envelope passes its gate.**
   Requests follow `references/protocol.md`. Validate each response with
   `scripts/validate.py envelope --stage <stage> <file>` BEFORE you use its
   content. Never parse prose with a regex.
4. **Stage 2 is anonymous.** Review payloads carry only `label` +
   `answer_md`. Assign labels in shuffled order. Reviewers rank ALL surviving
   responses, unknowingly including their own. Never tell a reviewer which
   response it authored.
5. **Quorum: 2.** Fewer than 2 valid Stage 1 opinions abort the run with an
   explanation. Still invite seats that failed Stage 1 to review in Stage 2
   (mirrors the original).
6. **Retry policy: exactly one.** An invalid envelope gets one retry with the
   validator findings verbatim. A second failure marks the seat `failed` for
   that stage and excludes it.
7. **Output is the structured run directory** defined in
   `references/output-structure.md`, always with its README and
   `manifest.json`. Never collapse a run into a single file.
8. **Language split.** `answer_md` fields and human-readable artifacts follow
   the language of the question. All structural output (envelopes, manifest,
   file names, README headings) stays in English.
9. **Parallel within a stage, strictly sequential across stages.** Dispatch
   all seat requests of a stage in one parallel batch. Never start Stage N+1
   before you gate and archive Stage N.
10. **Read-only toward the user's project.** The council writes only under
    `.llmcouncil/` in the project root (or the working directory if not in a
    project). Sole exception: the one-time, user-approved seat installation
    copy in "Seat availability".

---

## Protocol

Read:

- `references/protocol.md` before you build the first envelope.
- `references/output-structure.md` before you write the first run file.
- `references/evaluation.md` before you compute the aggregate ranking.

### Stage 0 — Convene

1. Capture the question **verbatim**. Optional user-provided background goes
   to `context.notes`. Referenced local files go to `context.files` (paths
   only).
2. Build `run_id`: `<YYYYMMDD-HHMMSS>-<slug>`. The slug is 3–5 lowercase
   hyphenated words that summarize the question. This is the original's
   title-generation step. The Clerk does it because it is metadata, not
   council content.
3. Create `.llmcouncil/<run_id>/` with subfolders `01-opinions/`,
   `02-reviews/`, `03-synthesis/`, `envelopes/`.
4. Write `00-question.md` from `assets/question.md`. Initialize
   `manifest.json` per `references/output-structure.md`.

### Stage 1 — First opinions

1. Build one `opinion` request envelope per seat (`references/protocol.md`
   §Stage 1). All four get the same question. Only `seat` differs.
2. Dispatch all four in ONE parallel batch to the seat subagents.
3. For each reply:
   1. Extract the LAST fenced ```json block.
   2. Save it to `envelopes/opinion-<seat>.json`.
   3. Gate it (`scripts/validate.py envelope --stage opinion --seat <seat> <file>`).
      Invalid → one retry with findings (Hard rule 6).
4. Enforce quorum (Hard rule 5).
5. Shuffle the surviving seats. Assign labels `A`, `B`, `C`, … in shuffled
   order. Record `label_map` in the manifest.
6. Write one `01-opinions/<label>-<seat>.md` per survivor from
   `assets/opinion.md`. Update the manifest (`stages.opinions`, statuses).

### Stage 2 — Peer review

1. Build one `review` request envelope per seat — every configured seat, even
   Stage 1 failures (Hard rule 5). The payload carries the question, the
   anonymized `responses` array (`label` + `answer_md` ONLY), the scoring
   rubric, and the expected envelope skeleton.
2. Dispatch all reviews in ONE parallel batch. Seats are stateless: each
   reviewer is a fresh instance with no memory of Stage 1.
3. Gate each reply with
   `scripts/validate.py envelope --stage review --seat <seat> --labels A,B,…`.
   The reply must pass the schema. `final_ranking` must be an exact
   permutation of the issued labels. `evaluations` must cover each label
   exactly once. Invalid → one retry, then `failed`.
4. Compute the aggregate ranking per `references/evaluation.md` (mean
   position, ties broken by first-place votes, then label). If zero
   reviews survive, record a degraded run. The run continues, and the
   Chairman works from opinions alone.
5. Write `02-reviews/review-by-<seat>.md` per survivor from
   `assets/review.md`. Write `02-reviews/rankings.md` (aggregate + label
   reveal) from `assets/rankings.md`. Update the manifest (`stages.reviews`,
   `stages.aggregate_ranking`).

### Stage 3 — Synthesis

1. Build the single `synthesis` request envelope for `council-chairman`:
   question, DE-anonymized opinions, all peer reviews, aggregate ranking
   (`references/protocol.md` §Stage 3).
2. Dispatch it. Extract the reply envelope to `envelopes/synthesis.json`.
   Gate it with `--stage synthesis`. Invalid → one retry. Second failure →
   run `failed` (Hard rule 1).
3. Write `03-synthesis/final-answer.md` from `assets/final-answer.md`.

### Stage 4 — Close and audit

1. Write the run `README.md` from `assets/run-readme.md` (reading order,
   structure map, provenance, degradation notes).
2. Finalize `manifest.json` (all statuses, `validation` block).
3. Run the full-run audit: `python3 <skill>/scripts/validate.py run .llmcouncil/<run_id>/`.
   Fix only structural findings (missing files, manifest drift). Never edit
   council content. Re-run until exit 0, or record the remaining findings in
   the manifest and the run README.
4. Report to the user:
   - the Chairman's answer (inline)
   - the aggregate ranking table
   - any failed/degraded seats
   - the run directory path
   - the audit verdict

---

## Validation gates (summary)

| Gate | When | Test | On failure |
|---|---|---|---|
| Envelope gate | after every subagent reply | `validate.py envelope --stage <stage>` | 1 retry with findings, then seat `failed` |
| Quorum gate | end of Stage 1 | ≥ 2 successful opinions | abort run, report |
| Ranking gate | Stage 2 (inside envelope gate) | permutation + full label coverage | same as envelope gate |
| Aggregate gate | Stage 2 step 4 | recompute per `references/evaluation.md` | fix computation (Clerk math, not content) |
| Run audit | Stage 4 | `validate.py run <dir>` exit 0 | fix structure only. Log residual findings |

If `python3` is unavailable, apply the manual checklist in
`references/evaluation.md` §Manual gate. Never skip a gate.

---

## Gotchas

- **Envelope extraction**: always take the LAST fenced ```json block of a
  reply. Seats may legitimately include other JSON examples earlier.
- **Do not "help" reviewers.** Do not send a reviewer its own Stage 1 text
  with a hint. Do not exclude its own answer from the review set. Both break
  the protocol: the original ranks all responses anonymously, self included.
- **Persona style can leak identity** in Stage 2 (a skeptical-sounding
  response is probably the skeptic's). Accepted — the original has the same
  property across model styles. Explicit leaks are forbidden: seat names never
  appear inside `answer_md`. Seat prompts enforce this. The envelope gate
  rejects violations (`E-ENV-004`) and triggers the normal retry.
- **Failed seat ≠ failed run.** Mirror the original: drop the seat and
  continue while quorum holds. Record `failed` statuses honestly in the
  manifest and README.
- **Do not drop disagreement from the summary.** If reviews conflict, the
  Chairman's `disputes`/`dissent_note` must carry the conflict. Your Stage 4
  report must mention it. Consensus theater defeats the purpose of a council.
- **Long questions with attachments**: pass file PATHS in `context.files`.
  Never inline large file bodies into envelopes. Seats read files themselves.

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
- `scripts/validate.py` — stdlib-only gate + run auditor (`--help` for usage,
  exit 0 pass / 1 findings / 2 usage error)
- `agents/` — canonical, runtime-neutral seat definitions: `_protocol.md`
  (shared member contract) + one stance file per seat + `chairman.md`
- `adapters/claude/`, `adapters/opencode/`, `adapters/codex/`,
  `adapters/kimi/` — generated, self-contained agent files per runtime, each
  with an `install.md`. Never edit them by hand.
- `scripts/generate_adapters.py` — projects `agents/` into `adapters/`
  (`--check` validates that they are in sync, exit 0/1/2)
- `assets/` — templates for every run artifact
- `README.md` — skill overview, install per harness, extension guide
