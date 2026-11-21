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
      // Create a controlled bullish three-candle gap at shift 2 and a
      // partial retest on the latest closed candle at shift 1.
      execBars[1].open=100.55;execBars[1].close=100.70;execBars[1].low=100.40;execBars[1].high=100.80;
      execBars[2].open=100.00;execBars[2].close=100.10;execBars[2].low=99.90;execBars[2].high=100.20;
      execBars[3].open=100.30;execBars[3].close=100.50;execBars[3].low=100.25;execBars[3].high=100.65;
      execBars[4].open=101.20;execBars[4].close=101.30;execBars[4].low=101.00;execBars[4].high=101.50;
      fixture.AttachBars(QSMC_SNAP_EXEC,execBars,ArraySize(execBars));
      CQSMCFairValueGaps fvgBuilder;
      report.Check(fvgBuilder.Build(fixture,QSMC_SNAP_EXEC,100,0.10),
                   "FVG builder detects controlled three-candle imbalance");
      SQSMCFairValueGap retestedGap;
      report.Check(fvgBuilder.BestCurrentRetest(QSMC_FVG_BULLISH,retestedGap),
                   "unfilled bullish FVG retest is identified");

      CQSMCSessionContext sessionFixture;sessionFixture.Reset();
      sessionFixture.ready=true;sessionFixture.activeSession="LONDON";
      sessionFixture.inLondonOrNewYork=true;
      SQSMCICTSetup ictTest;
      CQSMCStructure fixtureStructure;
      fixtureStructure.Detect(fixture,QSMC_SNAP_EXEC,150,2,2);
      CQSMCICTSetupModel::Evaluate(fixture,QSMC_SNAP_EXEC,fixtureStructure,
                                   sessionFixture,fvgBuilder,2,1.0,ictTest);
      report.Check(ictTest.ready && ictTest.stage==QSMC_ICT_WAIT_SWEEP && !ictTest.candidate,
                   "ICT funnel waits for sweep and does not fabricate a setup");
      sessionFixture.sweptLow=true;sessionFixture.sweptHigh=true;
      sessionFixture.sweptLowLevel=99.0;sessionFixture.sweptHighLevel=102.0;
      sessionFixture.sweptLowShift=4;sessionFixture.sweptHighShift=4;
      CQSMCICTSetupModel::Evaluate(fixture,QSMC_SNAP_EXEC,fixtureStructure,
                                   sessionFixture,fvgBuilder,2,1.0,ictTest);
      report.Check(ictTest.stage==QSMC_ICT_AMBIGUOUS && !ictTest.candidate,
                   "two-sided session raid is rejected as ambiguous");

      SQSMCOrderFlowProxyResult flowProxy;
      report.Check(CQSMCOrderFlowProxy::Calculate(fixture,QSMC_SNAP_EXEC,20,flowProxy) &&
                   StringFind(flowProxy.diagnostic,"no centralized aggressor")>=0,
                   "order-flow output is explicitly marked as a volume proxy");

      CQSMCSessionContext sessionResult;
      report.Check(CQSMCSessions::Evaluate(fixture,QSMC_SNAP_EXEC,true,
                         120,480,540,720,900,1080,sessionResult),
                   "broker-server session analysis evaluates closed bars");
      report.Check(!CQSMCSessions::Evaluate(fixture,QSMC_SNAP_EXEC,false,
                         120,480,540,720,900,1080,sessionResult),
                   "disabled session analysis fails closed");

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
      bool newestFirst=true;int previousShift=-1;
      for(int si=0;si<scanners.StructureCount();si++)
      {
         SQSMCStructurePoint point;
         if(!scanners.GetStructurePoint(si,point))continue;
         if(previousShift>=0 && point.shift<=previousShift)newestFirst=false;
         previousShift=point.shift;
      }
      report.Check(newestFirst,"confirmed structure points are exposed newest-first");
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

      // Both setup models are subject to common HTF/session/liquidity gates;
      // optional volume/Profile/Elliott data only adjust confluence points.
      SQSMCScanContext funnelContext;funnelContext.Reset();
      funnelContext.valid=true;funnelContext.price=100.0;funnelContext.atr=1.0;
      funnelContext.htfBias=QSMC_BIAS_BULLISH;funnelContext.inKillzone=true;
      funnelContext.sweptSessionLow=true;funnelContext.flowReady=true;
      funnelContext.flowPressure=0.4;funnelContext.relativeTickVolume=1.8;
      funnelContext.svpReady=true;funnelContext.aboveValue=true;
      funnelContext.elliottReady=true;funnelContext.elliottLastType=QSMC_SWING_LOW;
      funnelContext.ictCandidate=true;funnelContext.ictDirection=QSMC_DIR_BUY;
      funnelContext.ictStage="WATCH_CANDIDATE";funnelContext.ictConfluence=70.0;
      funnelContext.ictSummary="raid-MSS-FVG fixture";
      funnelContext.alternateCandidate=true;funnelContext.alternateDirection=QSMC_DIR_BUY;
      funnelContext.alternateStage="WATCH_CANDIDATE";funnelContext.alternateConfluence=65.0;
      funnelContext.alternateSummary="BOS/OB fixture";
      CQSMCSignalRegistry funnelRegistry;SQSMCOpportunityAudit audit;
      CQSMCOpportunityFunnel::Build(funnelContext,TimeCurrent(),0.55,funnelRegistry,audit);
      report.Check(funnelRegistry.Count()==2 && audit.primary.status=="ACCEPTED" &&
                   audit.alternate.status=="ACCEPTED",
                   "primary and secondary models register when common filters pass");
      funnelContext.htfBias=QSMC_BIAS_BEARISH;
      CQSMCOpportunityFunnel::Build(funnelContext,TimeCurrent(),0.55,funnelRegistry,audit);
      report.Check(funnelRegistry.Count()==0 &&
                   StringFind(audit.primary.reason,"conflicts with HTF Bias")>=0 &&
                   StringFind(audit.alternate.reason,"conflicts with HTF Bias")>=0,
                   "HTF bias rejects both conflicting model opportunities with reasons");
      funnelContext.htfBias=QSMC_BIAS_BULLISH;funnelContext.sweptSessionLow=false;
      CQSMCOpportunityFunnel::Build(funnelContext,TimeCurrent(),0.55,funnelRegistry,audit);
      report.Check(funnelRegistry.Count()==0 &&
                   StringFind(audit.primary.reason,"liquidity raid")>=0,
                   "directional session-liquidity filter records rejection reason");
      funnelContext.sweptSessionLow=true;funnelContext.elliottLastType=QSMC_SWING_LOW;
      CQSMCOpportunityFunnel::Build(funnelContext,TimeCurrent(),0.55,funnelRegistry,audit);
      double alignedElliottScore=audit.primary.scorePoints;
      funnelContext.elliottLastType=QSMC_SWING_HIGH;
      CQSMCOpportunityFunnel::Build(funnelContext,TimeCurrent(),0.55,funnelRegistry,audit);
      report.Check(MathAbs(alignedElliottScore-audit.primary.scorePoints-6.0)<0.001,
                   "Elliott hint adds/removes only a small score and cannot create the setup");

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
