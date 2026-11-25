# Known limitations and release blockers

**Not approved for broker trading.** Documentation and source hardening are not a
completed production release. All 38 baseline findings remain **not certified
closed**; source remediation and host evidence do not substitute for MT5 validation.

## Platform evidence missing

MQL errors/warnings UNKNOWN. Main EA, safety/broad self-tests, enrollment script and
preset imports have not been compiled/run here. Calendar APIs, CSV parsing,
Unicode/EOF semantics, file locks/flush/move, GVs, crashes/restarts and broker
history/lifecycle remain unverified. The 23 terminal scenarios are all NOT_RUN.
No market dataset, backtest, OOS performance result, forward-demo or broker order
was produced. Sixteen host tests are not a zero-warning compiler certificate.

## Deliberately incomplete execution/recovery

- Main App has no normal intent-construction/submission route. REAL stays blocked
  by manager and independent false release interlock. Do not remove barriers to
  test production orders; a separately approved isolated test is required.
- No complete transaction-driven pending resolver, automatic guard clearance,
  all-time intent archive, partial-residual retry or protective close/modify system.
  Filled/partial/pending retcodes and latest metadata do not prove final protection.
- Netting/exchange accounts unsupported. Hedging support is source policy, not a
  certified broker implementation. Final check/send and observations are not atomic.
- Risk loss is an estimate: gaps, fees, slippage beyond the checked bound and
  execution races can exceed it. No guaranteed-loss or profitability claim.
- Loss streak/closed/SL/TP counts are reconstructed reports, not a newly approved
  consecutive-loss-limit policy. Paper consumed submissions differ from broker deals.

## Persistence and operational restrictions

- General legacy migration, poisoned-state repair, review release, verified history
  compaction/anchors and pending clearance are unsupported. Never remove artifacts,
  reset latches or change magic to make a blocked instance start.
- Missing reviewed account/day baselines block. Automatic day rollover is absent;
  enrollment requires a reviewed clean flat/no-orders/no-deals-today account/day
  and leaves latches intact. Days with activity may need separate recovery work.
- Common-file writer/short account claims can contend; failures veto/latch rather
  than reading unlocked. Read-only diagnostics may refuse an in-progress staging
  artifact. OS handle sharing semantics need two-terminal tests.
- Checksummed alternating snapshots are not crypto authentication, filesystem
  fsync or a cross-file/GV transaction. No external monotonic rollback anchor;
  deletion of a complete newest generation cannot always be detected. No silent
  corrupt-slot fallback is supplied, but manual whole-file removal is not safe.
- Legacy scans do not see every private directory, machine or already-removed
  file. Search errors/platform behavior need validation; successful startup is not
  exhaustive proof of migration provenance. Old non-authoritative log naming remains.
- Replay is bounded to 100,000 deals / 256 position lifecycles. Overflow blocks;
  no verified archival/compaction. Missing entry/volume mismatches are detected,
  but entirely omitted completed lifecycles or equal-size changes may not be.
- Post-enrollment nontrade account postings conservatively require review,
  including some broker commission postings. No automatic cash-flow adjustment.
  Sampled peaks miss inter-sample/downtime highs; provider history success is not
  proof of completeness. Reconciliation is not an atomic broker snapshot.

## News, clock, broker configuration

Calendar empty-success/omissions and rescheduling within a cache interval cannot
be independently disproved. English keywords may miss localized lower-importance
events; broad substrings may over-block. No unscheduled-news protection. Tentative
relevant times conservatively block the intersecting query day.

CSV coverage is the provider's assertion, not proven historical completeness.
Synthetic January 2001 fixture is artificial. Each tester agent needs its own
provisioned dataset. No implicit UTC conversion, inactive-news bypass or automatic
historical DST inference. Sessions use manually reviewed broker-server windows.

Synchronous calendar/file/history calls can delay the EA thread, even though entry
vetoes do not logically gate risk monitoring. Point caps are not universal gold
price-unit limits; exact symbol/suffix and runtime metadata must be reviewed.

## Analytical correctness is still open

Phases 3–8 did not alter analytical rules or validate their profitability. In
particular, the baseline audit identifies:

- QSMC-019 inverted FVG labels; QSMC-020 ATR true-range indexing.
- QSMC-021 incompatible default ICT index constraints; QSMC-022 historical causality.
- QSMC-023 SVP value-area termination; QSMC-026 EMA seed double-counting.
- QSMC-027 midnight analytical range ownership; QSMC-034 zone geometry/mitigation.
- QSMC-035 sweep timing; QSMC-036 public analytical validity envelopes.

Other data validation, lifecycle/UI/logging/performance findings also need platform
and semantic review. Analytical candidates, overlays, RUNNING or passing historical
fixtures are not validated entry recommendations. Volume proxies are not true
order flow; scores are not calibrated probabilities; Elliott labels are heuristic.

## Documentation portability

Docs/ and docs/ casing remains unresolved; no directory rename was performed.
Historical inventory/audit/checkpoint reports intentionally retain prior-stage
source observations/line references. Use current README/safety/deployment docs for
current behavior, not old statements that broker APIs or news modules were absent.
