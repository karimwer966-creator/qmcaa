//+------------------------------------------------------------------+
//|                                                    QSMC_Types.mqh |
//|                        Shared value types and error taxonomy      |
//+------------------------------------------------------------------+
#ifndef QSMC_TYPES_MQH
#define QSMC_TYPES_MQH

//+------------------------------------------------------------------+
//| Operating mode                                                    |
//+------------------------------------------------------------------+
enum ENUM_QSMC_MODE
{
   QSMC_MODE_OFF      = 0,  // Disabled: no analysis, no execution
   QSMC_MODE_ANALYSIS = 1,  // Analysis + presentation only
   QSMC_MODE_DEMO     = 2,  // Simulated execution (no terminal orders)
   QSMC_MODE_REAL     = 3   // Live execution (gated, disabled by default)
};

//+------------------------------------------------------------------+
//| Log severity                                                      |
//+------------------------------------------------------------------+
enum ENUM_QSMC_LOG_LEVEL
{
   QSMC_LOG_DEBUG = 0,
   QSMC_LOG_INFO  = 1,
   QSMC_LOG_WARN  = 2,
   QSMC_LOG_ERROR = 3,
   QSMC_LOG_NONE  = 4
};

//+------------------------------------------------------------------+
//| Risk profile preset                                               |
//+------------------------------------------------------------------+
enum ENUM_QSMC_PRESET
{
   QSMC_PRESET_CONSERVATIVE = 0,
   QSMC_PRESET_BALANCED     = 1,
   QSMC_PRESET_AGGRESSIVE   = 2,
   QSMC_PRESET_CUSTOM       = 3
};

//+------------------------------------------------------------------+
//| Lifecycle state                                                   |
//+------------------------------------------------------------------+
enum ENUM_QSMC_STATE
{
   QSMC_STATE_CREATED      = 0,
   QSMC_STATE_INITIALIZING = 1,
   QSMC_STATE_READY        = 2,
   QSMC_STATE_RUNNING      = 3,
   QSMC_STATE_SAFE_MODE    = 4,
   QSMC_STATE_STOPPING     = 5,
   QSMC_STATE_STOPPED      = 6,
   QSMC_STATE_FAILED       = 7
};

//+------------------------------------------------------------------+
//| Direction / bias                                                  |
//+------------------------------------------------------------------+
enum ENUM_QSMC_DIRECTION
{
   QSMC_DIR_NONE = 0,
   QSMC_DIR_BUY  = 1,
   QSMC_DIR_SELL = 2
};

enum ENUM_QSMC_BIAS
{
   QSMC_BIAS_NEUTRAL = 0,
   QSMC_BIAS_BULLISH = 1,
   QSMC_BIAS_BEARISH = 2
};

//+------------------------------------------------------------------+
//| Result codes.  Every failure path in QSMC must return one of      |
//| these; messages are human readable and are never used for logic.  |
//+------------------------------------------------------------------+
enum ENUM_QSMC_RESULT
{
   QSMC_OK = 0,
   QSMC_ERR_INVALID_CONFIG,       // configuration rejected by validation
   QSMC_ERR_NOT_INITIALIZED,      // module used before successful Init
   QSMC_ERR_ALREADY_INITIALIZED,  // duplicate Init rejected
   QSMC_ERR_INVALID_STATE,        // transition / operation not allowed
   QSMC_ERR_MODULE_INIT,          // a module failed to initialise
   QSMC_ERR_TIMER,                // timer setup/cleanup failure
   QSMC_ERR_DATA_NOT_READY,       // history/market data insufficient
   QSMC_ERR_DATA_INVALID,         // data present but corrupted/stale
   QSMC_ERR_SYMBOL_UNAVAILABLE,   // symbol missing / not selectable
   QSMC_ERR_TRADE_FORBIDDEN,      // account or terminal forbids trading
   QSMC_ERR_IDENTITY_COLLISION,   // magic already owned by other settings
   QSMC_ERR_SAFETY_BLOCKED,       // safety controller veto
   QSMC_ERR_KILL_SWITCH,          // emergency disable engaged
   QSMC_ERR_RISK_LIMIT,           // risk/exposure/daily-loss limit
   QSMC_ERR_PREFLIGHT_REJECTED,   // order parameters invalid
   QSMC_ERR_EXECUTION_DISABLED,   // execution mode does not permit orders
   QSMC_ERR_DUPLICATE_ORDER,      // same intent already submitted
   QSMC_ERR_ORDER_REJECTED,       // broker/server rejected the order
   QSMC_ERR_NO_DECISION,          // no tradable setup
   QSMC_ERR_INSUFFICIENT_DATA,    // analysis window too small
   QSMC_ERR_INTERNAL,             // defensive catch-all
   QSMC_ERR_UNKNOWN
};

//+------------------------------------------------------------------+
//| Standard result envelope                                          |
//+------------------------------------------------------------------+
struct SQSMCResult
{
   ENUM_QSMC_RESULT code;
   string           message;

