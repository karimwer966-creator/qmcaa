# QSMC — Phase 0 inventory and discovery

Date: 2026-11-25 (UTC). Branch: `arena/95ec1526-qmcaa`.
Base commit: `d37bde4ece6449a9f349f5dcc60646bced83a8b2`.

## Scope and status

This is Checkpoint 0 only, not the full Phase 2 safety audit or a production certification.
Discovery used the current working-tree contents, including the changes from the earlier
conversation. No executable source, configuration, or existing documentation was changed
in this phase. This new report is the documentation-only exception needed to deliver
Checkpoint 0. Line references below are repository-relative, one-based, at this snapshot.

At phase entry there were **93 tracked files: 79 MQL source files, 12 Markdown files,
and 2 Python tools**. Of the MQL files, 75 are library headers under `Include/QSMC`,
1 is a test harness header, 1 is the EA, and 2 are scripts. This report is additional.
Git internals, generated caches, and external MT5 runtime files are excluded.

Pre-existing working-tree modifications, retained without alteration:
- `Experts/QSMC/QSMC.mq5`: unconditional Deinit callback after partial initialization.
- `Include/QSMC/App/QSMC_Orchestrator.mqh`: pending evaluation retry and delayed bar commit.
- `Docs/TESTING.md`: corresponding terminal regression scenarios.

### Supplied-context discrepancies verified against the checkout

- Actual EA: `Experts/QSMC/QSMC.mq5`, **not** `MQL5/Experts/QSMC.mq5`.
  Installation copies it to `MQL5/Experts/QSMC/QSMC.mq5` (README installation section).
- Actual umbrella: `Include/QSMC/QSMC.mqh`; installed under `MQL5/Include/QSMC`.
- Original non-operational RealAdapter is present. There is no `CQSMCBrokerExecutor`,
  `Arm`, `Disarm`, `QSMC_ENABLE_REAL_TRADING`, or `QSMC_ALLOW_LIVE_ACCOUNT` in the
  MQL sources. The requested replacement design is **not implemented**.
- The EA is the simple input version. It has a single opt-in preset-risk override,
  point-based spread/deviation/zone tolerance, and no input groups or gold-specific
  symbol validation. Its `cfg` assignments can be checked directly in
  `Experts/QSMC/QSMC.mq5:73–127` against `Core/QSMC_Config.mqh`.
- No calendar/news filter exists. Rollover/weekend entry guards are also absent.
- Existing documentation uses `Docs/` (capital D). The requested new deliverable uses
  `docs/` (lowercase d). Both coexist here; case-insensitive deployment needs care.

## Runtime call graph

References in this section abbreviate `Include/QSMC/` as `I/` only for readability.
The inventory later gives the actual full paths and direct include dependencies.

```text
Experts/QSMC/QSMC.mq5
OnInit [130–148]
  QSMC_BuildConfig [73–128]
    SetDefaults -> QSMC_ApplyPreset -> explicit inputs (risk overrides opt-in)
  CQSMCOrchestrator::Init [I/App/QSMC_Orchestrator.mqh:345–387]
    CQSMCBootstrap::Start [I/App/QSMC_Bootstrap.mqh:14–55]
      Root.Init -> config.Validate -> fingerprint.AddConfig -> identity.Build -> READY
      StateStore.Init -> Load
      compare persisted identity -> claim identity -> Save
    Logger.Init; OpportunityAuditLog.Init
    Clock.Init + TrackTimeframe(exec, HTF, LTF)
    Scanners.ConfigureICT
    new DataProvider -> Init(symbol)
    MarketData.Init(provider, timeframes, bars, closed-only)
    DataReadiness.Init(100)
    SafetyController.Init -> HealthMonitor.Init + IncidentSafety.Restore
    ExecutionManager.Init -> Resolve(mode) + RiskManager.Init (no Arm exists)
    Renderer.Init -> Dashboard + ChartLayers
    RefreshAndEvaluate(true)
    Lifecycle.Start -> EventSetMillisecondTimer
    EventDispatcher.Start -> initialized flag -> startup log -> Render

OnTick [EA:157–161] -> started flag -> Orchestrator.OnTick [389–400]
  initialized/event gate -> tick counter -> root.CanOperate
  MarketData.IsExecNewBar -> RefreshAndEvaluate(false) -> Render

OnTimer [EA:163–167] -> started flag -> Orchestrator.OnTimer [402–417]
  initialized/event gate -> Clock.Update -> UpdateHealth -> Safety.Probe
    blocked + RUNNING -> Root.EnterSafeMode (no automatic recovery)
  READY -> RefreshAndEvaluate(true)
  RUNNING -> new execution bar OR pending evaluation -> RefreshAndEvaluate(false)
  Render; StateStore.Save if dirty

RefreshAndEvaluate [I/App/QSMC_Orchestrator.mqh:106–295]
  OFF -> return
  MarketData.Refresh -> provider quote/contract/rates -> validate snapshot
  CopySnapshot -> DataReadiness.Evaluate
  allowStart + READY -> Root.Start -> Safety.Probe -> SAFE_MODE if blocked/latched
  root.CanOperate -> Gates.ValidateSnapshot -> closed-bar duplicate gate
  SvpCore.Build -> Scanners.SetValueContext -> Scanners.Scan
    structure/bias/zones/ranking/liquidity/reaction/breaks/candles
    sessions/FVG/ICT setup/order-flow proxy/Elliott guide/alternate OB model
  commit analyzed bar -> clear/draw bounded chart layers
  OpportunityFunnel.Build -> SignalRegistry -> Arbiter.Resolve
  append primary, alternate and arbiter opportunity audit rows
  diagnostics and runtime counters -> return
  **No intent construction, SizeLots, Geometry, or ExecutionManager.Submit call**

OnTradeTransaction [EA:169–175] -> started flag
  Orchestrator.OnTradeTransaction [419–427]
  initialized/event/RUNNING gates -> log transaction identifiers and retcode only
  **No fill reconciliation or safety/trade-counter updates**

OnDeinit [EA:150–155] -> Orchestrator.Deinit [429–439]
  stop event dispatcher -> Lifecycle.Stop -> EventKillTimer
  save dirty state -> Renderer.Deinit -> Root.Shutdown
  delete data provider -> shutdown log -> clear initialized flag
```

### Execution boundary available as callable library code, NOT reached by EA events

