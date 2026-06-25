# Workspace — `.moon/workspace.yml`

The workspace is the directory containing `.moon/`. `.moon/workspace.yml`
configures the project graph and repo-wide behavior. [src: https://moonrepo.dev/docs/config/workspace]

## Project discovery (`projects`) — the most important key

Three forms:

```yaml
# (a) glob list
projects:
  - 'services/*'
  - 'libs/*'
  - 'tools/*'

# (b) explicit map (id: source)
projects:
  web: 'services/web'
  core: 'libs/core'

# (c) combined — globs for the common case, sources for the root or odd paths
projects:
  globs:
    - 'services/*'
    - 'libs/*'
    - 'tools/*'
  sources:
    root: '.'
```

### Rules

- **R1.1 — every glob/source must resolve to ≥1 real project.** A glob matching
  nothing is dead weight; a `moon.yml` matched by nothing is an invisible project.
  Verify with `moon query projects`.
- **R1.2 — globs are literal path segments, not recursive.** `infra` matches only
  `infra/`. A project at `infra/db/moon.yml` needs `infra/*`, `infra/**/*`, or a
  `sources` entry. This is the #1 cause of "my project isn't discovered."
  - ❌ glob `infra` + project at `infra/db/` → `db` undiscovered.
  - ✅ glob `infra/*` → discovers `infra/db`.
- **R1.3 — set `vcs.defaultBranch` and `provider` explicitly.** moon defaults
  `defaultBranch` to `master`; CI and `--affected` key off it.
- **R1.4 — prefer globs over a hand-maintained `sources` map** for
  discoverability; reserve `sources` for the root project (`root: '.'`) or a path a
  glob can't express.

### Detection signals (for the verifier)

- For each glob, expand against the tree → flag zero-match (`dead-glob`).
- For each `moon.yml` on disk, confirm it appears in `moon query projects` →
  flag absent ones (`undiscovered-project`).

## `vcs`

```yaml
vcs:
  client: 'git'            # default 'git'
  defaultBranch: 'main'    # default 'master' — override it
  provider: 'github'       # github | gitlab | bitbucket | other
  hooks: {}                # optional git hooks managed by moon
  sync: false              # write hooks on run (v1 'syncHooks')
```

## Other top-level keys (all optional)

| Key                 | Purpose                                                                                                                       |
| ------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| `extends`           | inherit another workspace config (HTTPS URL or relative path; deep-merged, local wins). Pin remote sources by version/ref.    |
| `defaultProject`    | project focused when no scope is given                                                                                        |
| `pipeline`          | task pipeline tuning (**v2 name; was `runner`**): `cacheLifetime`, `installDependencies`, `syncProjects`, `syncWorkspace`, …  |
| `hasher`            | smart-hash tuning: `optimization`, `walkStrategy`, `ignorePatterns`, `ignoreMissingPatterns`, `warnOnMissingInputs`           |
| `cache`             | CAS tuning (`cas.verifyIntegrity`)                                                                                            |
| `experiments`       | opt-in experimental flags                                                                                                     |
| `constraints`       | project-boundary enforcement: `enforceLayerRelationships` (**v2; was `enforceProjectTypeRelationships`**), `tagRelationships` |
| `codeowners`        | CODEOWNERS generation: `globalPaths`, `orderBy`, `sync`                                                                       |
| `notifier`          | terminal/webhook notifications                                                                                                |
| `generator`         | codegen template sources (`templates`, default `['./templates']`)                                                             |
| `docker`            | Docker scaffold/prune defaults                                                                                                |
| `remote`            | remote cache service (**v2; was `unstable_remote`**): `host`, `api`, `auth`, `cache.*`                                        |
| `telemetry`         | usage/version data (default `true`)                                                                                           |
| `versionConstraint` | semver requirement for the moon binary itself                                                                                 |

[src: https://moonrepo.dev/docs/config/workspace, https://moonrepo.dev/docs/migrate/2.0]

## Constraints — enforcing layer/tag relationships

Use `constraints` to make the project graph self-policing:

```yaml
constraints:
  enforceLayerRelationships: true     # e.g. an 'application' may depend on a
                                      # 'library', but not vice-versa
  tagRelationships:
    frontend: ['shared', 'ui']        # a 'frontend'-tagged project may only
                                      # depend on 'shared'/'ui'-tagged projects
```

This pairs with the `layer`/`stack`/`tags` set on each project (see
`project-config.md`) — those values are what `constraints` reads.

## `$schema`

`$schema` is editor-only metadata, accepted in any moon YAML. If you use it, use
it **consistently** (all configs or none). The generated schemas live under the
gitignored `.moon/cache/` after `moon sync config-schema`; a public schema URL is
the alternative that needs no sync step. Pick one policy repo-wide.

## Anti-patterns

- A glob that matches nothing (F2). Fix the path or delete it.
- A nested project not covered by any glob/source (R1.2) → undiscovered.
- Leaving `defaultBranch` at the implicit `master` when the repo uses `main`.
