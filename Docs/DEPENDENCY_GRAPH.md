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

Current practical note: the analysis and presentation layers have direct type includes for zone data; the renderer is still read-only. The execution manager has no live broker implementation. Include graph must be checked in MetaEditor because no MQL compiler was present here.
