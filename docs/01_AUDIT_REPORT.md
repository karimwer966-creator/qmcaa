# QSMC — Phase 2 source audit

**Date:** 2026-11-25 UTC  
**Branch:** `arena/95ec1526-qmcaa`  
**Base:** `d37bde4ece6449a9f349f5dcc60646bced83a8b2`  
**Disposition:** **NOT production-ready. Do not enable broker execution.**  
**Checkpoint:** 2 — proposals only; implementation approval required.

## 1. Scope, evidence and limitations

This is a source-level audit of the existing 75 library headers, EA, two scripts and test-harness header, with supporting review of the Python verification/reporting tools and existing documentation. The complete per-file inventory and direct include graph are in [00_INVENTORY.md](00_INVENTORY.md). The requirement-by-requirement and module-coverage matrices below delimit this review. Source inspection is not proof of runtime correctness or an exhaustive absence-of-defects guarantee.

The user explicitly requested Phase 2 after Phase 1 was blocked. **The baseline build is still unverified:** no MetaEditor, Wine, compile log, MT5 terminal, broker connection, historical tick dataset or Strategy Tester execution is available here. Compiler errors and warnings are **unknown**, not zero. No performance or profitability claim is made.

Only this new report was created during Phase 2. No MQL, Python, configuration, earlier report or existing documentation was modified. Earlier conversation changes to `Experts/QSMC/QSMC.mq5`, `Include/QSMC/App/QSMC_Orchestrator.mqh` and `Docs/TESTING.md` were part of the audited working tree, not fixes made in this phase.

References are repository-relative, one-based line numbers at the audited snapshot. In finding references, **`I/` means `Include/QSMC/`**, not an installed path. Actual EA: `Experts/QSMC/QSMC.mq5`. Source ranges refer to implementations, not generated compiler diagnostics.

### Current safety boundary — important context for severity

- EA default is ANALYSIS (`Experts/QSMC/QSMC.mq5:12`).
- There are **no executable OrderSend, OrderSendAsync or CTrade calls** in the current MQL sources. REAL always rejects. DEMO is in-memory simulation, not broker-demo execution.
- The EA event path stops after analysis, arbitration and opportunity auditing. It never constructs/submits an order intent.
- Consequently execution findings describe defects in callable library contracts and **blockers to any future production activation**, not evidence that this checkout is placing dangerous live trades now.
- Never resolve a finding by removing the current no-order barrier alone. The required two new compile-time gates must remain commented out in delivered source; runtime acknowledgement and account restrictions remain mandatory.

**Severity rubric:** CRITICAL = fundamental production activation barrier or potential loss of a core safety invariant; HIGH = material correctness/control defect that must be resolved before deployment; MEDIUM = robustness, consistency or operational defect; LOW = presentation/documentation defect. Missing implementations are explicitly identified as gaps rather than misrepresented as implemented but malfunctioning behavior. All findings remain OPEN; none is accepted or fixed.

## 2. Findings sorted by severity

| ID | Severity | Finding |
|---|---|---|
| QSMC-001 | CRITICAL | Broker execution and mandatory layered gate design are absent |
| QSMC-002 | CRITICAL | First peak-equity observation is never persisted; drawdown can stay zero |
| QSMC-003 | CRITICAL | Submission proceeds without proving UID/counter writes succeeded |
| QSMC-004 | CRITICAL | Ownership/safety identity changes with configuration and lacks exclusive claiming |
| QSMC-005 | CRITICAL | No gold news blackout or calendar failure policy |
| QSMC-006 | HIGH | Incident restore discards GetBool return values |
| QSMC-007 | HIGH | Kill/latch/acknowledgement durability failures are reported as success |
| QSMC-008 | HIGH | State replacement fallback can destroy the last valid state |
| QSMC-009 | HIGH | State load accepts corrupt, incompatible or incomplete safety state |
| QSMC-010 | HIGH | Risk sizing uses balance/generic tick value and preflight tolerates excess risk |
| QSMC-011 | HIGH | Runtime numeric validation and volume rounding do not guarantee a strict risk cap |
| QSMC-012 | HIGH | Preflight uses stale snapshot/entry-relative stops and no margin buffer |
| QSMC-013 | HIGH | Broker outcomes, partial fills and uncertain requests are not reconciled |
| QSMC-014 | HIGH | No account-mode ownership policy or startup position adoption/management |
| QSMC-015 | HIGH | Daily equity loss and continuous, latched risk monitoring are missing |
| QSMC-016 | HIGH | Trade counters/cooldown are not rebuilt from broker history |
| QSMC-017 | HIGH | Execution and safety observability is incomplete and mostly non-durable |
| QSMC-018 | HIGH | Init does not reset reused object state; lifecycle cleanup lacks runtime proof |
| QSMC-019 | HIGH | FVG direction labels are reversed; fixture endorses the inversion |
| QSMC-020 | HIGH | ATR uses the wrong close and shifts its calculation window |
| QSMC-021 | HIGH | Default primary ICT chronology has no feasible index path |
| QSMC-022 | HIGH | Historical setup evidence lacks consistent availability-time boundaries |
| QSMC-023 | HIGH | Value-area expansion stops before the requested volume share |
| QSMC-024 | HIGH | Entry-time session, rollover and weekend guards are absent |
| QSMC-025 | HIGH | No compiler/runtime evidence; safety tests are incomplete |
| QSMC-026 | MEDIUM | EMA seed reuses the same observations and is not a conventional EMA |
| QSMC-027 | MEDIUM | Session range buckets mishandle active overnight ownership; DST is manual |
| QSMC-028 | MEDIUM | Gold input units, session component validation and effective settings are unclear |
| QSMC-029 | MEDIUM | Safety permission overloads enforce inconsistent contracts |
| QSMC-030 | MEDIUM | History synchronization, allocation and timestamp validation are incomplete |
| QSMC-031 | MEDIUM | Quote age uses a clock that can stop with ticks and accepts future timestamps |
| QSMC-032 | MEDIUM | Failed-data/safety paths can display stale decisions and have no operator recovery UI |
| QSMC-033 | MEDIUM | Disk output is unbounded and write failures are incompletely checked |
| QSMC-034 | MEDIUM | Zone merge can replace newer geometry with older state and lose mitigation |
| QSMC-035 | MEDIUM | Liquidity sweep metadata is not causal or actually newest-first |
| QSMC-036 | MEDIUM | Public geometry/decision envelopes leave invalid or ambiguous states possible |
| QSMC-037 | LOW | Dashboard text layout and object-operation failures are unverified |
| QSMC-038 | LOW | Documentation/path/case and self-test installation inconsistencies |

**Totals:** 38 OPEN findings — 5 CRITICAL, 20 HIGH, 11 MEDIUM, 2 LOW.

## 3. Detailed findings and proposed fixes

### QSMC-001 — CRITICAL — Execution and layered gates are not implemented

**Evidence:** `I/Execution/QSMC_RealAdapter.mqh:12–21`; `I/Execution/QSMC_ExecutionMode.mqh:20–24`; `I/Execution/QSMC_ExecutionManager.mqh:24–52`; `I/Core/QSMC_Constants.mqh:51–63`; `I/App/QSMC_Orchestrator.mqh:263–294,345–387`.

**Description / impact:** RealAdapter always returns execution-disabled. The manager resolves REAL to blocked and passes only `m_demo` to OrderManager. The EA never calls submission or sizing. `QSMC_ENABLE_REAL_TRADING`, `QSMC_ALLOW_LIVE_ACCOUNT`, `CQSMCBrokerExecutor`, Arm and Disarm are absent. The old `QSMC_ALLOW_REAL` default/ack check is not the requested gate design. There is no filling-policy resolver using symbol flags or broker request checker. This is an intentionally safe, incomplete analysis product, not an activatable live EA.

**Proposed fix:** In approved Phase 3 implement the adapter against the real existing intent/result contracts, with documented APIs, symbol execution/filling flags, a supported order check, fresh quotes and protective SL/TP. Put every broker submission behind Gate 1. Gate 2 must restrict non-tester accounts to DEMO unless separately defined. Both defines ship commented out. Arm requires the exact acknowledgement and is logged at startup; Disarm on all exits. Route every future intent through one checked manager/preflight/journal path. Do not activate the path before dependent CRITICAL/HIGH controls are resolved.

**Verification required:** Compile/test no defines, Gate 1 only, both gates, all runtime modes, wrong/right acknowledgement, demo/contest/real account modes, tester, and supported filling policies. ANALYSIS and unarmed paths must never invoke a spy broker adapter. No real orders are necessary for these gate tests.

