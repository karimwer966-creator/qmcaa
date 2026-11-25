# Testing

## Current Phase 7 entry points and evidence boundary

- Strict host runner: `python3 -B Tests/run_host_checks.py --report docs/phase7_host_results.json`.
  Requires Python >=3.10, g++ (C++17) and cpp. Missing tools/skips mean INCOMPLETE,
  not PASS. The JSON fingerprints source/tests/presets/fixtures, including dirty work.
- Pure terminal script: `Scripts/QSMC_SafetySelftest.mq5`; tester-only wrapper:
  `Experts/QSMC/QSMC_SafetySelftest.mq5`. Both invoke the same 42-check pure safety
  harness without state/calendar/order activity. Neither has been compiled/run here.
- Gold sets: `Presets/QSMC_Gold_Conservative.set` (0.25%) and
  `Presets/QSMC_Gold_Balanced.set` (0.50%), both ANALYSIS. See Presets/README.md.
- Authoritative current terminal instructions/matrix: Tests/StrategyTester/README.md.
  results_template.csv begins with every scenario NOT_RUN. No terminal pass inferred.
- The historical phase sections below are regression context, not proof of current
  automatic enrollment or complete recovery. Phase 6 supersedes first-peak seeding:
  missing account/day baselines must block; clean-day enrollment is explicit.
  Do not treat a pure arithmetic test as permission to initialize real safety state.

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

## Refresh and partial-initialization regression scenarios

- In a running instance, make history temporarily unavailable at a new execution
  candle. Restore history before the next candle: the next timer must retry and
  analyze the closed candle exactly once rather than wait for another new bar.
- Force a scanner failure on a closed candle, then restore its prerequisites.
  Confirm that the failed candle was not committed as analyzed and the timer
  retries it. After success, further timer events must not duplicate its audit.
- Force initialization to fail after provider allocation (for example, timer
  setup failure). Confirm MT5's `OnDeinit(REASON_INITFAILED)` releases the provider,
  stops the timer and removes chart objects despite the EA started flag being false.
- A health block or incident latch must still prevent retries from doing analysis
  in SAFE_MODE. Recovery continues to require explicit restart; these changes do
  not enable automatic safety recovery or broker order submission.

These regression scenarios require MetaTrader and have not been run here.

## Phase 4 risk/safety regression checks

Host command: `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Tests -p 'test_*.py' -v`.
The C++ shim tests execute the actual pure RiskMath and IncidentSafety headers,
not a Python formula mirror. They do **not** compile MQL or validate broker APIs,
terminal globals, real file failures, or restart durability. The incident test
uses a fake store/clock with write-failure injection.

Required terminal scenarios (not run here):

- Capture equity 10,000 → 11,000 → 9,000 with a new store; confirm first peak is
  written, final peak remains 11,000 and drawdown is about 18.18% after reload.
  DEMO/REAL-mode risk monitoring runs on operational timer events without intents;
  ANALYSIS/OFF do not write risk peaks. Peaks between samples remain unknowable.
- Verify loss-side tick value and OrderCalcProfit fallback on actual XAUUSD broker
  metadata. Test equity below balance, unavailable/NaN/zero metadata, sub-minimum
  budgets, quarter/nondecimal/fine volume steps and nonaligned caps. No rounding
  may increase lots or exceed the equity risk budget. `SizeLots` riskMoney now
  reports actual planned stop loss; execution independently recalculates it.
- Preflight must reject future/stale quotes, wrong-side SL/TP, invalid volume,
  excessive spread and exact zero-deviation violations. It must use fresh
  Bid/Ask stops distances and bound risk at adverse deviation, without changing SL.
- Margin reserve after estimated entry margin must be at least
  `max(10% of current equity, planned stop risk)` (user-approved policy).
  Check equality and just-below boundaries, calc failure and invalid free margin.
- Trigger a daily-loss or drawdown breach with no pending intent. Verify timer
  latches the brake and moves RUNNING to SAFE_MODE; subsequent equity recovery
  must not auto-resume. Capacity/free-margin vetoes alone are not permanent latches.
- Restore each safety flag independently from a freshly loaded store; malformed
  flags block. Inject full-store, save and GV-set failures: latch return must
  indicate failure while in-memory permission remains blocked. Failed explicit
  acknowledgement must not release the in-memory brake. Pending broker intent
  must prevent acknowledgement even when operatorConfirmed is true.
- Confirm no OrderSend/OrderCheck in no-trading-define builds and that the release
  interlock stays false under all flag combinations. No test requires an order.

Schema validation, atomic file replacement, exclusive/stable ownership, daily
baselines/history reconstruction and authoritative pending recovery remain Phase 6
work; these tests must not be represented as restart-durability certification.

## Phase 5 entry safeguards

The host unittest command above additionally executes the actual EntryTimeRules
and NewsPolicy headers under C++ string shims: all 10,080 minutes of a week with
sessions both on/off, midnight/exclusive-end behavior, overlapping sessions,
Friday 20:00, rollover boundaries, inclusive +/-30-minute news windows, exact
15-minute cache expiry, missing coverage, backwards clocks, USD scoping and
case-insensitive keyword handling. A source-shape test checks entry-only wiring.
These do NOT exercise MT5 Calendar APIs or FILE_CSV parsing.

Required terminal regressions (NOT run here):

1. Compile EA and script with no trading defines. Run existing and added self-tests.
2. With a controlled calendar/test feed, test USD HIGH, unknown HIGH name,
   lower-importance keyword matches, EUR HIGH, multiple overlapping events,
   all-day/tentative relevant events, invalid event metadata, calendar timeout,
   truncated results, zero-result success and stale-cache expiry. Errors must
   block entries; relevant uncertain-time events conservatively block throughout
   the intersecting server-day query, rather than assuming midnight is the release.
