# Context Map Routing

## Reading Map

TL;DR: `context-map.yaml` is the machine-readable task router for agents. It maps intent and symptom to the smallest useful read set.

Read:

- "Information model" when authoring `context-map.yaml`.
- "Allowed intents" when classifying tasks.
- "Composition flow" when implementing agent loaders or writing agent instructions.

## Purpose

The context map answers:

- What must be read?
- What must not be read initially?
- Which contracts must be inspected?
- Which code entrypoints are relevant?
- Which tests are relevant?
- Which guardrails apply?

It optimizes for task-relevant context, not exhaustive reading.

## Information Model

Start new files from `assets/context-map.template.yaml`.

```yaml
apiVersion: context-map/v1
context: <context-id>

bootstrap:
  - manifest.yaml
  - guide.md

intents:
  allowed:
    - fix_bug
    - investigate_incident
    - add_feature
    - change_contract
    - change_workflow
    - refactor_no_behavior_change
    - migrate_context
    - update_docs
    - split_context

tasks:
  fix_bug:
    read:
      - workflows/main-flow.md
      - observability/signals.md
    inspect_contracts:
      - published
      - consumed
    code: entrypoints.source
    tests: entrypoints.tests
    do_not_read:
      - references/
      - playbooks/
    invariant:
      - published_contracts_unchanged_unless_explicitly_requested
    require_adr_if:
      - boundary_changes
      - dependency_changes
      - ownership_changes
    symptoms:
      worker_not_receiving_tasks:
        read:
          - runbooks/worker-not-receiving-task.md
          - observability/queue-signals.md

  change_contract:
    read:
      - contracts/published/
      - ../../governance/contract-versioning.md
    inspect_contracts:
      - published
      - consumed
    require_adr_if:
      - breaking_semantic_change
      - dependency_topology_changes
    do_not_read:
      - references/

guardrails:
  - never_redefine_a_consumed_contract
  - never_modify_a_published_contract_without_version_bump
  - never_depend_on_other_context_internals
  - never_change_context_identity_without_adr
  - never_treat_references_as_source_of_truth
```

## Allowed Intents

Keep the intent vocabulary closed and small:

```text
fix_bug
investigate_incident
add_feature
change_contract
change_workflow
refactor_no_behavior_change
migrate_context
update_docs
split_context
```

Add context-specific symptoms freely under an intent, but do not create many near-duplicate intents.

## Agent Read Boundaries

Load:

```text
bootstrap
+ task.read
+ symptom.read
+ touched contracts
+ relevant entrypoints
+ relevant tests
```

Do not load:

```text
all docs
all references
other contexts' internals
all workflows
all ADRs
all runbooks
all playbooks
```

## Composition Flow

Use this flow for agent context composition:

1. Load global manifest.
2. Resolve target context by id, alias, service, module, or known entrypoint.
3. Load context manifest.
4. Load `context-map.yaml`.
5. Map the request to a closed intent.
6. Extract symptom or qualifier if present.
7. Load bootstrap docs.
8. Load task-specific docs.
9. Load symptom-specific docs.
10. Load only touched published or consumed contracts.
11. Load code and tests from declared entrypoints if needed.
12. Apply guardrails.
13. Stop when the loaded set answers the task.

Stop when:

- workflow plus contracts plus entrypoints answer the task;
- expansion would cross into another context's internals;
- a typed reference does not exist;
- the context budget is exhausted;
- the task requires a decision absent from current sources.

Expand only when:

- a loaded artifact contains a typed reference;
- the reference stays inside the same context;
- the reference points to another context's published contract;
- the reference points to repo-level governance, runbook, or playbook;
- the task requires the referenced artifact;
- there is enough context budget.

Do not infer required documents from free-text links unless they are declared as typed references.

## Scenario Minimum Reads

| Scenario | Minimum read | Contracts/evidence | Must not do | ADR required when |
| --- | --- | --- | --- | --- |
| Fix bug | workflow, relevant runbook, observability | touched contracts | silently change source of truth without classification | fix changes boundary, dependency, or ownership |
| Investigate incident | runbooks, observability, affected workflow | runtime signals, operational contracts | modify contracts during diagnosis | incident reveals architectural decision |
| Add feature | manifest, guide, affected workflow | published/consumed contracts | add hidden dependency | new boundary, dependency, or contract appears |
| Change contract | contract schema, versioning rules, consumers | impact graph | edit schema without version bump | semantic or architectural break |
| Refactor no behavior change | workflow, tests | invariant: contracts unchanged | alter published behavior | refactor changes architecture |
| Change workflow | specific workflow | contracts touched by workflow | update code only if workflow is source of truth | behavior boundary changes |