```text
ExecutionManager.Submit [Execution/QSMC_ExecutionManager.mqh:33–52]
  mode / RUNNING / identity checks
  RiskManager.CaptureAccount -> ValidateAccount
  OrderManager.Submit(..., m_demo, ...)  [only simulated adapter is passed]
    ExecutionJournal.Seen -> reject duplicate
    server-day submission count / cooldown checks
    ExecutionPreflight.Validate
      direction/symbol/magic/SL/TP/confidence/metadata/trade permissions
      snapshot quote drift / tick alignment / volume alignment / stops / spread
      account limits / planned stop risk / OrderCalcMargin
      SafetyController.CanSubmit (root/mode/build/latch/health/global kill)
    persist consumed UID, submission count, last-submit time before adapter call
    adapter.Submit -> in-memory fill -> in-memory journal entry

REAL -> blocked before adapter selection; RealAdapter.Submit also always rejects.
```

Including a module via the umbrella does not mean its public methods are called.
In particular, PositionManager reconciliation is a read-only library capability,
not a running position-management service in this EA.

## Explicit discovery answers (a–h)

### (a) Adapter selection by mode

`Include/QSMC/Execution/QSMC_ExecutionMode.mqh:20–24` maps DEMO to
`QSMC_EXEC_SIMULATED`, REAL to `QSMC_EXEC_REAL_BLOCKED`, and ANALYSIS/OFF to
`QSMC_EXEC_DISABLED`. `ExecutionManager.mqh:24–30` stores this selection.
`ExecutionManager.mqh:39–42` rejects disabled/REAL modes; line 52 passes `m_demo`
to OrderManager. `m_real` exists as a member (line 18) but is never submitted to.
`RealAdapter.mqh:14–20` independently rejects with `QSMC_ERR_EXECUTION_DISABLED`.

Current compile gate: `Core/QSMC_Constants.mqh` defaults `QSMC_ALLOW_REAL` to 0
under `#ifndef`; it is **not an unconditional hard-set constant**. Even externally
overriding it cannot create an order-sending path in this checkout. Config validation
at `Core/QSMC_Config.mqh:273–279` also requires the exact token
`I-ACCEPT-LIVE-TRADING-RISK`. The new mandatory two-define gating design remains
future work. ANALYSIS is the EA default (`Experts/QSMC/QSMC.mq5:13`).

### (b) DemoAdapter behavior

`Include/QSMC/Execution/QSMC_DemoAdapter.mqh:15–28` validates UID/positive volume,
assigns an incrementing synthetic ticket, returns the entire intent volume as filled,
and increments an in-memory counter. **No broker orders, no OrderSend, no CTrade,
no terminal-position mutation.** DEMO does not mean broker demo execution.
The ordinary EA path does not currently call even this paper simulator.

### (c) Lot calculation and formula

`Include/QSMC/Execution/QSMC_RiskManager.mqh:84–113` defines `SizeLots`:

```text
riskMoney  = ACCOUNT_BALANCE * riskPercent / 100
oneLotRisk = abs(entry - stop) / SYMBOL_TRADE_TICK_SIZE * SYMBOL_TRADE_TICK_VALUE
rawLots    = riskMoney / oneLotRisk
lots       = NormalizeDouble(floor(rawLots / VOLUME_STEP) * VOLUME_STEP, precision)
reject if below VOLUME_MIN
cap to VOLUME_MAX and configured exposure-lot cap
floor to step again; reject if below VOLUME_MIN
```

Precision is chosen by step thresholds (2, 3 or 4 digits), not arbitrary-step
precision discovery. It uses **balance, not equity** and generic tick value, not
loss tick value or OrderCalcProfit. No production caller of SizeLots exists in the
MQL source tree; search finds only the definition. Preflight separately calculates
planned risk with balance and permits one tick-value-times-volume above the cap
(`ExecutionPreflight.mqh:76–83`). These are observations, not approved fixes.

### (d) SL/TP geometry, stops and freeze

`Include/QSMC/Decision/QSMC_ExecutionRules.mqh:27–55` defines `Geometry`:
stop distance is `max(abs(entry - swingOpposite), ATR * cfg.sl_atr_mult)`, or the
ATR term alone if no positive opposing swing. BUY SL/TP are entry minus distance /
entry plus distance times `cfg.tp_rr`; SELL reverses the signs. It validates positive
prices and minimum RR. No caller is present in the MQL sources.

`Data/QSMC_DataProvider.mqh:120–121` reads both stops and freeze levels;
`Data/QSMC_MarketData.mqh:132–139` stores them in the snapshot. Preflight
`Execution/QSMC_ExecutionPreflight.mqh:46–67` **checks**, rather than normalizes,
tick alignment and minimum stop distances measured from intent entry using snapshot
metadata. It is not a fresh-tick-side-aware broker stops check. Freeze level is
carried but **not enforced**. PositionManager has no modify/close implementation
(`Execution/QSMC_PositionManager.mqh:23–41`), so no trailing or break-even currently
exists. This does not establish readiness for future position modifications.

### (e) Persistence: contents, locations, load/save timing

`Include/QSMC/Infrastructure/QSMC_StateStore.mqh:66–80` constructs
`MQL5/Files/QSMC/state_<magic>.state` in the terminal/tester file sandbox and loads
it during Bootstrap (`App/QSMC_Bootstrap.mqh:21`), before upper-layer module startup.
This is not FILE_COMMON storage. `Load` (`StateStore.mqh:227–268`) reads key=value
lines, skipping comments; the written schema header is not validated on load.

Writers and persisted keys:

| Writer | Keys / meaning | References |
|---|---|---|
| Bootstrap | `identity.fingerprint`, `identity.id` | `App/QSMC_Bootstrap.mqh:42–43` |
| StateStore kill helper | `kill`, `kill_reason`; terminal GlobalVariable `QSMC_GV_PREFIX + magic + "_kill"` | `Infrastructure/QSMC_StateStore.mqh:160–187` |
| IncidentSafety | `safety.kill`, `safety.uncertain`, `safety.reason`, `safety.time` | `Safety/QSMC_IncidentSafety.mqh:33–57` |
| RiskManager | `risk.peak_equity` when a higher sampled equity is found | `Execution/QSMC_RiskManager.mqh:39–46` |
| OrderManager | `execution.day`, `execution.daily_count`, `execution.last_submit` | `Execution/QSMC_OrderManager.mqh:35–69` |
| ExecutionJournal | `execution.last_uid`, `execution.uid.0` through `.15` | `Execution/QSMC_ExecutionJournal.mqh:56–68` |

Save occurs on identity claim; kill/latch/acknowledgement operations; a higher sampled
peak; journal UID commitment; submission guard commitment; dirty timer/deinit state.
Execution-specific writes are not reached through the normal EA analysis flow.
Daily P/L itself is recomputed from deal history plus floating P/L when CaptureAccount
is called, not saved as a daily equity baseline. Submission count is persisted, not
reconstructed from deals. Position state is not persisted/adopted by the app.

