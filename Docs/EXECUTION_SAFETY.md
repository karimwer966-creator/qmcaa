# Execution and Safety

## Default behavior

- `SQSMCConfig::SetDefaults()` selects `QSMC_MODE_ANALYSIS`.
- `QSMC_ALLOW_REAL` is `0`. `SQSMCConfig::Validate()` rejects REAL mode.
- `CQSMCRealAdapter` does not call `OrderSend` or `CTrade`; every request is rejected as execution-disabled, irrespective of an input acknowledgement.
- `QSMC_MODE_DEMO` routes to an in-memory adapter, not a broker demo account.
- No automatic transition from SAFE_MODE to RUNNING is provided.

## Controls implemented

- Terminal, account, symbol availability, quote freshness, spread and permissions are probed fail-closed by HealthMonitor.
- IncidentSafety persists a kill state in the per-magic StateStore and terminal GlobalVariable; the persisted flag blocks startup operations until operator acknowledgement/restart.
- Central preflight checks intent direction/ownership symbol/magic/UID, positive values, confidence, volume bounds/step, stop side/distance, spread and configured account limits, then calls SafetyController.
- RiskManager computes conservative approximate volume from balance, risk percentage, tick value/tick size and stop distance; captures magic-owned positions; derives server-day deal P/L plus floating P/L; persists peak equity; and rejects missing metadata or configured daily-loss/drawdown/position/exposure/margin-limit failures.
- Preflight checks estimated stop risk against the configured per-trade cap and uses `OrderCalcMargin` against current free margin.
- OrderManager enforces daily submission-count and cooldown limits, then persists a bounded 16-UID history before adapter invocation so recent uncertain outcomes are not blindly replayed. StateStore failures block submission.
- PositionManager reads positions owned by the configured magic and symbol only; it does not modify/close them.

## Not yet sufficient for live use

The current work must not be considered complete live-trading risk management. The risk and order-manager contracts implement daily realized-plus-floating loss, drawdown, exposure, daily count and cooldown checks, but they are not called by the normal ANALYSIS event path and have not been platform-verified. Restart reconciliation is read-only and uncertain lifecycle state is not rebuilt; broker filling modes, partial fills, retcodes, retries, netting/hedging edge cases and position lifecycle are not exercised. No actual execution adapter exists. `QSMC_ALLOW_REAL` must remain zero until these gaps are closed, tested in MT5/Strategy Tester and explicitly approved.

## Emergency stop/recovery

`CQSMCOrchestrator::EmergencyStop(reason)` latches the stop and moves RUNNING to SAFE_MODE. This callable is available to a future operator control but no dashboard button is exposed. Restart with a persisted kill/uncertain latch stays blocked; operator acknowledgement alone does not resume the root. Deinitialization does not clear the latch.
