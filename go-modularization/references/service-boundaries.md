# Service boundaries: what two services must agree on

Read this file when designing or reviewing **anything two services must agree
on** — a datastore, a value set, an enum, a state machine, a failure
taxonomy, or a contract version.

This file is a **scope extension**: the rest of the skill places files
*inside* one service; this file governs the seams *between* services
(ADR-32). It adds boundary rules only — folder placement for the artifacts
named here is unchanged and stays where the existing references put it:
contract tiers in [`shared-code.md`](shared-code.md), translation/ACL and
enforcement-locus rules in [`placement-rules.md`](placement-rules.md).

`scripts/arch-checks.sh` supports (not enforces) this file with report-only
`boundary-review` warnings — heuristics for rules 1 and 2 (duplicate
datastore-identifier constants across services; identically-suffixed env-tag
names under different service prefixes).

## 1. Durable-state privacy

A service's datastores (tables, collections, buckets) are **private**. Peers
get its data through its API/contract, never by reaching into its collections
or tables. Another service reading them is a *contract*: declare it (consumed
contract id + pinned version), implement it against a schema artifact, and
never re-declare table/collection identifiers as string literals in the
reader. Indirection through a logical third context does not exempt the
physical reading process.

Reaching in anyway — or re-declaring the owner's datastore identifiers on the
reader's side — is the **peer-datastore reach-in** anti-pattern (SKILL.md).

## 2. Agreed values are contract (the agreed-values ladder)

Any value two services must both hold to behave correctly (lease windows,
heartbeat intervals, timeouts that bound each other) is contract, whatever
file it lives in. Preference ladder for keeping the two sides agreed:

1. Transmit in-band at session establishment; the receiver **adopts** the
   transmitted value.
2. Transmit and **fail** on mismatch.
3. Transmit and warn — a smell.
4. Silent config mirroring with no runtime comparison — **forbidden** when
   the value feeds a correctness decision (authority windows, idempotency,
   lease reclaim). That is the **silent config mirror** anti-pattern
   (SKILL.md).

Where an agreed value set lives in the tree: prefer contract-tier
constants/enums over per-service mirrors, and pick the tier by the existing
contract-scope ladder (adapter-local → service-scoped → root) — read
"Contract scope — three tiers" in [`shared-code.md`](shared-code.md); this
file does not restate it. Two services agreeing on a value set is precisely
the "second service consumes it" trigger that promotes a contract to root
`internal/contracts/`.

## 3. One enforcement locus per cross-service machine; coupling table for the peer

Each state machine (and each rule two services could both enforce over a
shared datastore) is owned and enforced by exactly **one service** — name
that enforcing service and locus. The non-owner documents only a **coupling
table** — own-state ↔ peer-state, mediated by which messages — recording who
owns what, and never re-declares the peer's transition table or models the
peer's private enum in its `domain/`; if peer state is needed for logs, keep
it a string at the adapter.

Inside the owning service, *where* enforcement lives (domain-enforced vs
datastore-enforced, declaration, conformance oracle) is already settled by
"State machines: one enforcement locus" in
[`placement-rules.md`](placement-rules.md) — this rule adds only the
cross-service half: one owning service, a coupling table for everyone else.

## 4. Enum mirrors need exhaustiveness tests

Re-modeling a closed wire enum as a domain type is correct layering — *if* a
test round-trips the domain set against the generated enum's name map (count
+ values) so a contract bump breaks the lagging mirror's build. If a service
MUST mirror a peer's enum, that exhaustiveness test binds the mirror to the
source so additions fail loudly. A mirror the service's own code bypasses
(emitting the raw wire constant) signals the mirror is dead or the layering
is broken.

A hand-copied mirror with no exhaustiveness binding is the **peer-enum
modeling** anti-pattern (SKILL.md); rule 3 forbids mirroring a peer's
*private* (non-contract) enum outright.

## 5. Dual enforcement requires a reconciliation story

When both sides of a stream track the same numeric invariant (credits, slots,
quotas), name the authoritative side and design the disagreement path (reject
verdict + compensating update) up front, so a reconciliation process detects
divergence. Two ledgers with no reconciliation protocol is an incident
template.

## 6. Failure taxonomies classify by fault locus

Cross-boundary failure reasons are classified by locus (work-intrinsic /
infrastructure / peer-protocol), not by the executor's internal stage names;
stage-named wire reasons make internal refactors into contract bumps. The
classification lives with the service that owns the fault domain; peers
translate into their own vocabulary at their adapters (translation/ACL rules
in [`placement-rules.md`](placement-rules.md)). Where stage detail is kept
for diagnostics, pair it with a locus class owned by the coordinator.

## 7. One version authority

Exactly one service owns a contract's version lifecycle. A contract has one
version identity mapped to something runtime-observable (wire field,
negotiated capability, or an explicit "additive-only within envelope N"
policy written beside the envelope constant). A documented SemVer and a wire
version with no written mapping is a defect.