Save writes a `.tmp` file then FileMove with replacement
(`StateStore.mqh:191–224`), but on failure it deletes the old destination and retries.
Thus **do not assume atomic durability**. Return checking and recovery correctness
need Phase 2 review. Filenames and GlobalVariable names contain magic only, not
explicit login+symbol+magic components; account and symbol are inputs to the magic
hash, not a collision-free namespace. No GlobalVariablesFlush call is present.

A discovery issue requiring later audit: `Safety/QSMC_IncidentSafety.mqh:24–25`
calls `store.GetBool(key, localFlag)` and discards the returned bool. The actual
signature `Infrastructure/QSMC_StateStore.mqh:126–131` returns a value and takes a
default, not an output reference. The mirrored kill check still contributes to the
latch at line 26; independent `safety.*` restoration must not be assumed correct.

### (f) Daily loss, drawdown, maximum trades and cooldown

**SafetyController does not itself calculate/enforce these four numeric limits.**
`Safety/QSMC_SafetyController.mqh:43–57` gates readiness, root, execution mode,
compile permission, incident latch, environment health, and terminal-global kill.

- `Execution/RiskManager.mqh:28–80` captures account balance/equity/free margin,
  compares account equity with the sampled stored peak, and computes daily loss
  from magic-filtered current-server-day realized P/L (profit, swap, commission,
  fee) plus current magic-filtered floating profit/swap, divided by current balance.
  These position/deal loops filter magic but not symbol.
- `RiskManager.mqh:116–125` rejects daily loss, drawdown, position count, exposure,
  and non-positive free margin; ExecutionManager calls this at lines 48–51.
- `Execution/OrderManager.mqh:35–56` uses `TimeToString(TimeCurrent(), TIME_DATE)`
  for daily submission reset; it checks `max_daily_trades` against persisted
  submissions and cooldown against `execution.last_submit`. Counts increment
  **before** adapter submission, not upon a confirmed broker entry/fill.
- `Execution/ExecutionPreflight.mqh:71–74` repeats selected account limits and
  includes the proposed volume in exposure; lines 87–90 check calculated margin
  against free margin without a configurable buffer.
- A limit rejection does not itself invoke IncidentSafety.Latch. These checks are
  on the callable submission path, not continuous enforcement in the EA event flow.

### (g) Session computation and midnight wrapping

`Include/QSMC/Analysis/QSMC_Sessions.mqh:73–99` converts candle timestamps to
broker-server minute/day. `InWindow` uses a half-open interval: for start < end,
`minute >= start && minute < end`; for start > end, `minute >= start || minute < end`.
Equal endpoints mean disabled. **Midnight wrap membership is supported.**
`SessionDay` moves post-midnight bars into the preceding start day.
`Evaluate` (`Sessions.mqh:160–254`) uses the newest included candle's timestamp,
not the submission-time wall clock; computes current/prior server-day range buckets;
and tests recent raids against completed session ranges. It uses calendar-day
subtraction, not previous-trading-session discovery. The interaction between
wrapping ranges and current/prior-day labeling needs full audit/fixtures before
claiming all wrapping behavior is correct. No automatic DST adjustment is wired.
`Infrastructure/QSMC_Clock.mqh:127–130` exposes a TimeCurrent-minus-TimeGMT offset,
not the requested TimeTradeServer-based offset-change warning service.
The opportunity funnel requires London/New York membership
(`Decision/QSMC_OpportunityFunnel.mqh:63–64`), but preflight does not recheck current
session, news, weekend, or rollover.

### (h) Magic derivation and uniqueness

`Include/QSMC/Core/QSMC_InstanceIdentity.mqh:48–80` hashes version tag, symbol,
execution period, account login, ChartID and input fingerprint, then maps the hash
into the reserved band with `magicOffset` and modulo arithmetic. Build time is
recorded but not hashed. `Core/QSMC_Constants.mqh` defines the base/range.
`App/QSMC_Bootstrap.mqh:29–48` compares persisted fingerprint and instance id.

It is **not mathematically unique per instance**: modulo collisions remain possible;
the check does not compare every raw identity input, and there is no concurrent
exclusive claim. Because ChartID/config/version affect the hash, identity continuity
across recreated charts/configuration changes/upgrades must be validated before
using it to recover live positions or safety state. No uniqueness or restart-safety
proof is claimed.

## Required code searches

Scope: all 79 tracked `.mq5` / `.mqh` files (Experts, Include, Scripts, Tests).
Search is **case-sensitive literal substring**, including comments and strings,
matching the requested terms. Counts below distinguish matching lines and total
occurrences. Paths and line numbers list every hit, including test code.
Documentation/Python are excluded to avoid counting this report or prose as API use.
A hit is not proof of an executable API call.

| Term | Matching lines | Occurrences | Locations |
|---|---:|---:|---|
| `OrderSend` | 2 | 2 | `Include/QSMC/Execution/QSMC_DemoAdapter.mqh:3`; `Include/QSMC/Execution/QSMC_RealAdapter.mqh:4` |
| `CTrade` | 3 | 3 | `Include/QSMC/Decision/QSMC_ExecutionRules.mqh:11`; `Include/QSMC/Decision/QSMC_ExecutionRules.mqh:29`; `Include/QSMC/Execution/QSMC_RealAdapter.mqh:4` |
| `SYMBOL_FILLING_MODE` | 0 | 0 | None |
| `SYMBOL_TRADE_TICK_VALUE` | 3 | 3 | `Include/QSMC/Data/QSMC_DataProvider.mqh:115`; `Include/QSMC/Execution/QSMC_ExecutionPreflight.mqh:76`; `Include/QSMC/Execution/QSMC_RiskManager.mqh:93` |
| `SYMBOL_TRADE_TICK_SIZE` | 4 | 4 | `Include/QSMC/Data/QSMC_DataProvider.mqh:116`; `Include/QSMC/Execution/QSMC_ExecutionPreflight.mqh:77`; `Include/QSMC/Execution/QSMC_RiskManager.mqh:94`; `Tests/Harness/QSMC_Selftest.mqh:95` |
| `OrderCalcProfit` | 0 | 0 | None |
| `OrderCalcMargin` | 1 | 1 | `Include/QSMC/Execution/QSMC_ExecutionPreflight.mqh:87` |
| `SYMBOL_TRADE_STOPS_LEVEL` | 1 | 1 | `Include/QSMC/Data/QSMC_DataProvider.mqh:120` |
| `SYMBOL_TRADE_FREEZE_LEVEL` | 1 | 1 | `Include/QSMC/Data/QSMC_DataProvider.mqh:121` |
| `TRADE_RETCODE_` | 0 | 0 | None |
| `Calendar` | 0 | 0 | None |
| `GlobalVariableSet` | 2 | 2 | `Include/QSMC/Infrastructure/QSMC_StateStore.mqh:168`; `Include/QSMC/Infrastructure/QSMC_StateStore.mqh:170` |
| `FileOpen` | 6 | 6 | `Include/QSMC/Infrastructure/QSMC_Logger.mqh:44`; `Include/QSMC/Infrastructure/QSMC_Logger.mqh:87`; `Include/QSMC/Infrastructure/QSMC_OpportunityAudit.mqh:26`; `Include/QSMC/Infrastructure/QSMC_OpportunityAudit.mqh:50`; `Include/QSMC/Infrastructure/QSMC_StateStore.mqh:196`; `Include/QSMC/Infrastructure/QSMC_StateStore.mqh:232` |
| `EventSetTimer` | 0 | 0 | None |
| `EventSetMillisecondTimer` | 2 | 2 | `Include/QSMC/App/QSMC_Lifecycle.mqh:22`; `Include/QSMC/App/QSMC_Lifecycle.mqh:23` |
| `IndicatorRelease` | 0 | 0 | None |
| `ObjectsDeleteAll` | 0 | 0 | None |

