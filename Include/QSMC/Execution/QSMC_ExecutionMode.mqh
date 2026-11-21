//+------------------------------------------------------------------+
//|                                          QSMC_ExecutionMode.mqh |
//|  Explicit execution capability selector. REAL is hard-disabled    |
//|  by this repository build and cannot be enabled from inputs.       |
//+------------------------------------------------------------------+
#ifndef QSMC_EXECUTIONMODE_MQH
#define QSMC_EXECUTIONMODE_MQH
#include "../Core/QSMC_Types.mqh"

enum ENUM_QSMC_EXECUTION_MODE
{
   QSMC_EXEC_DISABLED=0,
   QSMC_EXEC_SIMULATED=1,
   QSMC_EXEC_REAL_BLOCKED=2
};
class CQSMCExecutionMode
{
public:
   static ENUM_QSMC_EXECUTION_MODE Resolve(const ENUM_QSMC_MODE mode)
   {
      if(mode==QSMC_MODE_DEMO) return QSMC_EXEC_SIMULATED;
      if(mode==QSMC_MODE_REAL) return QSMC_EXEC_REAL_BLOCKED;
      return QSMC_EXEC_DISABLED;
   }
   static string Name(const ENUM_QSMC_EXECUTION_MODE mode)
   {
      if(mode==QSMC_EXEC_SIMULATED)return "SIMULATED";
      if(mode==QSMC_EXEC_REAL_BLOCKED)return "REAL_BLOCKED";
      return "DISABLED";
   }
};
#endif // QSMC_EXECUTIONMODE_MQH
