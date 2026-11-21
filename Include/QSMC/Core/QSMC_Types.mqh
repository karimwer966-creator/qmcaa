#ifndef QSMC_TYPES_MQH
#define QSMC_TYPES_MQH

enum ENUM_QSMC_MODE
{
   QSMC_MODE_OFF = 0,        // Disabled
   QSMC_MODE_ANALYSIS,       // Analysis only
   QSMC_MODE_DEMO,           // Demo (simulated) execution
   QSMC_MODE_REAL            // Real execution
};

enum ENUM_QSMC_LOG_LEVEL
{
   QSMC_LOG_DEBUG = 0,
   QSMC_LOG_INFO,
   QSMC_LOG_WARN,
   QSMC_LOG_ERROR,
   QSMC_LOG_NONE
};

enum ENUM_QSMC_PRESET
{
   QSMC_PRESET_CONSERVATIVE = 0,
   QSMC_PRESET_BALANCED,
   QSMC_PRESET_AGGRESSIVE,
   QSMC_PRESET_CUSTOM
};

enum ENUM_QSMC_STATE
{
   QSMC_STATE_CREATED = 0,
   QSMC_STATE_INITIALIZING,
   QSMC_STATE_READY,
   QSMC_STATE_RUNNING,
   QSMC_STATE_SAFE_MODE,
   QSMC_STATE_STOPPING,
   QSMC_STATE_STOPPED,
   QSMC_STATE_FAILED
};

enum ENUM_QSMC_DIRECTION
{
   QSMC_DIR_NONE = 0,
   QSMC_DIR_BUY,
   QSMC_DIR_SELL
};

enum ENUM_QSMC_BIAS
{
   QSMC_BIAS_NEUTRAL = 0,
   QSMC_BIAS_BULLISH,
   QSMC_BIAS_BEARISH
};

enum ENUM_QSMC_RESULT
{
   QSMC_OK = 0,
   QSMC_ERR_INVALID_CONFIG,
   QSMC_ERR_NOT_INITIALIZED,
   QSMC_ERR_DATA_NOT_READY,
   QSMC_ERR_INVALID_STATE,   // new
   QSMC_ERR_MODULE_INIT,     // new
   QSMC_ERR_TIMER,           // new
   QSMC_ERR_UNKNOWN
};

struct SQSMCResult
{
   ENUM_QSMC_RESULT code;
   string           message;

   void Set(const ENUM_QSMC_RESULT c, const string msg = "")
   {
      code = c;
      message = msg;
   }
   bool Ok() const { return code == QSMC_OK; }
};

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

#endif