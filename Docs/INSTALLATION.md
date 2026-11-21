# Installation

## MetaTrader 5 terminal data folder

In MT5 choose **File → Open Data Folder**. Copy the repository subtrees as follows:

- `Include/QSMC/**` → `<data folder>/MQL5/Include/QSMC/`
- `Experts/QSMC/QSMC.mq5` → `<data folder>/MQL5/Experts/QSMC/QSMC.mq5`
- Optional self-test script → `<data folder>/MQL5/Scripts/QSMC_Selftest.mq5`
- `Tests/Harness/QSMC_Selftest.mqh` → `<data folder>/MQL5/Tests/Harness/QSMC_Selftest.mqh`

Open the EA and optional script in MetaEditor and compile. The EA source includes `<QSMC/QSMC.mqh>`. The self-test script includes its harness relatively from `MQL5/Scripts` to `MQL5/Tests/Harness`. Do not copy only the EA: all headers are required.

## Initial operation

1. Compile and inspect MetaEditor diagnostics.
2. Attach to a chart with AutoTrading disabled for the first inspection.
3. Keep `InpMode=QSMC_MODE_ANALYSIS`; REAL is not available and DEMO is virtual.
4. Wait for execution/HTF/LTF history and quotes. Dashboard status must reach `RUNNING` with data `ready` before analysis bars are evaluated.
5. Review Experts and Journal logs. Remove the EA normally to exercise timer/object cleanup.

This installation procedure is not a claim of successful compilation. The code has not been compiled or run on MetaTrader in the sandbox.