### QSMC-002 — CRITICAL — Peak-equity initialization disables drawdown tracking

**Evidence:** `I/Execution/QSMC_RiskManager.mqh:39–46`.

**Description / impact:** For a missing `risk.peak_equity`, GetDouble defaults to current equity. The code persists only when `max(priorPeak,currentEquity) > priorPeak`. On a fresh store that is false on every capture: the key stays absent and drawdown stays zero, even as equity falls. Moreover sampling occurs only on a submission attempt, so intervening equity peaks are missed even when a valid key exists.

**Proposed fix:** Persist a validated initial peak explicitly when the key does not exist; sample equity on the approved safety schedule independently of entries; monotonically retain the high-water mark across restart. Block activation if initialization or storage fails. Decide account-scope/cash-flow adjustment semantics with the user.

**Verification required:** New store, equity 10,000 → 11,000 → 9,000: persist 11,000 and report approximately 18.18% drawdown, including after restart. A read-only arithmetic mirror of the current code instead produced no stored key and zero drawdown for all three observations. This was not an MT5 execution test.

### QSMC-003 — CRITICAL — Durable duplicate/counter commitment is not established

**Evidence:** `I/Execution/QSMC_ExecutionJournal.mqh:38–68`; `I/Execution/QSMC_OrderManager.mqh:35–69`; `I/Infrastructure/QSMC_StateStore.mqh:34–53`.

**Description / impact:** MarkSubmitted returns void and ignores all SetString/Save failures. OrderManager ignores SetInt/SetString results for daily state and checks only a final Save. If a required key cannot be inserted (e.g. full store), saving the remaining keys may succeed without a UID or counter actually being recorded. The final successful Save does not prove every preceding mutation succeeded. Only 16 recent submitted UIDs survive restart; there is no retained unresolved-request set, history reconciliation or exclusive submission owner.

**Proposed fix:** Make guard commitment a checked transaction: validate capacity, store the pending intent and all guard fields, confirm durable commit, then allow a broker attempt. Keep unresolved intents until explicit reconciliation; bounded retention must not evict uncertainty. Add exclusive instance ownership and a stable intent identity. Fail closed on any mutation/commit failure.

**Verification required:** Full store, short write, rename failure, terminal crash at each commit boundary, >16 pending/recent UIDs, repeated rejection, reconnect and restart. Assert no submission follows a failed guard commitment and no uncertain intent is blindly resubmitted.

### QSMC-004 — CRITICAL — Ownership and persistence identity are not restart-stable

**Evidence:** `I/Core/QSMC_InstanceIdentity.mqh:58–78`; `I/Core/QSMC_InputFingerprint.mqh:99–150`; `I/App/QSMC_Bootstrap.mqh:29–48`; `I/Infrastructure/QSMC_StateStore.mqh:66–80,185–187`.

**Description / impact:** Magic hashes version, symbol, execution period, login, ChartID and the entire configuration fingerprint, including dashboard/log settings, mode and acknowledgement. A cosmetic input change, upgrade or recreated chart can select a new magic/state file and stop recognizing old positions/counters/latches. The finite one-million-number band is not unique. Bootstrap compares fingerprint and a display id derived from magic/symbol/timeframe, not every raw owner field, and uses no exclusive claim. Two instances can race or collide. Filenames/global keys contain magic only, not explicit account+symbol+magic.

**Proposed fix:** Separate stable operator-assigned ownership identity from changing configuration fingerprints; namespace by account/server, symbol and magic; persist raw identity and schema. Validate/migrate existing state explicitly, lock exclusive active ownership, and refuse conflicting or ambiguous ownership. Never silently abandon or take over an existing position after an input edit.

**Verification required:** Reattach, parameter/chart changes, terminal/VPS restart, version upgrade, account switching, two simultaneous instances, intentional hash collision and migration with open positions. Identity policy/migration requires approval.

### QSMC-005 — CRITICAL — Gold news blackout is entirely absent

**Evidence:** `I/Execution/QSMC_ExecutionPreflight.mqh:17–93`; `I/Core/QSMC_Config.mqh:14–73`; no Calendar API or NewsFilter module in the 79 MQL source files (see Phase 0 search).

**Description / impact:** No entry barrier exists for high-impact USD releases/Fed events, no keyword matching, cached schedule, event-time audit or calendar outage policy. The requirement calls this a critical gold gap. Future broker activation without it would expose new entries to known scheduled event risk. A news filter cannot guarantee protection from gaps or unscheduled events.

**Proposed fix:** Add the approved Phase 5 NewsFilter with documented MT5 calendar APIs, high-importance USD and configurable keywords, default ±30-minute windows, ≤15-minute refresh frequency, stale/error state and reason logging. For live calendar failure/staleness, propose blocking new entries; obtain approval. Tester must use an explicit CSV source or prominently report inactive filtering. Do not let news blackout disable open-position protection.

**Verification required:** Mock events at both window boundaries, multiple events, timezone, keyword cases, stale cache/outage, tester with/without CSV and continued management of existing positions. Calendar APIs still require MetaEditor/runtime validation here.

### QSMC-006 — HIGH — Incident restore ignores stored safety flags

**Evidence:** `I/Safety/QSMC_IncidentSafety.mqh:21–31`; `I/Infrastructure/QSMC_StateStore.mqh:132–136`; `Tests/Harness/QSMC_Selftest.mqh:258–268`.

**Description / impact:** `GetBool(key, localFlag)` takes a **default value**, not an output reference. Both returned values are discarded. `latch` and `uncertain` remain false; `RecoveryUncertain()` is false even when persisted true. The mirrored `kill`/GlobalVariable may still latch the instance, so this is not a claim that every emergency stop bypasses restoration. The existing uncertain-restart self-test should detect the bad uncertainty restoration if run.

**Proposed fix:** Assign the return values and validate consistent persisted safety state. Restore kill/uncertainty monotonically fail-closed on disagreement; test each source independently.

**Verification required:** safety.kill only, safety.uncertain only, file kill only, global kill only, conflicting/missing fields, reload into a new store object and full terminal restart.

### QSMC-007 — HIGH — Safety persistence failures are not propagated

**Evidence:** `I/Safety/QSMC_IncidentSafety.mqh:33–58`; `I/Infrastructure/QSMC_StateStore.mqh:160–180`; `I/Safety/QSMC_SafetyController.mqh:59–69`; `I/App/QSMC_Orchestrator.mqh:446–452`.

**Description / impact:** Latch/Acknowledge ignore key writes and Save results and report true. Acknowledge clears memory before proving durable clearance. SetKillSwitch ignores Save and GlobalVariableSet results and returns only the initial SetBool status; GlobalVariablesFlush is absent. EmergencyStop propagates no persistence failure. The running process may be stopped but restart behavior can contradict the reported durable state.

**Proposed fix:** Check every safety write and durable flush outcome; stage acknowledgement until commit; retain the latch on uncertainty; clearly log whether memory/file/global copies were committed. Define precedence and recovery for disagreement, never silently clear it.

**Verification required:** Read-only directory, full storage, failed global-variable write, power-loss/reboot simulation and acknowledgement interrupted before/after each step.

### QSMC-008 — HIGH — State save is not safely atomic

**Evidence:** `I/Infrastructure/QSMC_StateStore.mqh:191–224`.

**Description / impact:** Save writes a temporary file, but does not check write lengths/errors. If replacement FileMove fails, it deletes the last state and tries another move; if that fails too, the temporary file is also deleted. A failed save can destroy both copies. Atomic replacement and crash durability are not established by the current fallback.

**Proposed fix:** Retain the last verified state on failure, validate every write, flush/close before a supported replacement operation, and use an explicitly versioned recovery/backup protocol. Reject unsafe replacement rather than deleting the known-good copy. Validate the actual filesystem behavior on the target terminal/VPS; do not assume POSIX atomic guarantees.

**Verification required:** Fault injection on open/write/flush/move/close and process termination at each boundary; at least one valid recoverable generation must remain or startup must fail closed.

### QSMC-009 — HIGH — State loader treats malformed safety state as normal defaults

**Evidence:** `I/Infrastructure/QSMC_StateStore.mqh:227–261,99–136`; `I/Core/QSMC_Constants.mqh:66`; `I/App/QSMC_Bootstrap.mqh:29–43`.

**Description / impact:** The schema/version header is skipped as a comment. Unknown format, duplicate keys, malformed lines, invalid numeric values, excess keys and missing mandatory guard fields are not rejected. Missing file is always treated as first run. Truncated/missing state after prior trading can therefore look like a clean state with reset limits. Bootstrap reclaims identity when identity fields are absent.

