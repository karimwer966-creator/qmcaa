# Checkpoint 6 — scoped persistence and conservative recovery

Date: 2026-11-25. This is a source-implementation checkpoint, **not a storage durability certificate or trading release**.

## Approved policy

The user explicitly selected:

1. Stable ownership = account login + broker server + exact symbol + positive operator-assigned magic; default **53000001**. Chart, timeframe, software version and ordinary configuration changes no longer derive a different owner.
2. Manual legacy migration. Preserve old files; never automatically take over positions, reset counters or clear old latches. Operational startup refuses detected legacy/ambiguous state or exposure. ANALYSIS may remain diagnostic-only.
3. Account-wide equity high-water drawdown without automatic cash-flow adjustment; ownership-scoped day loss baselines. Missing/ambiguous baselines block entries rather than being invented. Day changes never clear an active safety latch.

**Safety unchanged:** ANALYSIS default; both trading defines commented out; REAL manager blocked; independent release interlock literal false. No broker execution was attempted.

## Stable identity and writer ownership

- Added `Core/QSMC_OwnerScope.mqh`, a validated length-prefixed raw account/server/symbol/magic scope. Hashes name files/keys only; stored raw scope must match exactly when loading.
- Added `InpOwnerMagic`/`owner_magic`, validated in [1,2147483647]. Existing identity Build signature remains callable with an optional explicit-magic argument. `magic_offset` is deprecated and retained/validated only for compatibility; it no longer changes ownership.
- Fingerprints remain configuration-drift diagnostics. Bootstrap logs drift and preserves safety/counter state instead of treating ordinary input changes as new ownership. Display identity may still include timeframe; that display string is not ownership authority.
- Operational owner claims use an OS-held, non-shared common-files lock handle until Deinit/destruction. No clock/lease-expiry takeover. ANALYSIS/OFF open read-only and cannot save, mutate or operate the kill switch. Read-only diagnostic instances do not claim an operational writer slot.
- Store readiness also checks current login/server against its original raw scope, preventing an account switch from leaving the old store writable.
- Account risk has a separate shared scope using reserved marker `__ACCOUNT_RISK__` and magic 1. Normal trading configuration rejects that reserved symbol. Its short-held writer claim serializes account peak/review updates across owner scopes; contention fails closed rather than reading unlocked.

## Schema-2 storage

`Infrastructure/QSMC_StateStore.mqh` now uses terminal **Common/Files/QSMC**, not the old per-terminal magic-only state path:

```text
v2_<scope-hash>.lock
v2_<scope-hash>.a.state
v2_<scope-hash>.b.state
v2_<scope-hash>.tmp
```

Kill GV names are `QSMC_GV_V2_<scope-hash>_kill`. Terminal globals are a local-terminal secondary brake; common-file snapshots/claims are the cross-terminal mechanism.

Each UTF-16 snapshot contains schema marker, full raw scope, generation, entry count, typed key/value rows and an FNV checksum footer. The checksum detects accidental corruption; it is **not authentication or protection from deliberate editing**.

New `Infrastructure/QSMC_StateCodec.mqh` validates scalar grammar and critical-key types, rejecting malformed numeric/bool/UID fields, wrong safety-key type and line/control-character injection. Existing public getters/setters remain, with typed writes and finite doubles. Duplicate keys, wrong schema/scope, count/footer/checksum failures and invalid slot parity are rejected before a loaded snapshot can be used.

Save stages a complete next generation, checks write length/error, flushes, closes and rereads/verifies staging before replacing the alternating slot with FileMove. **No FileDelete or in-place-write fallback exists in StateStore.** A failed write/flush/verification/move poisons that instance's store, preserves staging/prior slots and blocks further normal use.

Load validates every existing slot, then selects the highest valid generation. An unresolved staging file or **either corrupt slot blocks loading**; the code does not silently fall back to a previous guard/counter generation. Lock handles close on explicit Close, Deinit and object destruction. Interrupted artifacts are deliberately left for review, not auto-cleaned.

FileFlush/FileMove/OS crash semantics still require platform fault tests. Flush APIs do not establish power-loss durability, and this implementation does not claim a cross-file/file-GV atomic transaction. Manual deletion of whole snapshots is outside the recovery contract; without an external monotonic anchor, deletion of a complete newest generation cannot always be distinguished from an earlier legitimate state. Do not delete/rename artifacts to bypass a refusal.

