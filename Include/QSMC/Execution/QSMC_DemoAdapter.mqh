//+------------------------------------------------------------------+
//|                                             QSMC_DemoAdapter.mqh |
//|  In-memory simulation adapter. Does not call OrderSend or mutate   |
//|  terminal positions.                                               |
//+------------------------------------------------------------------+
#ifndef QSMC_DEMOADAPTER_MQH
#define QSMC_DEMOADAPTER_MQH
#include "QSMC_ExecutionAdapter.mqh"

class CQSMCDemoAdapter : public CQSMCExecutionAdapter
{
private:
   ulong m_nextTicket;
   int m_submissions;
public:
   CQSMCDemoAdapter(){m_nextTicket=1;m_submissions=0;}
   bool Submit(const SQSMCOrderIntent &intent,SQSMCExecutionResult &result)
   {
      result.Reset();
      if(intent.uid==0 || intent.volume<=0.0)
      {result.code=QSMC_ERR_PREFLIGHT_REJECTED;result.message="invalid simulated intent";return false;}
      result.accepted=true;
      result.code=QSMC_OK;
      result.ticket=m_nextTicket++;
      result.filledVolume=intent.volume;
      result.message="simulated fill; no terminal order sent";
      m_submissions++;
      return true;
   }
   int Submissions() const{return m_submissions;}
};
#endif // QSMC_DEMOADAPTER_MQH
