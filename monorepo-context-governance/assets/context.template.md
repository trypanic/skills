---
type: BoundedContext

id: <context-id>                 # stable; MUST match the directory name; renaming requires ADR + migration plan
title: <Human Readable Title>
status: proposed                 # proposed | active | deprecated | retired
owner:
  team: <team-id>                # must resolve in docs/OWNERS
  contact: <channel-or-distribution-list>
last_reviewed: <YYYY-MM-DD>

contracts:
  published: []
  # - id: <context-id>.<contract_name>   # globally unique
  #   kind: event                        # event | command | query | api | workflow
  #   version: 1.0.0
  #   stability: draft                   # draft | stable | deprecated
  #   replacement: null                  # required non-null when stability: deprecated
  consumed: []
  # - id: <other-context>.<contract_name>
  #   version: "1.x"                     # pinned version or range; id + version ONLY — never a path
  #   usage: <why this context consumes it>

dependencies:
  allowed: []
  # - context: <other-context-id>
  #   via: [<contract-id>]
  forbidden: []
  # - context: <other-context-id>
  #   reason: <why coupling is forbidden>

signals: []                      # contractual signals only; internal signals go to observability.md
# - name: <signal-name>
#   kind: metric                 # metric | log | span
#   version: 1.0.0
#   used_by:
#     - context: <consumer-context-or-team>
#       purpose: <why it depends on this signal>

entrypoints:
  source: []                     # paths/modules implementing this context; must resolve
  tests: []
---

# <Human Readable Title>

<One-paragraph purpose statement: why this context exists and the specific problem it owns.>

## What this context owns

<Prose responsibilities. Complete sentences, written for humans.>

## What this context does not own

<Prose non-responsibilities with links to the owning context, e.g. price computation → [pricing](/contexts/pricing/context.md).>

## Start here

<Reading path for a newcomer: which documents, in which order, and why.>

## Main workflows

<One line per workflow, linking into workflows/.>

## Contracts

<One line per published/consumed contract, linking to its contract.md. Summaries only — frontmatter and schema files are authoritative.>

## Operational knowledge

<Links to runbooks, playbooks, observability.md.>

## Relevant decisions

<Links to the ADRs that explain the current shape.>

## Open questions

<Unresolved decisions with owner and status. Delete this section if empty.>
