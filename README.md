# skills

Agent-agnostic skills bundle. Works with **Claude Code**, **Codex CLI**, **OpenCode**, and any other agentic CLI that supports skills/instructions.

## Available

| Skill                                                   | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| ------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [go-code-quality-check](go-code-quality-check/SKILL.md) | Run static-analysis + security gates on Go projects (`go vet` + `staticcheck` + `semgrep`) via bundled `scripts/staticanalysis.sh`. Returns prioritized fix plan grouped by file and severity. Read-only by default.                                                                                                                                                                                                                                                                                                                                                                                                                |
| [go-modularization](go-modularization/SKILL.md)         | Opinionated folder/package layout for Go projects (monorepos and single-service repos). Pragmatic flat hexagonal architecture, suffix-then-folder promotion, `go-pkgs/` (never `pkg/`), `data_repositories/` vs `storage/` split, migration grammar, forbidden folder list. Both users and AI agents must consult before placing new code or refactoring layout; agents must escalate to the user when no rule clearly applies.                                                                                                                                                                                                     |
| [go-design-principles](go-design-principles/SKILL.md)   | Project-agnostic Go design judgement complementing `samber/cc-skills-golang` (no duplication). KISS, DRY (rule-of-three), SRP, object calisthenics adapted for Go (one indent, no else, named-type wrappers, first-class collections, one dot per line, small entities), feature-envy detection, sharper forbidden generic package names (util/common/helpers/shared/manager/handler/processor/data/service), type-driven design (sealed sum-type interfaces, state-transition methods, primitive wrappers like `UserID`/`Cents`/`Email`), immutability defaults, YAGNI. Includes `errorkit` appendix for trypanic/go-sdk projects. |
| [go-sdk-bootstrap](go-sdk-bootstrap/SKILL.md)           | Scaffold or extend a Go service that imports `github.com/trypanic/go-sdk`. Encodes the canonical wiring (logger + telemetry + httpclient + postgres + messaging), the directory-vs-package-name divergences (`postgres/`→`database`, `mongo/`→`mongodb`), the tracing constructor triplet, and the errorkit wrapping rules. Includes a verified `main.go` template.                                                                                                                                                                                                                                                                 |
| [go-testing-strategy](go-testing-strategy/SKILL.md)     | Test strategy complementing `samber/cc-skills-golang@golang-testing` (no duplication of unit idioms). Test pyramid per layer: contract tests against JSON Schemas, unit at interactor/domain, integration with schema-validated `httptest` mocks at port boundaries, real-infrastructure tests for stored-procedure repositories (never mock the DB when behavior lives in it), minimal e2e smoke. Workflow gates (each spec slice passes its tests before the next), build-tag conventions (`integration`/`e2e`), atomicity test pattern for leases/claims.                                                                        |
| [traceflow](traceflow/SKILL.md)                         | Lifecycle-driven documentation skill with spec-delta traceability. Agent-agnostic and stack-agnostic. Four axes (idea, domain, decisions, specs) with per-area scoping, append-only ADRs (typed), file-path reverse-index maps, and a mandatory Update Manifest at end of every agent turn. Includes bash invariants suite and templates for every artifact. Replaces ad-hoc lifecycles in monorepos with multiple areas or long-lived projects.                                                                                                                                                                                    |

## Deprecated

_None._

## Install via [skillshare](https://github.com/runkids/skillshare)

`skillshare` = single source of truth for skills, fanned out to every detected agent CLI via symlinks (junctions on Windows). Auto-detects Claude Code, Codex, OpenCode, and 60+ others — no manual path config.

```bash
# create config, central source, detect installed agents
skillshare init

# install skill from this repo into central source
skillshare install trypanic/go-code-quality-check

# fan out to all detected agent dirs (symlinks)
skillshare sync
```

After `sync`, skill is symlinked into each agent's skill dir automatically. Agents auto-discover on next session. No need to touch `.claude/`, `.codex/`, `.opencode/` by hand.
