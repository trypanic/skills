---
name: moon-proto-monorepo
description: Use when defining, placing, or reviewing moon + proto build-tooling config in a monorepo — workspace globs, project discovery, toolchain pinning, task definition and inheritance, env loading, caching, CI, codegen, and the proto↔moon seam. Decides which file a task, project, toolchain, or tool-version belongs in, and detects and fixes drift from the canonical moon v2 model. Triggers on "add a moon task", "new project in the monorepo", "where does this task go", "pin a tool version", "add a language or toolchain", "why won't moon discover my project", "review .moon config", "moon.yml / .prototools / workspace.yml / toolchains.yml", "task inheritance", "enable caching", or any new or edited file under .moon/, a moon.yml, or .prototools. Not for folder/package layout (see go-modularization), lint/static-analysis config (see go-code-quality-check), or non-moon repos.
---

# moon-proto-monorepo

Opinionated [moon](https://moonrepo.dev/docs) **v2** + [proto](https://moonrepo.dev/docs/proto) build-tooling config for polyglot monorepos. Consult before adding or editing any `.moon/` file, a `moon.yml`, or `.prototools`. The skill defines the one correct way and detects + fixes drift — the way `go-modularization` does for folder layout, this does for build tooling.

Out of scope: folder/package layout and file placement (→ `go-modularization`), lint / static analysis / security gates (→ `go-code-quality-check`), language source style, and the *contents* of the scripts a task happens to run.

---

## How to use this skill

This file holds the routing table and the invariants that apply to **every** invocation (the proto↔moon contract, single-source pinning, v2-only keys, forbidden values, Step 0). Task detail lives in `references/`. **Read the matching file BEFORE acting — the summaries here are for routing, not for executing:**

| Your task                                                                 | Read first                                                                   |
| ------------------------------------------------------------------------- | ---------------------------------------------------------------------------- |
| Edit workspace globs / vcs / discovery; "why isn't my project found"      | [`references/workspace.md`](references/workspace.md)                         |
| Pin/add a tool version; add a language or toolchain; proto↔moon questions | [`references/toolchains-proto.md`](references/toolchains-proto.md)           |
| Add/edit a task; decide where a task goes; task inheritance               | [`references/tasks-and-inheritance.md`](references/tasks-and-inheritance.md) |
| Create/scaffold a project; set language/layer/toolchains.default/metadata | [`references/project-config.md`](references/project-config.md)               |
| Enable caching; CI; codegen; env loading                                  | [`references/ci-cache-codegen.md`](references/ci-cache-codegen.md)           |
| Need a worked example or a full canonical file                            | [`references/examples.md`](references/examples.md)                           |
| Verify after editing                                                      | run [`scripts/moon-checks.sh`](scripts/moon-checks.sh)                       |

Exception — no extra read needed when a flowchart below already gives the full canonical answer for a single-line edit (a version bump, one new task in an obvious file). For a new project, a new language, enabling caching, or anything touching the project graph: read the task file first.

If a rule in this file and a reference file disagree, this file wins; report the mismatch.

---

## Step 0 — Hard rule: ask when unclear

Before changing config, check this skill against the case at hand. If **any** of the following is true, stop and start a discussion with the user:

- No rule in this skill cleanly covers the situation.
- Two or more rules could apply and the choice changes behavior (e.g. *enable a language toolchain* vs *set `toolchains.default: system`* — both remove an invalid value but behave differently).
- A value falls outside a closed set (`language`, `toolchains.default`, `layer`, `stack`) and the right replacement is not obvious in context.
- A new language, or a new **remote** plugin/config source, is being introduced (a toolchain + supply-chain decision).
- Enabling caching on a task whose determinism you cannot confirm.

Present 2–3 concrete options with trade-offs. Do **not** silently pick one.

**Non-interactive runs** (CI, headless): do not block and do not improvise. Take the most conservative option — no new files, no enabling cache, delete only provably-dead globs — proceed, and list every deferred decision under a "Deferred (Step 0)" heading in the final report.

---

## When to use

Trigger phrases:

- "add a moon task" / "where does this task go"
- "new project in the monorepo" / "scaffold a moon project"
- "pin a tool version" / "bump go/node/rust/python"
- "add a language" / "enable a toolchain"
- "why won't moon discover my project" / "task isn't inherited"
- "enable caching" / "speed up CI"
- "review .moon config" / "is this moon.yml canonical"

Auto-trigger on a new or edited:

- `.moon/workspace.yml`, `.moon/toolchains.yml`, `.moon/tasks/**`
- any `moon.yml`
- `.prototools`

Skip for:

- Non-moon repos (no `.moon/` directory).
- Folder/package layout and file placement — that is `go-modularization`.
- Lint, formatter, static-analysis, or test-framework config — out of scope.

Placeholders: `<service>` / `<lib>` / `<tool>` = a project; `<lang>` = a language id; `<toolchain-id>` = an enabled toolchain; `<org>/<repo>` = a remote source. Worked examples use a fictional `acme/` monorepo (a Go service, a Rust library, a Python tool) — see [`references/examples.md`](references/examples.md).

---

## Invariant — the proto↔moon contract

Applies to every invocation; never lazy-load this.

> **proto = WHICH version of a tool. moon = HOW and WHEN tasks run.**

- proto is the version manager: it resolves and installs tools into `~/.proto` and puts them on `PATH`. moon is the task runner over the project graph; it does not manage tool versions itself — it "piggybacks off proto's toolchain." [src: https://moonrepo.dev/docs/concepts/toolchain]
- moon learns a tool's version from `.prototools` **only** through `versionFromPrototools` in `.moon/toolchains.yml` (default `true`). Keep one version source. [src: https://moonrepo.dev/docs/config/toolchain]
- Bootstrap is `proto install`, wrapped as a moon task (e.g. a `setup` task). Never hand a human a raw `proto`/toolchain command when a moon task can own it.
- Do not push version logic into tasks, or task logic into `.prototools`.
- Use only documented `PROTO_*` / `MOON_*` env vars. Invented switches (an env var that no tool reads) are forbidden.

This boundary is language-agnostic: identical for Go, Rust, Python, Node, Bun, Deno, or a custom plugin tool.

---

## Invariant — single source of truth & everything through `moon run`

Never lazy-load this.

- **`.prototools` is the only place tool versions live.** Every tool any task invokes is pinned there (or via a `versionFromPrototools` link). A task that shells out to an un-pinned tool is non-reproducible. The one accepted alternative is a *pinned ephemeral* invocation (`go run pkg@ver`, `npx pkg@ver`, `bunx pkg@ver`, `uvx pkg@ver`).
- **Humans and agents invoke work via `moon run <project>:<task>`**, never the raw toolchain (`go`, `cargo`, `python`, `node`, …) directly. This is the one syntax for everything; it loads env and the pinned version automatically. (A task's *internal* `script` may of course call a shell or a pinned tool — the rule is about the entrypoint, not the task body.)
- Discover before guessing: `moon query projects`, `moon query tasks`, `moon project <id>`, `moon task <target>`.

---

## Invariant — v2-only keys & closed-set values

Never lazy-load this. moon **v2 ("Phobos")** renamed much of v1. Judging "is this canonical" hinges on knowing the renames and the closed sets.

**v1 → v2 renames (v1 form is forbidden):**

| v1 (forbidden)                       | v2 (canonical)                      |
| ------------------------------------ | ----------------------------------- |
| `type:`                              | `layer:`                            |
| `platform:`                          | `toolchains.default:`               |
| singular `toolchain:`                | `toolchains:` (object)              |
| `project.name:`                      | `project.title:`                    |
| `.moon/toolchain.yml`                | `.moon/toolchains.yml`              |
| `.moon/tasks.yml` + filename scoping | `.moon/tasks/**/*` + `inheritedBy:` |
| `runner:` (workspace)                | `pipeline:`                         |
| `unstable_remote:`                   | `remote:`                           |
| task `local: true`                   | `preset: 'server'` / `'utility'`    |

[src: https://moonrepo.dev/docs/migrate/2.0]

**Closed-set value tables** (a value outside its set is a schema violation):

| Field                | Allowed values                                                                                                           |
| -------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| `language`           | `bash`, `batch`, `go`, `javascript`, `php`, `python`, `ruby`, `rust`, `typescript`, `unknown`, or a custom kebab-case id |
| `toolchains.default` | any **enabled** toolchain id, or `system` — **never `unknown`**                                                          |
| `layer`              | `application`, `automation`, `configuration`, `library`, `scaffolding`, `tool`, `unknown`                                |
| `stack`              | `backend`, `data`, `frontend`, `infrastructure`, `systems`, `unknown`                                                    |

[src: https://moonrepo.dev/docs/config/project]

> **The single most common trap:** `unknown` is valid for `language` but **invalid** for `toolchains.default`. If there is no toolchain to point at, the value is `system`, not `unknown`.

---

## Gotchas

Concrete corrections to reasonable-but-wrong assumptions. Read before acting:

- **The filename under `.moon/tasks/` is cosmetic in v2.** Scoping is the `inheritedBy:` block, not the name. A file named `go.yml` with **no** `inheritedBy` is inherited by **all** projects, not just Go ones. Conversely, scoping works in a file named anything.
- **`unknown` is not a valid `toolchains.default`** (see invariant above) — use a toolchain id or `system`.
- **A `projects` glob is a literal path segment, not recursive.** `infra` matches only `infra/`; a project at `infra/db/moon.yml` needs `infra/*` or a `sources` entry, or it is silently undiscovered.
- **`layer` and `stack` are real moon v2 keys** (`layer` is the renamed v1 `type`), not a repo convention. They feed `--query`, `enforceLayerRelationships`, and layer-scoped inheritance.
- **Caching needs declared `outputs` to hydrate.** `cache: true` on a task that declares no `outputs` saves nothing. And `cache: true` on a non-deterministic task (start/serve/migrate) poisons the cache.
- **`command` has no shell.** Pipes, `&&`, `;`, and redirects require `script`. A `command` value containing them silently breaks.
- **There is no `MOON_OFFLINE`** — offline is `PROTO_OFFLINE` (proto-level).
- **`.prototools.<env>` overlays (`PROTO_ENV`) merge per-setting, and BOTH
  dotenvs load.** The overlay's `[env].file` does not replace the base file — a
  var missing from the tier dotenv silently inherits the base value. Explicit
  `[env]` keys beat dotenv values from either file, so every per-tier explicit
  key (e.g. an `ENVIRONMENT` selector consumed by scripts) is re-declared in
  each overlay — kept in the base, never deleted. A missing overlay or dotenv
  target is silent: an unset or typo'd `PROTO_ENV` runs the base tier.
- **`moon migrate` was removed in v2.** Don't suggest it.
- **Version-gated:** features like the task-tag target `project:#tag` and the MQL `taskTag` field require **moon ≥ 2.3.0**. Check the `moon` pin in `.prototools` before recommending them.
- **proto is pre-1.0**: `[settings]` are nested + kebab-case (`[settings.http]`, `[settings.offline]`, `[settings.build]`). There is no flat `unstable` or `offline` key.

---

## Decision flowcharts

### "I need to add X" → where it goes

```text
Bump a tool version (go/node/rust/…)   → edit the .prototools pin. Done.
Add a tool the repo lacks              → .prototools pin; if not a built-in,
                                         add a [plugins.tools] locator first.
Add a new LANGUAGE                      → .prototools pin
                                         + .moon/toolchains.yml block (versionFromPrototools: true)
                                         + .moon/tasks/<x>.yml with inheritedBy
                                         + set toolchains.default on the projects.
Add a TASK used by ONE project         → that project's moon.yml.
Add a TASK used by N same-kind projects→ .moon/tasks/<name>.yml + inheritedBy {language|toolchain|tag|layer}.
Group cross-project tasks by purpose   → task tags (tasks.<name>.tags) + run :#tag  [moon >= 2.3.0].
Add a NEW PROJECT                      → mkdir + moon.yml (language + valid toolchains.default
                                         + layer (+ stack) + metadata);
                                         ensure a projects glob/source covers it.
Make a task CACHEABLE                   → declare inputs + outputs, set cache: true.
A task needs ENV                        → envFile / shared dotenv; never inline secrets.
Run tasks against another env TIER      → committed .prototools.<env> overlay
                                         + inline PROTO_ENV=<env> (see
                                         toolchains-proto.md R2.7);
                                         never per-script --env flags.
A task needs workspace-root paths       → runFromWorkspaceRoot: true.
```

### "Why isn't moon doing X" → diagnosis

```text
Project not discovered      → glob doesn't match its path (literal, not recursive),
                              or no glob/source covers it. Check moon query projects.
Task not inherited          → the tasks file has no inheritedBy, or the condition
                              (language/toolchain/tag/layer) doesn't match the project.
Cache always misses/stale   → no outputs declared, or inputs too broad (**/*) / too narrow.
A `command` with a pipe fails → it needs to be a `script`.
```

If none clearly applies → Step 0. Detail per axis lives in the matching `references/` file.

---

## Anti-patterns to refuse

When generating or reviewing config, reject these. Cite the rule, offer the canonical fix; if none fits → Step 0.

| #   | Anti-pattern                                                                                                    | Canonical fix                                                  |
| --- | --------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------- |
| F1  | `toolchains.default: unknown`                                                                                   | a toolchain id, or `system`                                    |
| F2  | a `projects` glob matching zero directories                                                                     | fix the path or delete the glob                                |
| F3  | invoking a raw toolchain (`go`/`cargo`/`node`…) as the entrypoint instead of `moon run …`                       | wrap in a moon task; run via `moon run`                        |
| F4  | a task running an **un-pinned** tool (not in `.prototools`, no `@version`)                                      | pin in `.prototools` or use `tool@ver`                         |
| F5  | `cache: true` on a non-deterministic task (start/serve/dev/migrate/up)                                          | `cache: false`                                                 |
| F6  | deterministic build/test with `cache: false` or no `outputs`                                                    | declare `inputs`/`outputs`, `cache: true`                      |
| F7  | secrets inline in `moon.yml` / `.prototools`                                                                    | `envFile` / shared dotenv; example file is value-free          |
| F8  | any v1 key (`type`, `platform`, singular `toolchain`, `project.name`, `.moon/toolchain.yml`, `.moon/tasks.yml`) | the v2 name (see invariant table)                              |
| F9  | `.moon/tasks/<lang>.yml` with **no** `inheritedBy`                                                              | add `inheritedBy` (or rename to an explicit all-projects file) |
| F10 | a task duplicated across ≥2 same-kind projects                                                                  | hoist to a scoped `.moon/tasks/*.yml`                          |
| F11 | a plugin/config locator on a moving branch (`/main/`) or malformed (`//`)                                       | pin to a tag/sha; single clean URL                             |
| F12 | an invented env var no tool reads                                                                               | remove it, or document the consumer                            |
| F13 | a `language`/`toolchains.default`/`layer`/`stack` value outside its closed set                                  | use a listed value                                             |

---

## Verify

After editing config, run [`scripts/moon-checks.sh`](scripts/moon-checks.sh) from the repo root (`bash scripts/moon-checks.sh`; `--json` for machine output, `--help` for usage). It validates any moon repo against the rules above: dead globs, undiscovered projects, invalid/`unknown` `toolchains.default`, toolchain referenced but not enabled, v1 keys, out-of-set enum values, `$schema` inconsistency, malformed maintainers, metadata gaps, inline secrets, cache-on-nondeterministic, cache-without-outputs, un-pinned tool in a task, malformed/branch plugin locators, a tasks file missing `inheritedBy`, and undocumented `[env]` keys (the locator/env checks also sweep `.prototools.<env>` overlays, with an advisory NOTE when an overlay re-points `[env].file` without re-declaring a base explicit key — R2.7). The `proto`-vs-installed check is advisory and SKIPs with a NOTE when `proto`/network is unavailable. Structured report on stdout, diagnostics on stderr; **exit 0 = clean, 1 = violations, 2 = bad usage, 3 = missing prerequisite.** If the script is unavailable, the per-check logic is inside it — run the equivalents manually.

Then report using this template (omit empty sections):

```text
## moon-proto-monorepo result
- Edited/created: <config paths>
- Project graph: <N projects discovered> (expected <M>)
- Violations: <path:line: rule-id → canonical fix>   (none if clean)
- Drift fixed: <what changed>
- Deferred (Step 0): <decision + the 2–3 options>   (required in non-interactive runs)
```

---

## Inputs

Optional argument:

- **No argument** — interactive: ask what is being added (task / project / language / version), route to the matching reference, then act.
- **`review`** — first detect adoption: a repo is adopted iff a `.moon/workspace.yml` exists. Not adopted → report "moon not adopted", ask whether to scaffold; do not flag anything. Adopted → audit and emit the report template.
- **`audit`** — full drift scan: run `scripts/moon-checks.sh` and explain each finding with its rule id and canonical fix.
- **`add <thing>`** / **`place <thing>`** — route a new task / project / tool-version to its canonical file via the "I need to add X" flowchart; read the matching reference when the flowchart line alone doesn't settle it. Unclear → Step 0.
- **`scaffold <project>`** — emit a canonical `moon.yml` (valid `language` + `toolchains.default` + `layer` + metadata) and ensure a `projects` glob/source covers it. Read [`references/project-config.md`](references/project-config.md) first.

---

## Boundaries

- Do not invent keys or values outside the documented closed sets. If something doesn't fit, escalate via Step 0.
- Do not edit folder/package layout — that is `go-modularization`. The adjacency: this skill owns a project's `moon.yml`; `go-modularization` owns the project's folder tree. Cross-link, don't overlap.
- Do not enforce lint/formatter/test-framework config — out of scope.
- Do not enable caching on a task whose determinism you cannot confirm — Step 0.
- Violations noticed during an unrelated task: report them; do not fix them in the same change unless asked.
