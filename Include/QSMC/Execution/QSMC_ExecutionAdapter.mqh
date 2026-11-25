// QSMC-001/013: adapter/result contracts. Direct broker Submit fails closed.
#ifndef QSMC_EXECUTIONADAPTER_MQH
#define QSMC_EXECUTIONADAPTER_MQH
#include "QSMC_BrokerRules.mqh"
#include "QSMC_ExecutionPreflight.mqh"

struct SQSMCExecutionResult
{
   bool accepted; // broker accepted, NOT necessarily fully filled
   ENUM_QSMC_RESULT code;
   ulong ticket; // legacy compatibility: order ticket, otherwise deal ticket
   double filledVolume;
   string message;
   bool submitted;
   bool uncertain;
   uint brokerRetcode;
   uint requestId;
   int terminalError;
   ulong orderTicket;
   ulong dealTicket;
   ulong intentUid;
   double filledPrice;
   ENUM_QSMC_BROKER_OUTCOME outcome;
   void Reset()
   {
      accepted=false;code=QSMC_ERR_EXECUTION_DISABLED;ticket=0;
      filledVolume=0.0;message="";submitted=false;uncertain=false;
      brokerRetcode=0;requestId=0;terminalError=0;orderTicket=0;
      dealTicket=0;intentUid=0;filledPrice=0.0;outcome=QSMC_BROKER_NOT_SENT;
   }
};

class CQSMCExecutionAdapter
{
public:
   virtual bool Submit(const SQSMCOrderIntent &intent,SQSMCExecutionResult &result)
   {
      result.Reset();result.intentUid=intent.uid;
      result.message="execution adapter has no enabled implementation";
      return false;
   }
   // Contextful entry point preserves the original Submit signature for paper
   // callers while requiring centralized preflight on the broker boundary.
   virtual bool SubmitChecked(const SQSMCOrderIntent &intent,const SQSMCConfig &cfg,
                             const CQSMCMarketSnapshot &snap,const CQSMCRoot &root,
                             CQSMCSafetyController &safety,const SQSMCAccountState &account,
                             const ulong expectedMagic,CQSMCStateStore &store,
                             SQSMCExecutionResult &result)
   {
      result.Reset();result.intentUid=intent.uid;
      string why;
      if(!CQSMCExecutionPreflight::Validate(intent,cfg,snap,root,safety,account,expectedMagic,why))
      {result.code=QSMC_ERR_PREFLIGHT_REJECTED;result.message=why;return false;}
      if(store.Magic()!=expectedMagic)
      {result.code=QSMC_ERR_IDENTITY_COLLISION;result.message="adapter store identity mismatch";return false;}
      return Submit(intent,result);
   }
   virtual bool IsLive() const {return false;}
   virtual bool IsBroker() const {return false;}
};
#endif // QSMC_EXECUTIONADAPTER_MQH
