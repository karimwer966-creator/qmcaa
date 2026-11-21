//+------------------------------------------------------------------+
//|                                         QSMC_ExecutionManager.mqh |
//|  Coordinates the order manager and mode-specific adapter.           |
//+------------------------------------------------------------------+
#ifndef QSMC_EXECUTIONMANAGER_MQH
#define QSMC_EXECUTIONMANAGER_MQH
#include "QSMC_ExecutionMode.mqh"
#include "QSMC_OrderManager.mqh"
#include "QSMC_DemoAdapter.mqh"
#include "QSMC_RealAdapter.mqh"

class CQSMCExecutionManager
{
private:
   CQSMCOrderManager m_orders;
   CQSMCRiskManager m_risk;
   CQSMCDemoAdapter m_demo;
   CQSMCRealAdapter m_real;
   ENUM_QSMC_EXECUTION_MODE m_mode;
   ulong m_magic;
   bool m_initialised;
public:
   CQSMCExecutionManager(){m_mode=QSMC_EXEC_DISABLED;m_magic=0;m_initialised=false;}
   bool Init(const SQSMCConfig &cfg,const ulong magic)
   {
      if(magic==0)return false;
      m_mode=CQSMCExecutionMode::Resolve(cfg.mode);
      m_magic=magic;
      m_risk.Init(cfg);
      m_initialised=true;
      return true;
   }
   bool Submit(const SQSMCOrderIntent &intent,const SQSMCConfig &cfg,
               const CQSMCMarketSnapshot &snap,const CQSMCRoot &root,
               CQSMCSafetyController &safety,CQSMCStateStore &store,
               SQSMCExecutionResult &result,string &why)
   {
      result.Reset();why="";
      if(!m_initialised || m_mode==QSMC_EXEC_DISABLED)
      {why="execution disabled by configured mode";result.code=QSMC_ERR_EXECUTION_DISABLED;result.message=why;return false;}
      if(m_mode==QSMC_EXEC_REAL_BLOCKED)
      {why="REAL execution is deliberately blocked";result.code=QSMC_ERR_EXECUTION_DISABLED;result.message=why;return false;}
      if(!root.CanOperate())
      {why="root is not RUNNING";result.code=QSMC_ERR_INVALID_STATE;result.message=why;return false;}
      if(intent.magic!=m_magic)
      {why="intent magic does not match execution-manager instance";result.code=QSMC_ERR_IDENTITY_COLLISION;result.message=why;return false;}
      SQSMCAccountState current;
      if(!m_risk.CaptureAccount(current,m_magic,store))
      {why="account/risk snapshot unavailable";result.code=QSMC_ERR_RISK_LIMIT;result.message=why;return false;}
      if(!m_risk.ValidateAccount(current,why))
      {result.code=QSMC_ERR_RISK_LIMIT;result.message=why;return false;}
      return m_orders.Submit(intent,cfg,snap,root,safety,current,m_magic,store,m_demo,result,why);
   }
   ENUM_QSMC_EXECUTION_MODE Mode() const{return m_mode;}
   string Describe() const{return CQSMCExecutionMode::Name(m_mode);}
};
#endif // QSMC_EXECUTIONMANAGER_MQH
