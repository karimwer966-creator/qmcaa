# Checkpoint 7 — tests and gold analysis presets

Date: 2026-11-25. Phase 7 approved. **This prepares and runs host validation; it does not certify MQL compilation or approve trading.** No production trading/risk/strategy logic was changed in this phase.

## Deliverables

### Gold sets

- `Presets/QSMC_Gold_Conservative.set`: existing CONSERVATIVE profile, **0.25% equity risk**.
- `Presets/QSMC_Gold_Balanced.set`: existing BALANCED profile, **0.50% equity risk**.
- `Presets/README.md`: effective values, loading instructions and broker/ownership caveats.

Both files explicitly contain all **59 current main-EA inputs**, ANALYSIS mode, blank real acknowledgement, closed bars, session safeguards and Friday 20:00 cutoff. They use the same explicit magic 53000001 so changing profiles does not select a fresh safety owner. Empty symbol inherits the exact chart broker symbol/suffix; tester CSV is deliberately blank, not silently populated with synthetic news.

`InpOverridePresetRisk=false` makes the selected built-in profile authoritative. Risk/geometry inputs displayed in each set also match that built-in profile. Tests check every risk assignment against the actual preset source and enforce risk <=0.5%, one position, no optimization ranges and complete input-name coverage. The generic AGGRESSIVE profile was not changed and is not delivered as a gold set.

Existing point-based spread/deviation/tolerance thresholds and broker-server session assumptions were not converted or tuned. These are conservative starting analysis settings, not universal gold contract limits, optimized parameters or evidence of profitability. MT5 import must still be checked; no preset was loaded in a terminal here.

### Separate pure safety self-test

Added:

- `Tests/Harness/QSMC_SafetySelftest.mqh` — 42 explicitly invoked pure checks.
- `Scripts/QSMC_SafetySelftest.mq5` — chart/script entry point.
- `Experts/QSMC/QSMC_SafetySelftest.mq5` — tester-only wrapper with custom criterion.

The same harness covers compile/account/acknowledgement/release policy, equity sizing, volume floors, peak arithmetic, margin reserve, retcodes/filling/tick-grid/stops, session/rollover/weekend/Friday boundaries, news windows/cache/keywords, owner scope and typed schema/UID limits. It does not invoke account, state, calendar, enrollment or order APIs. Source-shape tests reject direct side-effect API calls in these three files; this is not formal call-graph proof.

Expected terminal marker after an actual successful run: `QSMC SAFETY SELFTEST passed=42 failed=0`. **No such terminal result is claimed.** A source-level check count is not a test run. This pure suite does not certify restart durability, complete history reconstruction, realistic broker execution or strategy correctness.

The existing broader self-test remains available and retains synthetic state-file side effects and historical analytical fixture limitations. It is not silently replaced by a green pure-safety suite. Use only an isolated terminal for it; never treat known analytical fixtures as proof that open strategy audit findings are fixed.

### Strict repeatable host runner

`Tests/run_host_checks.py` runs unittest discovery with bytecode disabled and records optional JSON evidence. Requirements: Python >=3.10, g++ with C++17, cpp.

```text
python3 -B Tests/run_host_checks.py --report docs/phase7_host_results.json
```

- Exit 0: host PASS with no skipped tests and required tools present.
- Exit 1: failing suite.
- Exit 2: incomplete (missing tools, skipped tests, absent/zero test count).

The JSON records environment/tool versions, branch/HEAD, dirty-worktree status and SHA-256 of code/tests/presets/CSV fixtures. This identifies uncommitted source, not merely the base Git commit. It explicitly marks MQL compilation and terminal tests NOT RUN, and broker execution blocked/not run. No secrets or full environment dump are collected. Hashes are evidence labels, not authentication or compile certificates.

Added `Tests/test_presets.py` for complete/duplicate-free input parsing, preserving semicolons within news-keyword values, optimization-range rejection, matching effective built-in risk settings, safe modes and explicit unrun terminal matrix. Existing structure tests now use the current Python executable rather than assuming a python3 binary name.

### Terminal plan and result template

`Tests/StrategyTester/README.md` now supplies:

- Exact six-entry-point MetaEditor compile commands with separate logs.
- Isolation/evidence prerequisites and pure-versus-broad self-test instructions.
- **23 terminal scenario IDs**, covering analysis/readiness/closed bars, modes/netting, sizing/margin/quotes, news/time/DST, ownership/locks/storage crashes/schema/legacy/enrollment, history/uncertainty, lifecycle cleanup and chronological OOS evidence.
- Clear distinction between runnable pure tests and fault-injection scenarios needing a controlled platform harness. It does not claim a ready-made terminal OrderSend or filesystem fault injector.

`Tests/StrategyTester/results_template.csv` starts every case as **NOT_RUN**, with empty evidence fields. The test checks matrix/template consistency. Copy the template for a real run; do not relabel it PASS without the required evidence.

`Docs/TESTING.md` links the current entry points and explains that older phase sections are regression history. Phase 6 reviewed-baseline requirements supersede earlier automatic first-peak descriptions.

## Verification performed here

Strict host runner: **PASS — 16 tests, zero skipped**, including all earlier actual-header C++ shim/fake-broker checks and four new preset/template/harness-boundary checks.

Static structure/API-boundary check: **PASS — 94 MQL source files**. `git diff --check`: **PASS**. Python source syntax parsed successfully. Both trading defines remain commented out, ANALYSIS remains default, and ReleaseApproved remains literal false.

Detailed evidence: `docs/phase7_host_results.json`. Host checks include 20,000 seeded volume-floor cases, a full minute-of-week schedule sweep and actual replay header execution with a fake broker; they are **not equivalent to MT5 API/runtime testing**.

## NOT RUN / release limitations

- MetaEditor/Wine unavailable: **MQL errors/warnings UNKNOWN** for the main EA and new/old test/enrollment entry points.
- The 42 MQL checks, .set imports, Calendar APIs, FILE_CSV parsing, common-files locking, Unicode/EOF handling, disk/crash/rename faults, terminal restart recovery and true broker-history replay have not been executed here.
- No tick dataset, historical/OOS performance study, Strategy Tester run, forward-demo test or broker request was executed. No profit or loss result is asserted.
- Main-application analytical zero-order runs would not by themselves exercise its dormant broker path. Full broker-path integration/fault injection remains outstanding; no automatic normal-intent submission route was added.
- Phase 6 still requires reviewed clean-day enrollment; automatic day-baseline rollover, general state migration/recovery release, verified archival/compaction and pending-lifecycle clearance remain unsupported. New tests/presets do not fill those gaps or reset safety state.
- Open analytical audit findings remain open; no analytical rules/thresholds were corrected or optimized in this phase.
- A host PASS is not production readiness, a zero-warning MQL certificate or permission to trade. REAL remains blocked independently of defines/inputs.

## Checkpoint

**Stopped at Checkpoint 7. Await approval for Phase 8 final documentation.** Please provide MetaEditor compile logs and terminal scenario evidence when available. Phase 8 may document the known limitations; it must not silently treat NOT_RUN cases or unsupported recovery workflows as completed validation.
