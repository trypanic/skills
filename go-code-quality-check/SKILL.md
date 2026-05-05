---
name: go-code-quality-check
description: Run static-analysis, security, and quality gates on a Golang project using the bundled scripts/staticanalysis.sh runner (go vet + staticcheck + semgrep), then summarize findings as a prioritized fix plan grouped by file and severity. Use when the user says "check quality", "check the security", "scan the code", "run security audit", "review code quality", "lint the project", "run quality gates", "is my code clean", "find vulnerabilities", "check for bugs before commit", "audit go code", "run semgrep", "check the project", or any phrase asking to evaluate Go code health, security posture, or readiness to commit/push.
---

# go-code-quality-check

Run a static-analysis + security stack on a Go project and produce a prioritized fix plan. Read-only by default — never auto-fixes unless the user asks.

## When to use

Trigger on natural-language phrases like:
- "check the quality" / "check code quality" / "is my code clean?"
- "check the security" / "run a security audit" / "find vulnerabilities"
- "scan the project" / "lint everything" / "run semgrep"
- "run quality gates" / "audit go code"
- "what should I fix before committing?" / "ready to commit?"

## Canonical runner

`go vet`, `staticcheck`, and `semgrep` are wrapped by **`scripts/staticanalysis.sh`**. Default execution is full-repo sweep.

```bash
QG_FULL=1 bash scripts/staticanalysis.sh
```

Run from the project root so the script discovers `./...` and `.semgrep.yml`.

## Generated artifacts

Outputs land under `.staticanalysis/` (override with `QG_OUT_DIR=path`):

| File                       | Contents                                              |
|----------------------------|-------------------------------------------------------|
| `report.go-vet.json`       | Normalized `go vet` findings.                         |
| `report.staticcheck.json`  | Normalized `staticcheck` findings.                    |
| `report.semgrep.json`      | Normalized `semgrep` findings.                        |
| `plan.<tool>.md`           | Per-tool fix-list grouped by file.                    |
| `<tool>.stderr.log`        | Captured tool stderr (debugging).                     |

Exit `1` if any tool emits an `ERROR`-severity finding, `0` otherwise. Per-tool summary line: `[1/3] go-vet ✓ (0 findings, 0 errors, rc=0)`.

## Knobs

| Variable             | Effect                                                 |
|----------------------|--------------------------------------------------------|
| `QG_FULL=1`          | Scan whole repo (`./...`). Default for this skill.     |
| `QG_SKIP_VET=1`      | Skip `go vet`.                                         |
| `QG_SKIP_SC=1`       | Skip `staticcheck`.                                    |
| `QG_SKIP_SEMGREP=1`  | Skip `semgrep`.                                        |
| `QG_VERBOSE=1`       | Stream tool stderr live instead of writing to log.     |
| `QG_OUT_DIR=path`    | Override output directory (default `.staticanalysis`). |

## Required tools

The script checks each tool before running and skips gracefully if missing:

- `go` — required for `go vet`.
- `staticcheck` — install: `go install honnef.co/go/tools/cmd/staticcheck@latest`.
- `semgrep` — preferred path is the `semgrep/semgrep` Docker image; falls back to a host `semgrep` binary (`pip install semgrep` or `brew install semgrep`).
- `jq` — required by the runner for JSON normalization.

## Semgrep specifics

- Docker path (preferred): `semgrep/semgrep` image with `.semgrep.yml`, `p/golang`, `p/gosec`, `p/secrets`.
- CLI fallback (when Docker unavailable): host `semgrep` binary with `.semgrep.yml` only.
- Script does **not** authenticate with Semgrep Platform (`SEMGREP_APP_TOKEN` is unused). Findings stay local.

## Security-only execution

Skip vet + staticcheck, run semgrep alone against security packs:

```bash
QG_SKIP_VET=1 QG_SKIP_SC=1 QG_FULL=1 bash scripts/staticanalysis.sh
```

For richer packs not wired into the runner:

```bash
semgrep scan --config=p/gosec --config=p/secrets --config=p/owasp-top-ten --error
```

## Boundaries

- Read-only by default. Never edit `.go` files unless the user says "fix" or "apply fixes".
- If `semgrep`, `staticcheck`, `jq`, or `go` is missing, quote the install command and stop. Do **not** auto-install.
- Never bypass with `--no-verify` or `QG_SKIP_*` to make a report look green.

## Inputs

- Optional argument: `full` (default) | `security`.
- Optional path filter: scope to a subdirectory (e.g. `httpserver/`). When scoping, run the underlying tools directly on the path rather than going through `staticanalysis.sh`, which infers targets from `./...`.

## After running

If findings exist:
1. Read `plan.<tool>.md` files under `.staticanalysis/` and surface findings ordered ERROR → WARNING → INFO.
2. State whether commit is blocked (any tool reporting ERROR).
3. Ask: "Want me to fix the ERROR-severity items now?" — only edit code on explicit yes.

If clean:
1. State "0 findings, all gates green."
2. Suggest next step: `git add` → commit.
