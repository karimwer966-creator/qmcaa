# QSMC — MQL5 analysis and safety-hardening prototype

> **NOT APPROVED FOR BROKER TRADING.** Default `ANALYSIS`; `DEMO` is in-memory paper simulation, not a broker demo order. `REAL` remains refused. Both trading defines ship commented out and a separate literal-false release interlock stays closed. Changing an input, acknowledgement or legacy macro does not release execution.

The main EA builds three-timeframe closed-bar snapshots, runs heuristic analysis,
records model/arbiter reasons and renders diagnostics. It does **not** construct
and submit normal order intents. Gated OrderCheck/OrderSend foundation code exists,
but the broker path is intentionally unreachable and unverified.

## Verification status

- **16 host tests passed, zero skipped**, including actual MQL-compatible helper
  headers under C++ shims/fake stores/broker history; static structure checks cover
  **94 MQL files**. See [host evidence](docs/phase7_host_results.json).
- **MQL compile errors/warnings UNKNOWN.** No MetaEditor/MT5/Wine available here.
- The 42-check MQL safety suite, preset imports, calendar/CSV behavior, file locks,
  crash/restart recovery, backtests and forward-demo tests are **NOT RUN**.
- Host PASS is not a trading release, a compile certificate or profitability evidence.
  Open analytical audit findings remain; no strategy correctness claim is made.

## Implemented source foundations

- EA lifecycle/timer/data readiness, retry discipline, state-only presentation and
  auditable heuristic model/arbiter outputs. Scores are not calibrated probabilities.
- Equity-based sizing using loss-side tick value/OrderCalcProfit fallback, strict
  volume flooring, fresh preflight and approved post-margin reserve.
- Entry-only USD high-impact/keyword ±30-minute news, coverage/cache checks, current
  sessions, rollover/weekend/Friday controls and manual DST diagnostics.
- Stable explicit-magic ownership; full raw account/server/symbol/magic scope;
  exclusive writer claims; typed, sealed schema-2 common-files snapshots.
- Bounded history replay, persistent uncertainty/pending guards and reviewed risk
  enrollment. These are conservative foundations, not complete broker recovery.

## Start with isolated analysis only

1. Read [deployment](Docs/DEPLOYMENT.md) and [known limitations](Docs/KNOWN_LIMITATIONS.md).
2. Copy Include/QSMC, Experts/QSMC, Scripts and Tests/Harness into corresponding
   MQL5 folders; do not install the whole repository blindly.
3. Compile every entry point and inspect complete logs; target zero errors/warnings.
4. First run the separate pure safety script/tester expert in an isolated terminal.
5. Load a [gold analysis preset](Presets/README.md), verify imported inputs and keep
   ANALYSIS. Inspect exact symbol/suffix, broker contract, costs and server clock.

| Gold set | Equity risk | Default mode |
|---|---:|---|
| [Conservative](Presets/QSMC_Gold_Conservative.set) | 0.25% | ANALYSIS |
| [Balanced](Presets/QSMC_Gold_Balanced.set) | 0.50% | ANALYSIS |

Both retain owner magic 53000001. Do not switch magic, remove state artifacts or
clear latches to make a blocked configuration run. Presets do not migrate legacy
positions, supply news coverage, enroll baselines or authorize trading.

## Host checks

```sh
python3 -B Tests/run_host_checks.py --report docs/local_host_results.json
```

Requires Python >=3.10, g++ (C++17) and cpp. Exit 0 = host PASS, 1 = FAIL,
2 = INCOMPLETE (missing tools/skips/zero test discovery). Source hashes label dirty
work as well as Git HEAD. No terminal execution is performed by this command.

## Operator boundaries

- Missing/stale news blocks prospective entries; the synthetic CSV is not real news.
- Missing/ambiguous account/day baselines block. Automatic day rollover, general
  migration/recovery release, verified history compaction and pending clearance
  are **unsupported**. Clean-day enrollment is explicit and leaves latches intact.
- No forced Friday close, protective close/modify system, automatic retry, martingale,
  grid, averaging down, recovery hedge or SL widening/removal was introduced.
- Equity/risk formulas cannot guarantee maximum realized loss through gaps,
  commissions or broker execution beyond a checked price bound.

## Documentation map

- [Configuration](Docs/CONFIGURATION.md), [architecture](Docs/ARCHITECTURE.md),
  [execution safety](Docs/EXECUTION_SAFETY.md), [migration restrictions](Docs/MIGRATION_PLAN.md).
- [Terminal matrix](Tests/StrategyTester/README.md), [test context](Docs/TESTING.md),
  [changelog](Docs/CHANGELOG.md), [final checkpoint](docs/07_FINAL_HANDOVER.md).
- [Historical inventory](docs/00_INVENTORY.md) and [38-finding audit](docs/01_AUDIT_REPORT.md)
  describe the pre-remediation baseline. Later checkpoint reports document source
  changes; **no finding is certified closed** by host checks alone.

`Docs/` and `docs/` are distinct repository paths with a known Windows casing risk.
They were not renamed in this task. Follow exact links in a case-sensitive checkout;
copy MQL source subtrees selectively and review any case-insensitive checkout conflicts.