## Legacy migration behavior

Bootstrap checks for old `QSMC/state_*.state` files in the current terminal's files and common-files roots, and active old numeric-magic kill GVs. Detected artifacts block DEMO/REAL startup, without deleting, renaming, loading or rewriting them. Because old files lack reliable account/server scope, the refusal is deliberately broad and may include unrelated old QSMC artifacts requiring review.

Position/order enumeration rejects unreadable ownership, legacy reserved-band magic conflicts, same-magic cross-symbol exposure and matching exposure without scoped state. A second writer of the same scope is refused by the claim. This is conservative conflict detection, **not a proof that all historical positions can be identified**.

No automated migration, legacy-state merger, pending-intent clearance or general recovery-release tool was implemented. Review must preserve old magic, raw broker/account/symbol identity, pending UIDs, latches, equity peaks, baseline provenance and history evidence before any separately approved migration. Legacy artifacts in another terminal's private data directory, on another machine, or already removed are not exhaustively discoverable here; file-search errors also need platform validation. There is no permission to ignore them based solely on this scan.

## Risk enrollment and daily baseline policy

`RiskManager::CaptureAccount` no longer invents a missing peak or day baseline. It requires:

- Reviewed account enrollment time and finite persisted account peak in the shared account scope.
- Reviewed owner enrollment, current server-day stamp, finite positive day-equity denominator and explicit floating baseline.
- Successful history replay, owned-position observations and checked state commits.

Account peak is monotonic and shared across symbols/owner magics; deposits/withdrawals do not automatically adjust it. Daily loss is:

```text
max(0, -(owned realized net since server midnight
         + current owned floating profit/swap
         - reviewed day floating baseline)) / reviewed day equity * 100
```

The supplied enrollment tool deliberately supports **clean flat-day baselines only**, so its floating baseline is zero. It does not reconstruct hypothetical midnight floating equity from current data.

### Explicit enrollment script

New `Scripts/QSMC_EnrollRisk.mq5` is a manual review tool, **not an EA auto-start mechanism**. Compile and validate it only in an isolated terminal first. Stop operational EAs that hold the intended owner claim before running it.

It requires the exact acknowledgement `I-REVIEWED-CLEAN-ACCOUNT-AND-DAY`, the intended exact symbol/magic, no detected legacy artifacts, an entirely flat/order-free account and **no account deals on the current server day**. It refuses an existing same-day baseline, invalid/poisoned snapshots, pending UID or account review-required marker. This is stricter than simply clicking an acknowledgement after losses.

It preserves account enrollment time/peak and all existing safety flags; commits account enrollment/peak before the owner day baseline, rechecking account inactivity between them. A partial two-store commit must not be treated as successful enrollment. It does not clear latches or pending intents, approve positions, enable defines or release trading. If the clock rolls to a new day, the EA blocks until a new reviewed clean-day baseline is supplied. **Automatic midnight baseline reconstruction/rollover is not implemented.** A day with activity that cannot satisfy the tool requires separate recovery review; no reset bypass is supplied.

Missing baselines encountered by the operational monitor cause an uncertain safety latch. Enrollment leaves that latch engaged. Existing explicit acknowledgement methods still require review and do not start the root; there is no new one-click EA acknowledgement/reset input in this phase.

## History replay and counters

New `Execution/QSMC_RiskRecovery.mqh` performs bounded, read-only hedging lifecycle replay from available history:

- Full magic/symbol ownership, checked fields, chronological deal times, realized profit including commission/swap/fees.
- Groups by position identifier; entries and partial exits update volume; only final closure counts a completed trade. Remaining volumes must match current owned open-position identifiers/volumes.
- Reconstructs closed trades today, loss streak, SL/TP final-close classifications and last entry time. Break-even/nonnegative completed trades reset the reported loss streak; final exit reason determines SL/TP classification. These are reported counters; **no new loss-streak threshold was invented**.
- Account nontrade deals since enrollment, unsupported reversals, missing entries, overclosed/mismatched volumes, invalid fields, unordered history and capacity overflow refuse capture. A replay refusal attempts a persistent **account review-required marker**; the enrollment script cannot clear it.
- Hard bounds: 100,000 history deals and 256 position lifecycles. Exceeding either blocks rather than dropping history. Compaction/archival with verified anchors is not implemented.

