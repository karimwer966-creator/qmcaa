# Checkpoint 4 — risk and safety hardening

Date: 2026-11-25. Phase 4 approved by user. Margin-policy clarification: user selected the conservative reserve, requiring free margin **after estimated entry margin** of at least `max(10% of equity, planned stop risk)`.

**Status: implementation checkpoint, not a broker release.** Both trading defines remain commented out, ANALYSIS remains the default, REAL manager remains blocked, and `ReleaseApproved()` remains literal false. No order was submitted.

## Implementation

### Equity-based strict sizing — QSMC-010/011

- New `Execution/QSMC_RiskMath.mqh` provides finite-value, equity-budget, monotonic-peak, volume-flooring and margin-reserve arithmetic.
- `SizeLots` uses current **equity**, not balance: budget = equity × riskPercent / 100. Requested risk must not exceed the configured or existing hard cap.
- Stop loss per lot uses `SYMBOL_TRADE_TICK_VALUE_LOSS` and runtime tick size. If unavailable/invalid, `OrderCalcProfit` estimates stop loss using runtime minimum volume, then scales to one lot. Failed or nonnegative fallback profit rejects sizing. No generic/profit-side tick-value substitution.
- Lots are floored by actual runtime step after risk, symbol maximum and configured exposure caps; no fixed decimal assumptions or minimum-volume uplift. A minimum lot exceeding budget is rejected. Conservative floating-point under-allocation/rejection is possible; no epsilon authorizes more risk.
- `riskMoney` output now reports **actual sized stop risk**, not the unused budget. Existing method signature is preserved; there were no production callers in the current tree. Preflight never trusts a caller-supplied riskAmount as authority.
- Commissions, slippage beyond the checked bound and gaps can make realized loss exceed the stop-distance estimate. This is not a guaranteed-loss cap.

### Fresh preflight — QSMC-011/012

- Explicit finite/positive validation of intent values, account snapshot and runtime contract metadata. Account capture must be no more than five server seconds old by TimeCurrent. Fresh quote timestamp uses TimeTradeServer and must be neither future nor more than five seconds old.
- Fresh tick, point/tick size, min/max/step, stops/freeze levels and symbol trade mode are read with checked APIs. Missing/unknown permissions are not allowed. SL/TP must lie on the proper side of both reference and current entry; protective distance uses fresh Bid for BUY, Ask for SELL.
- Price/SL/TP must be tick-aligned; volume must meet bounds and step. No SL, TP, price or volume is silently repaired. Zero deviation is now exact; negative or over-configured deviation rejects.
- A positive spread cap is required, including for paper preflight. Stale snapshot spread/contract values are no longer execution authority.
- Risk is recomputed at the worse of reference/current price plus adverse allowed deviation, and must fit the budget with **no previous one-tick excess-risk allowance**. Equity uses the lower of fresh and captured values. Existing exposure plus intended volume must fit the cap.
- `OrderCalcMargin` must succeed with finite nonnegative margin. Free margin uses the lower of fresh and captured values and must retain the approved reserve. Zero required margin is permitted only if the calculation succeeds and reserve is still met.
- Freeze metadata is read/validated. Freeze restrictions apply to modifications/deletions, not this new-market-entry path. No close/modify API is supplied; no claim of safe trailing/breakeven/position modification is made.

### Account capture and peak monitoring — QSMC-002/014

- Store readiness and magic identity are verified before risk persistence. First peak observation is explicitly saved; later peaks never decrease. Invalid persisted numeric peaks block; dirty state retries saving before capture can pass.
- Account data, positions and deal reads fail closed on unavailable/invalid fields rather than skipping unreadable positions/deals.
- Capture uses Phase 3 read-only hedging reconciliation, scoped by **magic AND configured symbol**; includes realized profit, commission, swap and fees plus current owned floating profit/swap. Missing SL on an owned position blocks capture. Netting/exchange margin modes remain unsupported.
- Timer invokes risk monitoring while operational in DEMO/REAL capability modes, even without an intent. A daily-loss/drawdown breach latches safety and moves RUNNING to SAFE_MODE. Capture uncertainty also latches. Capacity/free-margin limits remain entry vetoes rather than permanent incidents.
- ANALYSIS/OFF do not initialize/update risk peaks through this monitor. Monitoring is sampled, not continuous, and stops when non-operational; it cannot recover equity highs between samples or during downtime.
- Existing daily-loss definition is retained: scoped server-day realized P/L plus current floating, divided by current account balance. It is **not** a day-start equity drawdown or full mark-to-market daily attribution. Daily baselines, cash-flow adjustment, account-scoped peaks independent of unstable magic and history reconstruction remain Phase 6/release blockers. Daily/drawdown latches do not automatically clear at midnight.

