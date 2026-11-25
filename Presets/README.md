# Gold analysis presets — not a trading release

| File | Built-in preset | Effective equity risk | Daily loss limit | Positions | Daily submissions | Cooldown | Drawdown |
|---|---|---:|---:|---:|---:|---:|---:|
| QSMC_Gold_Conservative.set | CONSERVATIVE | 0.25% | 1% | 1 | 3 | 900 s | 6% |
| QSMC_Gold_Balanced.set | BALANCED | 0.50% | 2% | 1 | 5 | 300 s | 10% |

These reproduce the existing built-in profiles; they are not optimized or evidence
of profitability. Both explicitly load **ANALYSIS**, blank real acknowledgement,
closed bars and session/news safety settings. All 59 main-EA inputs are present.
`InpOverridePresetRisk=false` intentionally makes the selected built-in preset
authoritative; the displayed input risk/geometry values also match that preset.
The host tests check both the file values and the current built-in source values.

Load using the main EA's Inputs -> Load in an isolated terminal first. Verify all
values in MT5 after loading; file import has NOT been tested here. These are plain
ASCII key=value sets with no optimization ranges. They are not input files for
the separate safety-selftest EA, which has no strategy inputs.

- Empty symbol means the chart's exact broker symbol, including any suffix.
- M15 execution, H4 higher and M5 lower timeframe are explicit.
- Existing spread caps remain **points**: 20 Conservative, 30 Balanced; deviation
  is 10 points. Startup logs show price equivalents from runtime point size.
  These are NOT universal dollar/price-unit gold limits. Review contract, costs,
  stop/freeze/filling metadata and server clock for each broker; do not loosen
  controls merely to force a test pass.
- Sessions are broker-server 02:00–08:00, 09:00–12:00 and 15:00–18:00. Friday cutoff
  is 20:00. Review DST manually. Rollover/weekend/news guards remain mandatory.
- Tester news CSV is deliberately blank, not silently set to the synthetic fixture.
  Any future attempted paper/broker entry requiring news must block without a
  valid covering dataset. ANALYSIS itself does not claim news-filtered execution.
- Both files use owner magic 53000001. Choose a reviewed unique operator magic
  for a genuinely different owner; do NOT change magic to bypass state/latches.
  An operational second instance of the same owner is refused. Do not assume
  legacy state or positions are migrated by loading a preset.
- The general AGGRESSIVE preset still exists in source but is not shipped as a
  gold set. No preset enables either compile define or the release interlock.

Loading a preset does not supply enrollment, pending recovery, a valid news feed,
MQL compile evidence or approval to trade. Phase 6 manual baseline/migration
restrictions remain. Follow Tests/StrategyTester/README.md; do not deploy for
trading based on host checks or the presence of these files.
