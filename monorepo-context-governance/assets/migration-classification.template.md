# Migration Classification

Source: `<path>`
Target context: `<context-id>`
Reviewer: `<name-or-team>`
Date: `<YYYY-MM-DD>`

Allowed classifications:

```text
identity
responsibility
non_responsibility
boundary
dependency
published_contract
consumed_contract
workflow
runbook
playbook
ADR
contractual_signal
non_contractual_signal
reference
duplicate
obsolete
unknown
conflict
```

| Source section       | Classification     | Target artifact           | Owner decision needed? | Notes     |
| -------------------- | ------------------ | ------------------------- | ---------------------- | --------- |
| `<heading-or-lines>` | `<classification>` | `<target-path-or-action>` | `yes/no`               | `<notes>` |

## Conflicts

| Conflict        | Classification                 | Resolution artifact                                                | Owner     |
| --------------- | ------------------------------ | ------------------------------------------------------------------ | --------- |
| `<description>` | `<1-8 from conflict taxonomy>` | `<manifest/contract/workflow/ADR/open-question/code-issue/delete>` | `<owner>` |

## Unknowns

- `<question>` -> `open-questions.md`