   void Set(const ENUM_QSMC_RESULT c, const string msg = "")
   {
      code    = c;
      message = msg;
   }

   void Clear()
   {
      code    = QSMC_OK;
      message = "";
   }

   bool Ok() const { return (code == QSMC_OK); }
};

//+------------------------------------------------------------------+
//| Order intent: the ONLY structure execution accepts.  Produced by  |
//| the decision layer, validated by preflight and safety.            |
//+------------------------------------------------------------------+
struct SQSMCOrderIntent
{
   string               symbol;
   ENUM_QSMC_DIRECTION  direction;
   double               volume;          // lots, already risk-sized
   double               price;           // reference price (market)
   double               sl;
   double               tp;
   double               riskAmount;      // account currency at risk
   double               confidence;      // 0..1, informational
   ulong                magic;
   ulong                uid;             // deterministic intent id (dedupe)
   int                  deviationPoints; // max slippage
   datetime             barTime;         // decision bar
   string               comment;
   string               reason;          // audit trail

   void Reset()
   {
      symbol          = "";
      direction       = QSMC_DIR_NONE;
      volume          = 0.0;
      price           = 0.0;
      sl              = 0.0;
      tp              = 0.0;
      riskAmount      = 0.0;
      confidence      = 0.0;
      magic           = 0;
      uid             = 0;
      deviationPoints = 0;
      barTime         = 0;
      comment         = "";
      reason          = "";
   }
};

//+------------------------------------------------------------------+
//| Account / exposure snapshot used by risk and safety               |
//+------------------------------------------------------------------+
struct SQSMCAccountState
{
   double   balance;
   double   equity;
   double   margin;
   double   freeMargin;
   double   dailyLossPct;      // realised+floating loss today, per cent
   double   peakEquity;        // persisted high-water mark
   double   drawdownPct;       // decline from the persisted equity peak
   double   exposureLots;      // QSMC-owned exposure
   int      openPositions;     // QSMC-owned positions
   datetime captured;

   void Reset()
   {
      balance       = 0.0;
      equity        = 0.0;
      margin        = 0.0;
      freeMargin    = 0.0;
      dailyLossPct  = 0.0;
      peakEquity    = 0.0;
      drawdownPct   = 0.0;
      exposureLots  = 0.0;
      openPositions = 0;
      captured      = 0;
   }
};

//+------------------------------------------------------------------+
//| Enum -> string helpers (never used for control flow)              |
//+------------------------------------------------------------------+
string QSMC_ModeToString(const ENUM_QSMC_MODE m)
{
   switch(m)
   {
      case QSMC_MODE_OFF:      return "OFF";
      case QSMC_MODE_ANALYSIS: return "ANALYSIS";
      case QSMC_MODE_DEMO:     return "DEMO";
      case QSMC_MODE_REAL:     return "REAL";
   }
   return "UNKNOWN";
}

string QSMC_StateToString(const ENUM_QSMC_STATE s)
{
   switch(s)
   {
      case QSMC_STATE_CREATED:      return "CREATED";
      case QSMC_STATE_INITIALIZING: return "INITIALIZING";
      case QSMC_STATE_READY:        return "READY";
      case QSMC_STATE_RUNNING:      return "RUNNING";
      case QSMC_STATE_SAFE_MODE:    return "SAFE_MODE";
      case QSMC_STATE_STOPPING:     return "STOPPING";
      case QSMC_STATE_STOPPED:      return "STOPPED";
      case QSMC_STATE_FAILED:       return "FAILED";
   }
   return "UNKNOWN";
}

string QSMC_DirectionToString(const ENUM_QSMC_DIRECTION d)
{
   switch(d)
   {
      case QSMC_DIR_NONE: return "NONE";
      case QSMC_DIR_BUY:  return "BUY";
      case QSMC_DIR_SELL: return "SELL";
   }
   return "UNKNOWN";
}

string QSMC_BiasToString(const ENUM_QSMC_BIAS b)
{
   switch(b)
   {
      case QSMC_BIAS_NEUTRAL: return "NEUTRAL";
      case QSMC_BIAS_BULLISH: return "BULLISH";
      case QSMC_BIAS_BEARISH: return "BEARISH";
   }
   return "UNKNOWN";
}

string QSMC_PresetToString(const ENUM_QSMC_PRESET p)
{
   switch(p)
   {
      case QSMC_PRESET_CONSERVATIVE: return "CONSERVATIVE";
      case QSMC_PRESET_BALANCED:     return "BALANCED";
      case QSMC_PRESET_AGGRESSIVE:   return "AGGRESSIVE";
      case QSMC_PRESET_CUSTOM:       return "CUSTOM";
   }
   return "UNKNOWN";
}

