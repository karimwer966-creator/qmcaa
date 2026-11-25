//+------------------------------------------------------------------+
//|                                        QSMC_SafetyController.mqh |
//|  Central fail-closed permission gate. No order API is called here.  |
//+------------------------------------------------------------------+
#ifndef QSMC_SAFETYCONTROLLER_MQH
#define QSMC_SAFETYCONTROLLER_MQH
#include "../Core/QSMC_Config.mqh"
#include "../Core/QSMC_Root.mqh"
#include "../Infrastructure/QSMC_StateStore.mqh"
#include "QSMC_HealthMonitor.mqh"
#include "QSMC_IncidentSafety.mqh"
#include "QSMC_EntryFilters.mqh"

class CQSMCSafetyController
{
private:
   SQSMCConfig m_cfg;
   CQSMCHealthMonitor m_health;
   CQSMCIncidentSafety m_incident;
   CQSMCEntryFilters m_entries;
   bool m_ready;
   string m_reason;
   string m_killGv;
public:
   CQSMCSafetyController(){m_ready=false;m_reason="not initialised";m_killGv="";}
   bool Init(const SQSMCConfig &cfg,CQSMCStateStore &store)
   {
      m_ready=false;m_incident.Reset();m_reason="initialising";
      if(!store.IsReady()){m_reason="state store unavailable";return false;}
      m_cfg=cfg;
      m_killGv=store.KillGvName();
      if(!m_health.Init(cfg.symbol,cfg.max_spread_points,60))
      {m_reason="health monitor init failed";return false;}
      if(!m_entries.Init(cfg)){m_reason="entry filters init failed";return false;}
      m_incident.Restore(store);
      m_ready=true;
      m_reason=(m_incident.IsLatched()?m_incident.Reason():"ready");
      return true;
   }
   ENUM_QSMC_HEALTH Probe()
   {
      if(!m_ready){m_reason="safety controller not initialised";return QSMC_HEALTH_BLOCKED;}
      ENUM_QSMC_HEALTH h=m_health.Update();
      if(m_incident.IsLatched()) {m_reason="incident latch: "+m_incident.Reason();return QSMC_HEALTH_BLOCKED;}
      m_reason=m_health.Reason();
      return h;
   }
   bool CanSubmit(const CQSMCRoot &root,string &why)
   {
      why="";
      if(!m_ready){why="safety controller unavailable";return false;}
      if(!root.CanOperate()){why="root is not RUNNING";return false;}
      if(m_cfg.mode!=QSMC_MODE_DEMO && m_cfg.mode!=QSMC_MODE_REAL)
      {why="configured mode is analysis/off";return false;}
      if(m_cfg.mode==QSMC_MODE_REAL)
      {
         if(!CQSMCExecutionGates::EnvironmentPermits(m_cfg.real_ack,why))return false;
         if(!CQSMCExecutionGates::ReleaseApproved())
         {why=CQSMCExecutionGates::ReleaseReason();return false;}
      }
      if(m_incident.IsLatched()){why="incident latch: "+m_incident.Reason();return false;}
      if(m_health.Update()!=QSMC_HEALTH_HEALTHY)
      {why="health blocked: "+m_health.Reason();return false;}
      if(StringLen(m_killGv)>0 && GlobalVariableCheck(m_killGv) && GlobalVariableGet(m_killGv)!=0.0)
      {why="terminal global kill switch engaged";return false;}
      return m_entries.Check(why);
   }
   bool EmergencyStop(CQSMCStateStore &store,const string reason,const bool uncertain=false)
   {
      bool ok=m_incident.Latch(store,reason,uncertain);
      m_reason=m_incident.Reason();
      return ok;
   }
   bool AcknowledgeStop(CQSMCStateStore &store,const bool operatorConfirmed)
   {
      bool ok=m_incident.Acknowledge(store,operatorConfirmed);
      if(ok)m_reason="operator acknowledged; explicit restart/start required";
      return ok;
   }
   bool IsLatched() const{return m_incident.IsLatched();}
   bool RecoveryUncertain() const{return m_incident.RecoveryUncertain();}
   string Reason() const{return m_reason;}
   string HealthDescription() const{return m_health.Describe();}
   // Compatibility accessor cannot refresh news/time and is never authorization.
   // Use CanSubmit(root,why), which owns the authoritative entry gate.
   bool CanSubmitOrders() const{return false;}
   void ObserveEntryClock(){m_entries.ObserveClock();}
   bool ProbeEntryFilters(string &why){return m_entries.Check(why);}
   string EntryFilterDescription() const{return m_entries.Status();}
   bool CanSubmitOrders(string &why)
   {
      why="";
      if(!m_ready){why="safety controller unavailable";return false;}
      if(m_cfg.mode!=QSMC_MODE_DEMO && m_cfg.mode!=QSMC_MODE_REAL)
      {why="mode does not permit execution";return false;}
      if(m_cfg.mode==QSMC_MODE_REAL)
      {
         if(!CQSMCExecutionGates::EnvironmentPermits(m_cfg.real_ack,why))return false;
         if(!CQSMCExecutionGates::ReleaseApproved())
         {why=CQSMCExecutionGates::ReleaseReason();return false;}
      }
      if(m_incident.IsLatched()){why="incident latch: "+m_incident.Reason();return false;}
      if(m_health.Update()!=QSMC_HEALTH_HEALTHY){why="health blocked: "+m_health.Reason();return false;}
      if(StringLen(m_killGv)>0 && GlobalVariableCheck(m_killGv) && GlobalVariableGet(m_killGv)!=0.0)
      {why="kill switch engaged";return false;}
      return m_entries.Check(why);
   }
};
#endif // QSMC_SAFETYCONTROLLER_MQH
