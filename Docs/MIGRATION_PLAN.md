# Migration/recovery restrictions — no automatic migration tool

## Identity change

Legacy ownership depended on config/version/chart/timeframe and selected a local
magic-only state filename. Current ownership is raw account login + broker server
+ exact symbol + explicit operator magic. Fingerprint drift is diagnostic, not a
new owner. New safety snapshots live in Common/Files/QSMC/v2_<scope-hash>.* with raw
scope inside; scoped terminal kill keys start QSMC_GV_V2_.

**This is not a compatible in-place state migration.** Loading a new preset,
choosing a magic or seeing an empty new scope does not adopt old positions/counters.
Operational bootstrap refuses detected legacy files/active old kill GVs and certain
conflicting/missing-state exposure. Detection cannot enumerate every private data
folder/machine, missing old artifact or broker-omitted history. ANALYSIS is read-only;
its ability to inspect is not migration clearance.

## Required review, not an executable repair recipe

1. Stop affected instances, verify no writer is active and preserve ALL original
   files, staging/slots, logs and relevant terminal globals. Do not delete lock or
   staging artifacts to bypass errors. Separate terminal folders may share storage.
2. Inventory raw account/server/symbol/magic identities, open positions/orders,
   pending UIDs and last broker responses, all latches/review markers, peak equity,
   day-baseline provenance, committed counters/cooldown and available history.
3. Resolve conflicts and incomplete history with operator/broker evidence. Never
   assume absence of a fill after timeout, silently reassign a position, reset
   equity peaks or reduce consumed-intent guards. Account cash flows require review.
4. Specify and approve an explicit mapping/recovery procedure, including how
   uncertainty and schema versions are retained. Test it in isolation against
   interrupted commits and restarts before it may touch operational state.

No general migration/merger, poisoned-slot repair, pending clearance, review-marker
release or verified history compaction tool was delivered. The steps above do not
supply one and do not authorize manual file editing/resealing or old-state deletion.
Keep unsupported recovery blocked; request a separately reviewed implementation.

## Enrollment is NOT migration or reset

QSMC_EnrollRisk is an explicit clean-day enrollment tool only. After compilation
and isolated validation, it still requires an exact review token, intended raw
scope, no detected legacy artifacts, a fully flat/order-free account and no
account deals today. It refuses a same-day reset, pending UID, poisoned snapshot
or persistent account-review marker. It preserves account enrollment time/peak
and all safety latches. Account and owner writes are not one atomic transaction.

Automatic day baseline rollover is unsupported. A missing next-day baseline blocks
until reviewed clean-day enrollment; an active day that cannot meet those conditions
requires separate recovery review. Enrollment after an uncertain safety stop does
not clear that stop or start the root. No new one-click acknowledgement UI exists.
Do not use a new magic/account/symbol to evade this workflow.

## Rollback

Keep binary/source and schema evidence together. Never attach an older build to
schema-2 files or restore an older valid slot as a shortcut: that can erase newer
pending/UID guards. Interrupted staging or either corrupt slot intentionally blocks
loading. Backup restoration or cash-flow adjustment needs its own reviewed plan.
No crash/power-loss/rollback procedure is certified by the host tests.
