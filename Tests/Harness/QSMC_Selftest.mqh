//+------------------------------------------------------------------+
//|                                           QSMC_Selftest.mqh |
//|  Deterministic, terminal-independent checks for pure contracts.    |
//|  No test outcome is claimed until run in MetaTrader.                |
//+------------------------------------------------------------------+
#ifndef QSMC_SELFTEST_MQH
#define QSMC_SELFTEST_MQH
#include <QSMC/QSMC.mqh>

struct SQSMCTestReport
{
   int passed;
   int failed;
   string details;
   void Reset(){passed=0;failed=0;details="";}
   void Check(const bool ok,const string name)
   {
      if(ok)passed++;else failed++;
      details+=(ok?"PASS ":"FAIL ")+name+"\n";
   }
};

class CQSMCSelftest
{
private:
   static void BuildBars(MqlRates &rates[],const int count,const int seconds)
   {
      ArrayResize(rates,count);
      ArraySetAsSeries(rates,true);
      datetime now=TimeCurrent();
      for(int i=0;i<count;i++)
      {
         double phase=(double)(count-i)*0.31;
         double close=100.0+0.002*(double)(count-i)+0.12*MathSin(phase);
         double open=close+0.025*MathSin(phase*0.7);
         rates[i].time=now-(datetime)((long)i*seconds);
         rates[i].open=open;
         rates[i].close=close;
         rates[i].high=MathMax(open,close)+0.04;
         rates[i].low=MathMin(open,close)-0.04;
         rates[i].tick_volume=100+i;
         rates[i].real_volume=0;
         rates[i].spread=5;
      }
   }
public:
   static void Run(SQSMCTestReport &report)
   {
      report.Reset();
      string why;
      SQSMCConfig invalidCfg;invalidCfg.SetDefaults();invalidCfg.timer_ms=1;
      bool validCfg=invalidCfg.Validate(why);
      report.Check(!validCfg && StringFind(why,"timer_ms")>=0,
                   "configuration timer boundary is rejected with diagnostic");

      CQSMCStateMachine fsm;
      report.Check(fsm.Transition(QSMC_STATE_INITIALIZING,why),"state CREATED->INITIALIZING");
      report.Check(!fsm.Transition(QSMC_STATE_RUNNING,why),"state skips READY rejected");
      report.Check(fsm.Transition(QSMC_STATE_READY,why),"state INITIALIZING->READY");
      report.Check(fsm.Transition(QSMC_STATE_RUNNING,why),"state READY->RUNNING");
      report.Check(!fsm.Transition(QSMC_STATE_READY,why),"running cannot silently recover to READY");
      report.Check(fsm.Transition(QSMC_STATE_SAFE_MODE,why),"running enters SAFE_MODE");
      report.Check(!fsm.CanOperate(),"SAFE_MODE is non-operational");
      report.Check(fsm.Transition(QSMC_STATE_READY,why),"SAFE_MODE recovery returns READY");

      SQSMCConfig cfg;cfg.SetDefaults();
      CQSMCInputFingerprint fp1;fp1.Reset();fp1.AddConfig(cfg);
      CQSMCInputFingerprint fp2;fp2.Reset();fp2.AddConfig(cfg);
      report.Check(fp1.Hex()==fp2.Hex(),"input fingerprint stable for identical config");
      cfg.risk_percent+=0.01;
      CQSMCInputFingerprint fp3;fp3.Reset();fp3.AddConfig(cfg);
      report.Check(fp1.Hex()!=fp3.Hex(),"behavior-changing risk input changes fingerprint");

      CQSMCInstanceIdentity id1,id2;
      report.Check(id1.Build(_Symbol,PERIOD_M15,fp1.Hex(),0),"identity builds for first fingerprint");
      report.Check(id2.Build(_Symbol,PERIOD_M15,fp3.Hex(),0),"identity builds for changed fingerprint");
      report.Check(id1.Magic()!=id2.Magic(),"different fingerprints produce different identity in fixture");

      string tfError;
      report.Check(CQSMCTimeframeManager::ValidateOrdering(PERIOD_H4,PERIOD_M15,PERIOD_M5,tfError),
                   "valid HTF/exec/LTF ordering accepted");
      report.Check(!CQSMCTimeframeManager::ValidateOrdering(PERIOD_M15,PERIOD_M15,PERIOD_M5,tfError),
                   "invalid timeframe ordering rejected");

      CQSMCMarketSnapshot fixture;
      MqlRates execBars[],htfBars[],ltfBars[];
      BuildBars(execBars,180,PeriodSeconds(PERIOD_M15));
      BuildBars(htfBars,80,PeriodSeconds(PERIOD_H4));
      BuildBars(ltfBars,120,PeriodSeconds(PERIOD_M5));
      fixture.SetSymbol(_Symbol);
      fixture.SetTimeframes(PERIOD_M15,PERIOD_H4,PERIOD_M5);
      fixture.SetClosedOnly(true);
      fixture.SetQuote(100.0,100.02,SymbolInfoDouble(_Symbol,SYMBOL_POINT),2);
      fixture.SetContract((int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS),1.0,
                          SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE),
                          SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),
                          SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX),
                          SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP),0,0);
      fixture.AttachBars(QSMC_SNAP_EXEC,execBars,ArraySize(execBars));
      fixture.AttachBars(QSMC_SNAP_HTF,htfBars,ArraySize(htfBars));
      fixture.AttachBars(QSMC_SNAP_LTF,ltfBars,ArraySize(ltfBars));
      fixture.SetCaptured(TimeCurrent());
      CQSMCStructure closedA,closedB;
      bool structA=closedA.Detect(fixture,QSMC_SNAP_EXEC,150,2,2);
      MqlRates changedExec[];ArrayResize(changedExec,ArraySize(execBars));
      for(int bi=0;bi<ArraySize(execBars);bi++)changedExec[bi]=execBars[bi];
      changedExec[0].open=1000.0;changedExec[0].close=1000.1;
      changedExec[0].high=1000.2;changedExec[0].low=999.9;
      fixture.AttachBars(QSMC_SNAP_EXEC,changedExec,ArraySize(changedExec));
      bool structB=closedB.Detect(fixture,QSMC_SNAP_EXEC,150,2,2);
      bool unchanged=(structA && structB && closedA.Count()==closedB.Count());
      if(unchanged)
      {
         SQSMCStructurePoint pa,pb;
         for(int pi=0;pi<closedA.Count();pi++)
         {
            closedA.Get(pi,pa);closedB.Get(pi,pb);
            if(pa.type!=pb.type || pa.price!=pb.price || pa.time!=pb.time)unchanged=false;
         }
      }
      report.Check(unchanged,"current candle mutation does not alter closed-bar structure");
      fixture.AttachBars(QSMC_SNAP_EXEC,execBars,ArraySize(execBars));

      CQSMCDataReadiness readiness;readiness.Init(100);
      CQSMCMarketSnapshot emptyData;
      report.Check(!readiness.Evaluate(emptyData,why),"missing snapshot is not data-ready");
      report.Check(readiness.Evaluate(fixture,why),"synthetic three-timeframe snapshot reaches ready state");
      CQSMCScanners scanners;
      string scanWhy;
      bool scanned=scanners.Scan(fixture,150,2,2,20.0*SymbolInfoDouble(_Symbol,SYMBOL_POINT),scanWhy);
      report.Check(scanned,"analysis scanner accepts deterministic oscillating fixture");
      SQSMCScanContext analysis;scanners.ContextCopy(analysis);
      report.Check(analysis.valid && analysis.atr>0.0 && analysis.swingCount>0,
                   "analysis output contains validated ATR and structure evidence");
      CQSMCSvpCore profile;
      report.Check(profile.Build(fixture,QSMC_SNAP_EXEC,100,30,70.0),
                   "SVP core builds bounded profile from fixture");
      report.Check(profile.Poc()>0.0 && profile.Vah()>=profile.Val(),
                   "SVP profile returns ordered value-area levels");

      CQSMCRiskManager risk;risk.Init(cfg);
      SQSMCAccountState account;account.Reset();account.balance=10000.0;account.equity=10000.0;
      account.freeMargin=10000.0;account.dailyLossPct=cfg.max_daily_loss_pct;
      report.Check(!risk.ValidateAccount(account,why),"daily loss cap enforced by risk contract");

      CQSMCMarketSnapshot emptySnapshot;
      CQSMCRoot emptyRoot;
      CQSMCSafetyController uninitialisedSafety;
      SQSMCOrderIntent invalidIntent;invalidIntent.Reset();
      report.Check(!CQSMCExecutionPreflight::Validate(invalidIntent,cfg,emptySnapshot,emptyRoot,
                                                      uninitialisedSafety,account,1,why),
                   "execution preflight rejects invalid intent before environment access");

      CQSMCSignalRegistry registry;
      registry.Add(QSMC_DIR_BUY,0.7,"test","buy evidence");
      registry.Add(QSMC_DIR_SELL,0.7,"test","sell evidence");
      SQSMCUnifiedDecision decision;
      report.Check(!CQSMCArbiter::Resolve(registry,0.5,TimeCurrent(),decision),"equal opposing signals rejected");
      report.Check(decision.direction==QSMC_DIR_NONE && decision.rejectionCount>0,"rejection is explicit and auditable");

      CQSMCSignalRegistry empty;
      report.Check(!CQSMCArbiter::Resolve(empty,0.5,TimeCurrent(),decision),"missing candidates are no-trade");

      ulong testMagic=987654321+(ulong)(ChartID()%100000);
      CQSMCStateStore testStore;
      bool storeReady=testStore.Init(testMagic);
      report.Check(storeReady,"temporary state store initializes for recovery tests");
      if(storeReady)
      {
         CQSMCExecutionJournal journal;
         journal.MarkSubmitted(1122334455,testStore);
         report.Check(journal.Seen(1122334455,testStore),"persisted intent UID blocks duplicate replay");
         report.Check(!journal.Seen(5566778899,testStore),"different intent UID remains eligible");

         CQSMCIncidentSafety incident,restored;
         incident.Latch(testStore,"self-test safety latch",true);
         bool recovered=restored.Restore(testStore);
         report.Check(!recovered && restored.RecoveryUncertain(),"uncertain restart remains safety-latched");
         testStore.SetBool("safety.kill",false);
         testStore.SetBool("safety.uncertain",false);
         testStore.SetKillSwitch(false);
         testStore.Save();
         GlobalVariableDel(testStore.KillGvName());
         FileDelete(testStore.FileName());
         FileDelete(testStore.FileName()+".tmp");
      }

      ENUM_QSMC_PRESET preset;
      report.Check(QSMC_PresetFromString("balanced",preset)&&preset==QSMC_PRESET_BALANCED,
                   "preset parser normalizes case");
   }
};
#endif // QSMC_SELFTEST_MQH
