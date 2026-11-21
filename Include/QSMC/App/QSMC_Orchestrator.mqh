//+------------------------------------------------------------------+
//|                                             QSMC_Orchestrator.mqh |
//|  Composition root. Coordinates lifecycle, infrastructure, market   |
//|  data, analysis, decision audit, safety and state-only presentation. |
//|  Default configuration is ANALYSIS; no normal event sends orders.  |
//+------------------------------------------------------------------+
#ifndef QSMC_ORCHESTRATOR_MQH
#define QSMC_ORCHESTRATOR_MQH

#include "../Core/QSMC_Root.mqh"
#include "../Core/QSMC_Preset.mqh"
#include "../Infrastructure/QSMC_Clock.mqh"
#include "../Infrastructure/QSMC_Logger.mqh"
#include "../Infrastructure/QSMC_StateStore.mqh"
#include "../Infrastructure/QSMC_Stats.mqh"
#include "../Data/QSMC_DataProvider.mqh"
#include "../Data/QSMC_MarketData.mqh"
#include "../Data/QSMC_DataReadiness.mqh"
#include "../Analysis/QSMC_Scanners.mqh"
#include "../SVP/QSMC_SvpCore.mqh"
#include "../SVP/QSMC_SvpVolumeProfile.mqh"
#include "../Decision/QSMC_Gates.mqh"
#include "../Decision/QSMC_OpportunityFunnel.mqh"
#include "../Decision/QSMC_Arbiter.mqh"
#include "../Safety/QSMC_Diagnostics.mqh"
#include "../Safety/QSMC_HealthMonitor.mqh"
#include "../Safety/QSMC_SafetyController.mqh"
#include "../Execution/QSMC_ExecutionManager.mqh"
#include "../Presentation/QSMC_Renderer.mqh"
#include "QSMC_EventDispatcher.mqh"
#include "QSMC_Lifecycle.mqh"
#include "QSMC_Bootstrap.mqh"

class CQSMCOrchestrator
{
private:
   CQSMCRoot m_root;
   CQSMCClock m_clock;
   CQSMCLogger m_logger;
   CQSMCStateStore m_store;
   CQSMCStats m_stats;
   CQSMCDataProvider *m_provider;
   CQSMCMarketData m_market;
   CQSMCDataReadiness m_readiness;
   CQSMCScanners m_scanners;
   CQSMCSvpCore m_svp;
   CQSMCSafetyController m_safety;
   CQSMCExecutionManager m_execution;
   CQSMCRenderer m_renderer;
   CQSMCEventDispatcher m_events;
   CQSMCLifecycle m_lifecycle;
   CQSMDiagnostics m_diagnostics;
   SQSMCConfig m_cfg;
   SQSMCUnifiedDecision m_decision;
   string m_healthText;
   string m_dataText;
   string m_analysisText;
   string m_decisionText;
   string m_lastError;
   bool m_initialised;
   bool m_haveSnapshot;
   bool m_lastDecisionValid;
   datetime m_lastDecisionBar;
   int m_analysisCount;

   void SetNoTrade(const ENUM_QSMC_RESULT code,const string source,const string reason)
   {
      m_decision.Reset();
      m_decision.Reject(code,source,reason);
      m_lastDecisionValid=false;
      m_decisionText="NO TRADE | "+reason;
   }