Interpretation of ambiguous search hits:
- `OrderSend`: both hits are comments; **zero executable calls**.
- `CTrade`: the RealAdapter hit is a comment. The two ExecutionRules hits are
  substrings of `SQSMCTradeGeometry`, not uses of the standard-library CTrade class.
- `EventSetMillisecondTimer`: one invocation (Lifecycle line 22), one diagnostic
  string (line 23).
- `SYMBOL_TRADE_TICK_VALUE_LOSS`: absent (the generic-value hits above do not use it).
- `ObjectsDeleteAll`: absent does not mean objects are not cleaned up; presentation
  modules enumerate names and use ObjectDelete. No indicator-release call was found;
  handle lifecycle correctness is reserved for Phase 2, not inferred from hit counts.

## Complete file inventory and direct dependencies

Sizes are bytes in the current working tree, not compiled artifact sizes. Each MQL
row lists direct `#include` dependencies exactly as written; relative includes resolve
from that source's directory, angle includes from the terminal Include root.
Transitive closure is obtained by following the listed module rows. All modules also
rely on the MT5/MQL5 platform; these built-ins are not external packages. Purpose
summaries describe module responsibility, not a claim that each module is executed
or verified. For documents, dependencies are explicit relative Markdown links;
source paths mentioned in prose are descriptive references rather than includes.
Python dependencies are standard-library imports.

