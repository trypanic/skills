# ADR Policy

## Required

An ADR is required for:

- creating, retiring, splitting, merging, or renaming a bounded context;
- changing context ownership;
- adding a new cross-context dependency;
- changing dependency direction or ownership;
- introducing a shared kernel (plus approval from at least two affected owners);
- making a breaking semantic contract change;
- changing contract architecture (e.g. schema format, envelope strategy);
- changing a major technology strategy;
- superseding an accepted ADR.

## Not Required

- adding a backward-compatible optional field to a contract;
- correcting typos or improving examples;
- updating a non-contractual workflow description;
- adding a runbook or a local playbook;
- changing implementation under stable contracts;
- adding tests;
- refactoring without boundary or behavior change.

## Immutability

Accepted ADRs are immutable (enforced rule E8). If the decision changes:

1. create a new ADR;
2. mark the old one `status: superseded` and set `superseded_by`;
3. set `supersedes` on the new one — link both directions;
4. update affected `context.md` frontmatter, contracts, and workflows in the same change set.

ADRs explain **why** a decision was made — never current state. Current declared facts live in `context.md` frontmatter; if an ADR is the only place a current fact exists, extract the fact.

Use `assets/adr.template.md`. One decision per file. Technology choices (language, framework, broker, schema format, codegen, validation, runtime) are always ADRs — never hardcoded into the knowledge model.