   bool RefreshAndEvaluate(const bool allowStart)
   {
      if(m_cfg.mode==QSMC_MODE_OFF) return false;
      SQSMCResult res;
      if(!m_market.Refresh(res))
      {
         m_dataText=res.message;SetNoTrade(QSMC_ERR_DATA_NOT_READY,"market-data",res.message);
         m_diagnostics.Warn("MARKET_DATA",res.message);
         return false;
      }
      CQSMCMarketSnapshot snap;
      if(!m_market.CopySnapshot(snap))
      {m_dataText="snapshot copy unavailable";SetNoTrade(QSMC_ERR_DATA_INVALID,"snapshot",m_dataText);return false;}
      string why;
      if(!m_readiness.Evaluate(snap,why))
      {
         m_dataText=why;SetNoTrade(QSMC_ERR_DATA_NOT_READY,"readiness",why);
         m_diagnostics.Warn("DATA_READINESS",why);
         return false;
      }
      m_haveSnapshot=true;m_dataText="ready";

      if(allowStart && m_root.State()==QSMC_STATE_READY)
      {
         if(!m_root.Start(res))
         {m_lastError=res.message;m_diagnostics.Critical("ROOT_START",res.message);return false;}
         ENUM_QSMC_HEALTH startupHealth=m_safety.Probe();
         m_healthText=EnumToString(startupHealth)+" "+m_safety.HealthDescription();
         if(m_safety.IsLatched() || startupHealth==QSMC_HEALTH_BLOCKED)
         {
            SQSMCResult safeRes;
            string reason=(m_safety.IsLatched()?"persisted safety incident: "+m_safety.Reason():m_safety.Reason());
            m_root.EnterSafeMode(reason,safeRes);
         }
      }
      if(!m_root.CanOperate()) return true;

      // All later work requires an explicit snapshot gate pass.
      SQSMCUnifiedDecision gateDecision;
      gateDecision.Reset();
      if(!CQSMCGates::ValidateSnapshot(snap,gateDecision))
      {
         m_decision=gateDecision;
         m_lastDecisionValid=false;
         m_decisionText="NO TRADE | "+(gateDecision.rejectionCount>0?gateDecision.rejections[0].reason:"snapshot gate rejected");
         m_diagnostics.Warn("SNAPSHOT_GATE",m_decisionText);
         return true;
      }

      // New-bar discipline uses closed execution candles only.
      datetime bar=snap.BarTime(QSMC_SNAP_EXEC,snap.NewestIndex());
      if(bar<=0){m_dataText="closed bar unavailable";return false;}
      if(bar==m_lastDecisionBar)return true;
      m_lastDecisionBar=bar;

      string scanWhy;
      double tolerance=(double)m_cfg.zone_tolerance_points*snap.Point();
      if(!m_scanners.Scan(snap,m_cfg.structure_lookback,m_cfg.swing_left,
                          m_cfg.swing_right,tolerance,scanWhy))
      {
         m_analysisText=scanWhy;SetNoTrade(QSMC_ERR_INSUFFICIENT_DATA,"analysis",scanWhy);
         m_stats.noTrades++;
         m_diagnostics.Warn("ANALYSIS",scanWhy);return true;
      }

      m_svp.Build(snap,QSMC_SNAP_EXEC,m_cfg.svp_lookback,m_cfg.svp_bins,m_cfg.svp_value_area_pct);
      m_scanners.SetValueContext(m_svp.IsReady(),m_svp.Poc(),m_svp.Vah(),m_svp.Val());
      m_renderer.ClearLayers();
      datetime layerUntil=TimeCurrent()+PeriodSeconds(m_cfg.exec_tf)*20;
      for(int z=0;z<m_scanners.ZoneCount();z++)
      {
         SQSMCZone zone;
         if(!m_scanners.GetZone(z,zone))continue;
         color zoneColor=(zone.IsDemandLike()?clrSeaGreen:clrIndianRed);
         m_renderer.DrawZone(zone,zoneColor,layerUntil);
      }
      SQSMCScanContext context;
      m_scanners.ContextCopy(context);
      m_analysisText=context.summary+" | "+m_svp.Describe();

      CQSMCSignalRegistry registry;
      CQSMCOpportunityFunnel::Build(context,registry);
      m_decision.Reset();
      bool selected=CQSMCArbiter::Resolve(registry,m_cfg.min_confidence,bar,m_decision);
      if(!selected && m_decision.rejectionCount==0)
         m_decision.Reject(QSMC_ERR_NO_DECISION,"decision","no candidate selected");
      m_lastDecisionValid=selected;
      m_decisionText=(selected ? QSMC_DirectionToString(m_decision.direction)+
                      " confidence="+DoubleToString(m_decision.confidence,2)+" | "+m_decision.explanation
                      : "NO TRADE | "+m_decision.explanation);
      for(int i=0;i<m_decision.rejectionCount;i++)
         m_diagnostics.Info("REJECT_"+IntegerToString(i+1),m_decision.rejections[i].source+": "+m_decision.rejections[i].reason);
      m_analysisCount++;
      m_stats.scans++;
      m_stats.decisions++;
      if(!selected)m_stats.noTrades++;
      m_stats.rejections+=m_decision.rejectionCount;
      return true;
   }

