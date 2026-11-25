# Execution safety — unreleased

## Non-negotiable release state

Default mode is ANALYSIS. DEMO is an in-memory simulated adapter, not a broker demo
submission. The main application does not create/submit normal intents. The manager
resolves REAL to REAL_BLOCKED; configuration/root/safety/preflight/executor also
check independent policy. `QSMC_ENABLE_REAL_TRADING` and `QSMC_ALLOW_LIVE_ACCOUNT`
remain commented out. `ReleaseApproved()` returns literal false. Exact runtime
acknowledgement is necessary for policy eligibility, never sufficient to trade.
`QSMC_ALLOW_REAL` is deprecated compatibility data, not execution authority.

The dormant executor contains compile-gated OrderCheck/OrderSend. Context-free REAL
Submit always refuses. Arming cannot succeed with the closed interlock. No retry,
residual partial-fill submission or pending-guard clearance is supplied. Retcodes
distinguish full, partial, pending, rejected and uncertain outcomes; broker acceptance
is not proof of fill, protection or final lifecycle state.

**Do not enable defines, edit the interlock or attach a locally enabled copy.** A
compile-only flag matrix in an isolated copy is not permission for execution.

## Source-level entry checks

- Root RUNNING, exact symbol/magic/UID, writable claimed store and valid intent.
- Finite positive equity/metadata and strict risk budget: equity × risk% / 100.
  Loss per lot uses loss-side tick value and tick size, with OrderCalcProfit
  fallback at runtime minimum volume. Lots floor to runtime step after caps;
  minimum above budget rejects. No upward rounding or one-tick excess allowance.
- Fresh Bid/Ask/timestamps, runtime symbol permission, volume bounds/step,
  tick-aligned price/SL/TP, correct sides and protective stops distances.
- Positive spread cap and exact configured deviation. Risk includes the checked
  adverse deviation and the lower of fresh/captured equity.
- OrderCalcMargin success and remaining free margin >= max(10% equity, stop risk).
  Freeze metadata is read; no close/modify path is implemented or certified.
- Reviewed account peak and current owner day baseline, scoped exposure/positions,
  daily loss/drawdown, submission limit and cooldown with replayed observations.
- Current server-time session union; rollover [23:45,01:15), weekends, Friday at
  or after configurable 20:00 default. No automatic DST shift or forced close.
- USD HIGH or configured name-keyword blackout, inclusive ±30 minutes. Cache age
  <15 minutes and full window coverage required. Missing/stale/error data blocks.
  Relevant tentative/all-day calendar times conservatively block the queried day.

Tester news requires an explicit covering server-time CSV. There is no inactive
filter bypass. See [CSV schema and limitations](../docs/04_GOLD_FILTERS_CHECKPOINT.md).
English keywords may miss localized lower-importance names; provider empty-success
or omissions cannot independently be disproved. Unscheduled news/gaps remain risk.

Preflight primes potentially blocking news before fresh financial checks, repeats
entry checks and rejects aged snapshots. The dormant broker boundary rechecks
preflight after OrderCheck. Checks and send are not atomic; platform delays and
market changes remain release-validation concerns.

## Persistence, uncertainty and recovery

Full raw account/server/symbol/explicit-magic scope is validated, not inferred solely
from a filename hash. Operational writer claims are exclusive common-file handles.
Schema-2 snapshots alternate sealed generations. Short write/flush/move/verification
failure poisons the store; staging and prior slots remain. Either corrupt slot or
unresolved staging blocks load; there is no destructive in-place fallback.

These mechanisms are untested on MT5 and not an fsync/power-loss guarantee. No
cross-file/GV atomic transaction or external monotonic rollback anchor exists.
Terminal GVs are a local secondary brake, not the cross-terminal ownership lock.

Pending UID restores an uncertain latch and survives day/ring/replay/restart.
Ordinary acknowledgement refuses pending state. Latest broker response metadata
can be persisted but never automatically resolves uncertainty. No general migration,
repair, pending clearance or automatic next-day baseline reset is implemented.

Account-wide peak has no automatic cash-flow adjustment. Replay refuses nontrade
post-enrollment account postings, malformed/missing entries, unsupported reversal,
volume mismatch and bounded overflow. A review marker is sticky. History success
cannot prove all completed historical lifecycles were supplied by the broker.

## Emergency stop

EmergencyStop engages the in-memory latch before persistence and returns whether
required persistence operations reported success. Failure leaves memory blocked;
best-effort file/GV braking is not guaranteed durable under platform failure.
Acknowledgement does not start the root. There is no dashboard release button or
one-click reset input. Restart does not clear latches.

Entry-only news/time vetoes do not invoke EmergencyStop or gate risk/reconciliation.
Synchronous calendar/file/history calls can still delay this EA's event thread.
No protective position management exists; preserving monitoring is not a promise
that positions will be automatically closed or their SL adjusted.

## Evidence boundary

16 host tests/94-source static checks passed at Phase 7. MQL errors/warnings UNKNOWN;
terminal safety checks, broker lifecycle, storage/crash, news/CSV, restart and forward
validation NOT RUN. See [terminal plan](../Tests/StrategyTester/README.md) and
[known limitations](KNOWN_LIMITATIONS.md). No live-safety or profitability claim.
