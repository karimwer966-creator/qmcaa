# Installation — analysis validation only

The current procedure is [DEPLOYMENT.md](DEPLOYMENT.md). Broker trading is not
approved; this is not a live-product installation guide.

Copy Include/QSMC, Experts/QSMC, Scripts and Tests/Harness into matching MQL5
subdirectories. Compile all six entry points in an isolated terminal, inspect logs,
then run the pure safety suite before main-EA ANALYSIS inspection. Preserve relative
includes; copying only the main .mq5 file is insufficient.

Both gold sets load ANALYSIS. DEMO means in-memory simulation; REAL stays blocked.
Keep defines commented and the release interlock closed. Legacy state is not
migrated; Common/Files can be shared by multiple terminal installations, so a
separate terminal folder is not sufficient isolation for persistence fault tests.

MQL errors/warnings UNKNOWN; no MT5 installation/run/import result is claimed here.
See [terminal plan](../Tests/StrategyTester/README.md) and
[configuration](CONFIGURATION.md) before attaching any entry point.
