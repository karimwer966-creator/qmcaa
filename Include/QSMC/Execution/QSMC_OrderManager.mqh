//+------------------------------------------------------------------+
//|                                             QSMC_OrderManager.mqh |
//|  Central submission funnel. A UID is committed before adapter call |
//|  to prevent duplicate replay after uncertain failures/restarts.     |
//+------------------------------------------------------------------+
#ifndef QSMC_ORDERMANAGER_MQH
#define QSMC_ORDERMANAGER_MQH
#include "QSMC_ExecutionPreflight.mqh"
#include "QSMC_ExecutionJournal.mqh"
#include "QSMC_ExecutionAdapter.mqh"

class CQSMCOrderManager
{
private:
   CQSMCExecutionJournal m_journal;
public:
   bool Submit(const SQSMCOrderIntent &intent,const SQSMCConfig &cfg,
               const CQSMCMarketSnapshot &snap,const CQSMCRoot &root,
               CQSMCSafetyController &safety,const SQSMCAccountState &account,
               const ulong expectedMagic,CQSMCStateStore &store,
               CQSMCExecutionAdapter &adapter,SQSMCExecutionResult &result,string &why)
   {
      result.Reset();why="";
      if(!store.IsWritable() || expectedMagic==0 || store.Magic()!=expectedMagic)
      {
         why="execution store unavailable or identity mismatch";
         result.code=QSMC_ERR_IDENTITY_COLLISION;result.message=why;return false;
      }
      if(m_journal.Seen(intent.uid,store))
      {
         why="duplicate intent UID rejected";
         m_journal.Record(intent,QSMC_ERR_DUPLICATE_ORDER,why,"not submitted");
         result.code=QSMC_ERR_DUPLICATE_ORDER;result.message=why;return false;
      }
      // Pending broker intent is never evicted/cleared by the recent UID ring.
      if(adapter.IsBroker() && StringLen(store.GetString("execution.pending_uid",""))>0)
      {
         why="unresolved broker intent; no retry/replacement permitted";
         result.code=QSMC_ERR_SAFETY_BLOCKED;result.message=why;
         m_journal.Record(intent,result.code,why,"not submitted");return false;
      }
      string day=TimeToString(TimeCurrent(),TIME_DATE);
      if(store.GetString("execution.day","")!=day)
      {
         if(!store.SetString("execution.day",day) || !store.SetInt("execution.daily_count",0))
         {
            why="failed to stage daily submission state";
            result.code=QSMC_ERR_SAFETY_BLOCKED;result.message=why;
            m_journal.Record(intent,result.code,why,"not submitted");
            safety.EmergencyStop(store,why);return false;
         }
      }
      long dailyCount=store.GetInt("execution.daily_count",0);
      long observedEntries=store.GetInt("risk.entry_orders",0);
      if(observedEntries>dailyCount)dailyCount=observedEntries; // never lower the committed guard on replay
      long lastSubmit=store.GetInt("execution.last_submit",0);
      long observedEntryTime=store.GetInt("risk.last_entry_time",0);
      if(observedEntryTime>lastSubmit)lastSubmit=observedEntryTime;
      if(TimeCurrent()<=0 || dailyCount<0 || lastSubmit<0 || lastSubmit>(long)TimeCurrent())
      {
         why="invalid counter/clock state; recovery review required";
         result.code=QSMC_ERR_SAFETY_BLOCKED;result.message=why;
         m_journal.Record(intent,result.code,why,"not submitted");
         safety.EmergencyStop(store,why,true);return false;
      }
      if(dailyCount>=cfg.max_daily_trades)
      {
         why="daily submission limit reached";
         m_journal.Record(intent,QSMC_ERR_RISK_LIMIT,why,"not submitted");
         result.code=QSMC_ERR_RISK_LIMIT;result.message=why;return false;
      }
      if(cfg.cooldown_seconds>0 && lastSubmit>0 && TimeCurrent()-lastSubmit<cfg.cooldown_seconds)
      {
         why="submission cooldown active";
         m_journal.Record(intent,QSMC_ERR_RISK_LIMIT,why,"not submitted");
         result.code=QSMC_ERR_RISK_LIMIT;result.message=why;return false;
      }
      if(!CQSMCExecutionPreflight::Validate(intent,cfg,snap,root,safety,account,expectedMagic,why))
      {
         m_journal.Record(intent,QSMC_ERR_PREFLIGHT_REJECTED,why,"preflight rejected");
         result.code=QSMC_ERR_PREFLIGHT_REJECTED;result.message=why;return false;
      }
      // Persist intent as consumed before call: timeout/uncertain outcomes
      // must not be blindly replayed on restart.
      bool committed=m_journal.MarkSubmitted(intent.uid,store,false);
      committed=committed && store.SetInt("execution.daily_count",dailyCount+1);
      committed=committed && store.SetInt("execution.last_submit",(long)TimeCurrent());
      if(adapter.IsBroker())
         committed=committed && store.SetString("execution.pending_uid",StringFormat("%I64u",intent.uid));
      if(!committed || !store.Save())
      {
         why="failed to persist execution guard state";
         result.code=QSMC_ERR_SAFETY_BLOCKED;result.message=why;
         m_journal.Record(intent,result.code,why,"submission blocked");
         safety.EmergencyStop(store,why);return false;
      }
      bool ok=adapter.SubmitChecked(intent,cfg,snap,root,safety,account,expectedMagic,store,result);
      if(adapter.IsBroker() && result.submitted)
      {
         bool saved=store.SetInt("execution.broker_retcode",(long)result.brokerRetcode) &&
            store.SetInt("execution.request_id",(long)result.requestId) &&
            store.SetString("execution.order",StringFormat("%I64u",result.orderTicket)) &&
            store.SetString("execution.deal",StringFormat("%I64u",result.dealTicket)) &&
            store.SetDouble("execution.filled_volume",result.filledVolume) &&
            store.SetDouble("execution.filled_price",result.filledPrice) &&
            store.SetString("execution.outcome",EnumToString(result.outcome)) && store.Save();
         if(!saved)
         {
            result.uncertain=true;result.code=QSMC_ERR_SAFETY_BLOCKED;
            result.message+="; broker-result persistence failed";ok=false;
         }
      }
      if(result.uncertain)
         safety.EmergencyStop(store,"uncertain/pending broker outcome; reconciliation required",true);
      m_journal.Record(intent,result.code,why,result.message);
      if(!ok)why=result.message;
      return ok;
   }
};
#endif // QSMC_ORDERMANAGER_MQH
