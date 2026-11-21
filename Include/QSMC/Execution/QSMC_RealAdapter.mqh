//+------------------------------------------------------------------+
//|                                              QSMC_RealAdapter.mqh |
//|  Deliberately non-operational. This implementation never calls      |
//|  OrderSend/CTrade. REAL trading remains blocked pending a distinct   |
//|  implementation, platform tests, audit and explicit approval.      |
//+------------------------------------------------------------------+
#ifndef QSMC_REALADAPTER_MQH
#define QSMC_REALADAPTER_MQH
#include "QSMC_ExecutionAdapter.mqh"

class CQSMCRealAdapter : public CQSMCExecutionAdapter
{
public:
   bool Submit(const SQSMCOrderIntent &intent,SQSMCExecutionResult &result)
   {
      result.Reset();
      result.code=QSMC_ERR_EXECUTION_DISABLED;
      result.message="REAL adapter is hard-disabled: no broker order API is implemented";
      return false;
   }
   bool IsLive() const{return false;}
};
#endif // QSMC_REALADAPTER_MQH