string QSMC_TfToString(const ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M1:  return "M1";
      case PERIOD_M2:  return "M2";
      case PERIOD_M3:  return "M3";
      case PERIOD_M4:  return "M4";
      case PERIOD_M5:  return "M5";
      case PERIOD_M6:  return "M6";
      case PERIOD_M10: return "M10";
      case PERIOD_M12: return "M12";
      case PERIOD_M15: return "M15";
      case PERIOD_M20: return "M20";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H2:  return "H2";
      case PERIOD_H3:  return "H3";
      case PERIOD_H4:  return "H4";
      case PERIOD_H6:  return "H6";
      case PERIOD_H8:  return "H8";
      case PERIOD_H12: return "H12";
      case PERIOD_D1:  return "D1";
      case PERIOD_W1:  return "W1";
      case PERIOD_MN1: return "MN1";
      case PERIOD_CURRENT: return "CURRENT";
   }
   return "TF?";
}

bool QSMC_IsKnownTimeframe(const ENUM_TIMEFRAMES tf)
{
   return (tf != PERIOD_CURRENT && PeriodSeconds(tf) > 0);
}

string QSMC_LogLevelToString(const ENUM_QSMC_LOG_LEVEL l)
{
   switch(l)
   {
      case QSMC_LOG_DEBUG: return "DEBUG";
      case QSMC_LOG_INFO:  return "INFO";
      case QSMC_LOG_WARN:  return "WARN";
      case QSMC_LOG_ERROR: return "ERROR";
      case QSMC_LOG_NONE:  return "NONE";
   }
   return "UNKNOWN";
}

string QSMC_ResultToString(const ENUM_QSMC_RESULT r)
{
   switch(r)
   {
      case QSMC_OK:                      return "OK";
      case QSMC_ERR_INVALID_CONFIG:      return "ERR_INVALID_CONFIG";
      case QSMC_ERR_NOT_INITIALIZED:     return "ERR_NOT_INITIALIZED";
      case QSMC_ERR_ALREADY_INITIALIZED: return "ERR_ALREADY_INITIALIZED";
      case QSMC_ERR_INVALID_STATE:       return "ERR_INVALID_STATE";
      case QSMC_ERR_MODULE_INIT:         return "ERR_MODULE_INIT";
      case QSMC_ERR_TIMER:               return "ERR_TIMER";
      case QSMC_ERR_DATA_NOT_READY:      return "ERR_DATA_NOT_READY";
      case QSMC_ERR_DATA_INVALID:        return "ERR_DATA_INVALID";
      case QSMC_ERR_SYMBOL_UNAVAILABLE:  return "ERR_SYMBOL_UNAVAILABLE";
      case QSMC_ERR_TRADE_FORBIDDEN:     return "ERR_TRADE_FORBIDDEN";
      case QSMC_ERR_IDENTITY_COLLISION:  return "ERR_IDENTITY_COLLISION";
      case QSMC_ERR_SAFETY_BLOCKED:      return "ERR_SAFETY_BLOCKED";
      case QSMC_ERR_KILL_SWITCH:         return "ERR_KILL_SWITCH";
      case QSMC_ERR_RISK_LIMIT:          return "ERR_RISK_LIMIT";
      case QSMC_ERR_PREFLIGHT_REJECTED:  return "ERR_PREFLIGHT_REJECTED";
      case QSMC_ERR_EXECUTION_DISABLED:  return "ERR_EXECUTION_DISABLED";
      case QSMC_ERR_DUPLICATE_ORDER:     return "ERR_DUPLICATE_ORDER";
      case QSMC_ERR_ORDER_REJECTED:      return "ERR_ORDER_REJECTED";
      case QSMC_ERR_NO_DECISION:         return "ERR_NO_DECISION";
      case QSMC_ERR_INSUFFICIENT_DATA:   return "ERR_INSUFFICIENT_DATA";
      case QSMC_ERR_INTERNAL:            return "ERR_INTERNAL";
      case QSMC_ERR_UNKNOWN:             return "ERR_UNKNOWN";
   }
   return "ERR_UNKNOWN";
}

//+------------------------------------------------------------------+
//| Small helpers                                                     |
//+------------------------------------------------------------------+
bool QSMC_IsFatal(const ENUM_QSMC_RESULT r)
{
   return (r == QSMC_ERR_MODULE_INIT || r == QSMC_ERR_INTERNAL ||
           r == QSMC_ERR_IDENTITY_COLLISION || r == QSMC_ERR_INVALID_CONFIG);
}

ENUM_QSMC_DIRECTION QSMC_DirectionFromBias(const ENUM_QSMC_BIAS b)
{
   if(b == QSMC_BIAS_BULLISH) return QSMC_DIR_BUY;
   if(b == QSMC_BIAS_BEARISH) return QSMC_DIR_SELL;
   return QSMC_DIR_NONE;
}

ENUM_QSMC_BIAS QSMC_BiasOpposite(const ENUM_QSMC_BIAS b)
{
   if(b == QSMC_BIAS_BULLISH) return QSMC_BIAS_BEARISH;
   if(b == QSMC_BIAS_BEARISH) return QSMC_BIAS_BULLISH;
   return QSMC_BIAS_NEUTRAL;
}

#endif // QSMC_TYPES_MQH
