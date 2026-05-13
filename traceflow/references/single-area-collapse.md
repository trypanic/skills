# Single-area mode

When a repository has exactly one area (one bounded problem space,
one product, one service), KEEP the `<area>/` folder. Do NOT flatten.

This file explains why, what the minimum-viable layout looks like,
and how growth from one area to many proceeds without restructuring.

---

## The rule

For a repo with one area named `<area>`, the layout is:

```
.traceflow/
├── STATUS.md                              # global state, one area row
├── preamble.md                            # reading map
├── domain/
│   ├── MAP.md                             # one row, no deps
│   ├── glossary.md                        # transversal terms
│   └── <area>/
│       └── (durable knowledge files)
├── decisions/
│   └── <area>/
│       └── INDEX.md
├── ideas/
│   └── <area>/
└── specs/
    └── <area>/
        ├── STATUS.md
        ├── MAP.md
        └── (S0NN folders + archive/)
```

The `<area>/` level is present. `_shared/` is omitted. `decisions/_shared/`
and `domain/_shared/` only appear once a second area is added.

---

## Why not flatten

Flattening (removing `<area>/`) is cheaper on day one. It costs more
than it saves the first time you add a second area: you must move
every domain, decision, idea, and spec file into a freshly created
`<area>/` folder, update every cross-reference, retag, and rebuild
every MAP.

The folder level is one path component. Tab-completion handles it.
The cost of keeping it from day one is zero. The cost of adding it
later, after a year of references, is significant.

---

## What collapses, what doesn't

| Element | Single-area | Multi-area |
|---|---|---|
| `<area>/` folder | present | present |
| `_shared/` folders | absent | present |
| `domain/MAP.md` | minimal (one row, no deps) | full topology |
| `domain/glossary.md` | global, with all terms | partitioned when over budget |
| `STATUS.md` (global) | one area row | many area rows |
| `specs/<area>/MAP.md` | present | present |
| `decisions/<area>/INDEX.md` | present | present |
| All ADR numbering | global, per-area | global across _shared and per-area |
| Conventions-adopted ADR | one, per-area | typically per-area, optional `_shared/` |

ADR numbering remains globally unique even in single-area mode. The
moment a second area is added, the existing ADR numbers stay; new
ADRs in the new area continue the sequence.

---

## Promotion to multi-area

When the criteria in `references/lifecycle.md §6.2` are met, the second
area is added:

1. Open an ADR in `decisions/<existing-area>/` of type `structure`
   proposing the new area name and rationale. Mark it `proposed`.
2. After acceptance:
   - Create `domain/<new-area>/`, `decisions/<new-area>/`, `ideas/<new-area>/`,
     `specs/<new-area>/`.
   - Move the new area's content from `<existing-area>/` to `<new-area>/`
     using `git mv` (preserves blame).
   - Update `domain/MAP.md`: add the new row, add any dependency edges.
   - Move the structural ADR FROM `decisions/<existing-area>/` TO
     `decisions/_shared/`: it now governs the cross-area boundary, not
     one area's interior.
   - Create `decisions/_shared/INDEX.md` and `domain/_shared/`.
3. Run `scripts/invariants.sh`. Resolve drift.
4. Add a `conventions-adopted` ADR in `decisions/_shared/` if the
   skills adopted are now repo-wide.

The existing area's content is unchanged. No renames inside it.

---

## What single-area mode does NOT change

These rules apply regardless of single- or multi-area:

- The four axes (idea, domain, decisions, specs) exist and are populated.
- Per-axis state machines apply.
- Spec-deltas are mandatory; the `<area>/` prefix is the same in single-area.
- The Update Manifest is required.
- `scripts/invariants.sh` runs and must pass.
- `conventions-adopted` ADR is still required, just lives in `decisions/<area>/`.

Skipping any of these because the repo is small is the most common
failure mode for solo or early-stage projects. The point of traceflow
is that the discipline scales with the project; it does not arrive
late.

---

## Minimum-viable seed commit

A new repo adopting traceflow can be seeded with this commit:

```
.traceflow/
├── STATUS.md                              # one area row, state: setup
├── preamble.md                            # reading map (copy from skill assets)
├── domain/
│   ├── MAP.md                             # one area row, deps: (none)
│   ├── glossary.md                        # empty seed
│   └── <area>/
│       └── README.md                      # one-paragraph area purpose
├── decisions/
│   └── <area>/
│       ├── INDEX.md                       # header row only
│       └── ADR-001-conventions-adopted.md # pins traceflow@0.1.0
├── ideas/
│   └── <area>/                            # empty
└── specs/
    └── <area>/
        ├── STATUS.md                      # header row only
        └── MAP.md                         # header row only
```

The first real artifact is usually an idea or the first spec. The
`ADR-001-conventions-adopted.md` ratifies the project's adoption of
traceflow and any companion skills.
