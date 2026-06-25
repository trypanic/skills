# CI, caching, codegen, env loading

## CI — `moon ci`

`moon ci` is the CI entrypoint: it compares HEAD vs a base, computes affected
projects, and runs all affected CI-eligible targets plus their deps and
dependents. [src: https://moonrepo.dev/docs/guides/ci]

```bash
moon ci                       # auto-detects base/head from the CI provider
moon ci --base main --head HEAD
moon ci --job 0 --job-total 4 # shard across 4 CI runners
moon ci :build :test          # restrict to explicit targets
```

- Auto-detects base/head from the CI provider, falling back to
  `vcs.defaultBranch` (so set it — see `workspace.md` R1.3).
- Gate per-task with `runInCI` (`'affected'` default; `'skip'`/`false` for dev
  servers; `'always'` for must-run tasks).
- Affected detection outside CI: `moon run :task --affected` (+ `--query`).

**R7.1 — CI runs through `moon ci`, not a hand-rolled matrix.** It already knows
the graph and the affected set.

## Caching — correctness depends on `inputs`/`outputs`

moon hashes `command` + `args` + `env` + `inputs` + `outputs` + deps + toolchain
version into a SHA256; a matching hash is a cache hit and outputs are hydrated from
`.moon/cache/`. [src: https://moonrepo.dev/docs/concepts/cache]

**R7.2 — cache correctness is an `inputs`/`outputs` hygiene problem:**

- **Too broad** (`inputs: ['**/*']`) → the hash changes on every unrelated edit →
  the cache never hits. (The root project's default input is `**/*`; restrict it.)
- **Too narrow** → a real source change doesn't bust the cache → stale output ships.
- **No `outputs`** → nothing to hydrate; `cache: true` is a no-op.

Cache vs not:

| Cache ON (deterministic) | Cache OFF (non-deterministic / side effects) |
| --- | --- |
| build / compile / bundle | start / dev / serve (persistent) |
| test / typecheck / lint | dependency install / tidy |
| codegen with declared outputs | db migrate / seed |
| | infra up / down |
| | in-place formatters |

**R7.4 — remote caching** is the workspace `remote` block (gRPC/HTTP CAS); the
local `.moon/cache/` stays gitignored.

## Codegen — `moon generate`

```bash
moon generate <template-name> [dest]
```

- Templates are sourced from `generator.templates` in `workspace.yml` (`file://`,
  `git://#ref`, `npm://#ver`, `glob://`, `https://….zip`).
- A `template.yml` declares `variables` (type/default/required/prompt); rendering
  is the Tera engine (`.raw` files bypass; "partial" paths are skipped).
- **R7.3 — generated output is a task `outputs`** so the codegen task caches and
  downstream tasks see it as inputs. [src: https://moonrepo.dev/docs/guides/codegen]

A common pattern is a per-project `proto-gen`/`codegen` task that runs a pinned
generator and declares the generated directory as `outputs`:

```yaml
tasks:
  codegen:
    command: 'go run github.com/some/gen@v1.2.3 ./schema'   # pinned ephemeral tool
    inputs: ['schema/**/*']
    outputs: ['gen/**/*']
    options:
      cache: true
      runFromWorkspaceRoot: true   # if it reads a root-level config
```

## Env loading & precedence

**R6.1 — precedence (high → low):** shell-set vars > project `.env`
(`options.envFile`) > repo-wide dotenv (proto `[env].file`) > `[env]` / `env:`
literals.

**R6.2 — repo-wide vars in a shared dotenv** (proto `[env].file = ".env.shared"`);
**per-project vars in `<project>/.env`** (task `options.envFile: true`).

**R6.3 — never hardcode secrets** in `moon.yml`/`.prototools`; document new vars in
a value-free `*.example` file. [F7]

```yaml
# in a scoped tasks file or project
taskOptions:        # or per-task options:
  envFile: true     # loads <project>/.env
```

## Anti-patterns

- A hand-rolled CI matrix instead of `moon ci` (R7.1).
- `cache: true` with `inputs: ['**/*']` (never hits) or no `outputs` (no-op) (R7.2).
- Caching a non-deterministic task (F5).
- Secrets inline (F7).
- Generated output not declared as `outputs` (breaks caching + downstream inputs).
