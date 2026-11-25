# Phase 7 terminal validation plan

**All terminal results are NOT RUN.** Host PASS is not MQL compilation, a backtest,
restart validation or a trading release. Do not enable either trading define or
change the literal-false release interlock. None of these tests requires a real
order or a funded live account. Do not run destructive fault tests on production
state or a terminal sharing production Common/Files.

## Evidence and environment

Use an isolated MT5 installation/OS profile and dedicated demo/tester environment.
Record terminal/MetaEditor build, source hashes, broker server (no credentials),
hedging/netting mode, exact symbol suffix, runtime contract summary, timeframe,
server clock/UTC offset, test dates, tick model, input set and dataset provenance.
Use the same source revision for compiler logs and runtime evidence. Save Experts/
Journal/tester logs and exported inputs/report. Redact credentials and identifiers
before sharing. A successful OnInit alone is not a test pass.

Copy the repository's Include/QSMC, Experts/QSMC, Scripts and Tests/Harness trees
into the corresponding MQL5 subdirectories; relative test includes must resolve.
Presets can be loaded from their repository location via Inputs -> Load. Provision
news CSV separately into each tester agent's MQL5/Files sandbox when required.

Compile every entry point individually, preserving separate logs:

```text
metaeditor64.exe /compile:"<path>\MQL5\Experts\QSMC\QSMC.mq5" /log:"<path>\main_compile.log"
metaeditor64.exe /compile:"<path>\MQL5\Experts\QSMC\QSMC_SafetySelftest.mq5" /log:"<path>\safety_ea_compile.log"
metaeditor64.exe /compile:"<path>\MQL5\Scripts\QSMC_SafetySelftest.mq5" /log:"<path>\safety_script_compile.log"
metaeditor64.exe /compile:"<path>\MQL5\Scripts\QSMC_Selftest.mq5" /log:"<path>\full_selftest_compile.log"
metaeditor64.exe /compile:"<path>\MQL5\Scripts\QSMC_Phase1_Test.mq5" /log:"<path>\phase1_compile.log"
metaeditor64.exe /compile:"<path>\MQL5\Scripts\QSMC_EnrollRisk.mq5" /log:"<path>\enrollment_compile.log"
```

Target zero errors and warnings. Read the log contents: MetaEditor's process exit
alone does not prove compilation succeeded. Compiling enrollment is NOT approval
to run it. No compile result is available from this workspace.

## Pure safety self-test (no state side effects)

Run Scripts/QSMC_SafetySelftest on a chart, or select the separate
QSMC/QSMC_SafetySelftest expert in Strategy Tester, use a short supported historical
interval with valid ticks, single run, optimization OFF. No preset is needed.
Expected journal marker: `QSMC SAFETY SELFTEST passed=42 failed=0`; inspect every
PASS/FAIL line. The tester expert returns custom criterion 1 only when its executed
checks have zero failures. Failure/no marker/no run is not PASS. The EA wrapper
refuses normal non-tester attachment; the script is the chart diagnostic entry.

Checks cover pure gates, equity/volume/margin/peak math, retcodes/filling/stops,
time/news policy, raw scope and scalar schema. They do not call the calendar,
state store, broker, enrollment or an order adapter. Included utility classes
contain unused environment methods; this is a test of explicitly invoked pure
contracts, not formal call-graph certification.

The older Scripts/QSMC_Selftest is a broader integration/analysis fixture harness.
It DOES create/delete synthetic common-files snapshots and a test GV. Run it only
in an isolated environment. Its analytical fixtures include historical audit
limitations; passing them would not certify strategy correctness. Never interpret
pure peak arithmetic as permission to seed an unreviewed production peak.

## Scenario matrix

Each row starts NOT_RUN in results_template.csv. Record PASS only with the stated
observable evidence; SKIP/BLOCKED/INCONCLUSIVE are not release passes. Fault-injection
rows require a controlled harness/environment; those injectors are not supplied
as ready-to-run production tools. Do not improvise faults against real state.

