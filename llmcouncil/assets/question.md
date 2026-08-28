<!-- Template: 00-question.md — written by the Clerk at Stage 0.
     Replace every {{placeholder}}. Roster rows: keep only configured seats. -->
# Council Run {{run_id}}

- Convened: {{created_at}}
- Protocol: llmcouncil/v1
- Provider: {{harness}} / {{model}} (single provider — every seat runs the same model)

## Question (verbatim)

> {{question}}

## Context

{{context_notes_or_"none provided"}}

Files in scope: {{comma_separated_paths_or_"none"}}

## Roster

| Seat | Stance | Role |
|---|---|---|
| council-analyst | First-principles decomposition and rigor | Member |
| council-skeptic | Adversarial stress-testing, failure modes | Member |
| council-pragmatist | Actionability, constraints, tradeoffs | Member |
| council-explorer | Reframing, alternatives, second-order effects | Member |
| council-chairman | Synthesis of the council's collective wisdom | Chairman |
