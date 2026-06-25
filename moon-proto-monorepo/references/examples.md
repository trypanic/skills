# Examples — the canonical `acme/` monorepo

A complete, copy-pasteable polyglot monorepo: a Go service, a Rust library, a
Python tool. Every file below is canonical per the rules in `SKILL.md`. After it,
a set of ✅/❌ pairs for the common traps.

```
acme/
├── .prototools
├── .env.shared                 # repo-wide env (value-free example: .env.shared.example)
├── .moon/
│   ├── workspace.yml
│   ├── toolchains.yml
│   └── tasks/
│       ├── go.yml              # inheritedBy: language go
│       ├── rust.yml            # inheritedBy: language rust
│       └── all.yml             # no inheritedBy → every project (named honestly)
├── moon.yml                    # root project (repo-wide tasks)
├── services/web/moon.yml       # go    · application · backend
├── libs/core/moon.yml          # rust  · library     · systems
└── tools/gen/moon.yml          # python· tool
```

## `.prototools`

```toml
moon   = "2.3.0"
proto  = "0.57.0"
go     = "1.24.0"
rust   = "stable"
python = "3.13.0"

[env]
file = ".env.shared"

[settings]
auto-install = true
auto-clean = true
telemetry = false
detect-strategy = "first-available"

# a tool proto doesn't ship built-in — PINNED to a tag, single clean URL
[plugins.tools]
acmegen = "github://acme/proto-plugins@v1.0.0"
```

```toml
# pin the custom tool's version too
acmegen = "0.4.2"
```

## `.moon/workspace.yml`

```yaml
projects:
  globs:
    - 'services/*'
    - 'libs/*'
    - 'tools/*'
  sources:
    root: '.'

vcs:
  defaultBranch: 'main'
  provider: 'github'

constraints:
  enforceLayerRelationships: true
```

## `.moon/toolchains.yml`

```yaml
proto:
  version: '0.57.0'

go:
  versionFromPrototools: true

rust:
  versionFromPrototools: true

python:
  versionFromPrototools: true
```

## `.moon/tasks/go.yml` (scoped by language)

```yaml
inheritedBy:
  language: [go]
tasks:
  build:
    command: 'go build -o dist/app ./cmd'
    inputs: ['**/*.go', '/go.work']
    outputs: ['dist/app']
    options:
      cache: true
  test:
    command: 'go test ./...'
    inputs: ['**/*.go']
    options:
      cache: true
  start:
    command: 'go run ./cmd'
    options:
      cache: false       # non-deterministic, long-running
      persistent: true
```

## `.moon/tasks/rust.yml` (scoped by language)

```yaml
inheritedBy:
  language: [rust]
tasks:
  build:
    command: 'cargo build --release'
    inputs: ['src/**/*', 'Cargo.toml', 'Cargo.lock']
    outputs: ['target/release/']
    options:
      cache: true
  test:
    command: 'cargo test'
    inputs: ['src/**/*', 'Cargo.toml']
    options:
      cache: true
```

## `.moon/tasks/all.yml` (every project — named honestly, no `inheritedBy`)

```yaml
# Intentionally applies to ALL projects: the filename says so and inheritedBy is
# omitted on purpose. Do NOT name a language-scoped file like this.
tasks:
  clean:
    command: 'rm -rf dist target __pycache__'
    options:
      cache: false
```

## Root `moon.yml`

```yaml
language: unknown
toolchains:
  default: system
layer: configuration
project:
  title: 'acme'
  description: 'acme polyglot monorepo'
  owner: 'platform-team'
  maintainers:
    - 'Jane Doe <jane@example.com>'
workspace:
  inheritedTasks:
    include: []          # the root inherits nothing
tasks:
  setup:
    command: 'proto install'
    options: { cache: false }
```

## `services/web/moon.yml`

```yaml
language: go
toolchains:
  default: go
layer: application
stack: backend
project:
  title: 'web'
  description: 'public HTTP API'
  owner: 'platform-team'
  maintainers:
    - 'Jane Doe <jane@example.com>'
tags: ['go', 'service']
```

## `libs/core/moon.yml`

```yaml
language: rust
toolchains:
  default: rust
layer: library
stack: systems
project:
  title: 'core'
  description: 'shared domain primitives'
  owner: 'platform-team'
  maintainers:
    - 'Jane Doe <jane@example.com>'
tags: ['rust', 'lib']
```

## `tools/gen/moon.yml`

```yaml
language: python
toolchains:
  default: python
layer: tool
project:
  title: 'gen'
  description: 'code generator'
  owner: 'platform-team'
  maintainers:
    - 'Jane Doe <jane@example.com>'
tags: ['python', 'tool']
tasks:
  generate:
    command: 'uvx acmegen@0.4.2 ./schema'   # pinned ephemeral tool
    inputs: ['schema/**/*']
    outputs: ['out/**/*']
    options:
      cache: true
```

---

## ✅ / ❌ pairs (the common traps)

### Project discovery (globs are literal)

```yaml
# ❌ project at infra/db/moon.yml is undiscovered — `infra` matches only infra/
projects: ['infra']
# ✅
projects: ['infra/*']
```

### `toolchains.default`

```yaml
# ❌ 'unknown' is not a valid toolchains.default
toolchains: { default: unknown }
# ✅ a toolchain id (enabled in toolchains.yml) …
toolchains: { default: go }
# ✅ … or 'system' for PATH-managed
toolchains: { default: system }
```

### Inheritance scoping (filename is cosmetic)

```yaml
# ❌ .moon/tasks/go.yml with NO inheritedBy → applies to ALL projects
tasks: { test: { command: 'go test ./...' } }
# ✅ scope it
inheritedBy: { language: [go] }
tasks: { test: { command: 'go test ./...' } }
```

### Caching

```yaml
# ❌ deterministic build, no outputs, cache off → re-runs every time, no hydration
build: { command: 'go build -o dist/app ./cmd', options: { cache: false } }
# ✅
build:
  command: 'go build -o dist/app ./cmd'
  inputs: ['**/*.go']
  outputs: ['dist/app']
  options: { cache: true }

# ❌ caching a long-running / side-effecting task
start: { command: 'go run ./cmd', options: { cache: true } }
# ✅
start: { command: 'go run ./cmd', options: { cache: false, persistent: true } }
```

### `command` vs `script`

```yaml
# ❌ pipe in a command (no shell)
report: { command: 'cat log | grep ERROR' }
# ✅ use a script for a shell
report: { script: 'cat log | grep ERROR' }
```

### Plugin locator

```toml
# ❌ moving branch + double slash
acmegen = "https://raw.githubusercontent.com//acme/proto-plugins/main/acmegen.toml"
# ✅ pinned tag, single clean URL
acmegen = "github://acme/proto-plugins@v1.0.0"
```

### v1 → v2 keys

```yaml
# ❌ v1
type: application
platform: go
project: { name: 'web' }
# ✅ v2
layer: application
toolchains: { default: go }
project: { title: 'web' }
```

### Inline secret

```yaml
# ❌ secret in config
env: { API_TOKEN: 'sk-live-abc123' }
# ✅ load from env; document value-free in .env.shared.example
taskOptions: { envFile: true }
```

---

## Version note

This tree targets **moon ≥ 2.3.0** (`.prototools` `moon = "2.3.0"`). On an older
pin (e.g. 2.2.x) the v2 model still applies, but a few features are gated:
the task-tag target `project:#tag` and the MQL `taskTag` field require 2.3.0+.
Check the `moon` pin before using them.
