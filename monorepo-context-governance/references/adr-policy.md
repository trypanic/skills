# ADR Policy

## Reading Map

TL;DR: Use ADRs for boundary, ownership, dependency, shared-kernel, contract-architecture, breaking-contract, and major strategy decisions. Accepted ADRs are immutable.

Read:

- "ADR required" before making structural changes.
- "ADR not required" before creating unnecessary decision records.
- "Immutability" when changing an accepted decision.

## ADR Required

Require an ADR for:

- creating a bounded context;
- retiring a bounded context;
- splitting a context;
- merging contexts;
- changing context ownership;
- changing context identity;
- adding a new cross-context dependency;
- changing dependency direction or ownership;
- introducing a shared kernel;
- making a breaking semantic contract change;
- changing contract architecture;
- changing a major technology strategy;
- superseding an accepted ADR.

## ADR Not Required

Do not require an ADR for:

- adding an optional field to a contract when backward compatible;
- correcting typos;
- improving examples;
- updating a non-contractual workflow description;
- adding a runbook for a known failure mode;
- adding a local playbook;
- changing implementation under stable contracts;
- adding tests;
- refactoring without boundary or behavior change.

## Immutability

Accepted ADRs are immutable.

If the decision changes:

1. Create a new ADR.
2. Mark the old ADR as superseded.
3. Link both directions.
4. Update affected manifests, contracts, and workflows.

## Drafting Rules

- Keep one decision per ADR.
- State status clearly: proposed, accepted, superseded, rejected.
- Link affected context ids, contracts, workflows, and prior ADRs.
- Capture alternatives considered only when they explain the trade-off.
- Do not use ADRs as current-state manifests; update `manifest.yaml` for current facts.

Use `assets/adr.template.md` for new ADRs.