   void Render()
   {
      SQSMCDashboardData d;
      d.state=QSMC_StateToString(m_root.State());
      if(m_root.State()==QSMC_STATE_READY)
         d.state=(m_cfg.mode==QSMC_MODE_OFF?"STOPPED":"INITIALIZING");
      if(m_root.State()==QSMC_STATE_FAILED)d.state="ERROR";
      d.mode=QSMC_ModeToString(m_cfg.mode);
      d.instance=m_root.InstanceId();
      d.health=m_healthText;
      d.readiness=m_dataText;
      d.analysis=m_analysisText;
      d.decision=m_decisionText;
      d.safety=m_safety.Reason();
      d.execution=m_execution.Describe();
      d.diagnostics=m_diagnostics.Last();
      m_renderer.Render(d);
   }

   void UpdateHealth()
   {
      ENUM_QSMC_HEALTH state=m_safety.Probe();
      m_healthText=EnumToString(state)+" "+m_safety.HealthDescription();
      if(state==QSMC_HEALTH_BLOCKED && m_root.State()==QSMC_STATE_RUNNING)
      {
         SQSMCResult r;
         m_root.EnterSafeMode(m_safety.Reason(),r);
         m_diagnostics.Critical("HEALTH_BLOCK",m_safety.Reason());
      }
   }

public:
   CQSMCOrchestrator()
   {
      m_provider=NULL;m_initialised=false;m_haveSnapshot=false;m_lastDecisionValid=false;
      m_lastDecisionBar=0;m_analysisCount=0;m_healthText="unknown";m_dataText="initializing";
      m_analysisText="";m_decisionText="NO TRADE";m_lastError="";
      m_decision.Reset();
   }

   bool Init(const SQSMCConfig &cfg,SQSMCResult &result)
   {
      result.Clear();
      if(m_initialised){result.Set(QSMC_ERR_ALREADY_INITIALIZED,"application already initialized");return false;}
      m_cfg=cfg;
      if(!CQSMCBootstrap::Start(m_root,cfg,m_store,m_diagnostics,result))return false;
      string logPath=QSMC_FILE_FOLDER+"qsmc_"+IntegerToString((long)m_root.Magic())+".log";
      m_logger.Init(cfg.log_level,cfg.enable_log_file,logPath,m_root.InstanceId());
      m_clock.Init(cfg.symbol);
      m_clock.TrackTimeframe(cfg.exec_tf);m_clock.TrackTimeframe(cfg.htf);m_clock.TrackTimeframe(cfg.ltf);
      m_provider=new CQSMCDataProvider();
      if(m_provider==NULL || !m_provider.Init(cfg.symbol))
      {result.Set(QSMC_ERR_SYMBOL_UNAVAILABLE,"market data provider failed to initialize");m_root.Fail(result.message);return false;}
      if(!m_market.Init(m_provider,cfg.symbol,cfg.exec_tf,cfg.htf,cfg.ltf,cfg.bars_back,cfg.use_closed_bars_only))
      {result.Set(QSMC_ERR_MODULE_INIT,"market data module initialization failed");m_root.Fail(result.message);return false;}
      if(!m_readiness.Init(100))
      {result.Set(QSMC_ERR_MODULE_INIT,"readiness initialization failed");m_root.Fail(result.message);return false;}
      if(!m_safety.Init(cfg,m_store))
      {result.Set(QSMC_ERR_MODULE_INIT,"safety controller initialization failed");m_root.Fail(result.message);return false;}
      if(!m_execution.Init(cfg,m_root.Magic()))
      {result.Set(QSMC_ERR_MODULE_INIT,"execution manager initialization failed");m_root.Fail(result.message);return false;}
      m_renderer.Init(ChartID(),m_root.InstanceId(),cfg.enable_dashboard,cfg.enable_chart_layers);

      // Attempt initial history load. Data may still be downloading; timer
      // retries without entering operational state until readiness succeeds.
      RefreshAndEvaluate(true);
      if(m_root.State()==QSMC_STATE_READY && m_dataText!="ready")
         m_diagnostics.Warn("STARTUP_DATA",m_dataText);

      if(!m_lifecycle.Start(cfg.timer_ms,result))
      {m_root.Fail(result.message);return false;}
      m_events.Start();
      m_initialised=true;
      m_logger.Info("APP","initialized: "+m_root.Summary());
      result.Set(QSMC_OK,"QSMC initialized; "+m_root.DescribeConfig());
      Render();
      return true;
   }

