# Checkpoint 5 — gold entry safeguards

Date: 2026-11-25. Phase 5 and the following policy choices were explicitly approved:

- Friday new-entry cutoff **20:00 broker-server time**, configurable.
- Mandatory rollover **23:45–01:15**, weekend blocking, no forced position close.
- USD HIGH-impact events **or** configured major-release keywords: inclusive **30 minutes before and after**.
- News coverage cache expires at **15 minutes**; unavailable/stale data blocks entries.
- Tester requires server-time CSV; missing CSV blocks entries, with no silent inactive filter.
- Recheck the union of enabled configured sessions at submission; overlap is one permission, not multiple entries.

**This is not a trading release.** ANALYSIS remains default, both trading defines remain commented out, the REAL manager remains blocked and the independent release interlock remains literal false. No broker request was submitted.

## Implementation

### Entry-only time rules

New `Safety/QSMC_EntryTimeRules.mqh` implements validated minute-of-day membership, including midnight wrap and start-inclusive/end-exclusive sessions. Rollover starts inclusively at 23:45 and ends exclusively at 01:15. Friday blocks at and after the configured cutoff; Saturday and Sunday always block.

When `sessions_enabled` is true, any of Asia/London/New York permits the current server-time minute, subject to all other gates. Disabling that existing session switch does **not** disable rollover, weekend, Friday or news protection. Equal session endpoints and malformed times are not interpreted as all-day permission.

The EA now validates hour/minute components before combining them; 08:90 and 24:00 reject instead of normalizing to a valid minute total. No analytical range/FVG/ICT/session-ownership algorithm was changed.

### News filter and cache

New `Safety/QSMC_NewsPolicy.mqh` contains pure keyword/window/coverage policy. New `Safety/QSMC_NewsFilter.mqh` owns an instance-local, bounded cache:

- Live/non-tester source: `CalendarValueHistory` filtered by USD, then `CalendarEventById` for importance/name/time mode. Queries cover whole server days intersecting the required window so tentative/all-day midnight placeholders are not silently skipped.
- Relevant means USD and either HIGH importance or a case-insensitive configured substring. Defaults cover NFP/nonfarm/payrolls, CPI/consumer prices, FOMC/Fed/interest rates, PCE/personal consumption, GDP/gross domestic product and employment.
- The default keyword list is English. Configure equivalent localized event-name fragments if the terminal's calendar uses another language. HIGH importance remains independent of name matching. Broad substring matches may deliberately over-block.
- Relevant non-exact/tentative/all-day timestamps conservatively block the intersecting server-day query, not just a fictional midnight blackout. Missing event metadata/name or cache capacity overflow blocks.
- Cache validity requires full coverage of current time minus/plus 30 minutes and age strictly less than 900 seconds. Query horizon includes the extra 15-minute forward cache interval. No stale-on-error fallback. Failed refreshes are rate-limited to once per minute while entries remain blocked.
- Time and coverage are checked again after synchronous source I/O; backwards clock/offset-change diagnostics invalidate the cache.
- A successful empty calendar response is treated as no known scheduled events in that queried interval. The filter cannot independently prove the provider's completeness or detect a feed silently reporting an empty success.
- No WebRequest or external service dependency. No news-enabled input or inactive tester bypass was added.

### Composition and final-entry checks

`Safety/QSMC_EntryFilters.mqh` composes current-server-time schedule and news checks and logs status transitions. SafetyController owns it; the authoritative `CanSubmit(root,why)` and mutable compatibility wrapper refresh these checks. The no-argument `CanSubmitOrders()` signature is retained but now always returns false because it cannot refresh news/time; there are no production callers of it.

Preflight primes potentially blocking news I/O before fresh financial checks, repeats the entry checks at the end and rejects quote/account snapshots that aged beyond five seconds while checking. The dormant broker boundary repeats full preflight after OrderCheck and immediately before its sole OrderSend site. No guard commit is automatically cleared if a late veto occurs.

News/schedule vetoes do not invoke EmergencyStop, gate health/risk timers, stop trade-event logging/reconciliation, or issue closes/modifications. Risk monitoring remains independently wired. Calendar calls are synchronous on the EA's event thread, so latency can still delay later events; this is a release-validation concern, not a claim of nonblocking execution.

News is evaluated lazily at submission or explicit `ProbeEntryFilters`, not on every analysis timer. Startup logs explicitly say the source has not yet been queried. A diagnostic probe is not permission to trade; it does not evaluate root, risk, arm state or the release interlock. Analytical signals and a displayed `not evaluated` filter status are not execution permissions.

### Clock and broker-contract diagnostics

- Timer calls observational server-UTC offset diagnostics, using TimeTradeServer and TimeGMT. A change of at least two observed minutes logs a warning, invalidates news cache and requests manual DST/session review. No session is automatically shifted.
- Tester logs that historical UTC/DST offset cannot be inferred from its clock; CSV must already be expressed in historical broker-server time. Offset baseline is memory-only; restart-spanning detection is not implemented.
- Startup logs selected symbol, digits, point, tick size, loss tick value, contract size, volume min/step/max, stops/freeze and fill flags from runtime metadata, plus effective point-to-price equivalents of existing spread/deviation/zone-tolerance inputs. These are diagnostics, not metadata validity certification.
- Existing point thresholds are **not changed**, automatically rescaled or interpreted as fixed dollar values. No hardcoded gold digits, lot contract, symbol suffix or fill mode. The selected exact broker symbol is used; the operator must confirm it is the intended XAUUSD contract. Gold price-unit input redesign and conservative/balanced preset files remain later approved work, not silently invented trading behavior.

