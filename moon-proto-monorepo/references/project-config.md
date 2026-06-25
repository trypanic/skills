# Project config — `moon.yml`

A project is a directory with a `moon.yml`, located by a `projects` glob/source
(see `workspace.md`). [src: https://moonrepo.dev/docs/config/project]

## Every top-level key

| Key | Meaning | Notes |
| --- | --- | --- |
| `language` | primary language | closed set + `unknown` (see below); auto-detected if omitted |
| `toolchains` | object: `default` = which toolchain commands run on, plus per-toolchain override blocks | **v2 key** (was `platform`/singular `toolchain`) |
| `layer` | the project's role in the stack | closed set (was v1 `type`) |
| `stack` | the technology stack | closed set; optional but useful |
| `id` | override the project id | default = folder name |
| `project` | metadata: `title`, `description`, `channel`, `owner`, `maintainers` | `title` (was v1 `name`) |
| `tags` | string array for categorization, constraints, `#tag:` targets | |
| `dependsOn` | explicit project deps (ids or `{id, scope}`) | scope `production`/`development`/`build`/`peer` |
| `fileGroups` | named globs reusable in tasks via `@group`/`@files`/… | |
| `tasks` | project-local tasks | |
| `env` | env applied to all the project's tasks | |
| `owners` | code-ownership block | |
| `workspace.inheritedTasks` | `include`/`exclude`/`rename` inherited tasks | |
| `docker` | per-project Docker config | |

## Closed-set values (a value outside the set is a violation)

| Field | Allowed | Trap |
| --- | --- | --- |
| `language` | `bash`, `batch`, `go`, `javascript`, `php`, `python`, `ruby`, `rust`, `typescript`, `unknown`, custom kebab | `unknown` is **valid** here |
| `toolchains.default` | any **enabled** toolchain id, or `system` | `unknown` is **invalid** here — use `system` |
| `layer` | `application`, `automation`, `configuration`, `library`, `scaffolding`, `tool`, `unknown` | match the role, not the language |
| `stack` | `backend`, `data`, `frontend`, `infrastructure`, `systems`, `unknown` | |

**R3.2 — `toolchains.default` is a toolchain id or `system`, never `unknown`.** If
there's nothing to point at, the value is `system` (PATH-managed) — and ideally
you enable the toolchain in `.moon/toolchains.yml` and point at it. [F1]

**R3.3 — `layer` matches the project's role.** A shared library is `library`, a
deployable service is `application`, a codegen/dev binary is `tool`, infra scripts
are `automation`. Picking by language ("it's Go so application") is wrong.

**R3.5 — v2 key names only.** No `type:`, `platform:`, singular `toolchain:`,
`project.name:`. [F8]

## Choosing `layer` and `stack` (examples, not requirements)

| Project | `language` | `toolchains.default` | `layer` | `stack` |
| --- | --- | --- | --- | --- |
| a deployable HTTP service | `go` | `go` | `application` | `backend` |
| a shared library other projects import | `rust` | `rust` | `library` | `systems` |
| a codegen / build helper binary | `python` | `python` | `tool` | `unknown` |
| a UI app | `typescript` | `node` | `application` | `frontend` |
| infra / provisioning scripts | `bash` or `unknown` | `system` | `automation` | `infrastructure` |

These rows are illustrative — the closed sets are the rule; the pairings are
guidance.

## Metadata consistency

**R3.4 — if the repo populates metadata, every project does (or none do).**
Keep `maintainers`/`owner`/`tags` uniform. `maintainers` entries follow
`Name <email>` (a missing `>` is a malformed entry the verifier flags).

```yaml
project:
  title: 'web'
  description: 'public HTTP API'
  owner: 'platform-team'
  maintainers:
    - 'Jane Doe <jane@example.com>'
tags:
  - 'go'
  - 'service'
```

## Canonical project `moon.yml` (a Go service in the `acme/` repo)

```yaml
# services/web/moon.yml
language: go
toolchains:
  default: go            # 'go' toolchain enabled in .moon/toolchains.yml
layer: application
stack: backend
project:
  title: 'web'
  description: 'public HTTP API'
  owner: 'platform-team'
  maintainers:
    - 'Jane Doe <jane@example.com>'
tags:
  - 'go'
  - 'service'
# tasks come from .moon/tasks/go.yml via inheritedBy: { language: [go] };
# declare project-local tasks here only when they're unique to this project.
```

## Scaffolding a new project

1. `mkdir -p <path>/<name>`.
2. Create `<path>/<name>/moon.yml` with a valid `language`, `toolchains.default`,
   `layer` (+ `stack`), and metadata (R3.*).
3. Ensure a `projects` glob/source in `.moon/workspace.yml` covers `<path>/<name>`
   (R1.1/R1.2). Verify with `moon query projects`.
4. If it's a new language, do the toolchain steps in `toolchains-proto.md` first.

> Folder *layout inside* the project (which subfolders, file naming) is
> `go-modularization`'s job, not this skill's. This skill stops at `moon.yml`.

## The root project (optional)

If you register the root as a project (`sources: { root: '.' }`) for repo-wide
tasks, constrain it so it doesn't scan the whole tree or inherit everything:

```yaml
# root moon.yml
workspace:
  inheritedTasks:
    include: []        # inherit nothing
tasks:
  setup:
    command: 'proto install'
    options: { cache: false }
```

[src: https://moonrepo.dev/docs/guides/root-project]

## Anti-patterns

- `toolchains.default: unknown` (F1).
- An out-of-set `layer`/`stack`/`language` (F13).
- `layer` chosen by language instead of role (R3.3).
- Uneven metadata; a malformed `maintainers` entry (R3.4).
- v1 keys (F8).
