# Artifact Responsibilities

## Reading Map

TL;DR: Create only artifacts with a clear consumer. Put governable facts in `manifest.yaml`, agent routing in `context-map.yaml`, human onboarding in `guide.md`, and current behavior or operations in focused files.

Read:

- "Proposed structure" when creating a package.
- "Control files" when deciding what each top-level file may contain.
- "Splitting rules" when a document is getting long.

## Proposed Structure

Use this shape as the default:

```text
/
  docs/
    manifest.yaml
    context-map.yaml
    OWNERS

    contexts/
      <context-id>/
        manifest.yaml
        context-map.yaml
        guide.md
        README.md
        open-questions.md
        glossary.md

        contracts/
          published/
            events/
            commands/
            queries/
            apis/
          consumed/

        workflows/
        runbooks/
        playbooks/
        observability/
        decisions/
        references/

    contracts/
      shared/
      integration/

    governance/
      rules.md
      document-types.md
      context-composition.md
      contract-versioning.md
      shared-kernel.md
      migration.md

    playbooks/
    runbooks/
    decisions/
      shared/

  <code>
```

## Global Files

| File | Purpose |
| --- | --- |
| `docs/manifest.yaml` | Global registry of contexts, aliases, and locations. |
| `docs/context-map.yaml` | Global router for resolving context by name, alias, service, module, or task. |
| `docs/OWNERS` | Team registry used by manifests and CODEOWNERS. |

## Context Files

| File or folder | Required? | Rule |
| --- | --- | --- |
| `manifest.yaml` | Yes | Required for every context. |
| `guide.md` | Yes | Human entrypoint. |
| `context-map.yaml` | Yes when agents/loaders depend on it | Required in mature agent-driven workflows. |
| `contracts/published/` | If context publishes contracts | Contains owned schemas. |
| `contracts/consumed/` | Optional | Contains references or notes only; no schema bodies. |
| `workflows/` | On demand | Required for behavior agents must understand or preserve. |
| `runbooks/` | On demand | Only context-specific operational diagnosis or mitigation. |
| `playbooks/` | On demand | Only context-specific deliberate procedures. |
| `observability/` | On demand | Signal catalog and diagnostics. |
| `decisions/` | On demand | Context-scoped ADRs. |
| `references/` | On demand | Supporting material linked from canonical docs. |
| `README.md` | Optional | Thin pointer only. |
| `glossary.md` | Optional | Create when glossary grows. |
| `open-questions.md` | Optional but recommended | Pending decisions. |

## Control Files

| File | Consumer | Must contain | Must not contain |
| --- | --- | --- | --- |
| `manifest.yaml` | Agents, CI, humans | identity, owner, responsibilities, boundaries, dependencies, contracts, entrypoints | long prose, schema bodies, procedures |
| `context-map.yaml` | Agents, loaders | intents, read sets, guardrails, contracts to inspect, code/test pointers | explanations, duplicated doc content |
| `guide.md` | Humans | where to start, what this context owns, how to read docs | duplicated source-of-truth content |
| `README.md` | Humans/git host | links to `guide.md`, `manifest.yaml`, `context-map.yaml` | real documentation |
| `open-questions.md` | Humans, agents | unresolved questions, owner, status | accepted decisions |
| `AGENTS.md` / `CLAUDE.md` | Agents | task classification, code-change rules, validation expectations | context-specific source of truth |

## Knowledge Folder Semantics

```text
workflow = what the system does
runbook  = how to diagnose or mitigate when it fails
playbook = how to execute a deliberate repeated change
ADR      = why a decision was made
contract = what stable boundary is promised
manifest = what governable facts define the context
```

Examples:

| Scenario | Artifact |
| --- | --- |
| How does task assignment work? | `workflows/task-assignment.md` |
| Worker is not receiving tasks; what should I inspect? | `runbooks/worker-not-receiving-task.md` |
| How do I add a new selector family? | `playbooks/add-selector-family.md` |
| Why did we choose pull-based workers? | `decisions/ADR-xxxx-pull-based-workers.md` |
| What event is published when a task completes? | `contracts/published/events/task_completed/` |

## Splitting Rules

Split by purpose, consumer, and change frequency, not arbitrary size.

| Criterion | Rule |
| --- | --- |
| Purpose | One document must have one primary purpose. |
| Consumer | Agent-routed docs and human onboarding docs should not be the same artifact. |
| Change frequency | Content that changes at different rates should be split. |
| Contract relation | Workflows reference contracts; they do not inline schemas. |
| Operation vs change | Diagnosis goes to runbook; deliberate change goes to playbook. |
| Decision vs current state | Rationale goes to ADR; current declared fact goes to manifest. |
| Reference vs source | References support; they do not define. |
| Reuse | Generic procedure moves to repo level. |
| Local specificity | Context-level procedure exists only if context-specific, recurrent, risky, or non-obvious. |

Suggested limits:

| Artifact | Suggested limit | If exceeded |
| --- | ---: | --- |
| `manifest.yaml` | about 150 lines | Move prose out. |
| `context-map.yaml` | about 120 lines | Review intent and symptom granularity. |
| `guide.md` | about 200 lines | Link instead of inline. |
| workflow | about 300 lines | Split by flow or add reading map. |
| runbook/playbook | one scenario per file | Split if multiple procedures exist. |
| ADR | one decision per file | Supersede, do not mutate. |

If a document is unavoidably long, begin with:

```md
## Reading Map

TL;DR: <short summary>

Read:
- Section 2 if changing task assignment.
- Section 3 if debugging worker polling.
- Section 4 if changing retry behavior.
- Section 5 only if modifying contracts.
```
