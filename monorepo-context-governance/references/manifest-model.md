# Manifest Model

## Reading Map

TL;DR: `manifest.yaml` is the source of governable facts. Keep it concise, machine-readable, and free of schema bodies or long procedures.

Read:

- "Required shape" when authoring a new manifest.
- "Manifest limits" when content starts becoming prose.
- "Review checks" when validating a manifest.

## Required Shape

Start new manifests from `assets/manifest.template.yaml`.

Required top-level intent:

```yaml
apiVersion: context/v1
kind: BoundedContext
```

Recommended information model:

```yaml
identity:
  name: <stable-context-id>
  title: <human-readable-title>
  status: active # proposed | active | deprecated | retired
  owner:
    team: <team-id>
    contact: <team-channel-or-dl>
  created: <YYYY-MM-DD>
  last_reviewed: <YYYY-MM-DD>

purpose:
  statement: >
    <One concise paragraph explaining why this context exists.>
  problem_solved: >
    <The specific problem owned by this context.>

responsibilities:
  - <capability-owned-by-this-context>

non_responsibilities:
  - capability: <capability-not-owned-here>
    owned_by: <other-context-id>
    reason: <brief reason>

boundaries:
  knowledge_in:
    - <knowledge-category-owned-here>
  knowledge_out:
    - knowledge: <knowledge-category-not-owned-here>
      lives_in: <other-context-id>
  dependencies:
    allowed:
      - context: <other-context-id>
        via: contract
        contracts:
          - <contract-id>
        reason: <why this dependency exists>
    forbidden:
      - context: <other-context-id>
        reason: <why coupling is forbidden>

contracts:
  published:
    - id: <context.contract_name>
      type: event # event | command | query | api
      direction: outbound # inbound | outbound
      version: <semver>
      schema: contracts/published/events/<name>/v1.schema.<ext>
      stability: stable # draft | stable | deprecated
      deprecates: <optional-id@version>
      replacement: <optional-id@version>
  consumed:
    - id: <other.contract_name>
      type: event
      version: <pinned-semver-or-range>
      from: <owning-context-id>
      usage: <why this context consumes it>
      ref: ../<owner>/contracts/published/events/<name>/v1.schema.<ext>

observability:
  signals:
    - name: <metric-log-or-span-name>
      type: metric # metric | log | span | dashboard | alert
      meaning: <what it indicates>
      contractual: false
      stability: internal # internal | stable | deprecated

entrypoints:
  source:
    - <path-or-module>
  tests:
    - <path-or-suite>
  runtime:
    - <optional-runtime-entrypoint>
  docs:
    guide: guide.md
    context_map: context-map.yaml

governance:
  versioning: semver
  open_questions: open-questions.md
  review_triggers:
    - contract_change
    - boundary_change
    - ownership_change
    - adr_superseded
  since: <semver-or-date>
  sunset: <optional-date-or-version>
```

## Field Rules

- Use `identity.name` as the stable context id. Do not change it because a folder is renamed, code moves, a service splits internally, a language migration happens, or packages are reorganized.
- Use `identity.status` from this set only: `proposed`, `active`, `deprecated`, `retired`.
- Resolve `identity.owner.team` against `docs/OWNERS` when that file exists.
- Put responsibilities and non-responsibilities in lists. Include owner pointers for non-responsibilities when known.
- Declare allowed dependencies only when they are via contract.
- Declare forbidden dependencies when common ambiguity exists.
- Register every published contract in `contracts.published`.
- Register consumed contracts as references with pinned versions or ranges.
- Declare contractual observability signals with owner/version/stability information.
- Keep entrypoints as pointers to source, tests, runtime, and docs, not explanations.

## Manifest Limits

Move content out when it grows:

| If it grows | Move to |
| --- | --- |
| glossary | `glossary.md` |
| workflow explanation | `workflows/**` |
| troubleshooting | `runbooks/**` |
| change procedure | `playbooks/**` |
| decision rationale | `decisions/ADR-*.md` |
| implementation detail | code world or technical ADR |
| contract body | `contracts/published/**` |
| generated list | generated index |

## Review Checks

- Every context has a `manifest.yaml`.
- `apiVersion` is `context/v1`.
- `kind` is `BoundedContext`.
- `identity.name` is stable and matches the context id unless an ADR justifies otherwise.
- `identity.owner.team` resolves in `docs/OWNERS` when owners are governed.
- Responsibilities and non-responsibilities are explicit.
- Dependencies are declared and go through contracts.
- Published contracts have schema paths, versions, and stability.
- Consumed contracts are references and do not duplicate schema bodies.
- Entry points resolve to existing paths or known modules.
- Long prose is moved out.
