# QSMC Architecture

## Purpose and status

This is an integrated MQL5 EA scaffold with working analysis/data/presentation paths and a deliberately non-operational live execution boundary. It should be reviewed and compiled in MetaEditor before use. It does not encode a proprietary QSMC strategy specification.

## Dependency direction

`Core → Infrastructure → Data → Analysis → Decision → Execution`

Safety is a cross-cutting gate that depends on Core plus environment/persistence contracts; it does not own analysis or order submission. Presentation renders state and copied evidence only. `App` composes all modules and receives MetaTrader events. See [DEPENDENCY_GRAPH.md](DEPENDENCY_GRAPH.md).

## Runtime lifecycle

1. `OnInit` builds configuration (defaults → preset → explicit inputs), rejects duplicate initialization and calls the application orchestrator.
2. `CQSMCRoot` validates config, computes fingerprint and instance identity, then transitions `CREATED → INITIALIZING → READY`.
3. Bootstrap initializes the per-magic state store and claims the identity tuple, rejecting a persisted mismatch.
4. Provider, market data, readiness, safety and presentation are initialized. The millisecond timer is installed once.
5. The first valid snapshot/readiness evaluation permits `READY → RUNNING`. An already-persisted incident latch sends the root to `SAFE_MODE` and requires explicit operator restart/recovery; no automatic resumption occurs.
6. Tick/timer callbacks update health and refresh data. Analysis runs at most once per closed execution bar. Missing data results in no analysis decision.
7. Health BLOCKED during `RUNNING` enters `SAFE_MODE`. `SAFE_MODE` does not transition back automatically.
8. Deinit stops event acceptance, kills the timer, saves dirty state, removes owned chart objects and shuts down the root.

Only `RUNNING` is operational according to `CQSMCStateMachine::CanOperate`. `OnTick` does not work outside that state. Timer callbacks in `READY` may retry data to complete startup; this is initialization, not analysis/execution activity.

## Data and analysis

The provider fetches three series (exec / HTF / LTF); snapshot arrays are series ordered, and closed-only mode makes index `1` the newest eligible bar. Analysis math reads through the snapshot contract. Structure points use a configurable n-bar fractal. Bias combines EMA separation, HTF close-vs-EMA and the latest swing sequence. Zones use swing-plus-opposite-displacement and clustered swing extremes. Liquidity identifies clustered levels and wick-through/close-back sweeps. SVP distributes each candle's available tick volume across the price bins intersected by its range; it is a bar-level approximation, not exchange volume-at-price.

These models are explicitly replaceable heuristics. The current selected ICT-inspired watch path is a strict sequence: recent raid of a completed Asia/London/prior-day session range during configured London/New York window, a post-raid displacement close through a previously confirmed opposing swing (MSS proxy), followed by a current retest of an unfilled post-MSS FVG. It is a chart/watch candidate only, not an entry instruction, and it does not estimate success probability. The server-time windows are manually editable and are not DST-aware.

The secondary model detects a historical displacement close through a confirmed swing, classifies a local BOS/CHoCH proxy, and waits for the current retest of an unmitigated swing/displacement zone used as an order-block proxy. Pivot confirmation timing is checked against the historical break to avoid using later-confirmed swings. This remains a replaceable heuristic, not a canonical OB definition.

A shared hard filter requires a non-neutral matching HTF close/EMA bias, a configured London/New York window, and a direction-aligned recent session liquidity raid for either model. A pivot-label guide annotates up to eight alternating fractal swings with `1..5/A..C`; the final pivot may add at most ±3 confluence points after a setup has qualified. It never creates a candidate, and Elliott rules/degree/alternates are not validated. The order-flow line computes close-location-weighted tick volume and relative volume, not aggressor delta/CVD/DOM/footprint. Volume Profile and tick-volume proxy modify points only when their data is ready. All scores are heuristic points, not calibrated probabilities.

Each closed-bar evaluation appends primary-model, alternate-model, and arbiter outcomes/reasons to `MQL5/Files/QSMC/opportunities_<magic>.csv` (or the Strategy Tester agent's `MQL5/Files/QSMC` folder). File-write failure is diagnostic-only and never changes signal decisions. No claim is made that these heuristics are canonical QSMC/ICT rules.

## Decision and execution boundary

The funnel emits candidates only from a completed reaction or displacement break. The arbiter picks the highest directional score, rejects exact opposing ties, and rejects below-threshold confidence. Every no-trade path has a code and reason. Decision modules cannot send orders.

`CQSMCExecutionManager` selects disabled, in-memory simulated, or real-blocked mode. Central preflight and a duplicate UID journal exist, but there is no live broker adapter: `CQSMCRealAdapter::Submit` always returns `QSMC_ERR_EXECUTION_DISABLED`. Default config is `ANALYSIS`. See [EXECUTION_SAFETY.md](EXECUTION_SAFETY.md).

## Known limitations

- No MetaEditor compiler or MT5 runtime was available; syntax/platform behavior is unverified.
- No genuine unit framework or terminal integration run is included in the sandbox; the MQL self-test is source, not a reported pass.
- RiskManager derives instance-magic server-day deal P/L plus floating P/L, persists peak equity, and validates drawdown. The order manager tracks daily submission count/cooldown and a bounded 16-UID persistence window. These controls are not invoked by the normal ANALYSIS event path and have not been validated on MT5.
- Restart reconcile is read-only for positions and does not rebuild uncertain broker-order lifecycle state. A persisted kill latch blocks rather than resumes.
- Chart zone objects are a minimal overlay; extensive dashboard interaction, alert policy and object lifecycle testing remain outstanding.
- Strategy semantics/definitions (sessions, structure breaks, liquidity sweeps, zone lifecycle, value profile period and entry/exit rules) need domain-owner approval.
