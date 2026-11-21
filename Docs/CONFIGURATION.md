# Configuration

EA inputs are translated to `SQSMCConfig` in `Experts/QSMC/QSMC.mq5`. Core validation rejects empty/unknown symbols, invalid timeframe order, out-of-range numeric values, and REAL mode while the build gate is zero.

## Defaults

- Mode: ANALYSIS; preset: BALANCED; symbol: chart symbol.
- Execution/HTF/LTF: M15/H4/M5; timer 1000 ms; closed bars only; 600 bars.
- Swing widths 2/2; structure lookback 300; zone lookback 200; SVP lookback 240 / 40 bins / 70% value area.
- Risk preset values: 0.5% per trade, 2% daily limit, 30 point spread cap, one position, 2 lots exposure, 5 trades/day, 300 second cooldown, 10% drawdown cap. These are validated configuration values; not all controls are wired into a completed execution lifecycle.

## Presets and overrides

The preset is applied before explicit strategy inputs. To avoid every numeric input silently defeating the selected preset, risk-related inputs are applied only when `InpOverridePresetRisk=true`. When enabled, the risk inputs override the preset. `InpPreset=CUSTOM` keeps defaults unless override inputs are enabled.

## Important limits

- Risk percent is bounded to (0, 2%]; daily loss to (0, 5%]; max RR <= 10; timer 100–60000ms; bars <= 5000; profile bins <= 80; magic offset [0, 999999].
- REAL acknowledgement text cannot bypass `QSMC_ALLOW_REAL=0` and the RealAdapter block.
- Chart layers/dashboard are presentation toggles only.
- Values affect an analytical prototype. They are not validated trading recommendations.
