# Deployment procedure — isolated analysis validation only

**No broker-trading deployment is approved.** This is a staged validation procedure,
not instructions to enable real execution. Keep both trading defines commented,
ReleaseApproved=false, real acknowledgement blank and the main EA in ANALYSIS.

## 1. Isolate and preserve evidence

Use a dedicated OS profile/VM and demo/tester environment with no production state.
A second terminal folder alone may still share Common/Files with production.
Back up source and any existing terminal files/GVs before testing. Do not delete,
rename or edit safety artifacts to force startup. Do not run disk/crash/fault tests
against a funded account or a directory shared with active owners.

Record source hashes, dirty-worktree status, terminal/MetaEditor versions, exact
broker server/symbol/suffix, contract summary, server clock/DST assumptions, input
set, dates and data provenance. Never collect passwords/tokens; redact identifiers
when sharing logs. Preserve original evidence alongside any redacted copy.

## 2. Copy selective source trees

In MT5: File -> Open Data Folder. Copy:

| Repository | Terminal data directory |
|---|---|
| Include/QSMC/** | MQL5/Include/QSMC/** |
| Experts/QSMC/** | MQL5/Experts/QSMC/** |
| Scripts/*.mq5 | MQL5/Scripts/*.mq5 |
| Tests/Harness/** | MQL5/Tests/Harness/** |

Keep these relative layouts for test includes. Presets may be loaded from the
repository via Inputs -> Load. Tests/Fixtures is not deployable news; provision a
reviewed dataset separately per tester agent when a scenario requires one.

Docs/ and docs/ have a known case-insensitive filesystem naming risk. No rename
was approved/performed. Avoid blind whole-tree merges into Windows paths; review
checkout conflicts and copy only the required MQL subtrees, not .git or old state.

## 3. Compile before attaching

Use MetaEditor and inspect complete logs for **all six entry points** listed in
[the terminal plan](../Tests/StrategyTester/README.md). Example main compile:

```text
metaeditor64.exe /compile:"<path>\MQL5\Experts\QSMC\QSMC.mq5" /log:"<path>\main_compile.log"
```

Target zero errors/warnings; process exit alone is insufficient. None has been
compiled here. Stop and review errors rather than weakening gates to get a build.
Compiling QSMC_EnrollRisk is not approval to run it.

## 4. Pure safety checks, then analysis

Run Scripts/QSMC_SafetySelftest or the separate tester-only safety expert. Inspect
all 42 checks and the final 42/0 marker; absence/failure is not PASS. It has no
explicitly invoked state/calendar/order side effects. The broad QSMC_Selftest DOES
create/delete synthetic common-file test artifacts and belongs only in isolation.

Load one gold set into the MAIN EA, verify all imported inputs and retain ANALYSIS.
Both use the same owner magic, blank acknowledgement/news path, and 0.25% or 0.50%
risk parameters. Those parameters do not cause ANALYSIS to trade or enroll risk.
Review point-based cost caps, current symbol metadata, server-session clock and
readiness/health. AutoTrading disabled may be reported as degraded permissions;
that is not a reason to enable broker execution. A displayed analytical signal is
not entry permission and known strategy defects remain open.

## 5. Run and record terminal scenarios

Copy results_template.csv for an actual run. All 23 scenarios start NOT_RUN. Use
separate evidence for compile, pure tests, analysis, state/restart and controlled
fault tests. A main-EA zero-order run does not test its dormant broker path.
No terminal file/order fault injector is supplied; do not improvise one on real
state. No test here authorizes broker demo/live orders or enabling defines.

Missing news, unsupported netting, missing baselines, pending uncertainty, stale
quotes or legacy conflicts are expected **vetoes**, not obstacles to bypass. Record
why the veto occurred; a different earlier veto does not prove the intended guard.

## 6. Stop and hand off

Remove EA normally; preserve logs, state/claims and exact inputs. Report cleanup
or commit failures. Ordinary shutdown/restart must not clear latches or pending
markers. Do not roll back binaries against newer state or restore an older slot
without reviewed recovery; code/state rollback can discard consumed-intent guards.

[Migration restrictions](MIGRATION_PLAN.md) and [known limitations](KNOWN_LIMITATIONS.md)
remain release blockers. Future trading release requires unsupported workflows to
be completed or explicitly excluded, clean compiler/runtime evidence and a new
explicit approval. Documentation completion does not grant that approval.
