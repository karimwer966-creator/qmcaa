# Current architecture — source implementation, unreleased

## Composition

Core owns configuration, lifecycle, explicit ownership, fingerprint diagnostics and
execution policy. Infrastructure owns clocks/logging, scalar schema and scoped
state. Data/Analysis/Decision build copied evidence and heuristic candidates.
Safety composes incident/health and entry-only time/news checks. Execution owns
risk/replay/preflight/adapters; App composes event flow; Presentation only renders
copied state. See [dependency graph](DEPENDENCY_GRAPH.md).

The public QSMC.mqh aggregator is not an alternative submission authority. Individual
modules use relative dependencies. Core does not include App, and analysis/decision
modules do not submit orders. Source structure checks do not replace MetaEditor.

## Lifecycle and event flow

1. Main OnInit builds defaults/preset/inputs; Root validates and builds the raw
   account/server/symbol/explicit-magic scope. Fingerprint no longer derives magic.
2. Bootstrap opens a read-only ANALYSIS/OFF store or claims an operational writer.
   It checks raw scope, legacy/conflicting artifacts/exposure and commits identity
   only for an operational writer. Ordinary fingerprint drift is diagnostic.
3. Market provider/readiness, scanners, safety, execution manager and renderer
   initialize. Timer startup/data prerequisites are fallible; cleanup handles
   partial Init failure. There is no claim this lifecycle has been platform-tested.
4. READY retries history/readiness. Start permits RUNNING only under policy; an
   incident/health block moves it to SAFE_MODE. No automatic SAFE_MODE resume.
5. Closed-bar scans commit the analyzed bar only after scanner success; failed
   work is retried within the same candle. All model outputs remain heuristics.
6. Operational timer events invoke risk monitoring independently of intents for
   DEMO/REAL capability modes, not ANALYSIS/OFF. Missing reviewed baselines or
   recovery uncertainty veto/latch rather than inventing values. Entry-only
   news/time filters do not gate that monitor.
7. Trade callbacks log events even in SAFE_MODE; they do not send orders or certify
   pending lifecycle completion. Deinit stops events/timer, reports commit failures,
   closes claims, cleans rendering/provider resources and shuts down Root.

## Analysis is not execution

Snapshots cover execution/HTF/LTF series, with closed-only consumers using their
newest eligible closed bar. Heuristic modules cover swings/bias/zones/liquidity,
sessions/FVG/ICT-inspired setup paths, BOS/CHoCH-OB proxies, tick-volume pressure,
SVP approximations and Elliott annotations. Candidate scores are not probabilities,
and tick volume is not aggressor-side order flow or exchange volume-at-price.

The analytical models were NOT corrected during Phases 3–8. The baseline audit
reports inverted FVG labels, ATR indexing, incompatible default ICT constraints,
causality, SVP, EMA and midnight session-range problems among other findings.
Descriptions of intended sequences are not proof that code satisfies them.
See [historical audit](../docs/01_AUDIT_REPORT.md) and [limitations](KNOWN_LIMITATIONS.md).

Per-bar opportunity CSVs remain non-authoritative local analytical logs. Their
older magic-based naming is not the schema-2 safety-state namespace. The OOS tool
is a descriptive close-to-close study, not realistic trading simulation.

## Execution boundary

Main App has no normal intent-construction/submission route. The manager resolves
ANALYSIS/OFF disabled, DEMO simulated and REAL blocked. Dormant broker request code
exists behind compile guards but cannot arm with ReleaseApproved=false. Checked
submission validates context/preflight/writable state and committed UID guards;
context-free REAL submission refuses. No retry or pending clearance is automatic.
See [execution safety](EXECUTION_SAFETY.md).

## Persistence/recovery boundary

Operational locks are non-shared OS file handles in Common/Files. Typed, scoped,
checksummed snapshots alternate generations via verified staging; ambiguous or
corrupt artifacts block rather than silently rolling back. The checksum is not
cryptographic authentication, and power-loss/rollback guarantees are incomplete.

Account-wide peak and review state use a separate short-held account-scope claim.
Owner-day baselines require clean-day review; no automatic rollover. Bounded
hedging lifecycle replay reconstructs counters from available history without
clearing pending uncertainty. General migration, recovery release and compaction
are unsupported. Complete history and atomic broker snapshots cannot be proved
from API success. See [persistence checkpoint](../docs/05_PERSISTENCE_CHECKPOINT.md).

## Verification

16 host tests and a 94-source structural check passed. Actual MQL compilation,
42-check pure terminal suite, locks/storage/calendar/CSV/restart/broker integration
remain NOT RUN/UNKNOWN. No release, strategy correctness or profitability claim.
