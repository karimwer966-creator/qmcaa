# QSMC — modular MQL5 analysis EA

QSMC is a layered MetaTrader 5 Expert Advisor reconstruction. The delivered EA builds closed-bar market snapshots, computes transparent analysis evidence, records a deterministic no-trade-or-direction decision, and presents lifecycle/data/safety status.

> **Safety status:** the default mode is `ANALYSIS`. The `REAL` configuration is rejected because `QSMC_ALLOW_REAL` is hard-set to `0`, and `CQSMCRealAdapter` has no broker submission implementation. The DEMO adapter is in-memory only; it sends no terminal orders. This repository is not a live-trading product.

## Capabilities currently implemented

- EA lifecycle entry points, millisecond timer setup/cleanup, duplicate-init guard, strict lifecycle transitions, and `RUNNING` operational gate.
- Validated configuration, preset application before opt-in risk overrides, stable input fingerprint, instance magic identity, and persisted collision check.
- Server-time clock, bounded logger/diagnostics, key-value state persistence, environment/quote health checks, and an incident/kill-switch latch.
- Closed-bar three-timeframe snapshots, history/quote validation, readiness gates, and stale-data handling.
- Transparent heuristic analysis: fractal swings, EMA/HTF/swing bias, supply-demand and clustered S/R zones, zone scoring, simple candle reactions, displacement-confirmed breaks, liquidity levels/sweeps, and an approximate bar-volume profile (POC/VAH/VAL/HVN/LVN).
- Auditable candidate funnel and deterministic arbiter. Missing data is not a signal; opposing equal-score candidates reject; all rejections carry codes and reasons.
- Central execution preflight, risk sizing/account checks, UID duplicate journal, in-memory simulated adapter, read-only position reconciliation, and a hard-disabled real adapter.
- State-only dashboard and namespaced chart-layer rendering.
- A MetaTrader self-test harness and a phase-1 lifecycle script.

The listed analysis thresholds are explicit modeling heuristics, not verified proprietary QSMC rules. See [Docs/ARCHITECTURE.md](Docs/ARCHITECTURE.md) and [Docs/MODULE_CONTRACTS.md](Docs/MODULE_CONTRACTS.md).

## Installation

1. Copy `Include/QSMC` into the terminal data folder at `MQL5/Include/QSMC`.
2. Copy `Experts/QSMC/QSMC.mq5` into `MQL5/Experts/QSMC/QSMC.mq5`.
3. Open MetaEditor, compile the EA, and inspect all compiler warnings/errors.
4. Attach to a chart and retain the default `ANALYSIS` mode. Select appropriate execution/HTF/LTF timeframes and allow history to download.
5. Check the chart dashboard and Experts/Journal tabs for readiness and diagnostics.

Detailed path variants and tests: [Docs/INSTALLATION.md](Docs/INSTALLATION.md), [Docs/TESTING.md](Docs/TESTING.md).

## Configuration

Defaults: chart symbol, M15 execution, H4 higher timeframe, M5 lower timeframe, closed candles only, one-second timer, 600 bars and analysis-only mode. Preset values are applied first. `InpOverridePresetRisk=false` means preset risk settings remain active; set it to true to apply the explicit risk fields. See [Docs/CONFIGURATION.md](Docs/CONFIGURATION.md).

## Safety and limits

- Do not set `QSMC_ALLOW_REAL` to `1`. Even doing so would not enable live orders: the real adapter intentionally rejects every request.
- DEMO means in-memory simulation, not broker demo-account execution.
- The analysis-derived geometry is illustrative; it is not an order recommendation.
- Daily loss, peak-equity drawdown, daily submission count/cooldown, margin, per-trade risk and recent duplicate-UID checks are implemented in the risk/preflight contracts but have not been validated on MT5 and are not automatically invoked by the ANALYSIS event path.
- Comprehensive broker lifecycle recovery and partial-fill handling are not implemented.
- No proprietary strategy specification was provided; derived rules are named heuristics and must be replaced/approved before strategic use.

## Verification status

A repository-local static check can verify include resolution, header guards, and delimiter balance. MetaEditor/MT5 are not available in the implementation sandbox, so compilation, terminal self-tests and Strategy Tester scenarios are **unverified**. No performance or trading results are claimed.