### Safety latch correctness — QSMC-006/007/017/018

- Fixed misuse of StateStore.GetBool: its return value is the stored bool; the second argument is only the fallback. Restore resets reused incident state and blocks malformed safety boolean flags/unready storage.
- Latch engages in memory first, preserves previous uncertainty and checks **every** write independently, including kill-switch persistence. Failed persistence returns false and leaves memory latched/uncertain; no success claim from a failed emergency write.
- SetKillSwitch checks file mutation/save and terminal GlobalVariableSet result, calls GlobalVariablesFlush, and attempts both stores even if one fails. Failed release attempts restore an active brake best-effort. Flush has no success return and is not a durability guarantee.
- Explicit acknowledgement clears memory only after all required operations report success; failed acknowledgement re-latches. An unresolved broker pending marker forbids acknowledgement. An acknowledgement does not start the root or bypass subsequent risk checks.
- Safety controller resets readiness on Init, propagates latch persistence results and applies mode/release/kill checks even through its cached-health accessor. Any nonzero global kill value blocks, not just values above 0.5. Uncertain broker outcomes now explicitly persist the uncertainty flag.
- Health probe uses a coherent tick, rejects future/invalid quote data, and evaluates the actual spread without rounding down or substituting a reported spread for an invalid tick.
- Order manager rejects negative/future persisted cooldown/count state. Schema and lexical parsing validation still belong to Phase 6.

## Verification performed

Command:

```text
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Tests -p 'test_*.py' -v
```

**7 host tests passed**:

- 5 existing boundary/structure checks, including all four trading/live preprocessor flag combinations.
- Actual RiskMath header executed under C++ math shims: equity budgets, 10,000 → 11,000 → 9,000 peak sequence, strict caps, min/max/nondecimal steps, margin boundary/nonfinite cases and **20,000 seeded volume-flooring cases**.
- Actual IncidentSafety header executed under C++ with a fake store/clock: stored-bool restoration, independent latch, uncertainty, operator refusal, pending-intent acknowledgement veto, injected mutation failure, failed release remaining latched, successful explicit release, malformed flag and unready-store blocking.

`Tests/static_check.py`: **PASS, 83 MQL sources**. `git diff --check`: **PASS**. C++ shim compilation used `-Wall -Wextra -Werror`; that statement applies only to the two host shim tests, **not MQL**.

Extended MQL self-test source with risk/margin boundaries, fresh-store latch reload, pending-intent acknowledgement veto and malformed safety flags. These terminal self-tests were **not executed**. `Docs/TESTING.md` now includes the host command, interpretation and required terminal regressions.

## Unverified / limitations

- MetaEditor and Wine are not available here. **MQL errors/warnings UNKNOWN.** No terminal self-tests, broker-contract tests, real file/GV fault injection, restart tests, demo execution or backtests were run. Host C++ shims do not establish MQL compatibility or persistence correctness.
- StateStore Save/Load atomicity, unchecked file writes, schema validation, stable ownership/exclusive claims, reliable scope, bool validation outside incident flags and authoritative pending lifecycle remain unresolved Phase 6 work. This phase changes the emergency-write call contract, not the storage format or full persistence implementation.
- File/GV writes are not a cross-store transaction. Best-effort re-latching cannot guarantee crash safety under filesystem or terminal failure. No release is permitted on this basis.
- Capture is not atomic across account/position/deal observations. Count-change checks cannot detect all equal-size concurrent changes. Future broker submission must close the final-check/send race as far as the platform permits, reconcile transactions and validate actual filled volume/price/protection before release.
- Read-only reconciling has a bounded entry-order observation buffer; overflow or history failure blocks capture rather than dropping data. Daily trades, realized loss streaks, SL/TP trade counts and day baseline recovery are not yet authoritative persistent risk counters.
- News, rollover, Friday/session and gold-specific filters remain Phase 5. No strategy/FVG/ICT/SVP/ATR analytical corrections were made in this phase.
- Historical audit findings remain unverified, not certified closed. Existing unrelated changes and Phase 3 safeguards were preserved.

## Checkpoint

**Stopped at Checkpoint 4. Await approval for Phase 5 (gold-specific entry safeguards).** Approval to continue does not approve arming, changing either define, or opening the release interlock.

Before any release, provide MetaEditor EA/self-test compile logs and terminal regression output. Example:

```text
metaeditor64.exe /compile:"<path>\MQL5\Experts\QSMC\QSMC.mq5" /log:"<path>\compile.log"
```