**Proposed fix:** Validate schema, complete required keys, identity, numeric domains and integrity before marking ready. Distinguish legitimate first run from missing expected state using broker-history/position reconciliation. Quarantine corruption and block new entries pending recovery; define explicit migrations.

**Verification required:** Empty/truncated file, future schema, duplicate/conflicting keys, negative/overflow/NaN values, capacity excess and missing file with existing owned deals/positions.

### QSMC-010 — HIGH — Risk formula violates the required equity-based strict cap

**Evidence:** `I/Execution/QSMC_RiskManager.mqh:84–113`; `I/Execution/QSMC_ExecutionPreflight.mqh:76–83`.

**Description / impact:** SizeLots uses balance, not equity, and generic `SYMBOL_TRADE_TICK_VALUE`, not loss-side tick value/validated OrderCalcProfit. With balance greater than equity, sizing exceeds the specified equity risk. Preflight also uses balance and explicitly permits `riskCap + tickValue * volume`, so it can accept more than the configured nominal stop-risk budget. Cost/gap risk is not modeled; no stop can guarantee an absolute realized-loss cap.

**Proposed fix:** Use current equity and a documented, validated loss-side one-lot stop valuation, with OrderCalcProfit fallback. Floor volume and reject below-minimum sizing; revalue the final normalized volume/entry/stop at submission and require nominal planned risk ≤ budget, allowing only a rigorously tiny numerical comparison tolerance, not another tick of risk. Agree a commission/slippage allowance separately without promising guaranteed fill losses.

**Verification required:** Equity below balance, asymmetric tick values, non-USD account, contract calculation variants, minimum lot exceeding budget, and final-price/volume normalization effects on risk.

### QSMC-011 — HIGH — Runtime numerics and volume precision are not fail-closed

**Evidence:** `I/Execution/QSMC_RiskManager.mqh:88–112,116–124`; `I/Execution/QSMC_ExecutionPreflight.mqh:31–89`; `I/Data/QSMC_DataValidator.mqh:29–67`; `I/Decision/QSMC_SignalRegistry.mqh:38–41`.

**Description / impact:** Config validates finite inputs, but intent/account/contract/bar numeric paths largely use only comparisons. NaN can make comparisons false and evade validation; runtime values need their own checks. Volume precision is hardcoded to 2/3/4 decimals, so for finer steps a NormalizeDouble rounding can increase an already floored value. Lot sizing does not recheck final monetary risk or subtract existing exposure when applying its individual lot cap (preflight does separately reject aggregate excess).

**Proposed fix:** Check finiteness/domains on every safety boundary, derive precision/step handling from the runtime contract, floor in step units conservatively and recheck step/min/max/exposure/final risk. Reject invalid metadata, calculations and intent fields rather than coerce them upward. Keep aggregate preflight checks.

**Verification required:** NaN/Inf, zero/negative metadata, steps 1/0.25/0.1/0.01/0.001 and finer precision, boundary floating-point cases, exposure remaining below minimum lot. Use mocks rather than hardcoding gold broker contracts.

### QSMC-012 — HIGH — Stops, spread, quote drift and margin checks are incomplete

**Evidence:** `I/Execution/QSMC_ExecutionPreflight.mqh:35–90`; `I/Data/QSMC_MarketData.mqh:94–139,154`; `I/Data/QSMC_DataProvider.mqh:103–121`.

**Description / impact:** Preflight uses snapshot bid/ask, spread and stop metadata without validating snapshot/account/decision age or fetching a fresh tick. Stop distances are measured from intent entry, not the relevant current bid/ask side; a BUY stop at the minimum below Ask can be too close to Bid. Freeze level is carried but unused. Margin has no buffer or broker request check. Caller-supplied `intent.deviationPoints` is not bounded against configuration and zero becomes at least one point in the drift check. There is no canonical tick-size-aware price-normalization utility.

**Proposed fix:** Define the intent construction contract, normalize prices direction-safely to tick size and recalculate risk; fetch a coherent fresh tick/contract immediately before preflight/submission, validate stop sides and distance against the correct side, enforce configured deviation, metadata age and broker request validity. Require a configurable approved margin reserve. For any future modifications enforce freeze level and monotonic protective stops; never widen a stop to make a rejected order fit.

**Verification required:** Wide spread, prices moving between decision/submit, 2-/3-digit gold with differing tick sizes, invalid ticks, zero/dynamic stops, freeze windows, insufficient buffered margin and deviation zero/bounds.

### QSMC-013 — HIGH — No broker outcome classification or reconciliation

**Evidence:** `I/Execution/QSMC_ExecutionAdapter.mqh:11–18`; `I/App/QSMC_Orchestrator.mqh:419–427`; `I/Execution/QSMC_ExecutionJournal.mqh:12–19,38–68`.

**Description / impact:** The result envelope has accepted/code/ticket/filledVolume/message only, without separate order/deal/request correlation, retcode class or pending/uncertain lifecycle. OnTradeTransaction only logs, and ignores all events when the root is not RUNNING. No partial-fill/SL/TP close reconciliation or late-event handling exists. A consumed UID alone is not proof that a broker request was rejected, filled, or safely recoverable.

**Proposed fix:** Extend existing contracts with all callers updated, classify documented retcodes as confirmed/retryable/uncertain/fatal, persist pending identity, reconcile transactions/history/positions idempotently even in SAFE_MODE, and block duplicate/replacement requests while uncertain. Apply bounded retries only after proving no prior request is pending/filled; do not resend because of timeout alone.

**Verification required:** Timeout followed by delayed fill, connection loss, partial fills in multiple deals, repeated/out-of-order transactions, SL/TP close during SAFE_MODE, restart with pending requests and broker-confirmed rejection. Validate retcodes using target MT5 documentation/compiler.

### QSMC-014 — HIGH — Position ownership and account-mode management are incomplete

**Evidence:** `I/Execution/QSMC_PositionManager.mqh:21–35`; `I/Execution/QSMC_RiskManager.mqh:48–78`; `I/App/QSMC_Orchestrator.mqh:345–387,402–427`.

**Description / impact:** PositionManager is read-only and not wired into startup/events. It checks symbol+magic, but sets ownershipCertain true even when position selection fails and skips that position. Risk loops filter only magic, not symbol, and skip selection/deal-ticket failures. No `ACCOUNT_MARGIN_MODE` policy handles netting, where a same-symbol manual/other-EA trade can share one net position. No startup adoption, broker-SL verification, close/modify/trailing/break-even path exists. **No current function widens a stop; the management feature is absent.**

**Proposed fix:** Reconcile owned orders/deals/positions at startup and continuously, fail closed on incomplete enumeration, scope ownership correctly and explicitly support or reject netting/shared symbols. Default to leaving other ownership untouched. Verify broker-side protection of adopted positions. Keep trailing/break-even OFF unless separately specified/approved; any implemented stop move must be monotonic and freeze/stops compliant.

**Verification required:** Hedging/netting, foreign/manual position on gold, matching magic on another symbol, partial close, selection failure and restart with an unprotected/ambiguous position. Netting ownership policy requires the user's decision.

### QSMC-015 — HIGH — Daily loss and risk-trip latching do not meet the specification

**Evidence:** `I/Execution/QSMC_RiskManager.mqh:17–22,28–80,116–124`; `I/Safety/QSMC_SafetyController.mqh:35–57`; `I/App/QSMC_Orchestrator.mqh:323–332,402–416`.

**Description / impact:** Daily loss is magic-filtered realized P/L since server midnight plus the entire current floating P/L, divided by current balance; it is not equity loss from a persisted server-day equity baseline. It can miss a large intraday fall from an overnight floating gain or count yesterday's floating loss as today's. Account-wide equity drawdown and per-magic daily loss have mixed scopes. Risk capture occurs only on a library submission attempt. Daily/drawdown rejection does not latch a safety incident and can disappear if equity improves. Limit checks do not follow the mandated kill→drawdown→daily→count→cooldown→positions→exposure→spread→margin precedence, and many share generic codes.

**Proposed fix:** Approve scope and cash-flow handling, persist/restore a server-midnight equity baseline and high-water state, monitor independently of entries, latch threshold crossings for the approved reset policy, and enforce ordered distinct reasons. Include floating P/L and document server time/day-boundary behavior. Keep emergency-stop acknowledgement explicit.

**Verification required:** Overnight winners/losers, realized+floating changes, deposits/withdrawals, midnight/weekend rollover, recovered equity after a trip, intra-day restart and multiple EAs. Do not silently choose account-wide versus owned-strategy daily risk.