| File | Bytes | Purpose | Direct dependencies |
|---|---:|---|---|
| `Docs/ARCHITECTURE.md` | 6453 | QSMC Architecture documentation. | `DEPENDENCY_GRAPH.md`; `EXECUTION_SAFETY.md` |
| `Docs/CHANGELOG.md` | 1169 | Existing reconstruction change history. | None explicit |
| `Docs/CONFIGURATION.md` | 2699 | Configuration documentation. | None explicit |
| `Docs/DEPENDENCY_GRAPH.md` | 1570 | Dependency Graph documentation. | None explicit |
| `Docs/EXECUTION_SAFETY.md` | 2894 | Execution and Safety documentation. | None explicit |
| `Docs/INSTALLATION.md` | 1294 | Installation documentation. | None explicit |
| `Docs/MIGRATION_PLAN.md` | 542 | Migration notes documentation. | None explicit |
| `Docs/MODULE_CONTRACTS.md` | 4366 | Module Contracts documentation. | None explicit |
| `Docs/REVIEW_2026-11-21.md` | 19394 | Earlier reconstruction review and stated verification limitations. | None explicit |
| `Docs/TESTING.md` | 5542 | Existing self-test, Strategy Tester and regression verification instructions. | None explicit |
| `Experts/QSMC/QSMC.mq5` | 7057 | QSMC Expert Advisor. | `QSMC/QSMC.mqh` |
| `Include/QSMC/Analysis/QSMC_Bias.mqh` | 4182 | Directional bias from three independent, auditable components: 1. | `../Core/QSMC_Types.mqh`; `../Data/QSMC_MarketSnapshot.mqh`; `QSMC_Structure.mqh` |
| `Include/QSMC/Analysis/QSMC_BreakOrderBlock.mqh` | 6667 | Secondary heuristic: confirmed BOS/CHoCH -> prior-origin zone retest. | `../Core/QSMC_Types.mqh`; `../Data/QSMC_MarketSnapshot.mqh`; `QSMC_Structure.mqh`; `QSMC_Zones.mqh`; `QSMC_CandlePatterns.mqh` |
| `Include/QSMC/Analysis/QSMC_CandlePatterns.mqh` | 6442 | Deterministic, hand-computable candle geometry. | `../Core/QSMC_Types.mqh`; `../Data/QSMC_MarketSnapshot.mqh` |
| `Include/QSMC/Analysis/QSMC_EarlyBreakDetector.mqh` | 2871 | Break-of-structure / range break with displacement confirmation. | `../Core/QSMC_Types.mqh`; `../Data/QSMC_MarketSnapshot.mqh`; `QSMC_Structure.mqh`; `QSMC_CandlePatterns.mqh` |
| `Include/QSMC/Analysis/QSMC_ElliottGuide.mqh` | 3480 | Heuristic pivot labels plus a small optional confluence hint. | `QSMC_Structure.mqh` |
| `Include/QSMC/Analysis/QSMC_FairValueGaps.mqh` | 6497 | Three-bar fair-value-gap geometry using closed, series-ordered bars. | `../Core/QSMC_Constants.mqh`; `../Core/QSMC_Types.mqh`; `../Data/QSMC_MarketSnapshot.mqh` |
| `Include/QSMC/Analysis/QSMC_ICTSetup.mqh` | 7564 | Explicit ICT-inspired candidate sequence selected by the user: prior session liquidity raid -> displacement/MSS -> post-MSS FVG retest. | `../Core/QSMC_Types.mqh`; `../Data/QSMC_MarketSnapshot.mqh`; `QSMC_Structure.mqh`; `QSMC_Sessions.mqh`; `QSMC_FairValueGaps.mqh`; `QSMC_CandlePatterns.mqh` |
| `Include/QSMC/Analysis/QSMC_Liquidity.mqh` | 480 | Stable public liquidity contract; calculation is in CQSMCLiquidityValue. | `QSMC_LiquidityValue.mqh` |
| `Include/QSMC/Analysis/QSMC_LiquidityValue.mqh` | 9526 | Liquidity map: equal highs/lows (resting liquidity), swing extremes and the range high/low. | `../Core/QSMC_Constants.mqh`; `../Core/QSMC_Types.mqh`; `../Data/QSMC_MarketSnapshot.mqh`; `QSMC_Structure.mqh` |
| `Include/QSMC/Analysis/QSMC_OrderFlowProxy.mqh` | 3209 | Candle/tick-volume participation proxy. | `../Core/QSMC_Constants.mqh`; `../Data/QSMC_MarketSnapshot.mqh` |
| `Include/QSMC/Analysis/QSMC_Reaction.mqh` | 4503 | Price reaction at a zone: did the market actually reject the level with a bullish/bearish candle, or is it just nearby? Returns an explicit direction and a bounded score. | `../Core/QSMC_Types.mqh`; `../Data/QSMC_MarketSnapshot.mqh`; `QSMC_Zones.mqh`; `QSMC_CandlePatterns.mqh` |
| `Include/QSMC/Analysis/QSMC_Scanners.mqh` | 18741 | Runs the analytical detectors once per decision bar and exposes a single immutable scan context. | `../Core/QSMC_Types.mqh`; `../Data/QSMC_MarketSnapshot.mqh`; `QSMC_Structure.mqh`; `QSMC_Bias.mqh`; `QSMC_Zones.mqh`; `QSMC_ZoneScorer.mqh`; `QSMC_LiquidityValue.mqh`; `QSMC_Reaction.mqh`; `QSMC_EarlyBreakDetector.mqh`; `QSMC_CandlePatterns.mqh`; `QSMC_Sessions.mqh`; `QSMC_FairValueGaps.mqh`; `QSMC_ICTSetup.mqh`; `QSMC_OrderFlowProxy.mqh`; `QSMC_ElliottGuide.mqh`; `QSMC_BreakOrderBlock.mqh` |
| `Include/QSMC/Analysis/QSMC_Sessions.mqh` | 9559 | Broker-server session ranges and recent liquidity raids. | `../Core/QSMC_Constants.mqh`; `../Data/QSMC_MarketSnapshot.mqh` |
| `Include/QSMC/Analysis/QSMC_Structure.mqh` | 8379 | Market structure: confirmed fractal swing points, running bias bookkeeping and break-of-structure detection. | `../Core/QSMC_Constants.mqh`; `../Core/QSMC_Types.mqh`; `../Data/QSMC_MarketSnapshot.mqh` |
| `Include/QSMC/Analysis/QSMC_StructurePoints.mqh` | 1902 | Contract-focused facade for confirmed swing extraction. | `QSMC_Structure.mqh` |
| `Include/QSMC/Analysis/QSMC_SupplyDemand.mqh` | 1586 | Explicit contract facade for supply/demand. | `QSMC_Zones.mqh` |
| `Include/QSMC/Analysis/QSMC_ZoneScorer.mqh` | 3634 | Zone ranking. | `../Core/QSMC_Types.mqh`; `../Data/QSMC_MarketSnapshot.mqh`; `QSMC_Zones.mqh` |
| `Include/QSMC/Analysis/QSMC_Zones.mqh` | 13168 | Supply/demand zones derived from confirmed swings plus a displacement filter, and support/resistance zones from clustered swing extremes. | `../Core/QSMC_Constants.mqh`; `../Core/QSMC_Types.mqh`; `../Data/QSMC_MarketSnapshot.mqh`; `QSMC_Structure.mqh`; `QSMC_CandlePatterns.mqh` |
| `Include/QSMC/Analysis/QSMC_ZonesPublic.mqh` | 538 | Public compatibility include for the S/R and supply-demand zone contracts. | `QSMC_Zones.mqh`; `QSMC_ZoneScorer.mqh`; `QSMC_SupplyDemand.mqh` |
| `Include/QSMC/App/QSMC_Bootstrap.mqh` | 2358 | Creates and validates core identity before upper-layer startup. | `../Core/QSMC_Root.mqh`; `../Infrastructure/QSMC_StateStore.mqh`; `../Safety/QSMC_Diagnostics.mqh` |
| `Include/QSMC/App/QSMC_EventDispatcher.mqh` | 1167 | Thin event accounting/ordering boundary. | None explicit |
| `Include/QSMC/App/QSMC_Lifecycle.mqh` | 1443 | Idempotent timer and event lifecycle guard. | `../Core/QSMC_Types.mqh` |
| `Include/QSMC/App/QSMC_Orchestrator.mqh` | 20595 | Composition root. | `../Core/QSMC_Root.mqh`; `../Core/QSMC_Preset.mqh`; `../Infrastructure/QSMC_Clock.mqh`; `../Infrastructure/QSMC_Logger.mqh`; `../Infrastructure/QSMC_StateStore.mqh`; `../Infrastructure/QSMC_Stats.mqh`; `../Infrastructure/QSMC_OpportunityAudit.mqh`; `../Data/QSMC_DataProvider.mqh`; `../Data/QSMC_MarketData.mqh`; `../Data/QSMC_DataReadiness.mqh`; `../Analysis/QSMC_Scanners.mqh`; `../SVP/QSMC_SvpCore.mqh`; `../SVP/QSMC_SvpVolumeProfile.mqh`; `../Decision/QSMC_Gates.mqh`; `../Decision/QSMC_OpportunityFunnel.mqh`; `../Decision/QSMC_Arbiter.mqh`; `../Safety/QSMC_Diagnostics.mqh`; `../Safety/QSMC_HealthMonitor.mqh`; `../Safety/QSMC_SafetyController.mqh`; `../Execution/QSMC_ExecutionManager.mqh`; `../Presentation/QSMC_Renderer.mqh`; `QSMC_EventDispatcher.mqh`; `QSMC_Lifecycle.mqh`; `QSMC_Bootstrap.mqh` |
| `Include/QSMC/Core/QSMC_Config.mqh` | 13261 | Immutable-by-convention configuration object plus strict validation. | `QSMC_Constants.mqh`; `QSMC_Types.mqh` |
| `Include/QSMC/Core/QSMC_Constants.mqh` | 2607 | QSMC Quantitative Framework Central compile-time constants and hard caps | None explicit |
| `Include/QSMC/Core/QSMC_InputFingerprint.mqh` | 5545 | Stable, order-sensitive fingerprint of every behaviour-affecting input. | `QSMC_Config.mqh` |
| `Include/QSMC/Core/QSMC_InstanceIdentity.mqh` | 4483 | Per-instance identity. | `QSMC_Constants.mqh`; `QSMC_Version.mqh`; `QSMC_InputFingerprint.mqh` |
| `Include/QSMC/Core/QSMC_Preset.mqh` | 3465 | Risk presets. | `QSMC_Config.mqh` |
| `Include/QSMC/Core/QSMC_Root.mqh` | 7579 | Core context: configuration, fingerprint, identity and the lifecycle state machine. | `QSMC_Version.mqh`; `QSMC_Constants.mqh`; `QSMC_Types.mqh`; `QSMC_Config.mqh`; `QSMC_Preset.mqh`; `QSMC_StateMachine.mqh`; `QSMC_InstanceIdentity.mqh`; `QSMC_InputFingerprint.mqh` |
| `Include/QSMC/Core/QSMC_StateMachine.mqh` | 4546 | Explicit lifecycle state machine. | `QSMC_Types.mqh` |
| `Include/QSMC/Core/QSMC_Types.mqh` | 12888 | Shared value types and error taxonomy Operating mode | None explicit |
| `Include/QSMC/Core/QSMC_Version.mqh` | 1053 | Single source of truth for build identity | None explicit |
| `Include/QSMC/Data/QSMC_DataProvider.mqh` | 5765 | Thin, retrying wrapper over CopyRates / SymbolInfo. | `../Core/QSMC_Constants.mqh`; `../Core/QSMC_Types.mqh` |
| `Include/QSMC/Data/QSMC_DataReadiness.mqh` | 5182 | Gates the pipeline: no readiness, no analysis, no decision. | `../Core/QSMC_Types.mqh`; `QSMC_MarketSnapshot.mqh`; `QSMC_DataValidator.mqh`; `QSMC_TimeframeManager.mqh` |
| `Include/QSMC/Data/QSMC_DataValidator.mqh` | 5175 | Structural validation of bar series and snapshots. | `../Core/QSMC_Types.mqh`; `QSMC_MarketSnapshot.mqh` |
| `Include/QSMC/Data/QSMC_MarketData.mqh` | 7805 | Builds and owns the current MarketSnapshot. | `../Core/QSMC_Constants.mqh`; `../Core/QSMC_Types.mqh`; `QSMC_DataProvider.mqh`; `QSMC_MarketSnapshot.mqh`; `QSMC_DataValidator.mqh`; `QSMC_TimeframeManager.mqh` |
| `Include/QSMC/Data/QSMC_MarketSnapshot.mqh` | 11001 | Immutable view of the market at decision time: three bar series (exec / htf / ltf), quote, spread and symbol contract metadata. | `../Core/QSMC_Constants.mqh`; `../Core/QSMC_Types.mqh` |
| `Include/QSMC/Data/QSMC_TimeframeManager.mqh` | 2131 | Timeframe arithmetic and ordering rules, in one place. | `../Core/QSMC_Types.mqh` |
| `Include/QSMC/Decision/QSMC_Arbiter.mqh` | 3230 | Stable winner selection: highest score; exact opposing tie rejects the opportunity rather than arbitrary long/short priority. | `QSMC_SignalRegistry.mqh`; `QSMC_UnifiedDecision.mqh` |
| `Include/QSMC/Decision/QSMC_ArbiterNotes.mqh` | 380 | Compatibility public include. | `QSMC_Arbiter.mqh` |
| `Include/QSMC/Decision/QSMC_ExecutionRules.mqh` | 2073 | Decision-side geometry checks only. | `../Core/QSMC_Config.mqh`; `QSMC_UnifiedDecision.mqh` |
| `Include/QSMC/Decision/QSMC_Gates.mqh` | 1629 | Fail-closed gates applied before candidate arbitration. | `../Core/QSMC_Types.mqh`; `../Data/QSMC_MarketSnapshot.mqh`; `QSMC_UnifiedDecision.mqh` |
| `Include/QSMC/Decision/QSMC_OpportunityFunnel.mqh` | 6562 | Primary Sweep->MSS->FVG and secondary BOS/CHoCH->OB-retouch models. | `../Analysis/QSMC_Scanners.mqh`; `QSMC_SignalRegistry.mqh` |
| `Include/QSMC/Decision/QSMC_SignalRegistry.mqh` | 1671 | Fixed-capacity candidate and rejection registry for deterministic decision audits. | `../Core/QSMC_Constants.mqh`; `../Core/QSMC_Types.mqh` |
| `Include/QSMC/Decision/QSMC_UnifiedDecision.mqh` | 1581 | Auditable final decision envelope. | `../Core/QSMC_Constants.mqh`; `../Core/QSMC_Types.mqh` |
| `Include/QSMC/Execution/QSMC_AlertManager.mqh` | 868 | Rate-limited terminal alerts for critical system events. | None explicit |
| `Include/QSMC/Execution/QSMC_DemoAdapter.mqh` | 1207 | In-memory simulation adapter. | `QSMC_ExecutionAdapter.mqh` |
| `Include/QSMC/Execution/QSMC_ExecutionAdapter.mqh` | 1083 | Adapter boundary: no decision or analysis code can reach broker APIs; all requests enter through CQSMCExecutionManager. | `../Core/QSMC_Types.mqh` |
| `Include/QSMC/Execution/QSMC_ExecutionJournal.mqh` | 2511 | Fixed-size runtime audit journal plus persisted UID duplicate guard. | `../Core/QSMC_Constants.mqh`; `../Core/QSMC_Types.mqh`; `../Infrastructure/QSMC_StateStore.mqh`; `QSMC_ExecutionAdapter.mqh` |
| `Include/QSMC/Execution/QSMC_ExecutionManager.mqh` | 2594 | Coordinates the order manager and mode-specific adapter. | `QSMC_ExecutionMode.mqh`; `QSMC_OrderManager.mqh`; `QSMC_DemoAdapter.mqh`; `QSMC_RealAdapter.mqh` |
| `Include/QSMC/Execution/QSMC_ExecutionMode.mqh` | 1083 | Explicit execution capability selector. | `../Core/QSMC_Types.mqh` |
| `Include/QSMC/Execution/QSMC_ExecutionPreflight.mqh` | 5709 | Central, fail-closed preflight contract. | `../Core/QSMC_Config.mqh`; `../Core/QSMC_Types.mqh`; `../Data/QSMC_MarketSnapshot.mqh`; `../Safety/QSMC_SafetyController.mqh`; `QSMC_RiskManager.mqh` |
| `Include/QSMC/Execution/QSMC_OrderManager.mqh` | 3279 | Central submission funnel. | `QSMC_ExecutionPreflight.mqh`; `QSMC_ExecutionJournal.mqh`; `QSMC_ExecutionAdapter.mqh` |
| `Include/QSMC/Execution/QSMC_PositionManager.mqh` | 1433 | Read-only ownership-aware position reconciliation. | `../Core/QSMC_Types.mqh` |
| `Include/QSMC/Execution/QSMC_RealAdapter.mqh` | 933 | Deliberately non-operational. | `QSMC_ExecutionAdapter.mqh` |
| `Include/QSMC/Execution/QSMC_RiskManager.mqh` | 5690 | Risk sizing and ownership-scoped account limits. | `../Core/QSMC_Config.mqh`; `../Core/QSMC_Types.mqh`; `../Infrastructure/QSMC_StateStore.mqh` |
| `Include/QSMC/Infrastructure/QSMC_Clock.mqh` | 4760 | Single time authority. | `../Core/QSMC_Constants.mqh`; `../Core/QSMC_Types.mqh` |
| `Include/QSMC/Infrastructure/QSMC_Logger.mqh` | 5866 | Level-filtered logger with an in-memory ring buffer (inspectable from the dashboard and the self-test) and optional append-only text file. | `../Core/QSMC_Constants.mqh`; `../Core/QSMC_Types.mqh` |
| `Include/QSMC/Infrastructure/QSMC_OpportunityAudit.mqh` | 3160 | Append-only per-bar opportunity decisions for reproducible review. | `../Core/QSMC_Constants.mqh`; `../Core/QSMC_Types.mqh` |
| `Include/QSMC/Infrastructure/QSMC_StateStore.mqh` | 7668 | Small, typed persistence layer used for restart recovery. | `../Core/QSMC_Constants.mqh`; `../Core/QSMC_Types.mqh`; `../Core/QSMC_Version.mqh` |
| `Include/QSMC/Infrastructure/QSMC_Stats.mqh` | 3258 | Monotonic runtime counters. | `../Core/QSMC_Types.mqh` |
| `Include/QSMC/Presentation/QSMC_ChartLayers.mqh` | 3558 | Minimal namespaced levels. | `../Core/QSMC_Constants.mqh`; `../Core/QSMC_InputFingerprint.mqh`; `../Analysis/QSMC_Zones.mqh` |
| `Include/QSMC/Presentation/QSMC_Dashboard.mqh` | 4129 | Read-only, instance-namespaced panel. | `../Core/QSMC_Types.mqh`; `../Core/QSMC_Root.mqh`; `../Core/QSMC_InputFingerprint.mqh` |
| `Include/QSMC/Presentation/QSMC_Renderer.mqh` | 1681 | Facade that composes a state-only dashboard and optional chart layers; never changes root, decision or safety state. | `QSMC_Dashboard.mqh`; `QSMC_ChartLayers.mqh` |
| `Include/QSMC/QSMC.mqh` | 3491 | Unified public include. | `Core/QSMC_Constants.mqh`; `Core/QSMC_Types.mqh`; `Core/QSMC_Version.mqh`; `Core/QSMC_Config.mqh`; `Core/QSMC_Preset.mqh`; `Core/QSMC_InputFingerprint.mqh`; `Core/QSMC_InstanceIdentity.mqh`; `Core/QSMC_StateMachine.mqh`; `Core/QSMC_Root.mqh`; `Infrastructure/QSMC_Clock.mqh`; `Infrastructure/QSMC_Logger.mqh`; `Infrastructure/QSMC_StateStore.mqh`; `Infrastructure/QSMC_Stats.mqh`; `Infrastructure/QSMC_OpportunityAudit.mqh`; `Safety/QSMC_Diagnostics.mqh`; `Safety/QSMC_HealthMonitor.mqh`; `Safety/QSMC_IncidentSafety.mqh`; `Safety/QSMC_SafetyController.mqh`; `Data/QSMC_MarketSnapshot.mqh`; `Data/QSMC_DataProvider.mqh`; `Data/QSMC_TimeframeManager.mqh`; `Data/QSMC_DataValidator.mqh`; `Data/QSMC_MarketData.mqh`; `Data/QSMC_DataReadiness.mqh`; `Analysis/QSMC_Structure.mqh`; `Analysis/QSMC_StructurePoints.mqh`; `Analysis/QSMC_Bias.mqh`; `Analysis/QSMC_CandlePatterns.mqh`; `Analysis/QSMC_Zones.mqh`; `Analysis/QSMC_ZoneScorer.mqh`; `Analysis/QSMC_SupplyDemand.mqh`; `Analysis/QSMC_LiquidityValue.mqh`; `Analysis/QSMC_Liquidity.mqh`; `Analysis/QSMC_Reaction.mqh`; `Analysis/QSMC_EarlyBreakDetector.mqh`; `Analysis/QSMC_Sessions.mqh`; `Analysis/QSMC_FairValueGaps.mqh`; `Analysis/QSMC_ICTSetup.mqh`; `Analysis/QSMC_OrderFlowProxy.mqh`; `Analysis/QSMC_ElliottGuide.mqh`; `Analysis/QSMC_BreakOrderBlock.mqh`; `Analysis/QSMC_Scanners.mqh`; `SVP/QSMC_SvpCore.mqh`; `SVP/QSMC_SvpVolumeProfile.mqh`; `SVP/QSMC_SvpZones.mqh`; `SVP/QSMC_SvpLiquidity.mqh`; `SVP/QSMC_SvpDecision.mqh`; `SVP/QSMC_SvpChart.mqh`; `Decision/QSMC_UnifiedDecision.mqh`; `Decision/QSMC_SignalRegistry.mqh`; `Decision/QSMC_Gates.mqh`; `Decision/QSMC_OpportunityFunnel.mqh`; `Decision/QSMC_Arbiter.mqh`; `Decision/QSMC_ExecutionRules.mqh`; `Execution/QSMC_ExecutionMode.mqh`; `Execution/QSMC_ExecutionAdapter.mqh`; `Execution/QSMC_DemoAdapter.mqh`; `Execution/QSMC_RealAdapter.mqh`; `Execution/QSMC_ExecutionJournal.mqh`; `Execution/QSMC_RiskManager.mqh`; `Execution/QSMC_ExecutionPreflight.mqh`; `Execution/QSMC_OrderManager.mqh`; `Execution/QSMC_PositionManager.mqh`; `Execution/QSMC_ExecutionManager.mqh`; `Execution/QSMC_AlertManager.mqh`; `Presentation/QSMC_Dashboard.mqh`; `Presentation/QSMC_ChartLayers.mqh`; `Presentation/QSMC_Renderer.mqh`; `App/QSMC_EventDispatcher.mqh`; `App/QSMC_Lifecycle.mqh`; `App/QSMC_Bootstrap.mqh`; `App/QSMC_Orchestrator.mqh` |
| `Include/QSMC/SVP/QSMC_SvpChart.mqh` | 782 | SVP presentation summary. | `QSMC_SvpCore.mqh` |
| `Include/QSMC/SVP/QSMC_SvpCore.mqh` | 10150 | SVP = Session Volume Profile. | `../Core/QSMC_Constants.mqh`; `../Core/QSMC_Types.mqh`; `../Data/QSMC_MarketSnapshot.mqh` |
| `Include/QSMC/SVP/QSMC_SvpDecision.mqh` | 3473 | Value-area permission model: where is price relative to value, and does that permit longs, shorts or neither?  SPEC NOTE: these are conservative, documented reference rules: above VAH  -> longs favoured, shorts discouraged below VAL  -> shorts favoured, longs discouraged inside VA  -> both permitted at reduced score They are not presented as an official QSMC specification. | `../Core/QSMC_Types.mqh`; `QSMC_SvpCore.mqh` |
| `Include/QSMC/SVP/QSMC_SvpLiquidity.mqh` | 3455 | Exposes POC / VAH / VAL / profile extremes as liquidity levels so the decision layer can reason about them uniformly with swing levels. | `../Core/QSMC_Constants.mqh`; `../Core/QSMC_Types.mqh`; `../Analysis/QSMC_LiquidityValue.mqh`; `QSMC_SvpCore.mqh` |
| `Include/QSMC/SVP/QSMC_SvpVolumeProfile.mqh` | 3792 | Read-only interpretation layer over CQSMCSvpCore: value area stats, price location and profile shape. | `../Core/QSMC_Types.mqh`; `QSMC_SvpCore.mqh` |
| `Include/QSMC/SVP/QSMC_SvpZones.mqh` | 4344 | Converts high-volume nodes into support/resistance style zones so that SVP evidence can enter the same zone-ranking pipeline as structure-derived supply/demand zones. | `../Core/QSMC_Constants.mqh`; `../Core/QSMC_Types.mqh`; `../Analysis/QSMC_Zones.mqh`; `QSMC_SvpCore.mqh` |
| `Include/QSMC/Safety/QSMC_Diagnostics.mqh` | 5222 | Structured, bounded diagnostic sink. | `../Core/QSMC_Constants.mqh`; `../Core/QSMC_Types.mqh` |
| `Include/QSMC/Safety/QSMC_HealthMonitor.mqh` | 7498 | Read-only environment probe: terminal/account/symbol permissions, quote freshness and spread sanity. | `../Core/QSMC_Constants.mqh`; `../Core/QSMC_Types.mqh` |
| `Include/QSMC/Safety/QSMC_IncidentSafety.mqh` | 2482 | Persistent incident latch. | `../Core/QSMC_Types.mqh`; `../Infrastructure/QSMC_StateStore.mqh` |
| `Include/QSMC/Safety/QSMC_SafetyController.mqh` | 3912 | Central fail-closed permission gate. | `../Core/QSMC_Config.mqh`; `../Core/QSMC_Root.mqh`; `../Infrastructure/QSMC_StateStore.mqh`; `QSMC_HealthMonitor.mqh`; `QSMC_IncidentSafety.mqh` |
| `README.md` | 5020 | Project capabilities, safety limits, installation and verification status. | `Docs/ARCHITECTURE.md`; `Docs/MODULE_CONTRACTS.md`; `Docs/INSTALLATION.md`; `Docs/TESTING.md`; `Docs/CONFIGURATION.md` |
| `Scripts/QSMC_Phase1_Test.mq5` | 425 | Script smoke test of root initialization, preset application and shutdown. | `QSMC/QSMC.mqh` |
| `Scripts/QSMC_Selftest.mq5` | 280 | Script entry point invoking the deterministic self-test harness. | `QSMC/QSMC.mqh`; `../Tests/Harness/QSMC_Selftest.mqh` |
| `Tests/Harness/QSMC_Selftest.mqh` | 15834 | Deterministic, terminal-independent checks for pure contracts. | `QSMC/QSMC.mqh` |
| `Tests/StrategyTester/README.md` | 2105 | Manual Strategy Tester scenario guidance. | None explicit |
| `Tests/oos_evaluate.py` | 5496 | Chronological descriptive forward-return report for exported opportunity CSVs. | `__future__`; `argparse`; `collections`; `csv`; `datetime`; `pathlib`; `statistics` |
| `Tests/static_check.py` | 5234 | Local include, header-guard and delimiter sanity checker; not an MQL compiler. | `__future__`; `pathlib`; `re`; `sys` |