Risk capture runs on an operational timer and before submissions, saving reconstructed counters and current scoped day net. Daily entry-order observations can only raise, never lower, the committed daily submission guard. Cooldown uses the later committed/replayed entry timestamp. Paper submissions remain separate from real deal counts.

Broker history success cannot prove the provider returned every historical lifecycle. Missing entry/open-position mismatches are detected; entirely omitted completed lifecycles or equal-size concurrent changes may not be. No claim of authoritative broker-history completeness or atomic account/deal/position capture is made. A general historical migration or repaired cash-flow baseline requires separate review, not guessed reconstruction.

## Pending intents and safety propagation

- Pending UID restores an uncertain latch even if ordinary safety flags are false. Day changes, recent-UID ring rollover and replay never clear it. Ordinary acknowledgement remains refused while pending exists.
- The dormant broker manager records retcode/request/order/deal/fill/outcome metadata after an attempted submission; persistence failure marks uncertainty and latches. Broker acceptance still does not certify final fill/protection or lifecycle resolution.
- Timer and shutdown commit failures are surfaced and request an uncertain brake. Orchestrator EmergencyStop propagates persistence success/failure rather than unconditionally returning success.
- Trade-event logging remains enabled in SAFE_MODE. No automatic pending reconciliation/clearance, broker retry or protective close/modify path was introduced.

## Verification performed

```text
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Tests -p 'test_*.py' -v
```

**12 host tests passed**, including prior entry/news/risk/latch checks and:

- Actual OwnerScope/StateCodec headers under C++ scalar shims: raw scope separation, invalid identities, integer/UID bounds, malformed scalars, critical-key types and control-character rejection.
- Actual RiskRecovery header under a fake broker: partial exits, final trade counts, replay idempotence, loss-streak reset, final SL/TP counts, net day P/L, open-volume matching, missing entries, foreign ownership, overclose/reversal, unordered history, cash-flow veto and bounded overflow.
- Source-shape assertions for non-destructive snapshots, exclusive claim flags, scope/seal checks, no pending removal and baseline refusal.

Static check: **PASS, 91 MQL files**. `git diff --check`: **PASS**. MQL self-test source updated for stable identity, read-only reload, typed safety-write rejection and duplicate writer refusal; **not executed**.

**MQL errors/warnings UNKNOWN.** MetaEditor/Wine is unavailable. None of these host tests compile MQL or validate actual MT5 common-files locks, Unicode/EOF behavior, FileMove/FileFlush semantics, terminal GVs, crashes, real broker history or enrollment. No terminal state was imported, migrated or deleted by this agent.

## Outstanding validation and limitations

- Required platform tests are listed in `Docs/TESTING.md`: crashes/short writes/disk-full/rename failures, two-terminal contention, schema corruption, state/scope collisions, account switching, clean-day enrollment, restart recovery and uncertain pending intents.
- Conservative restrictions are intentional: read-only diagnostics can fail if they observe an in-progress staging artifact; account-risk claim contention vetoes/latches; stale/missing day baselines require manual review; replay capacity is bounded; unexpected standalone commission/nontrade postings can require account review.
- Explicit state migration, general recovery release, verified history compaction/anchors and automatic safe day rollover remain unsupported. No durable all-time intent archive or transaction-driven pending lifecycle resolver is supplied. These limitations are release blockers where the deployment requires them.
- Existing opportunity/log files still have older non-authoritative naming conventions; this phase scopes safety state/claims and persisted execution outcome metadata, not a complete historical log migration.
- Analytical findings and strategy thresholds were not changed. Prior checkpoint documents describe their historical implementation stage; their magic/state-path and automatic first-peak descriptions are superseded here.
- No audit finding is certified closed and no production-readiness, zero-warning or profitability claim is made.

## Checkpoint

**Stopped at Checkpoint 6.** Await approval before Phase 7 tests/presets. Proceeding to test preparation is not permission to arm or release broker execution. The unsupported recovery workflows above and terminal validation must remain explicit in any release decision.

Compile EA, self-test script and enrollment script and provide their logs before any deployment:

```text
metaeditor64.exe /compile:"<path>\MQL5\Experts\QSMC\QSMC.mq5" /log:"<path>\compile.log"
```