### QSMC-016 — HIGH — Submission count/cooldown are not broker-history truth

**Evidence:** `I/Execution/QSMC_OrderManager.mqh:35–69`; `I/Execution/QSMC_RiskManager.mqh:59–80`; `I/App/QSMC_Orchestrator.mqh:345–387,419–427`.

**Description / impact:** `execution.daily_count` counts attempted adapter submissions before outcomes, not confirmed entries. `last_submit` is not a reconciled trade/fill time. Although realized P/L uses HistorySelect when CaptureAccount runs, no startup routine rebuilds today's entry count/cooldown from history or compares stored counts with deals. Missing/changed/corrupt state can reset guards. Conversely rejected attempts consume quota. Partial fills need an explicit counting rule.

**Proposed fix:** Keep attempt throttling separate from confirmed trade limits; reconstruct current server-day entries from filtered deals/orders with approved aggregation for partial fills, preserve unresolved attempts, reconcile conservatively with persisted counters and log mismatches. Define cooldown start point and crash semantics.

**Verification required:** Restart after a fill but before state update, repeated rejected orders, multi-deal partial fills, midnight-crossing order/fill, corrupt count and existing same-day history.

### QSMC-017 — HIGH — Required execution/safety audit trail is missing

**Evidence:** `I/Execution/QSMC_ExecutionJournal.mqh:12–36`; `I/Execution/QSMC_ExecutionManager.mqh:38–51`; `I/Safety/QSMC_Diagnostics.mqh:87–108`; `I/App/QSMC_Orchestrator.mqh:323–331,419–426,446–451`; `I/Infrastructure/QSMC_OpportunityAudit.mqh:29–36,53–63`.

**Description / impact:** Execution journal is a volatile ring without magic or durable lifecycle records. Several manager rejections return before the journal. Diagnostics writes only its in-memory ring; Critical does not automatically log, alert or latch safety despite the header implication. The alert manager is not wired to trips. Transaction logging lacks symbol/magic/intent linkage. Opportunity CSV is analytical evidence, not an order/fill/modification audit. Restart loses most operational detail.

**Proposed fix:** Add a structured, durable execution/safety audit sink with timestamp, symbol, account/instance, magic, intent id and lifecycle/outcome/reason fields. Wire every rejection, guard trip, arm status, request, fill, modification and recovery to it. Define which failures block new entries. Preserve meaningful unique reason codes and rate-limit repeated messages without hiding transitions.

**Verification required:** Trace one mocked intent through every accepted/rejected/uncertain/filled/closed path and across restart; inject logging failure; confirm safety trips remain visible without a dashboard.

### QSMC-018 — HIGH — Reinitialization does not reset all member state

**Evidence:** `I/App/QSMC_Orchestrator.mqh:335–387,429–439`; `I/Data/QSMC_MarketData.mqh:46–72`; `I/Analysis/QSMC_Scanners.mqh:181–208`; `I/Execution/QSMC_ExecutionManager.mqh:24–31`; `I/Execution/QSMC_DemoAdapter.mqh:14–27`; `I/Infrastructure/QSMC_Stats.mqh:35–59`.

**Description / impact:** Constructor initialization is not repeated in Init. Last analyzed bar, pending flag, scan/decision counters, cached analysis/decision, MarketData last-bar markers/snapshot, scanner context and simulator/journal state can survive a reused object's Deinit→Init path. Same-candle reinit can skip analysis or show old-instance evidence. Whether a particular terminal event reconstructs globals must be measured on the target build; reuse is already permitted by the public lifecycle and must work independently of that assumption.

**Positive evidence:** EA OnDeinit now calls orchestrator cleanup unconditionally (`Experts/QSMC/QSMC.mq5:150–154`). Lifecycle.Stop guards EventKillTimer; provider deletion checks NULL; renderer uses owned names. Logger/audit handles are opened/closed per write, not retained. There are no indicator handles to release. These are source observations, not leak-free runtime certification.

**Proposed fix:** Define a complete per-init reset contract for all stateful children while preserving validated persisted safety state; make partial cleanup idempotent and propagate save/cleanup failures. Future real adapter must always disarm. Do not clear persistent latches as part of a memory reset.

**Verification required:** Reuse the same orchestrator object across successful/failed Init, repeated Deinit, REASON_CHARTCHANGE/REASON_PARAMETERS and timer/provider failures. Check object counts, memory, timers, logs and same-candle analysis behavior on MT5.

### QSMC-019 — HIGH — FVG bullish/bearish labels are inverted

**Evidence:** `I/Analysis/QSMC_FairValueGaps.mqh:94–145`; `Tests/Harness/QSMC_Selftest.mqh:105–118`.

**Description / impact:** With series indexing, `olderLow > newerHigh` describes a downward gap, but the code labels it BULLISH. `olderHigh < newerLow` describes an upward gap, but is labeled BEARISH. Fill-side rules then use the inverted label. The controlled fixture calls the downward geometry bullish, so passing it would preserve the defect instead of independently verifying the definition.

**Proposed fix:** Confirm/approve the canonical intended FVG convention, correct both geometry-to-direction mapping and fill/retest logic, and replace the fixture with independent bullish/bearish mirrored cases. This changes strategy outputs and must not be silently deployed as a compile-only fix.

**Verification required:** Upward and downward three-candle gaps, partial/full fill from the correct side, post-formation-only retest, no same-bar retest, and directional funnel acceptance.

### QSMC-020 — HIGH — ATR true-range indexing is wrong

**Evidence:** `I/Data/QSMC_MarketSnapshot.mqh:237–251`; consumers include `I/Analysis/QSMC_Scanners.mqh:299–306`, `QSMC_ICTSetup.mqh:66–70`, `QSMC_BreakOrderBlock.mqh:85–89`.

**Description / impact:** Series bar i's previous chronological close is i+1, not i−1. ATR uses `Close(i-1)` and calculates bars startIndex+1 through startIndex+period, excluding the requested start bar. This distorts gaps, volatility thresholds, displacement ratios and any future ATR stops/sizing geometry. The function is a simple average, not Wilder-smoothed ATR; the intended smoothing needs an explicit specification.

**Proposed fix:** Correct chronological references/window after approving the intended simple-TR versus Wilder ATR contract; use one implementation with documented warm-up and historical availability boundaries. Do not claim the current calculation matches MT5 iATR.

**Verification required:** Hand-computed gapped bars and multiple start indices; compare with the agreed reference. For H=110/L=109, older close=100 and newer close=109.5, correct bar TR is 10 while the current newer-close expression gives 1. The arithmetic mirror is not an MT5 test.

### QSMC-021 — HIGH — Default ICT setup cannot satisfy its index constraints

**Evidence:** `I/Analysis/QSMC_Sessions.mqh:128–145`; `I/Analysis/QSMC_ICTSetup.mqh:62–94,150–166`; `I/Analysis/QSMC_FairValueGaps.mqh:149–152,168–176`; defaults `I/Core/QSMC_Config.mqh:105–106`.

**Description / impact:** Let n be the newest closed index. Sweep detection allows only s≤n+3. A later retest requires gap g>n; strictly post-MSS formation requires g<k, so MSS k≥n+2. FindMss requires pivot p≤s and p−right≥k. With default right=2, p≥n+4 but p≤n+3: impossible. This is a static index contradiction, independent of prices. Exhaustive enumeration of those inequalities produced zero tuples. The primary candidate therefore cannot be reached under default settings even if all other defects are repaired.

**Proposed fix:** Obtain strategy approval for the intended chronology: eligible pre-/post-raid swing, sweep memory, MSS expiry, gap timing and retest window. Implement explicit staged state or a correctly bounded historical sequence; do not merely loosen inequalities until trades appear.

**Verification required:** At least one complete positive sweep→MSS→FVG→later-retest fixture sourced from actual bar sequences, mirrored SELL path and negative temporal-order fixtures; assert reachability with shipping defaults.

### QSMC-022 — HIGH — Historical evidence uses information unavailable at its attributed time

**Evidence:** `I/Analysis/QSMC_Zones.mqh:217–259`; `I/Analysis/QSMC_BreakOrderBlock.mqh:91–121`; `I/Analysis/QSMC_FairValueGaps.mqh:86–90,118–124`; `I/Analysis/QSMC_Sessions.mqh:199–231`.

