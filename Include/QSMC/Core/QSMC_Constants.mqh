//+------------------------------------------------------------------+
//|                                                QSMC_Constants.mqh |
//|                                         QSMC Quantitative Framework|
//|                        Central compile-time constants and hard caps |
//+------------------------------------------------------------------+
#ifndef QSMC_CONSTANTS_MQH
#define QSMC_CONSTANTS_MQH

//--- naming / namespacing
#define QSMC_OBJ_PREFIX          "QSMC_"
#define QSMC_GV_PREFIX           "QSMC_GV_"
#define QSMC_FILE_FOLDER         "QSMC\\"

//--- magic-number space (order magic must stay inside one contiguous band)
#define QSMC_MAGIC_BASE          53000000
#define QSMC_MAGIC_RANGE         1000000

//--- capacity limits (fixed-size buffers, no dynamic growth at runtime)
#define QSMC_MAX_SYMBOLS          32
#define QSMC_MAX_TIMEFRAMES        9
#define QSMC_MAX_BARS            5000
#define QSMC_MAX_STRUCT_POINTS     64
#define QSMC_MAX_ZONES             64
#define QSMC_MAX_LEVELS            64
#define QSMC_MAX_PROFILE_BINS      80
#define QSMC_MAX_SIGNALS           16
#define QSMC_MAX_REJECTIONS        32
#define QSMC_MAX_JOURNAL          256
#define QSMC_MAX_LOG_ENTRIES      256
#define QSMC_MAX_STORE_KEYS        64
#define QSMC_MAX_DIAGNOSTICS       32
#define QSMC_MAX_POSITIONS          8

//--- timing
#define QSMC_TIMER_DEFAULT_MS    1000
#define QSMC_TIMER_MIN_MS         100
#define QSMC_TIMER_MAX_MS       60000
#define QSMC_UI_REFRESH_SECONDS       2

//--- numeric helpers
#define QSMC_INVALID_INDEX        (-1)
#define QSMC_EPSILON              1e-8

//--- risk hard caps (validated in SQSMCConfig::Validate)
#define QSMC_RISK_MAX_PERCENT          2.0
#define QSMC_RISK_DEFAULT_PERCENT      0.5
#define QSMC_DAILY_LOSS_MAX_PCT        5.0
#define QSMC_MAX_SPREAD_POINTS_HARD  500
#define QSMC_MAX_TOTAL_EXPOSURE     100.0
#define QSMC_MAX_RR                  10.0
#define QSMC_MIN_RR_FLOOR             1.0

//--- deprecated compatibility macro; grants NO execution authority.
//    Broker policy now lives in QSMC_ExecutionGates.mqh. Even defining this
//    legacy macro to 1 cannot enable Gate 1, Gate 2, arming or the release interlock.
#ifndef QSMC_ALLOW_REAL
#define QSMC_ALLOW_REAL              0
#endif

//--- exact runtime acknowledgement; never sufficient to enable execution alone.
#define QSMC_REAL_ACK_TOKEN          "I-ACCEPT-LIVE-TRADING-RISK"

//--- version of the persisted state format (bumped on incompatible changes)
#define QSMC_STATE_FORMAT_VERSION    2

#endif // QSMC_CONSTANTS_MQH
