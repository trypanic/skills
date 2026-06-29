# <Context title> - guide

## What this context owns

Link to `manifest.yaml` for authoritative responsibilities. Summarize only the navigation-level meaning here.

## What this context does not own

Link to `manifest.yaml` for authoritative non-responsibilities and owner pointers.

## Start here

- Read `manifest.yaml` for governed facts.
- Read `context-map.yaml` for agent routing.
- Read the listed workflows, runbooks, contracts, or ADRs only when the task requires them.

## Main workflows

- `<workflow-name>`: `workflows/<workflow-name>.md`

## Contracts

Published:

- `<contract-id>`: `contracts/published/<type>/<name>/v<major>.schema.<ext>`

Consumed:

- `<contract-id>`: see `manifest.contracts.consumed`

## Operational knowledge

- `<runbook-name>`: `runbooks/<runbook-name>.md`
- `<signal-catalog>`: `observability/<signals>.md`

## Relevant decisions

- `decisions/ADR-<id>-<slug>.md`

## Code entrypoints

See `manifest.entrypoints`.

## How agents should route tasks

See `context-map.yaml`.
