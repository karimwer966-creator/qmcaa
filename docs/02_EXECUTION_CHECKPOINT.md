# Checkpoint 3 — gated execution foundation

Date: 2026-11-25. Scope approved: hedging accounts only; broker submission must remain blocked until risk, news and persistence hardening is complete. This is an implementation checkpoint, **not a trading release or compile certificate**.

## Changes

- Added `Core/QSMC_ExecutionGates.mqh`: independent build, account and exact acknowledgement policy; rejects netting/exchange margin modes. `QSMC_ENABLE_REAL_TRADING` and `QSMC_ALLOW_LIVE_ACCOUNT` both remain commented out. A separate literal-false `ReleaseApproved()` interlock cannot be opened with inputs or build flags.
- Config validation, root start, safety permissions, central preflight and broker executor use the same policy/interlock. Legacy `QSMC_ALLOW_REAL` is retained solely for source compatibility; setting it grants no authority.
- Expanded the execution result without removing existing fields/call signatures: broker retcode, request/order/deal IDs, submitted/uncertain flags, actual fill information and distinct full/partial/pending/rejected/uncertain outcomes.
- Added contextful `SubmitChecked`. Context-free REAL submission always refuses. Broker executor starts disarmed, refuses arming under the release interlock, verifies identity/preflight and a clean persisted pending-intent marker before its compile-gated request path. Existing manager deliberately still returns `REAL_BLOCKED`; no application broker submission route was enabled.
- Added runtime fill-mode selection, finite tick-grid and fresh-side SL/TP checks. The dormant request builder reads runtime symbol metadata, uses a fresh quote with a five-second age ceiling, enforces deviation/spread limits, and never moves/widens SL or rounds lots upward. OrderCheck/OrderSend are confined to this executor and excluded without Gate 1.
- No automatic retries. An attempted broker submission disarms the executor. Timeout, connection loss and unknown results remain uncertain; PLACED is not reported as filled. A partial fill is distinct from a full fill, with no residual-volume resubmission.
- Order manager checks store identity before mutations, checks every submission-guard mutation and its save, refuses replacement of an unresolved broker intent, and requests an emergency latch on guard failure or uncertain/pending outcome. The pending marker is deliberately never automatically cleared. Journal records now include magic and emit a terminal log line.
- Added read-only `CQSMCTradeReconciler::Capture`: server-day deal enumeration scoped by magic/symbol; unique entry-order counts versus partial entry deals; exit/SL/TP deal observations; net profit including swap/commission/fees; owned-position SL observations. Rejects unavailable/invalid data, unsupported reversal deals and visibly changing collection sizes. It never submits, modifies, clears pending intents or writes risk counters.
- Updated the static checker to reject trade APIs outside the single compile-gated executor and reject active shipped trading defines. Added host-side boundary regression tests and terminal self-test cases for gates, fill modes, retcodes, grid/stops and unconfigured arming.

## Verification performed

- `python3 -m unittest discover -s Tests -p 'test_execution_boundary.py' -v`: **5 host tests passed**. Includes four C-preprocessor combinations (neither define, live-only, trading-only, both). Neither/no-trading builds contain zero OrderSend/OrderCheck call sites; all four retain the closed release interlock.
- `python3 Tests/static_check.py`: **PASS**, 82 MQL source files, includes/guards/delimiters and API-boundary shape checks.
- `git diff --check`: **PASS**.
- Confirmed actual `SQSMCConfig.real_ack`, `deviation_points` and StateStore `Magic()`, `IsReady()`, `IsDirty()` APIs against source.
- No MetaEditor executable is available. **MQL errors/warnings: UNKNOWN**. C preprocessing and Python assertions do not compile MQL or establish broker safety. New terminal self-tests have not run. No broker API, demo order, backtest or forward test was executed.

## Important limitations / deferred work

1. This is intentionally an unreachable broker foundation. Do not enable either define, change the release interlock or attempt deployment for trading.
2. Phase 4 must complete sizing, margin/free-margin buffer, freeze-level handling for any future modification path, risk counters/latches and other fail-closed entry protections. Existing preflight/risk defects in the audit are not declared fixed.
3. Phase 5 must implement and validate news, rollover, Friday/session and gold-specific safeguards. No absent safeguard is treated as a broker-entry pass: release remains blocked.
4. Phase 6 must fix stable ownership, schema/scoping, atomic replacement/durability, boolean restore, history-based risk reconstruction and pending lifecycle recovery. Checking `Save()` is not a durability guarantee with the current StateStore.
5. Reconciler output is an observation only, not authoritative risk accounting. Closed trades cannot be equated with exit deals; entry orders can have partial fills. Day-boundary entry-order observations are not full lifetime trade counts. Broker collections are not atomically captured; equal-size concurrent changes can evade the count-change check. No event-driven OnTradeTransaction integration or authoritative reconciliation/guard-clearance policy is implemented yet. This must be resolved and tested before release.
6. A pending marker remains even after a definite broker rejection or pre-send request failure. Conservative operator/recovery review is required; no automatic cleanup is supplied. A 16-UID recent ring alone is not durable lifetime idempotency.
7. Existing analytical rules were not changed. Earlier unrelated EA/orchestrator/test-document edits were preserved. `docs/01_AUDIT_REPORT.md` is the historical Phase 2 baseline; its zero-broker-API observation is no longer a description of the new gated source.
8. No audit finding is certified closed without compiler and terminal evidence. No zero-warning, production-ready or profitability claim is made.

## Terminal validation required

Install the tree under the corresponding terminal MQL5 folders. Compile the EA and `Scripts/QSMC_Selftest.mq5` with both defines absent; provide logs and self-test output. Example Windows command (substitute the actual terminal data directory):

```text
metaeditor64.exe /compile:"<path>\MQL5\Experts\QSMC\QSMC.mq5" /log:"<path>\compile.log"
```

The compile-only flag matrix must also be validated in an isolated terminal build without attaching the EA or sending orders. Verify ANALYSIS default, DEMO remains paper-only, REAL is refused, and netting is refused by policy. Supply errors/warnings verbatim before any release decision.

## Approval boundary

Stopped at Checkpoint 3. Await approval before Phase 4 risk/safety work. Approval to continue is **not** approval to arm or release broker execution.
