# Changelog

## Unreleased — 2026-11-25 safety-hardening checkpoints 0–8

**Not a trading release; MQL errors/warnings UNKNOWN; terminal results NOT_RUN.**

- Delivered historical inventory and 38-finding severity-ranked audit. No finding
  certified closed without compiler/platform evidence.
- Added independent build/account/acknowledgement policy and literal-false release
  interlock; both trading defines remain commented out, ANALYSIS default retained.
- Added unreachable broker request/outcome foundation with checked preflight,
  retcode classification, runtime filling and pending guards; no normal main-App
  submission route, retries or lifecycle clearance enabled.
- Hardened equity-based risk/volume/margin checks, latch restore/failure handling,
  fresh preflight and operational risk monitoring. Approved margin reserve is
  max(10% equity, planned stop risk) after estimated entry margin.
- Added strict USD news/time entry guards, Friday 20:00, rollover/weekend/session
  checks, manual DST warnings and runtime contract/price-unit diagnostics.
- Replaced config-derived ownership with explicit magic/raw account-server-symbol
  scope; added common-files writer claims and typed sealed schema-2 snapshots.
  **Breaking state/identity change; no automatic legacy migration.**
- Added bounded history replay, sticky uncertainty/review markers and explicit
  clean-day enrollment. Automatic day rollover/general recovery remain unsupported.
- Added 0.25%/0.50% ANALYSIS gold sets, 42-check pure MQL safety source suite,
  strict host evidence runner and 23-case terminal NOT_RUN matrix. Sixteen host
  tests passed; no MT5 execution result or profitability claim.
- Updated current README/deployment/configuration/architecture/safety/migration
  documentation and known limitations; retained historical reports and casing.
- No analytical rules, proprietary strategy definition or aggressive preset was
  corrected/optimized in these hardening phases. No broker order was sent.

## Historical baseline — reconstruction (superseded where noted)

The entries below describe the earlier implementation stage, not current broker,
identity or storage architecture. See the dated unreleased section above.


- Replaced incomplete core/lifecycle contracts with validated config, identity/fingerprint, explicit state machine and root.
- Added infrastructure, data provider/snapshot/readiness, analysis heuristics, SVP profile approximation, auditable decision pipeline, safety latch/health and preflight contracts.
- Added application orchestrator, EA event handlers, dashboard/chart layers, virtual demo adapter and intentionally disabled real adapter.
- Added primary session-liquidity-raid → MSS → FVG-retest and secondary BOS/CHoCH → OB-proxy retest models with common HTF-bias, session and liquidity filters; optional tick-volume/Volume Profile context and a small non-standalone Elliott confluence hint.
- Added append-only per-bar model/arbiter accept-wait-reject audit CSV and a chronological in-sample/out-of-sample forward-return reporting script (requires user-supplied MT5 history export).
- Added public aggregator, self-test harness, installation/configuration/architecture/safety documentation.
- MetaEditor compilation, MT5 runtime tests and Strategy Tester scenarios were not available and remain unverified.
