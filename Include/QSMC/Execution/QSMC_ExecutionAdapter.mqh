//+------------------------------------------------------------------+
//|                                       QSMC_ExecutionAdapter.mqh |
//|  Adapter boundary: no decision or analysis code can reach broker    |
//|  APIs; all requests enter through CQSMCExecutionManager.            |
//+------------------------------------------------------------------+
#ifndef QSMC_EXECUTIONADAPTER_MQH
#define QSMC_EXECUTIONADAPTER_MQH
#include "../Core/QSMC_Types.mqh"

struct SQSMCExecutionResult
{
   bool accepted;
   ENUM_QSMC_RESULT code;
   ulong ticket;
   double filledVolume;
   string message;
   void Reset(){accepted=false;code=QSMC_ERR_EXECUTION_DISABLED;ticket=0;filledVolume=0.0;message="";}
};

class CQSMCExecutionAdapter
{
public:
   virtual bool Submit(const SQSMCOrderIntent &intent,SQSMCExecutionResult &result)
   {
      result.Reset();
      result.code=QSMC_ERR_EXECUTION_DISABLED;
      result.message="execution adapter has no enabled implementation";
      return false;
   }
   virtual bool IsLive() const {return false;}
};
#endif // QSMC_EXECUTIONADAPTER_MQH
