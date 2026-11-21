# Module Contracts

## Shared contracts

- `SQSMCResult`: typed result code and human-readable message for lifecycle/module operations.
- `SQSMCConfig`: one configuration snapshot validated before component initialization; numeric bounds and timeframe order are enforced.
- `CQSMCMarketSnapshot`: copied symbol metadata, quote and three series. Series order is newest-first; closed-only consumers must use `NewestIndex()` rather than index zero.
- `SQSMCScanContext`: immutable-by-convention output of analysis, with explicit validity, evidence, data availability and diagnostics.
- `SQSMCUnifiedDecision`: direction or `QSMC_DIR_NONE`, confidence, bar/UID, explanation and bounded rejection list.
- `SQSMCOrderIntent`: sole proposed execution input; adapter access must be routed through manager + preflight + safety.

## Module inputs and outputs

| Module | Input | Output / failure behavior |
|---|---|---|
| State machine / Root | validated config and lifecycle commands | validated state transitions and identity; invalid operation returns result error |
| DataProvider | symbol, timeframe, requested count | rates/tick/metadata or false with last error; retry limited |
| MarketData | provider + symbol/timeframe contract | all-or-nothing snapshot; invalidates on failure |
| DataReadiness | snapshot | ready / not ready with explicit reason |
| Structure | snapshot slot, lookback, left/right | newest-first confirmed swing set; false on insufficient/no swings |
| Bias | snapshot + structure | neutral/bull/bear, score/confidence and components; false if EMA inputs absent |
| Zones | snapshot + structure + tolerance + ATR | bounded zone set; false if none; scoring is separate |
| Liquidity | snapshot + structure + tolerance | bounded reference levels and wick sweep flags |
| Sessions | closed-bar snapshot + broker-server minute windows | current/previous Asia/London/NY ranges, active window and recent sweep level/shift |
| FVG | closed-bar snapshot + lookback + min width in ATR | unfilled three-bar gaps, mitigation and current retest flags |
| ICT setup | sessions + confirmed swings + FVGs | WAIT_SESSION / WAIT_SWEEP / WAIT_MSS / WAIT_FVG_RETRACE / WATCH_CANDIDATE; only the full sequence emits a funnel candidate |
| Order-flow proxy | closed candle ranges + tick volume | relative tick volume and close-location pressure; explicitly not true order flow |
| Elliott guide | confirmed fractal pivots + direction | chronological heuristic labels plus a small ±3-point confluence hint; never a standalone candidate and wave rules are unvalidated |
| BOS/CHoCH-OB model | closed snapshot + confirmed swings + detected zones | historical displacement break followed by current retest of an unmitigated zone proxy; pivots must have been confirmed at the historical break (no future pivot leakage) |
| Opportunity funnel/audit | both setups + HTF/session/liquidity context + optional flow/profile/Elliott | two model-specific accepted/waiting/rejected reasons per bar plus arbiter result in append-only CSV |
| Reaction | snapshot + one zone | direction/score/pattern or explicit no-rejection reason |
| SVP Core | snapshot slot, lookback, bin count, value-area % | profile bins, POC/VAH/VAL; false if insufficient range/data |
| Funnel/Arbiter | valid analysis context and candidates | deterministic decision or no-trade rejections; no order side effects |
| Safety controller | config, state store, terminal/account/symbol environment | fail-closed submit permission and incident latch |
| Preflight | intent, config, snapshot, safety, account state | true only after parameter and safety checks; never sends |
| Execution adapter | preflight-approved intent | simulated fill only or real-blocked response |
| Renderer | dashboard data + optional zone value | chart comment/owned objects only; no strategy mutation |

## Strategy specification gaps

The following details are not established by a supplied strategy spec and therefore remain explicit heuristics: exact market structure/CHoCH/BOS semantics; order-block proxy/origin/mitigation; liquidity sweep validity; session boundary/volume definition; SVP tick-volume input and value-area algorithm; optional confluence point weights; entry trigger, stop placement, targets, position management and exit rules. Reviewers should not treat the current calculation outputs as a validated strategy.
