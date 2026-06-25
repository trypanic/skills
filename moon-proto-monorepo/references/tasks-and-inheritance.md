# Tasks & inheritance

## `command` vs `script`

Mutually exclusive. [src: https://moonrepo.dev/docs/concepts/task]

```yaml
tasks:
  # command: a single binary + optional args. NO shell. Participates in
  # arg-merge inheritance and CLI passthrough.
  test:
    command: 'go test ./...'

  # script: a shell string. Pipes / && / ; / redirects / multi-step allowed.
  # ALWAYS replaces on inheritance (never merges). No separate args, no passthrough.
  build:
    script: |
      if [ -f Cargo.toml ]; then cargo build --release; else go build ./...; fi
```

**R4.1 — use `command` for one binary; `script` only when you need a shell.**
- ❌ `command: 'cat a | grep b'` (no shell → breaks).
- ❌ `script: 'go test ./...'` (single command → should be `command`).

## Task keys

`command` | `script` | `args` | `deps` | `description` | `env` | `inputs` |
`outputs` | `extends` | `preset` | `toolchains` | `tags` | `options`.

- **`deps`** use target scopes: `^:build` (run `build` in every upstream
  `dependsOn` project first), `~:lint` / bare `lint` (this project's own task
  first), `other-project:task` (a specific target).
- **`preset`** (replaces v1 `local`): `server` (cache off, streamed, persistent,
  not in CI) for dev servers; `utility` (cache off, interactive, skipped in CI).
- **`toolchains`** per task overrides the project default (the v1 per-task
  `platform`).

## `options` (the important ones)

| Option | Values | Default | Use |
| --- | --- | --- | --- |
| `cache` | `true`/`false`/`'local'`/`'remote'` | `true` | off for non-deterministic tasks only |
| `runInCI` | `true`/`false`/`'affected'`/`'always'`/`'skip'` | `'affected'` | gate CI participation |
| `runFromWorkspaceRoot` | bool | `false` | task reads workspace-root files |
| `envFile` | `true`/`false`/path/path[] | none | load a dotenv |
| `interactive` | bool | `false` | needs a TTY |
| `persistent` | bool | `false` | long-running (dev server, watcher) |
| `internal` | bool | `false` | hide from the CLI |
| `outputStyle` | `stream`/`buffer`/`hash`/… | pipeline default | log style |
| `retryCount` | int | `0` | flaky tasks |
| `merge*` | `append`/`prepend`/`replace`/`preserve` | `append` | inherited-list merge |

Task **type is inferred**: declares `outputs` → *build*; `persistent` → *run*;
else *test*.

## Caching: `inputs` / `outputs`

**R4.2 — declare `inputs` and `outputs` on any deterministic task and enable
caching.** Outputs are what makes a cache hit *hydrate* (restore files); without
them `cache: true` saves nothing.

```yaml
tasks:
  build:
    command: 'go build -o dist/app ./cmd'
    inputs:
      - 'src/**/*'
      - 'cmd/**/*'
      - '/go.work'              # leading / = workspace-root-relative
    outputs:
      - 'dist/app'
    options:
      cache: true
```

**R4.3 — disable caching ONLY for non-deterministic / side-effecting tasks**:
`start`/`dev`/`serve`, `tidy`/dependency installs, `*migrate*`, infra `up`/`down`,
formatters that mutate in place.

Cache hazard: moon hashes only files **inside** the workspace. A task depending on
something out-of-tree (a local `replace` to an external module, a system lib) can
go stale; keep such a task uncached or include a marker input. → Step 0 if unsure.

## Where a task goes

- **R5.3 — task used by one project → that project's `moon.yml`.**
- **R5.1 — task used by N projects of the same kind → a scoped
  `.moon/tasks/<name>.yml` with `inheritedBy`.** Don't copy-paste a task.

## Inheritance (`.moon/tasks/**`)

**v2 uses config-based `inheritedBy`, not filename scoping.** Any file under
`.moon/tasks/` may declare tasks; the `inheritedBy` block decides who gets them.
[src: https://moonrepo.dev/docs/concepts/task-inheritance]

```yaml
# .moon/tasks/go.yml   ← the FILENAME is cosmetic; the block below does the work
inheritedBy:
  language: [go]        # AND-combined if multiple conditions
tasks:
  test:
    command: 'go test ./...'
taskOptions:            # defaults for every task IN THIS FILE
  cache: true
```

- **`inheritedBy` conditions:** `file(s)`, `language(s)`, `layer(s)`, `stack(s)`,
  `tag(s)`, `toolchain(s)`. All present conditions must match (AND). **Absent /
  empty → ALL projects inherit.**
- **R5.2 — scoping is the `inheritedBy` block, not the filename.** A
  `.moon/tasks/go.yml` with **no** `inheritedBy` applies to every project. [F9]
  - To intentionally apply to all projects, name it clearly (e.g.
    `.moon/tasks/all.yml`) and omit `inheritedBy`.
- **Resolution:** all matching files deep-merge in order; the project's own
  `moon.yml` tasks merge last and win.
- **Override / exclude** an inherited task: set it to `null` in the project, or use
  `workspace.inheritedTasks: { include: [...], exclude: [...], rename: {old: new} }`.
- **Merge strategies** for inherited lists: `mergeArgs`/`mergeDeps`/`mergeEnv`/
  `mergeInputs`/`mergeOutputs` ∈ `append` (default) / `prepend` / `replace` /
  `preserve`.

### `taskOptions` (file-level defaults)

Valid only in `.moon/tasks/*.yml` — sets defaults for every task in that file.
Projects set per-task defaults via `options:` instead. Don't blanket-disable
`cache` here unless every task in the file is genuinely non-deterministic.

## Task tags (moon ≥ 2.3.0)

Task tags categorize **individual tasks** (distinct from project `tags`, which
categorize whole projects) so cross-cutting groups can be run with one command,
regardless of language or project. [src: https://moonrepo.dev/docs/config/project,
https://moonrepo.dev/blog/moon-v2.3]

> **Version gate:** task tags, the `:#tag` targets, the MQL `taskTag` field, and
> `mergeTags` all require **moon ≥ 2.3.0**. On an older pin they do nothing — check
> the `moon` pin in `.prototools` first. (In 2.3 the MQL `tag` field was renamed
> `projectTag`; bare `tag` in a `--query` no longer resolves.)

```yaml
tasks:
  test:
    command: 'go test ./...'
    tags: ['ci']                # arbitrary string ids, no closed set
  lint:
    command: 'golangci-lint run'
    tags: ['quality', 'ci']
```

**Targeting** (CLI and task `deps`):

| Target | Runs |
| --- | --- |
| `:#ci` | every task tagged `ci`, all projects |
| `^:#ci` | every `ci`-tagged task in upstream `dependsOn` projects |
| `project:#ci` | `ci`-tagged tasks in one project |
| `#go:#ci` | tasks tagged `ci` in all projects tagged `go` (project-tag : task-tag) |

```bash
moon run ':#ci'          # named cross-language CI group (vs moon ci = affected-based)
moon query tasks --tags quality
```

- **R5.6 — use task tags for a *named* cross-project group** (a `quality` gate, a
  `db` migration set, a `setup` bootstrap) that spans languages. They complement
  `moon ci` (affected) and project-scoped inheritance; they don't replace either.
- **Inheritance:** task tags merge via `mergeTags` (`append` default / `prepend` /
  `replace` / `preserve`) like other inherited list fields. A task tag set in a
  scoped `.moon/tasks/*.yml` propagates to every inheriting project's copy of that
  task — define a cross-cutting tag once, in the scoped file.
- Tags are arbitrary strings; keep a small, documented vocabulary
  (e.g. `ci`, `quality`, `db`, `setup`, `dev`) rather than ad-hoc per-task labels.

## Anti-patterns

- A `script` that's a single command, or a `command` with a pipe (F: R4.1).
- A deterministic build/test with no `outputs` or `cache: false` (F6).
- `cache: true` on start/serve/migrate (F5).
- A tasks file with no `inheritedBy` (applies to all) (F9).
- The same task copy-pasted across projects (F10).
- An un-pinned tool inside a task body (F4).
- Task tags (`tasks.<name>.tags`) or `:#tag` targets on a repo pinned to
  moon < 2.3.0 — they silently no-op (R5.6 version gate).
- Sprawling ad-hoc task-tag labels instead of a small shared vocabulary (R5.6).
