# Toolchains & proto — `.prototools` + `.moon/toolchains.yml`

> **The contract:** proto = WHICH version of a tool; moon = HOW/WHEN tasks run.
> moon learns versions from `.prototools` only via `versionFromPrototools` in
> `.moon/toolchains.yml`. [src: https://moonrepo.dev/docs/concepts/toolchain]

## `.prototools` — the version source of truth

### Version pin table (top level)

`<tool> = "<spec>"`. Pin exactly for reproducibility; use a range only on purpose.

```toml
moon   = "2.3.0"
proto  = "0.57.0"
go     = "1.24.0"
rust   = "stable"
python = "3.13.0"
```

Backend-prefixed ids exist too: `"asdf:zig" = "…"`, `"npm:typescript" = "…"`.

**R2.1 — every tool a task invokes is pinned here** (or linked via
`versionFromPrototools`). The only accepted alternative is a *pinned ephemeral*
call inside a task (`go run pkg@ver`, `npx pkg@ver`, `bunx pkg@ver`, `uvx pkg@ver`).

### Version spec formats [src: https://moonrepo.dev/docs/proto/tool-spec]

- exact semver `1.2.3` (pre-release `-alpha.0`, build `+meta`)
- calver `2025-02-26`, `2024-02`
- partial `1.2` / `1` (a partial defaults to the `~` operator)
- requirements `= > >= <= < ~ ^`, AND via `,`/space, OR via `||`
- aliases `latest`, `stable`, `canary`, and tool-specific (`lts`, `next`, `beta`)

### Resolution order (high → low) [src: https://moonrepo.dev/docs/proto/detection]

1. CLI arg (`proto run go 1.24.0`)
2. `PROTO_<TOOL>_VERSION` env
3. upward filesystem traversal cwd→`~` (`.prototools` entry and/or the tool's
   ecosystem file, e.g. `go.mod`, `package.json`, `.python-version`)
4. global `~/.proto/.prototools`
5. fail

`detect-strategy` (a `[settings]` key) governs step 3: `first-available`
(default) / `prefer-prototools` / `only-prototools`. Nearest `.prototools` up the
tree wins per tool.

### `[env]` and per-tool env

```toml
[env]
file = ".env.shared"        # load a repo-wide dotenv (v0.43+)
NODE_ENV = "production"
SOME_FLAG = false           # value `false` REMOVES the variable

[tools.node.env]            # per-tool env; OVERRIDES [env]
NODE_OPTIONS = "--max-old-space-size=4096"
```

Precedence: shell-set vars > `[tools.<tool>.env]` > `[env]`. proto env never
overrides a var already set in the shell. There is **no `[env.<tool>]` section** —
per-tool env is `[tools.<tool>.env]`.

**R2.6 — `[env]` keys must be real, consumed vars.** No invented switches (an env
var that no documented tool and no repo code reads). [F12]

### `[settings]` [src: https://moonrepo.dev/docs/proto/config]

```toml
[settings]
auto-install = true            # install a missing version on run
auto-clean = true              # remove unused tools
telemetry = false
detect-strategy = "first-available"   # | prefer-prototools | only-prototools
pin-latest = "local"           # auto-pin when installing the `latest` alias
builtin-plugins = true         # bool, or an allow-list of names

[settings.http]                # allow-invalid-certs, proxies, secure-proxies, root-cert
[settings.offline]             # custom-hosts, override-default-hosts, timeout (750ms)
[settings.build]               # exclude-packages, install-system-packages, write-log-file
```

There is **no flat `unstable` or `offline` key** — those are sub-tables /
`unstable-lockfile` / `unstable-registries`.

### `[plugins.tools]` — custom tools

A tool proto doesn't ship built-in (a migrator, a db CLI, a codegen binary) is
declared here, then pinned and consumed like any tool:

```toml
[plugins.tools]
mytool = "github://<org>/<repo>@v1"          # release asset, PINNED ref
othertool = "https://example.com/plugins/othertool.toml"   # raw .toml/.wasm
localtool = "file://./plugins/localtool.toml"
```

```toml
mytool = "1.4.0"     # then pin its version in the table above
```

- **Locator schemes:** `github://org/repo`, `https://…/(plugin.toml|plugin.wasm)`,
  `file://path`. [src: https://moonrepo.dev/docs/proto/plugins]
- **R2.4 — pin remote locators to a tag/sha, never a moving branch** (`/main/`). [F11]
- **R2.5 — locators are single, well-formed URLs.** No double slash
  (`https://host//path`). [F11]
- Plugin kinds: non-WASM **TOML config plugins** (basic tools) and **WASM
  plugins** (advanced). Built-ins ship with proto.

## `.moon/toolchains.yml` — enabling languages

**This file is what turns a language on for moon.** Without a block, moon does not
manage that toolchain (it falls back to `system`/PATH). [src: https://moonrepo.dev/docs/config/toolchain]

```yaml
proto:
  version: '0.57.0'          # which proto moon should auto-install

go:
  versionFromPrototools: true   # inherit the version pinned in .prototools

rust:
  versionFromPrototools: true

python:
  versionFromPrototools: true
```

- **R2.2 — a language is enabled by a block here**, and the block inherits its
  version from `.prototools` via `versionFromPrototools: true` (default). Don't
  re-pin the version inline unless you deliberately want to diverge.
- A custom-language toolchain is added with a `plugin:` locator (a `.wasm`
  toolchain plugin) — relative path / HTTPS / `github://`.
- Built-in toolchains: `javascript`, `node` (+ `npm`/`pnpm`/`yarn`), `bun`,
  `deno`, `typescript`, `go`, `rust`, and Python via `unstable_python`.

### Detection signal

A project sets `toolchains.default: <id>` but `<id>` has no block in
`.moon/toolchains.yml` → `toolchain-not-enabled`. Fix: add the block, or set
`default: system`.

## Adding a new language (the config-only recipe)

**R2.3 — onboarding a language never touches service code.** Four edits:

1. `.prototools` — pin the tool: `deno = "2.0.0"`.
2. `.moon/toolchains.yml` — add the block: `deno: { versionFromPrototools: true }`.
3. `.moon/tasks/deno.yml` — shared tasks scoped by `inheritedBy: { language: [deno] }`
   (or `{ toolchains: [deno] }`).
4. each Deno project's `moon.yml` — `language: deno`, `toolchains.default: deno`.

## proto ↔ moon env vars

- `versionFromPrototools` (toolchains.yml) — the one link moon→`.prototools`.
- `MOON_TOOLCHAIN_FORCE_GLOBALS=true` (or a tool list) — force moon to use PATH
  binaries instead of downloading.
- Documented `PROTO_*`: `PROTO_HOME`, `PROTO_AUTO_INSTALL`, `PROTO_AUTO_CLEAN`,
  `PROTO_<TOOL>_VERSION`, `PROTO_OFFLINE`, `PROTO_OFFLINE_TIMEOUT`, `PROTO_ENV`
  (selects `.prototools.<env>` overlays), `PROTO_LOG`, `PROTO_VERSION`,
  `PROTO_BYPASS_VERSION_CHECK`.
- There is **no `ENABLE_MOON`** and **no `MOON_OFFLINE`** env var. Don't invent them.

## Bootstrap task

Wrap `proto install` as a moon task so a fresh checkout runs one command:

```yaml
# in the root project's moon.yml
tasks:
  setup:
    command: 'proto install'
    options:
      cache: false
```

## Anti-patterns

- A task running an un-pinned tool (F4).
- A plugin locator on `main` or with a `//` (F11).
- `toolchains.default` pointing at a toolchain with no block here (then it isn't
  really enabled).
- An invented `[env]` key (F12).
