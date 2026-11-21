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
      if(m_journal.Seen(intent.uid,store))
      {
         why="duplicate intent UID rejected";
         m_journal.Record(intent,QSMC_ERR_DUPLICATE_ORDER,why,"not submitted");
         result.code=QSMC_ERR_DUPLICATE_ORDER;result.message=why;return false;
      }
      string day=TimeToString(TimeCurrent(),TIME_DATE);
      if(store.GetString("execution.day","")!=day)
      {
         store.SetString("execution.day",day);
         store.SetInt("execution.daily_count",0);
      }
      long dailyCount=store.GetInt("execution.daily_count",0);
      long lastSubmit=store.GetInt("execution.last_submit",0);
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
      m_journal.MarkSubmitted(intent.uid,store);
      store.SetInt("execution.daily_count",dailyCount+1);
      store.SetInt("execution.last_submit",(long)TimeCurrent());
      if(!store.Save())
      {
         why="failed to persist execution guard state";
         result.code=QSMC_ERR_SAFETY_BLOCKED;result.message=why;
         m_journal.Record(intent,result.code,why,"submission blocked");
         return false;
      }
      bool ok=adapter.Submit(intent,result);
      m_journal.Record(intent,result.code,why,result.message);
      if(!ok && result.code==QSMC_ERR_ORDER_REJECTED)
         why=result.message;
      return ok;
   }
};
#endif // QSMC_ORDERMANAGER_MQH