The additional deliverable `docs/00_INVENTORY.md` is this Phase 0 report. Its
evidence dependencies are the 93 files inventoried above, especially the referenced
runtime source modules. Its own byte size is recorded below.

## Verification and environment

- `python3 Tests/static_check.py`: **PASS**, 79 sources inspected; non-empty sources,
  include resolution, guards and delimiter structure pass. This is not an MQL
  compiler or runtime test and cannot establish a zero-warning build.
- `command -v metaeditor64.exe` / `command -v wine`: neither tool is on PATH in this
  environment. No MetaEditor compilation was run. **Compiler error count: unknown;
  compiler warning count: unknown.** No compiled EX5 or compile log was supplied.
- No Strategy Tester, broker session, real order, fill, self-test execution, or
  persistence fault-injection test was run. Production-readiness criteria remain open.
- In Phase 1, use the actual installed EA path. If installed according to this repo:

```bat
metaeditor64.exe /compile:"<path>\MQL5\Experts\QSMC\QSMC.mq5" /log:"<path>\compile.log"
```

If deliberately installed flat at the mission's suggested location instead:

```bat
metaeditor64.exe /compile:"<path>\MQL5\Experts\QSMC.mq5" /log:"<path>\compile.log"
```

Replace `<path>` with the terminal data-directory parent appropriate to the actual
installation and use the full MetaEditor executable path if it is not on PATH.

## Phase 0 reporting / Checkpoint 0

1. **Done:** enumerated every tracked file, its bytes, responsibility and direct
   dependencies; mapped the active lifecycle and the disconnected execution boundary;
   answered (a)–(h); recorded all requested code-search counts and locations.
2. **Files changed in this phase:** only new `docs/00_INVENTORY.md`, to deliver the
   requested inventory. No implementation finding IDs assigned or fixes made;
   QSMC-001-style severity triage belongs to Phase 2. Earlier working-tree edits are
   listed above and are not represented as new Phase 0 fixes.
3. **Compile:** unavailable/not run; errors and warnings unknown. Structural check
   passed, not a substitute for MetaEditor.
4. **Open decisions:** approve Checkpoint 0; provide a MetaEditor compile log in
   Phase 1; confirm actual installed path if different from the repository layout.
   Broker-specific gold contract data and safety-behavior choices are deferred to
   later approved phases. No trading gate is enabled and no order is sent.
5. **Proposed next step:** Phase 1 baseline compile only, after approval. No Phase 2
   audit fixes or later implementation begins before the specified checkpoints.

**STOPPED AT CHECKPOINT 0 — awaiting user approval.**

Report byte size (UTF-8, including this line): 43223 bytes.