### Configuration identity warning

New Friday/news inputs participate in the existing behavior fingerprint. **This changes derived magic/state paths**, including with defaults, because the existing identity design hashes configuration. This is the known QSMC-004 release blocker, not a safe migration. Do not assume old positions, peaks, counters or latches will be inherited. Phase 6 must settle stable ownership and explicit migration before any activation. No identity migration or state deletion was performed here.

## Tester CSV schema

Place the dataset in each tester agent's `MQL5/Files` sandbox and set `InpTesterNewsCsv` to its relative path. Input filenames are not automatically distributed to every agent; provision each local/remote agent. Live/non-tester mode never substitutes CSV for the calendar.

Semicolon-separated ANSI/ASCII text, exactly five fields per row, no BOM, blank rows, embedded delimiters or multiline names:

```text
COVERAGE;YYYY.MM.DD HH:MM:SS;YYYY.MM.DD HH:MM:SS;SERVER;1
EVENT;YYYY.MM.DD HH:MM:SS;USD;HIGH;Event name
```

- Header timestamps are coverage start/end, strictly ordered; SERVER is the explicit timezone assertion; 1 is this CSV schema version.
- Event timestamps must be canonical full broker-server timestamps, within header coverage and sorted nondecreasing. Equal-time events are allowed. Currency must be three uppercase characters; only USD is filtered. Importance must be HIGH, MODERATE, LOW or NONE. A keyword can make a non-HIGH USD row relevant.
- File limit 1 MiB; at most 4,096 event rows and 2,048 relevant cached events; each field at most 512 characters. Invalid/truncated rows, unknown importance and missing/insufficient coverage block.
- Current coverage must include the entire +/-30-minute interval. At expiry the source is reread; if the current window has outgrown coverage, entries block. No UTC conversion or inferred historical DST is performed.
- A coverage-only file is an explicit dataset assertion that there are no known events. Parsing cannot verify that assertion. The provider must include all relevant events, avoid lookahead schedules and withhold/mark invalid coverage when relevant event times are unknown. An invalid/missing timestamp blocks rather than guessing.

`Tests/Fixtures/news_synthetic_example.csv` is an **artificial January 2001 test fixture**, not historical data, not a production news dataset and not automatically loaded or deployed.

## Verification

Command:

```text
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Tests -p 'test_*.py' -v
```

**9 host tests passed**, including all previous risk/latch/boundary tests plus:

1. Actual EntryTimeRules and NewsPolicy headers executed with C++ string shims: all **10,080 minutes of a week** with sessions on and off, overlapping and midnight windows, exact Friday/rollover/session boundaries, invalid hour/minute components, inclusive news boundaries, exact cache expiry, insufficient coverage/backwards clocks, USD scoping and keyword normalization/rejection.
2. Source-shape integration assertions: refreshed entry-gate calls, final broker preflight after OrderCheck, independent risk wiring, explicit tester/live source split and validated EA time-component conversion.

Static structure/API-boundary check: **PASS, 87 MQL source files**. `git diff --check`: **PASS**. C++ shims are not an MQL compiler or runtime API validation.

Added MQL self-test cases for time/news policy boundaries. **Not executed**. `Docs/TESTING.md` lists required terminal calendar/CSV/cache/DST/entry-only regressions and synthetic-fixture instructions.

## Remaining limitations / release blockers

- **MQL errors/warnings UNKNOWN.** No MetaEditor/Wine is available. Calendar APIs, FILE_CSV delimiter/EOF/line-ending behavior, terminal history/tester behavior and broker feed latency require actual compilation and terminal tests. No calendar, CSV-through-MQL, demo execution, restart, backtest or forward test has been run here.
- No claim of protection against unscheduled news, gaps, feed omissions, rescheduling between refreshes, localized unmatched keywords or slippage beyond a checked bound. Live provider completeness cannot be inferred solely from API success.
- Entry checks and OrderSend are not atomic. The platform can cross a time/news/quote boundary after the final check. Broker support remains intentionally unreleased pending complete persistence/reconciliation and platform evidence.
- Stable ownership, schema/durable counters, atomic file replacement, authoritative pending lifecycle and cash-flow/day baselines remain Phase 6. Known analytical findings remain open; midnight analytical range ownership is not repaired by the new entry membership rules.
- No protective position close/modify system was added. No forced Friday close, SL removal/widening, martingale/grid/averaging/recovery logic or trading-enable switch was introduced.
- Audit findings are not certified closed without compile/runtime evidence. Earlier checkpoint documents remain historical descriptions, superseded here only for the Phase 5 additions.

## Approval boundary

**Stopped at Checkpoint 5. Await approval before Phase 6 persistence/ownership work.** That phase requires an explicit stable identity/migration decision; approval to continue is not approval to trade.

Please provide EA and self-test MetaEditor logs when available:

```text
metaeditor64.exe /compile:"<path>\MQL5\Experts\QSMC\QSMC.mq5" /log:"<path>\compile.log"
```
