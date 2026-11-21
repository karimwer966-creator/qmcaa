# Testing

## Source harness

`Tests/Harness/QSMC_Selftest.mqh` contains deterministic checks for configuration boundaries, lifecycle transitions, fingerprint/identity behavior, timeframe ordering, snapshot readiness, closed-bar structure, a constructed three-candle FVG retest, session evaluation, ambiguous ICT raids, tick-volume proxy labeling, profile construction, primary/secondary funnel registration, HTF/liquidity rejection reasons, risk guards, persisted UID dedupe, safety recovery latch, and preset parsing. The harness is source only; it has not been executed in this environment.

## Strategy Tester scenarios to run

1. Invalid timeframe ordering, invalid server-session hour/minute, and numeric boundaries reject initialization.
2. Short/missing history, invalid quote, symbol deselection and stale rates keep data not-ready and emit a reason.
3. Mutate bar zero and verify analysis is unchanged with closed-only mode enabled.
4. Verify fixture bars produce expected fractal points, EMA bias, zone geometry and SVP levels.
5. Configure broker-server session windows; verify Asia/London/New York boundaries, current/previous ranges, daylight-saving adjustments and raid direction.
6. Construct Sweep → MSS → post-MSS FVG retest and BOS/CHoCH → OB-retouch fixtures. Missing stages remain WAIT and never create a candidate; historical swings must already be confirmed at the break bar.
7. Verify both models are rejected with explicit reasons when HTF Bias is neutral/opposed, the session is inactive, or the direction-aligned liquidity sweep is missing; an opposing two-sided sweep is AMBIGUOUS.
8. Confirm optional tick-volume proxy and Volume Profile change only confluence points when ready; unavailable data is omitted and identified. Elliott pivot hint is limited to ±3 points and cannot create a candidate.
9. Confirm per-bar audit CSV has both model records and an arbiter record, including rejection/wait reasons; write failure is diagnostic-only. Check OB/FVG/session/Elliott chart objects are namespaced and removed on deinit.
10. Confirm top-N zone filtering is nearby, score-ranked and aligned with bias; chart object count remains bounded.
10. Test risk sizing around min/step/max volume, invalid tick value, stop side, stops level, spread, per-trade risk, daily realized/floating loss, drawdown peak, margin, position/exposure limits, daily submission count and cooldown.
11. Trigger incident latch and restart with the same identity; verify no automatic resume. Test duplicate intent UID and confirm DEMO remains in-memory only.
12. Confirm REAL configuration fails and `CQSMCRealAdapter::Submit` rejects without a broker request.
13. Disconnect terminal, stale quotes, then restore; health must fail closed and SAFE_MODE must not automatically resume.

## Historical and out-of-sample workflow

1. In MT5 Strategy Tester, run both models over a chronologically earlier in-sample interval and export the generated `QSMC/opportunities_<magic>.csv` from the tester agent's `MQL5/Files` directory.
2. Freeze model/configuration choices before the later interval. Run the later, untouched dates separately; do not tune against those results. Keep symbol, timeframe, session clock/DST inputs, spread assumptions and test horizon fixed and record them alongside the export.
3. Run `python3 Tests/oos_evaluate.py opportunities_<magic>.csv --test-start YYYY-MM-DD --horizon 12 --cost-r 0.05`. The script uses future closed-bar close-to-close movement divided by entry ATR, avoids overlapping accepted events per model, and refuses training events whose horizon crosses the split. Set friction from the tested symbol and assumptions; the supplied cost is only an example.
4. This is a descriptive forward-return study, not a realistic fill, stop/target, spread/slippage or portfolio simulator. Review sample sizes, drawdown, parameter sensitivity and multiple market regimes before drawing conclusions. No historical dataset or MT5 terminal is available in this workspace, so no in-sample/OOS performance result is claimed.

## Validation available here

Run `python3 Tests/static_check.py` for include resolution, guards and delimiter sanity; `python3 -m py_compile Tests/oos_evaluate.py` checks the report tool's Python syntax. No MetaEditor/MT5 is installed in the sandbox, so compilation, MQL self-tests and Strategy Tester scenarios remain **unverified**. Do not infer pass/fail outcomes from the presence of test source.
