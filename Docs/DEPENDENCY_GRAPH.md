# Dependency Graph

```text
Core
 ├── Infrastructure (Clock, Logger, StateStore, Stats)
 ├── Data (Provider, Snapshot, Validator, Readiness, Timeframes)
 │    └── Analysis (Structure, Bias, Zones, Liquidity, Reaction, SVP)
 │          └── Decision (Gates, Funnel, Registry, Arbiter)
 │                └── Execution boundary (Risk, Preflight, Manager, Adapter)
 ├── Safety (Diagnostics, Health, Incident, SafetyController) ──┐
 └── Presentation (Dashboard, ChartLayers, Renderer)             │
                                                                 ↓
App (Bootstrap, Lifecycle, EventDispatcher, Orchestrator) composes modules
```

Layer direction: lower layers never include App. Analysis does not depend on Decision. Decision does not call execution. Execution requires a validated intent and SafetyController. Safety is cross-cutting and does not receive authority from Presentation. Presentation can display state but cannot change lifecycle or permission flags. App is the only normal composition root.

`Include/QSMC/QSMC.mqh` is a public aggregation header. Individual modules use relative includes to lower-level contracts. The aggregator may list every public module without changing ownership/dependency direction.

Current practical note: the analysis and presentation layers have direct type includes for zone data; the renderer remains read-only. Core now includes pure OwnerScope/policy helpers; Infrastructure includes typed StateCodec and scoped StateStore. SafetyController owns EntryFilters, which composes NewsFilter and pure schedule/news policy; it does not send orders. Execution includes read-only TradeReconciler/RiskRecovery and compile-gated dormant broker request code. REAL manager and the literal-false release interlock still block use; no normal App intent route was added. MQL include/API compatibility remains unverified without MetaEditor. The public test wrappers are separate entry points, not alternative execution authorities.