**Description / impact:** Zones are rebuilt using latest-decision ATR, origin pivots and displacement candles up to three bars after the pivot, but carry only pivot creation time, not displacement availability/confirmation time. The historical OB model checks pivot confirmation relative to a past break but cannot verify when that zone's selected displacement/geometry became known. FVG historical sizeAtr also uses today's ATR rather than formation-time ATR. Session sweep references lack a completion timestamp to prove the level was available at each historical raid. Rebuilt historical labels/scores can change as later data arrive. This does not prove every latest-bar candidate has future information; it invalidates a blanket causal-history/no-leakage claim.

**Proposed fix:** Store/compute formation and availability timestamps separately and ensure evidence exists by the event it supports; use causally anchored ATR/levels for historical claims. Replay prefixes chronologically and compare previously finalized outputs. Preserve current-time context separately if intentionally used. Strategy interpretation requires approval.

**Verification required:** Prefix replay versus full-history scan, one-bar-at-a-time construction, displacement after historical break, session-end timing and varying later volatility. Assert no finalized historical event changes when only later bars are appended.

### QSMC-023 — HIGH — SVP value-area loop terminates prematurely

**Evidence:** `I/SVP/QSMC_SvpCore.mqh:204–248`; `I/Analysis/QSMC_Scanners.mqh:460–461`; `I/Decision/QSMC_OpportunityFunnel.mqh:89–98`.

**Description / impact:** Every expansion restarts at distance one from POC. Once its immediate neighbors are both used/unavailable, line 222 breaks instead of advancing to the current value-area boundary. Generally no more than POC and its two immediate neighbors are included. On ten equal-volume bins the first POC is at index 0; the code includes bins 0 and 1, then stops at 20% instead of 70%, but still sets ready=true. Wrong VAH/VAL feed actual confluence adjustments.

**Proposed fix:** Expand from maintained lower/upper boundaries using the agreed neighboring-volume rule until the target share or all bins are reached; validate coverage and deterministic ties. This fixes a calculation, not a promise of predictive value.

**Verification required:** Uniform volume, edge/central POC, asymmetric and zero-volume bins, targets near 0/100 and postcondition includedVolume≥target (unless all bins exhausted). Existing ordered-level test is insufficient.

### QSMC-024 — HIGH — Current-time entry guards are absent

**Evidence:** `I/Execution/QSMC_ExecutionPreflight.mqh:17–93`; `I/Decision/QSMC_OpportunityFunnel.mqh:63–68`; `I/Analysis/QSMC_Sessions.mqh:160–179`; `I/Infrastructure/QSMC_Clock.mqh:132–149`.

**Description / impact:** Strategy membership uses a closed candle's opening timestamp, not intended submission time. No preflight session recheck, rollover window or Friday cutoff exists. Clock's IsWeekend helper is not called by execution. A stale candidate could pass past-session analysis after the entry window closes; an existing spread check alone does not implement rollover/weekend controls.

**Proposed fix:** Add entry-only guards using approved broker-server time, default rollover 23:45–01:15 and configurable Friday cutoff; recheck configured session at submission. Keep optional pre-weekend closing OFF unless explicitly approved. These guards must not stop reconciliation/protective management. Select cutoff and overlap behavior with the user.

**Verification required:** Exact boundaries, midnight wrap, Friday/Sunday, session closing between decision/submit, DST offset change and open-position protection throughout blocked windows.

### QSMC-025 — HIGH — Build and safety acceptance remain unverified

**Evidence:** `Tests/Harness/QSMC_Selftest.mqh:25–45,105–118,184–196,251–276`; `Tests/static_check.py:110–157`; `Scripts/QSMC_Selftest.mq5:1–11`; `Docs/TESTING.md`.

**Description / impact:** No MetaEditor compile or harness execution evidence exists. Current tests do not cover lot calculation/step flooring across contracts, tick-aware gold prices, stop-side/freeze enforcement, calendar windows, retcode classes, gated builds, fill/restart lifecycle or failure injection. Fixtures depend on current terminal symbol metadata/time despite the terminal-independent header claim; persistence test uses the same in-memory store, not a reopened file. The uncertain-latch assertion exposes QSMC-006; the FVG test encodes QSMC-019. Static checker rejects any OrderSend/CTrade reference even under compile-time-disabled code, so it must evolve when a gated adapter is added without deleting the no-orders invariant.

**Proposed fix:** Obtain baseline logs, fix confirmed compile blockers separately, create independent unit-style fixtures and mocked broker/calendar/clock/contract interfaces, and build/test every gate combination. Preserve strict off-build guarantees using preprocessor-aware checks/spies, not removal of the safety test. Execute terminal fault/restart scenarios and the requested stress/forward-demo protocol before any production signoff.

**Verification required:** 0 compiler errors/0 warnings with saved logs, all self-tests passed with reproducible environment, gate spies, documented fault injection, real-tick tester stress and 4–8-week forward-demo evidence. No test result is inferred from source presence.

### QSMC-026 — MEDIUM — EMA double-counts its seed window

**Evidence:** `I/Data/QSMC_MarketSnapshot.mqh:254–270`; `I/Analysis/QSMC_Bias.mqh:59–62`.

**Description / impact:** Ema seeds using closes from index through index+period−1, then recurses over period−1 of those same observations. It uses no older warm-up history despite the comment. This is not conventional chronologically seeded EMA and affects the hard HTF directional gate as well as bias.

**Proposed fix:** Approve/reference a precise EMA initialization and warm-up rule, then implement and test against hand calculations or a matching platform reference. Treat output changes as model changes, not compile fixes.

**Verification required:** Constant/step/ramp series, variable requested index, sufficient versus short history and prefix replay.

### QSMC-027 — MEDIUM — Midnight membership is supported but range ownership is inconsistent

**Evidence:** `I/Analysis/QSMC_Sessions.mqh:84–99,175–179,199–231`; `I/Infrastructure/QSMC_Clock.mqh:73–78,127–130`.

**Description / impact:** InWindow correctly supports start>end. SessionDay assigns post-midnight bars to the preceding start-day, but Evaluate compares every range to the evaluation's calendar currentDay/previousDay. At 00:30 for a 23:00–01:00 active session, its current bars fall into `previousReady` and may be offered as previous-day completed liquidity while that session is still open. Yesterday means calendar yesterday, not previous trading session; Monday/Sunday gaps are not handled as a previous-trading-day lookup. Server offset is TimeCurrent−TimeGMT and no offset-change warning/automatic DST policy is wired.

**Proposed fix:** Anchor each session to its own active/completed start/end timestamps, keep active ranges out of prior completed reference pools, define weekend handling and add the requested TimeTradeServer offset diagnostics/change warning. Do not automatically move strategy session windows without approval.

**Verification required:** 23:00–01:00 at 23:30/00:30/01:00, prior-session references, overlapping windows, Friday→Monday, missing Sunday bars and DST transitions.

### QSMC-028 — MEDIUM — Gold configuration is point-based and partially misleading

**Evidence:** `Experts/QSMC/QSMC.mq5:25–68,91–120`; `I/Core/QSMC_Config.mqh:37,48,211–215,254–263`; `I/Analysis/QSMC_Scanners.mqh:375–376`.

**Description / impact:** Spread, deviation and tolerance inputs are raw points with no price-unit gold conversions/contract startup summary. The single risk override controls unrelated-looking spread/geometry/confidence fields, so editing an input may have no effect unless opted in (documented, but easy to misread). Session hour/minute pairs are combined before validation; e.g. 08:90 becomes a valid 09:30 aggregate. `zone_lookback` is assigned/validated/fingerprinted but scanner passes structure lookback to Zones.Build instead. Spread 0 disables the cap. Aggressive preset is 1%, and custom risk permits up to 2%; the requested ≤0.5% gold presets have not been delivered. Generic presets are not automatically prohibited by that separate deliverable requirement.

**Proposed fix:** Add clear grouped inputs and startup effective-config/contract logging, validate hour/minute components before conversion, wire zone lookback or explicitly remove/deprecate it with callers updated, and agree gold price-unit conversion/rounding and live spread policy. Provide conservative/balanced gold sets ≤0.5%; do not silently change strategy thresholds or disable general-purpose presets.

**Verification required:** Two brokers with different digits/point/tick size, explicit overrides on/off, invalid component times that normalize into valid totals, and proof that changing zone lookback affects the intended calculation.

### QSMC-029 — MEDIUM — Safety permission overloads are not equivalent

**Evidence:** `I/Safety/QSMC_SafetyController.mqh:43–57,75–87`; `I/Safety/QSMC_HealthMonitor.mqh:189–194`.