3. In a tester agent, copy `Tests/Fixtures/news_synthetic_example.csv` into its
   MQL5/Files directory and set InpTesterNewsCsv to that relative path/name. This
   is an ARTIFICIAL January 2001 test fixture, NOT historical or deployable news.
   Dynamic input filenames are not automatically transferred to every agent;
   provision every local/remote agent explicitly. Missing files block entries.
4. Check missing/blank path, bad row length, malformed timestamp, unsorted dates,
   bad importance, missing coverage, oversized file and coverage ending before
   now+30 minutes. Test LF/CRLF and final newline handling in the actual terminal.
   A valid coverage-only file asserts there are no known events; accuracy and
   completeness are the dataset provider's responsibility, not proven by parsing.
5. Test around 12:00 synthetic HIGH and 12:15 synthetic Fed-keyword events.
   Blackout includes both exact endpoints. Test news directly or use a controlled
   session setting so a session veto is not mistaken for a news-test pass.
6. Test sessions at submission, not candle-open time, including 23:00-01:00,
   overlapping sessions, exact session end, Friday 19:59/20:00 and Sunday. A
   blocking calendar fetch crossing a cutoff must not retain earlier permission.
7. Simulate server-UTC offset changes and backwards server clock. Verify warning
   and news-cache invalidation, with NO automatic strategy-session shift. Tester
   offset diagnostics must explicitly disclose they cannot infer historical DST.
8. Verify entry blackouts do not call EmergencyStop, prevent MonitorRisk,
   gate trade-event logging/reconciliation or force-close/modify positions.
   Calendar calls are synchronous and can delay this EA's event thread; measure
   platform latency before release, even though no risk gate depends on news.
9. Confirm startup contract/price-unit logs against two brokers' actual metadata
   and selected symbol suffix. Existing point thresholds are unchanged.

The no-argument CanSubmitOrders compatibility accessor now always returns false;
root-aware CanSubmit(root,why) is the authoritative refreshed entry gate. News
is evaluated lazily at submission or explicit ProbeEntryFilters, not on every
analysis timer. A displayed analytical signal or 'not evaluated' filter status
must never be interpreted as entry permission. See docs/04_GOLD_FILTERS_CHECKPOINT.md
for the CSV schema, policy and remaining release blockers.

## Phase 6 persistence and ownership regressions

Run the same host unittest command. Added actual OwnerScope/StateCodec C++ shim
checks and actual RiskRecovery replay with a fake broker: partial exits,
idempotence, complete trade versus deal counts, net-loss streaks, SL/TP final
exits, live-volume matching, missing entry history, reversal/overclose, unordered
history, cash-flow veto and replay capacity. Source checks forbid destructive
snapshot deletion and automatic pending clearance. These do NOT test MT5
FileOpen/FileMove/FileFlush, common-files locking, crash recovery or broker
history completeness.

Required terminal tests (NOT run):

- Compile EA, QSMC_Selftest and QSMC_EnrollRisk with no trading defines. Updated
  self-test expects changed fingerprints to preserve owner magic, a read-only
  reload to recover the latch, and a second writer claim to fail. Test cleanup
  removes only the synthetic common-files snapshot slots after closing handles.
- Change chart, timeframe, version and ordinary inputs: explicit owner magic and
  raw account/server/symbol/magic scope must remain stable. Change each owner
  field: scope must differ. Cosmetic drift must not reset state or latches.
- Two charts and two terminals sharing common files must not both claim the same
  operational owner. Kill/crash the first process: OS must release its handle;
  no time-based stale-claim stealing is allowed. Missing common-directory access
  must fail closed. Independent owner scopes contend briefly on account risk;
  unavailable account claims conservatively veto/latch rather than read unlocked.
- Start with legacy local/common state files or an active old numeric-magic kill
  GV: operational startup must refuse without renaming, deleting or adopting them.
  Verify conflicts/missing state with existing orders/positions. ANALYSIS is
  read-only and cannot write, acknowledge or release another owner's store.
- Inject short writes, full disk, flush/move/open failures and crashes before and
  after staging, seal verification and slot replacement. Prior valid slots must
  never be deleted or overwritten in place. Staging or either corrupt slot must
  block initialization; no silent fallback to an older guard/counter is permitted.
- Reject schema mismatch, wrong raw scope despite matching hash filename, duplicate
  keys, malformed scalar/type, bad count/footer/checksum and unsupported generation.
  Test UTF-16 BOM/CRLF and EOF behavior in the actual terminal.
- Stop all owning EAs before explicitly reviewing enrollment on an isolated clean
  account/day. The script requires flat/no-orders/no-deals-today and an exact review
  token. It must not reset an existing current-day baseline, clear any latch/pending
  marker or repair a poisoned/legacy/review-required account. Missing next-day
  baseline blocks rather than silently choosing a late-day replacement.
- Across restart, confirm account-wide equity peak is shared by different owner
  scopes, daily baseline stays scoped, reconstructed daily entry count never lowers
  committed submission count, and cooldown uses the later committed/replayed entry.
- Missing entry history, unexpected nontrade account deals after enrollment,
  invalid volumes or bounded-replay overflow must refuse capture. Persistent
  account review markers must survive restart; enrollment cannot clear them.
- An unresolved pending UID must restore an uncertain latch and remain untouched
  by replay, ring rollover, day changes and ordinary acknowledgement. Broker
  response metadata may be saved but never certifies lifecycle reconciliation.

No file-system/crash or restart-durability result is claimed. See
`docs/05_PERSISTENCE_CHECKPOINT.md` for the conservative manual-day workflow,
known limitations and outstanding release validation.