| ID | Setup / fault | Required evidence |
|---|---|---|
| C01 | Compile all six entry points, no defines | Individual complete logs, zero errors/warnings |
| P01 | Pure safety script and tester expert | Both 42/0 markers; no orders or state writes |
| P02 | Broader self-test script | Complete pass/fail output and isolated test-artifact cleanup |
| A01 | Main EA, both gold sets separately in ANALYSIS, >=600 M5/M15/H4 bars | Correct loaded inputs/effective config; ready/RUNNING; zero broker requests; no operational enrollment |
| A02 | Missing/short history; restore within same closed candle | Readiness veto, retry, exactly one successful scan per closed candle |
| A03 | Mutate bar zero only, prefix replay | Closed-bar decisions unaffected; no lookahead claim without fixture evidence |
| G01 | OFF/ANALYSIS/DEMO/REAL; netting and hedging fixtures | No broker submission; REAL refused; paper outcomes explicitly simulated; netting unsupported |
| R01 | Equity below balance; min/step/max; invalid tick loss value; fallback; NaN/zero | Strict equity budget/flooring; missing minimum budget rejects; failed fallback rejects |
| R02 | Exact spread/deviation/stops/margin boundaries, stale/future tick | Fresh-side checks; max(10% equity, stop risk) reserve; no SL widening/repair |
| N01 | USD HIGH/keywords, EUR HIGH, overlapping releases, +/-30m endpoints | Explicit matched event/time reasons; USD scope; inclusive boundaries |
| N02 | Missing/bad CSV, missing coverage, uncertain calendar time, timeout/stale cache | Entry veto; no inactive-news fallback; no stale success; no risk-monitor veto |
| T01 | Midnight sessions, overlaps, Friday 19:59/20:00, rollover 23:45/01:15, weekend | Current submission-time veto/permission; no forced close |
| T02 | UTC offset change/backwards clock; tester historical clocks | Warning/cache invalidation; manual DST review; no automatic session shift |
| S01 | Stable config/chart/timeframe changes; raw owner-field changes | Same owner retains latches/counters; raw scopes differ when ownership differs |
| S02 | Duplicate writer, two terminals, owner process crash | No concurrent same-scope writers; OS release; no stale-lock stealing |
| S03 | Stage/flush/replace/open/full-disk faults; corrupt either slot | No destructive fallback; staging preserved; invalid/ambiguous load blocks |
| S04 | Wrong schema/scope, duplicate keys, malformed types/footer/generation | Refusal before state can authorize an entry |
| S05 | Legacy files/kill GVs, existing exposure with missing state | Operational refusal; no import, delete or takeover |
| S06 | Reviewed clean-day enrollment, partial commit, restart and next day | No reset of same-day baseline/latch; missing next-day baseline blocks; no guessed rollover |
| H01 | Partial fills/exits, fees/swap, closed lifecycles, missing history, replay overflow | Trade/deal counts distinct; idempotent counters; uncertainty/review marker persists |
| H02 | Uncertain UID, replay/restart, >16 recent UIDs, day change | Pending marker survives ring/day/replay; no retry or ordinary acknowledgement clearance |
| L01 | Init failure after resource allocation; disconnect and recovery | Timer/provider/object cleanup; SAFE_MODE never auto-resumes |
| O01 | Chronological in/out-of-sample analysis across regimes | Provenance, costs and untouched split recorded; no fill/profitability inference |

A01 is analytical execution only: the main app does not construct/submit normal
intents, so zero orders from that run alone does not test the dormant broker
boundary. There is no fake OrderSend fault-injection terminal harness supplied.
Broker-path integration and full crash/restart validation remain release blockers.
Any future compile-only switch-matrix validation must happen in a separate local
copy without attaching/running it; this task does not enable switches in the repo.

## Historical/OOS evidence

Use multiple spread/volatility regimes and at least two actual gold contract
specifications; do not change strategy thresholds or tune against the holdout to
force acceptance. The existing Tests/oos_evaluate.py studies descriptive
close-to-close forward returns, not realistic fills/stops or portfolio P/L.
Record input hashes, broker data source, timestamp/DST convention and assumptions.
No market dataset, backtest, forward-demo run or performance evidence is supplied.

## Acceptance boundary

Host checks: `python3 -B Tests/run_host_checks.py --report <local-evidence.json>`.
Requires Python >=3.10, g++ with C++17 and cpp. Missing tools or skipped tests mean
INCOMPLETE (exit 2); failed suite means FAIL (exit 1). PASS (exit 0) is host-only.
JSON records tool versions, branch/HEAD, dirty status and SHA-256 of code/tests/
sets/fixtures so uncommitted changes are identifiable. Hashes are evidence labels,
not signatures or a compile certificate.

Keep unresolved audit findings, unsupported Phase 6 recovery workflows, manually
reviewed day-baseline requirements and terminal NOT_RUN status visible. Phase 7
prepares validation; it does not authorize changing defines, arming the executor,
placing demo/live broker orders or opening the release interlock.