**Description / impact:** `CanSubmit(root,why)` has the strongest root-aware contract. The no-argument `CanSubmitOrders()` only checks cached health and the in-memory latch, ignoring mode/build/root/current terminal-global kill. The string overload refreshes health/mode/build/kill but still lacks the root argument. They are not used as the normal submit gate now, but their permission-sounding names invite accidental weaker authorization in future callers.

**Proposed fix:** Keep one authoritative root/mode/arm/account/safety entry permission function; clearly identify cached health-only accessors as diagnostics or strengthen them consistently while updating callers. Do not treat cached health as permission.

**Verification required:** ANALYSIS/OFF, SAFE_MODE, newly set global kill, stale cached health and unarmed/account-restricted builds across every public permission API.

### QSMC-030 — MEDIUM — History/allocation/time validation is incomplete

**Evidence:** `I/Data/QSMC_DataProvider.mqh:54–81`; `I/Data/QSMC_MarketSnapshot.mqh:86–103`; `I/Data/QSMC_DataValidator.mqh:19–67,107–118,133–145`; `I/Data/QSMC_DataReadiness.mqh:85–93,107–135`.

**Description / impact:** No SERIES_SYNCHRONIZED check or explicit cross-timeframe capture-boundary consistency exists; GetRates accepts any positive copied count. Readiness has generic thresholds rather than all configured lookback/warm-up requirements (50 HTF bars is not enough for Ema period 50 at index 1). AttachBars ignores ArrayResize failure and caller count versus input array size. Several helpers accept invalid negative/oversized indices and convert failed bar reads to 0. Future timestamps are treated as not stale; validation checks order, not future bounds or a coherent decision cutoff. HasGap is not wired. MT5 normal history gaps must not be confused with corrupt history.

**Proposed fix:** Verify synchronization and required warm-up, bound/check allocations and public indices, align snapshots to one decision cutoff and explicitly validate timestamp/skew. Distinguish downloading history, insufficient bars, valid session gaps and corrupt data. Avoid using zero as a successful missing-data substitute.

**Verification required:** Partial history download, mismatched timeframe synchronization, future bars, allocation failure, short arrays and market closures. Preserve fail-closed readiness and retry behavior.

### QSMC-031 — MEDIUM — Health quote freshness can be misleading

**Evidence:** `I/Safety/QSMC_HealthMonitor.mqh:96,113–132`; `I/Data/QSMC_MarketData.mqh:94–96,130–131,154`; `I/Infrastructure/QSMC_Clock.mqh:73–78`.

**Description / impact:** TimeCurrent may stop advancing with the last known quote. Measuring quote age solely against it can leave stale quotes apparently fresh if the connection flag remains true while ticks stop. Negative age also passes. Spread is recomputed with separate bid/ask reads instead of from the captured tick, so displayed/validated spread need not match snapshot bid/ask. Connection checks help but do not prove freshness.

**Proposed fix:** Use a documented server-time estimate plus monotonic tick-receipt age appropriate to live/tester contexts, reject implausible future timestamps, and derive spread from the same fresh tick. Explicitly distinguish market closed/no tick/disconnected.

**Verification required:** Connection remains true but no ticks, different chart/configured symbol, clock skew, stale tick timestamp and timer operation across market close/reopen.

### QSMC-032 — MEDIUM — Stale decisions and manual recovery are not sufficiently observable

**Evidence:** `I/App/QSMC_Orchestrator.mqh:70–76,112–140,297–331,402–416`; `I/Decision/QSMC_UnifiedDecision.mqh:45–51`; `I/Core/QSMC_Root.mqh:145–155`.

**Description / impact:** SetNoTrade records a rejection but leaves decision.explanation empty and does not clear scanner/presentation evidence. UpdateHealth enters SAFE_MODE without invalidating the previous selected decision or persisting the root health-stop reason; safety.Reason later follows health and may show 'ok' while root remains stopped. The EA has no operator-facing acknowledgement/recovery control, although library methods exist. It intentionally does not auto-resume, and should not be changed to do so casually. Repeated pending failed scans can retry heavy work every timer without backoff.

**Proposed fix:** Render decision age/invalidity, retained safety-stop reason and explicit restart instructions; clear or label stale analysis evidence. Specify a deliberate operator recovery path that revalidates readiness and never clears emergency latches implicitly. Rate-limit repeated failing scans/logs without delaying protection.

**Verification required:** Selected decision followed by stale data/disconnect, recovered health while SAFE_MODE, disabled dashboard, repeated scan failure and explicit recovery with an active incident latch.

### QSMC-033 — MEDIUM — Storage/performance failure handling needs hardening

**Evidence:** `I/Infrastructure/QSMC_Logger.mqh:40–53,85–100`; `I/Infrastructure/QSMC_OpportunityAudit.mqh:26–36,50–63`; `I/App/QSMC_Orchestrator.mqh:165–174,278–286,413`; `I/Data/QSMC_DataProvider.mqh:62–79`.

**Description / impact:** Runtime arrays/counters mostly have fixed capacities, but log/opportunity/state files have no rotation/retention budget. Logger and audit do not check every FileSeek/FileWrite return; audit Append returns true even if the write fails after open. Shared append uses seek-to-end without an inter-instance lock. Three audit rows each reopen/flush/close per successful candle. Failed history fetches Sleep inside the event handler; persistent scan failure can cause repeated bounded but expensive rebuilds. No measured upper event-duration budget exists.

**Proposed fix:** Check/propagate I/O failures, ensure unique writer ownership, add retention/rotation with recoverable audit rules and bounded retry/backoff. Measure worst-case scan/render/I/O duration at maximum configuration. Preserve safety events/reconciliation priority; do not optimize by dropping guard checks.

**Verification required:** Disk full mid-write, concurrent writers, max 5,000 bars/80 bins/64 structure points, prolonged missing history, months of file growth and timer saturation.

### QSMC-034 — MEDIUM — Zone merge mixes old/new geometry and mitigation

**Evidence:** `I/Analysis/QSMC_Zones.mqh:105–119,210–214,263–305`; `I/Analysis/QSMC_Structure.mqh:95–99,171–176`.

**Description / impact:** Structure is newest-first. AddOrMerge unconditionally replaces stored geometry/creation time with each later input, so an older overlapping zone can replace a newer one despite the comment saying to keep newer geometry. It does not transfer/recompute `mitigated` or bias with the replacement and combines touches/displacement from different geometries. An invalidated replacement can appear valid or vice versa, affecting alternate candidate eligibility/ranking.

**Proposed fix:** Define deterministic merge semantics (or keep immutable separate zones), preserve causal availability, and recompute/retain consistent mitigation/interactions for the chosen geometry. Do not silently alter zone modeling without approval.

**Verification required:** Two overlapping same-type zones of different ages/mitigation, reversed input order, repeated rebuilds and resulting OB-model selection.

### QSMC-035 — MEDIUM — Liquidity sweep metadata is not temporally reliable

**Evidence:** `I/Analysis/QSMC_LiquidityValue.mqh:98–119,197–257,286–297`; `I/Analysis/QSMC_Scanners.mqh:443–458`.

**Description / impact:** Price-only merging can combine upper/lower reference types. Range extrema include the bars later searched for sweeps, so a strict new extreme cannot sweep the same range high/low definition. MarkSweeps does not record raid time or prove a clustered level was available before each raid. RecentSweep returns the first stored matching level, not the latest sweep by time. This generic map is currently descriptive context; the final funnel uses separate session-liquidity flags, so do not overstate its direct entry impact.

**Proposed fix:** Keep side/type and formation availability in reference identity, calculate prior ranges excluding the test candle, record sweep timestamps/indices and select true latest events. Keep visualization-only versus hard-entry evidence clearly separated.

**Verification required:** Equal-price upper/lower levels, new range extreme/rejection, older raid against a later-confirmed level and multiple sweeps with different times.

### QSMC-036 — MEDIUM — Public analytical envelopes lack strict validity guarantees

**Evidence:** `I/Decision/QSMC_ExecutionRules.mqh:27–51`; `I/Decision/QSMC_UnifiedDecision.mqh:45–51`; `I/Decision/QSMC_SignalRegistry.mqh:38–41`; `I/Decision/QSMC_Arbiter.mqh:80–86`; `I/Core/QSMC_Types.mqh:69–73`.

**Description / impact:** Geometry rejects NONE but treats any other non-BUY enum as SELL, permits opposing swings on the wrong side via absolute distance and emits non-normalized prices. Reject only appends a diagnostic; it does not itself invalidate an already-valid decision, which is legitimate for losing-candidate notes but ambiguous as a general veto API. SignalRegistry similarly rejects NONE but not all invalid direction values or non-finite scores. Arbiter UID uses bar/time/direction/score only, not symbol/timeframe/stable owner, and converting SELL to an unsigned token relies on actual enum values (SELL is 2, not −1). No current intent-building caller supplies the missing context.

