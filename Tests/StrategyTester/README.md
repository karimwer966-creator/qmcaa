# Strategy Tester scenario matrix

These are test cases to configure and run in MT5; **no run results are included**. Use the EA in ANALYSIS mode unless exercising the in-memory adapter through a harness. Do not enable real execution.

| Scenario | Tester setup / fault | Expected observable outcome |
|---|---|---|
| Valid history | Load at least 600 bars for M5/M15/H4 | Dashboard reaches RUNNING / ready; one scan per closed M15 bar |
| Short history | Restrict available bars below readiness minimum | READY remains during startup retries; no scan/candidate/order |
| Closed candle isolation | Compare bars where only current bar changes | Closed-only analysis result does not change until a candle closes |
| Invalid timeframe order | Set HTF equal to or below exec, or LTF >= exec | Initialization rejected with configuration message |
| Stale/disconnected quote | Pause feed or test disconnect condition | Health blocks; any running instance enters SAFE_MODE and does not auto-resume |
| Spread limit | Use a test symbol/period with spread above configured cap | Health degradation and execution preflight rejection |
| Opposing evidence | Inject a deterministic fixture with tied buy/sell candidate scores in self-test | Arbiter returns no-trade with conflict reason |
| Daily loss / drawdown | Seed account-history fixture or controlled tester deals | Risk validator rejects at configured ceiling |
| Duplicate intent | Submit same UID twice through the in-memory manager harness | First is simulated only; duplicate is rejected; no terminal order is created |
| Kill latch restart | Trigger EmergencyStop, deinitialize/restart with same identity | Persisted latch remains; no automatic return to RUNNING |
| REAL mode guard | Select REAL or call the RealAdapter in a test harness | Config/adapter returns execution-disabled; no order request is sent |

The current automated self-test covers a subset of pure contracts. Full terminal integration tests, market-data fixtures, simulated lifecycle tests and broker-adapter tests remain to be implemented and executed before any REAL-mode approval.