   void OnTick()
   {
      if(!m_initialised || !m_events.Tick())return;
      m_stats.ticks++;
      if(!m_root.CanOperate())return;
      if(m_market.IsExecNewBar())
      {
         m_stats.newBars++;
         RefreshAndEvaluate(false);
         Render();
      }
   }

   void OnTimer()
   {
      if(!m_initialised || !m_events.Timer())return;
      m_stats.timerTicks++;
      m_clock.Update();UpdateHealth();
      if(m_root.State()==QSMC_STATE_READY)
         RefreshAndEvaluate(true);
      else if(m_root.CanOperate() && m_market.IsExecNewBar())
      {
         m_stats.newBars++;
         RefreshAndEvaluate(false);
      }
      Render();
      if(m_store.IsDirty())m_store.Save();
   }

   void OnTradeTransaction(const MqlTradeTransaction &trans,
                           const MqlTradeRequest &request,
                           const MqlTradeResult &result)
   {
      if(!m_initialised || !m_events.Trade() || !m_root.CanOperate())return;
      // No live order path is active. Transactions are logged for audit only.
      m_logger.Info("TRADE_EVENT",StringFormat("type=%s order=%I64u deal=%I64u retcode=%u",
                                                EnumToString(trans.type),trans.order,trans.deal,result.retcode));
   }

   void Deinit(const int reason)
   {
      if(!m_initialised && m_root.State()==QSMC_STATE_CREATED)return;
      m_events.Stop();m_lifecycle.Stop();
      if(m_store.IsDirty())m_store.Save();
      m_renderer.Deinit();
      m_root.Shutdown();
      if(m_provider!=NULL){delete m_provider;m_provider=NULL;}
      m_logger.Info("APP","stopped reason="+IntegerToString(reason));
      m_initialised=false;
   }

   ENUM_QSMC_STATE State() const{return m_root.State();}
   string LastError() const{return m_lastError;}
   int AnalysisCount() const{return m_analysisCount;}
   bool IsInitialised() const{return m_initialised;}
   string Diagnostics() const{return m_diagnostics.Report(5);}
   bool EmergencyStop(const string reason)
   {
      m_safety.EmergencyStop(m_store,reason);
      if(m_root.State()==QSMC_STATE_RUNNING)
      {SQSMCResult r;m_root.EnterSafeMode(reason,r);}
      m_diagnostics.Critical("EMERGENCY_STOP",reason);
      Render();return true;
   }
};
#endif // QSMC_ORCHESTRATOR_MQH