**Proposed fix:** Specify accepted enum/domain and geometry contracts, distinguish fatal decision veto from informational candidate rejection, and construct intent IDs from stable owner+symbol+timeframe+bar+setup identity rather than score alone. Preserve strongest downstream preflight regardless of analytical envelope validation.

**Verification required:** Invalid enum casts, wrong-side swing, NaN scores, losing-candidate note with valid winner, final veto and deterministic cross-symbol/restart intent identity.

### QSMC-037 — LOW — Dashboard rendering needs terminal validation

**Evidence:** `I/Presentation/QSMC_Dashboard.mqh:40–65,84–103`; `I/Presentation/QSMC_ChartLayers.mqh:39–81`.

**Description / impact:** One OBJ_LABEL receives long multiline text and model explanations within a fixed 590×270 panel. Display wrapping/multiline behavior, clipping and failure handling have not been verified on the target terminal. Object create/move/set/delete outcomes are largely ignored, so critical status can be invisible despite a running EA.

**Proposed fix:** Verify rendering on MT5, use bounded per-line labels if necessary and report object failures outside the chart. Keep all deletion strictly scoped to the initialized instance prefix/name; never delete foreign objects.

**Verification required:** Long diagnostics, different DPI/chart sizes, missing/deleted objects, disabled layers and manual/foreign objects surviving repeated cleanup.

### QSMC-038 — LOW — Documentation and deployment naming are inconsistent

**Evidence:** `README.md:5` and Installation section; `Scripts/QSMC_Selftest.mq5:3`; `docs/00_INVENTORY.md` discovery statements; `Docs/INSTALLATION.md`; actual paths in the repository.

**Description / impact:** Existing docs use `Docs/`, new requested reports use `docs/`, which can conflict on a case-insensitive Windows checkout. The mission's flat installed EA path differs from this repository's nested EA path. Selftest script references `../Tests/Harness`, which requires copying Tests alongside MQL5/Scripts rather than only copying the EA/Include directories. Prior inventory had a few approximate line anchors (e.g. the default-mode input is EA line 12, GetBool is StateStore lines 132–136, and Sessions ends at line 244); references in this report supersede those anchors. Documentation describing a hard-set real gate should acknowledge its #ifndef override while still making clear there is no operational broker adapter.

**Proposed fix:** In the approved documentation phase choose a single Windows-safe docs naming scheme with repository-wide links updated, publish one exact install/test path layout and correct safety/status descriptions. No directory rename was performed in this read-only phase.

**Verification required:** Fresh Windows checkout/copy, documented self-test compile and link/path checks.

## 4. Requirement-by-requirement audit results

| Required area | Source-level result | Finding(s) / verification debt |
|---|---|---|
| Global state across reinit | Init does not reset every member; actual terminal reconstruction semantics not assumed | 018 |
| Idempotent/partial Deinit | Current guards support cleanup; repeated/partial MT5 tests not run; save errors ignored | 007,018 |
| Indicator handle validation/release | No indicator handles, CopyBuffer, BarsCalculated or IndicatorRelease calls found; ATR/EMA are custom math | No handle to release currently; 020,026 |
| Timer cleanup | EventSetMillisecondTimer checked; Stop calls guarded EventKillTimer | Runtime proof pending, 018 |
| Namespaced chart deletion | ChartLayers enumerates/deletes prefix; Dashboard deletes exact names | Positive source evidence; 037 |
| Closed versus forming bars | Default NewestIndex=1 and fractals exclude bar zero; false is allowed and scans only once per candle, so forming-bar mode is not non-repainting | 019–022,025,030; see note below |
| Series indexing | CopyRates arrays explicitly series; snapshot copies logical indices to private ordinary arrays | Positive representation consistency; ATR exception 020 |
| Synchronization/readiness | OHLC/order/minimum bars checked; synchronized/capture-boundary validation incomplete | 030,031 |
| Repainting/leakage | Confirmed fractals are delayed; Elliott labels/merged zones can relabel on rebuild; historical availability not consistently retained | 022,034,035 |
| Adapter selection | ANALYSIS/OFF disabled; DEMO paper; REAL blocked; no app submission | 001 |
| Filling policy/retcodes | Not implemented; no symbol filling resolver, broker outcomes or partial fills | 001,013 |
| Duplicate uncertain requests | Pre-submit UID idea is present but not a durable unresolved lifecycle | 003,004,013 |
| Account mode/netting | No explicit account-mode policy; shared net-position ownership unresolved | 014 |
| Fresh tick/price normalization | Snapshot validation is not fresh broker request validation | 011,012 |
| Stop/freeze constraints | Stop side/distance checked against intent entry; freeze only captured | 012,014 |
| Equity-based stop-risk sizing | Uses balance/generic tick value; floor/min rejection exists but strict invariant incomplete | 010,011 |
| Exposure cap | Manager checks current; preflight includes intent volume, filtered by magic-only risk snapshot | 011,014 |
| Buffered margin | OrderCalcMargin present, positive/free-margin check present; no reserve | 012 |
| Floating daily risk/equity DD | Floating included in a different formula; drawdown peak initialization broken | 002,015 |
| Server day boundary | Risk and execution use TimeCurrent broker-calendar midnight/date | 015,016,027,031 |
| Latched daily/drawdown stop | Explicit emergency latch exists, risk thresholds do not invoke it | 006,007,015 |
| File/global persistence | Temp replacement, magic-only key and schema header exist; durability/validation not established | 003,004,007–009 |
| History-based restart counters | P/L select exists on CaptureAccount; daily trade/cooldown rebuild absent | 016 |
| Startup position adoption | Read-only helper exists, not app-wired; no protective modification path | 014 |
| No stop widening / foreign trades | No modification/close operations currently exist; helper filters symbol+magic; not a tested management guarantee | 012,014 |
| New-bar performance | Normal heavy analysis is on exec new bar; pending failures retry each timer; no per-tick normal full scan | 018,030,032,033 |
| Relevant timeframes | HTF/LTF refresh with exec evaluations, not separate model triggers; strategy must approve any different timing | 022,030 |
| Bounded arrays/objects | Constants bound model buffers/lookbacks/profile; app bounds zone/FVG/Elliott draw counts; allocation results incomplete | 030,033,037 |
| Logs for every intent/reject/fill/trip | Not present as a complete persistent correlated trail | 017,033 |
| News / rollover / weekend / DST | Not production-implemented; session membership alone is insufficient | 005,024,027 |
| Forbidden recovery strategies | No martingale/grid/loss-multiplication/recovery-hedging implementation found; no broker orders or SL removal/widening implementation | Preserve prohibition in all future changes |

**Forming-bar configuration note:** `use_closed_bars_only=false` is accepted (`Experts/QSMC/QSMC.mq5:90`; `I/Data/QSMC_MarketSnapshot.mqh:183`). With that option, the newest bar can change after a once-per-new-bar scan. Production activation should require closed-only or a separately specified/tested intrabar model, not inherit the same non-repainting claim. This is a necessary activation constraint under QSMC-022/QSMC-025; no setting was changed.

## 5. Module coverage and positive observations

This matrix covers all **75 library headers** (names omit `QSMC_` and `.mqh`). Compatibility facades were checked for delegation, not assumed to add separate algorithms.

