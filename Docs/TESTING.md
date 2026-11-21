# Testing

## Source harness

`Tests/Harness/QSMC_Selftest.mqh` contains deterministic checks for state transitions, non-operational SAFE_MODE, identical-config fingerprint stability, equal opposing candidate rejection, missing candidate no-trade, and preset parsing. Include it in `Scripts/QSMC_Selftest.mq5` and execute from MT5 to observe actual terminal results. The harness is source only; it has not been executed in this environment.

## Strategy Tester scenarios to run

1. Every invalid timeframe ordering and numeric boundary must reject initialization.
2. Short/missing history, invalid quote, symbol deselection and stale rates must keep data not-ready and emit a reason.
3. Verify only closed execution bars are analyzed; mutate bar zero and confirm analysis is unchanged in closed-only mode.
4. Verify fixture bars produce expected fractal points, EMA bias components, zone geometry, sweep flags and SVP profile values.
5. Candidate absence yields explicit no-trade; opposing exact tie rejects; one higher-scored direction resolves deterministically.
6. Test risk sizing around min/step/max volume, invalid tick value, stop side, stops level, spread, per-trade risk, daily realized/floating loss, drawdown peak, margin, position/exposure limits, daily submission count and cooldown.
7. Trigger incident latch, restart with same identity, and verify no auto-resume; acknowledgement must require an explicit subsequent start.
8. Submit the same UID twice through the simulated manager; second attempt must reject. Simulated fill must not create a terminal order/position.
9. Confirm REAL configuration fails, and direct `CQSMCRealAdapter::Submit` rejects without broker requests.
10. Disconnect terminal, remove symbol, stale quotes, then restore: health must fail closed and SAFE_MODE must not automatically resume.
11. Deinitialize during timer activity and confirm timer cleanup and only namespaced chart-object removal.

## Validation available here

A Python static audit was run during implementation for missing includes/braces in the initial codebase. After the reconstruction, run the repository static checker and inspect its findings. No MetaEditor/MT5 is installed in the sandbox, so compilation and all platform scenarios remain **unverified**. Do not infer pass/fail outcomes from the presence of test source.
