# Current configuration

The main EA maps inputs to SQSMCConfig. Order: defaults → built-in preset → explicit
inputs. Risk/geometry fields inside `InpOverridePresetRisk` apply only when it is
true: risk%, daily loss, spread, positions, exposure, daily trades, cooldown,
drawdown, SL ATR multiplier, minimum/target RR and minimum confidence. Other
strategy/time/identity inputs are applied independently. CUSTOM retains defaults
unless explicit overrides are selected. Read actual effective-config logs; input
labels alone do not prove an override took effect.

## Safe defaults and gold sets

ANALYSIS, BALANCED, chart symbol, M15/H4/M5, 1000 ms timer, 600 bars, closed bars.
Balanced risk is 0.50%, daily loss 2%, spread 30 points, one position, two-lot
exposure cap, five submissions/day, 300-second cooldown and 10% equity drawdown.
Conservative uses 0.25% risk, 1% daily loss, 20 points, one position, one-lot cap,
three submissions/day, 900-second cooldown and 6% drawdown. These are configuration
caps, not promised loss bounds. Actual lot sizing may reject or be much smaller.

The [two complete gold .set files](../Presets/README.md) load ANALYSIS with risk
<=0.5%, no real acknowledgement and `InpOverridePresetRisk=false`. Both use the
same explicit owner magic. Generic AGGRESSIVE remains 1% in source and is not a
gold set. Generic hard risk cap remains 2%; Phase 8 does not retune policy.

## Units and time

Spread/deviation/zone tolerance are raw broker points, not gold dollars. Values
are not auto-rescaled by digits; runtime point/tick/contract metadata are logged.
Volume uses broker min/max/step. No symbol-name/suffix normalization is performed;
confirm the exact chart/InpSymbol is the intended XAUUSD contract.

Existing analytical windows: Asia 02:00–08:00, London 09:00–12:00, New York
15:00–18:00, broker-server time. Components are validated before conversion.
Entry membership is start-inclusive/end-exclusive, supports midnight wrap and
unions overlaps when sessions are enabled. Turning sessions off does not disable
rollover, weekend, Friday or news gates. Analytical range ownership has separate
open audit findings and is not certified by entry membership tests.

Friday cutoff inputs default to 20:00. Mandatory rollover is 23:45–01:15; weekends
block entries. No automatic DST session shift or forced Friday close. Offset-change
warnings request manual review; tester clocks cannot infer historical DST.

News keywords are semicolon-separated, case-insensitive USD event-name fragments.
HIGH importance is relevant regardless of keyword. Default fragments are English;
review localization. Windows are fixed inclusive ±30 minutes, cache <15 minutes.
`InpTesterNewsCsv` defaults blank; prospective tester entries block without valid
covering CSV. The synthetic fixture is never a real dataset or auto-loaded fallback.
Full schema: [Phase 5 report](../docs/04_GOLD_FILTERS_CHECKPOINT.md).

## Ownership and state

`InpOwnerMagic=53000001` is stable operator assignment, valid [1,2147483647]. Raw
scope includes account login, broker server and exact symbol. Chart, timeframe,
version and ordinary input changes do not select a different owner. Fingerprints
log configuration drift without resetting counters/latches. `InpMagicOffset` is
deprecated and no longer changes ownership; do not use it as a reset mechanism.

Operational duplicate writers are refused. ANALYSIS/OFF use read-only state.
Schema-2 safety state lives in Common/Files/QSMC with a scoped hash filename and
full raw scope inside; legacy magic-only state is not auto-imported. Missing
reviewed account/day baselines block. See [migration](MIGRATION_PLAN.md).

## Modes and limits

DEMO is paper simulation only. REAL remains refused independently of any exact
acknowledgement, the deprecated QSMC_ALLOW_REAL macro or the two commented-out
trading defines. No input releases the literal-false interlock. No normal main-EA
intent-submission route was added.

Validation includes finite numeric bounds, timeframe ordering, timer 100–60000 ms,
bars <=5000, profile bins <=80, RR <=10 and existing generic risk caps. Validation
is source-level and unverified on MT5. Do not interpret accepted configuration,
RUNNING, an analytical candidate or an active chart overlay as entry permission.