| Layer | Headers reviewed | Coverage/result |
|---|---|---|
| Core (9) | Constants, Types, Version, Config, Preset, InputFingerprint, InstanceIdentity, StateMachine, Root | Actual enums/fields checked; state transitions prohibit direct SAFE_MODE→RUNNING; finite config checks and ANALYSIS default present; 001,004,018,028,036 |
| Infrastructure (5) | Clock, Logger, StateStore, Stats, OpportunityAudit | Bounded runtime rings; per-write file closure; server-day helpers; persistence/clock/I/O/audit gaps 002–004,007–009,017,031,033 |
| Safety (4) | Diagnostics, HealthMonitor, IncidentSafety, SafetyController | Connection/account/algo/symbol/spread checks exist; explicit emergency latch exists; restore/permission/durability issues 005–007,015,017,029,031 |
| Data (6) | MarketSnapshot, DataProvider, TimeframeManager, DataValidator, MarketData, DataReadiness | Explicit timeframe ordering, series copies, failed-refresh snapshot reset, OHLC/order validation; 011,012,020,026,030,031 |
| Analysis (19) | Structure, StructurePoints, Bias, CandlePatterns, Zones, ZonesPublic, ZoneScorer, SupplyDemand, LiquidityValue, Liquidity, Reaction, EarlyBreakDetector, Sessions, FairValueGaps, ICTSetup, OrderFlowProxy, ElliottGuide, BreakOrderBlock, Scanners | Confirmed fractals use closed comparisons by default; candle/tick-volume/Elliott claims explicitly heuristic; facade delegation intact; FVG/sequence/causality/merge issues 019–022,026–028,034,035 |
| SVP (6) | SvpCore, SvpVolumeProfile, SvpZones, SvpLiquidity, SvpDecision, SvpChart | Bounded bins and explicit bar-volume approximation; zero-volume time-at-price fallback; erroneous value-area loop 023; shape/classification inherits it |
| Decision (7) | UnifiedDecision, SignalRegistry, Gates, OpportunityFunnel, Arbiter, ArbiterNotes, ExecutionRules | Hard HTF/session/directional-liquidity funnel gates, opposing equal-score rejection, bounded registries; no execution authority; 012,022,024,036 |
| Execution (11) | ExecutionMode, ExecutionAdapter, DemoAdapter, RealAdapter, ExecutionJournal, RiskManager, ExecutionPreflight, OrderManager, PositionManager, ExecutionManager, AlertManager | Safe no-order default/paper-only simulation; explicit preflight and pre-submit UID concept; activation and safety gaps 001–004,010–017,025,029 |
| Presentation (3) | Dashboard, ChartLayers, Renderer | Read-only views, prefix/exact-name cleanup, fixed draw budgets; 017,032,037 |
| App (4) | EventDispatcher, Lifecycle, Bootstrap, Orchestrator | Gated events/timer/startup composition; 001,004,013–018,032 |
| Umbrella (1) | `Include/QSMC/QSMC.mqh` | Public aggregation includes modules; includes are not proof of runtime invocation |

Count reconciliation: Core 9 + Infrastructure 5 + Safety 4 + Data 6 + Analysis 19 + SVP 6 + Decision 7 + Execution 11 + Presentation 3 + App 4 + Umbrella 1 = **75**. EA, two scripts and test-harness header bring the MQL source total to **79**.

Additional review: self-test scenarios and their assumptions; static-check no-order rule; Python OOS tool; installation/testing/safety docs. No new independent production algorithm was inferred from a facade or module name.

### Analytical reporting limitations

`Tests/oos_evaluate.py:37–82` uses a row-count horizon within symbol/timeframe/model groups. Missing scan rows or duplicate rows after restarts change the effective bar horizon; rows are not deduplicated/validated as a complete bar timeline. `summarize` accumulates results in entry-time order, not a marked-to-market broker equity curve. Its `R` is ATR-normalized close-to-close movement, not money lost at the actual SL. These limitations supplement QSMC-025/QSMC-033: use a verified time/bar-indexed dataset, deduplicate exports and clearly label descriptive units. The existing script's disclaimer is appropriate; **its report cannot satisfy trading-system execution, drawdown, profit or production acceptance tests**.

## 6. Read-only verification performed

1. `python3 Tests/static_check.py` — **PASS**, 79 MQL files. Includes/guards/delimiters checked; current executable OrderSend/CTrade references absent. This check does not evaluate MQL types, platform API signatures, return-code semantics or preprocessor gate builds.
2. Source searches — no executable OrderSend/OrderSendAsync, CTrade, OrderCheck, calendar calls, indicator-handle APIs, SERIES_SYNCHRONIZED, account-margin-mode use or GlobalVariablesFlush were found in the MQL tree. Comments containing trade API names were distinguished from actual calls.
3. Read-only Python arithmetic mirrors (not MQL unit tests):
   - QSMC-002: equity 10,000→11,000→9,000 leaves the current peak key missing and computed drawdown zero.
   - QSMC-021: enumerating the source's default sweep/MSS/pivot/post-MSS gap index constraints yields zero legal tuples.
   - QSMC-023: ten equal-volume bins give two included edge-POC bins, 20% coverage, for a 70% target.
   - QSMC-020: gapped-bar true range example is 10 against the older close, 1 against the incorrectly used newer close.
4. `git diff --check` — PASS before report delivery; no implementation diff added. Existing tracked-file diff SHA-256 before this report: `a1ae6be80f37f4b2ca452b7445549095dca1f55291040f74b292e53bf009aa92` (hash is of `git diff --binary`, not a source-build attestation).

**Not run:** MQL compilation, terminal self-tests, broker request checks, filling-mode experiments, memory/object leak measurement, historical tick backtest, restart/VPS fault injection, real/demo broker trading or forward performance. All such claims remain unverified.

## 7. Decisions needed before fixes

Approval of this report is not permission to enable either trading define or operate a live account. Please decide/approve the following before the relevant implementation work:

1. **Ownership:** stable explicit magic/instance-id policy, migration of old identity and behavior on netting accounts or a same-symbol foreign position. Proposed conservative policy: refuse new entries on ambiguous/shared ownership; never modify another owner's trades.
2. **Risk:** account-wide versus owned-strategy daily equity loss; deposits/withdrawals; daily-trip reset/acknowledgement; persistent drawdown baseline; margin reserve. Default proposal: new entries blocked on any uncertainty, existing protection remains active.
3. **Strategy/math changes:** canonical FVG, ATR smoothing/window, EMA seed, ICT sweep/MSS/FVG timeline and expiry, historical availability and zone merging. QSMC-019–023/026/034 change outputs; do not apply them as incidental safety edits without approval.
4. **Gold entry controls:** Friday cutoff, gold symbol suffix/contract policy, price-unit spread/deviation/tolerance and rounding, and calendar outage/tester-without-CSV behavior. Proposed live behavior is fail-closed for unavailable/stale calendar; tester must disclose inactive filtering if explicitly allowed.
5. **Position management:** fixed protective broker SL/TP only versus separately specified trailing/break-even. Proposed initial scope: no discretionary trailing/break-even or pre-weekend liquidation; retain mandatory protection and reconciliation.
6. **Build evidence:** supply `compile.log` from the actual installed EA before any compile-success claim. The Windows MetaEditor command is in the inventory. A log remains necessary even if implementation approval is given.

## 8. Proposed remediation sequence (requires approval)

- Preserve no-order shipping defaults and current REAL rejection throughout work.
- Complete Phase 1 evidence/confirmed compile blockers first when a log is supplied.
- Phase 3: implement the **gated and unarmed-by-default** broker boundary, filling/retcode/journal/reconciliation contracts; initially keep activation unavailable while the dependent critical controls are incomplete. Resolve QSMC-001/003/012–014/017 with corresponding tests.
- Phase 4: strict sizing, peak initialization, ordered risk checks and persistent trips (002,006,007,010,011,015,016,029).
- Phase 5: calendar/session/rollover/weekend/contract inputs (005,024,027,028,031).
- Phase 6: stable identity migration, transactional persistence, history/position adoption and restart tests (003,004,007–009,014,016,018).
- Implement analytical corrections only in an explicitly approved, separately tested change set (019–023,026,034–036), not silently during broker wiring.
- Phase 7: full compiler gate matrix, independent fixtures, fault injection and stress/forward-demo plan (025,030,033,037).
- Phase 8: mapped changelog/deployment/rollback/limitations and exact installation paths (038).

Each phase still ends at its own checkpoint. Required gates ship commented out; no broker-specific digits/contract/filling constants are to be hardcoded. No martingale, grid, averaging down, recovery hedging, loss-based lot escalation, SL removal/widening or unprotected entry is proposed.

## 9. Phase 2 reporting / Checkpoint 2

1. **Done:** source audit and coverage matrix; 38 severity-ranked findings with file/line evidence, impact, proposed fix and required verification; current safe no-order boundary distinguished from activation gaps.
2. **Files changed:** only new `docs/01_AUDIT_REPORT.md`, to deliver this report. Finding IDs document proposed work; no finding is marked resolved.
3. **Compile result:** not available. Errors **unknown**, warnings **unknown**. Local structural check passed; no compiler result fabricated.
4. **Open risks/decisions:** unresolved CRITICAL/HIGH findings, all runtime acceptance tests, Phase 1 evidence and the policy/model choices above. This checkout is not approved for live use.
5. **Proposed next step:** approve findings and remediation scope, resolve the relevant policy questions, then begin Phase 3 subject to the continuing compile-evidence limitation. Do not bypass later safety checkpoints by turning on live execution now.

**STOPPED AT CHECKPOINT 2 — awaiting approval before any fixes.**
