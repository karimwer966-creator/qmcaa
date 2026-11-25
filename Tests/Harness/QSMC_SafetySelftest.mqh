// Pure safety contracts only. No files, globals, calendar, account or trade calls.
#ifndef QSMC_SAFETYSELFTEST_MQH
#define QSMC_SAFETYSELFTEST_MQH
#include <QSMC/Core/QSMC_ExecutionGates.mqh>
#include <QSMC/Core/QSMC_OwnerScope.mqh>
#include <QSMC/Execution/QSMC_RiskMath.mqh>
#include <QSMC/Execution/QSMC_BrokerRules.mqh>
#include <QSMC/Infrastructure/QSMC_StateCodec.mqh>
#include <QSMC/Safety/QSMC_EntryTimeRules.mqh>
#include <QSMC/Safety/QSMC_NewsPolicy.mqh>

struct SQSMCSafetyTestReport
{
   int passed,failed;
   string details;
   void Reset(){passed=0;failed=0;details="";}
   void Check(const bool ok,const string name)
   {
      if(ok)passed++;else failed++;
      details+=(ok?"PASS ":"FAIL ")+name+"\n";
   }
};
class CQSMCSafetySelftest
{
public:
   static void Run(SQSMCSafetyTestReport &r)
   {
      r.Reset();string why;
      r.Check(!CQSMCExecutionGates::BuildEnabled(),"shipped Gate 1 disabled");
      r.Check(!CQSMCExecutionGates::LiveAccountBuildEnabled(),"shipped live-account flag disabled");
      r.Check(!CQSMCExecutionGates::ReleaseApproved(),"release interlock closed");
      r.Check(!CQSMCExecutionGates::Policy(false,true,true,ACCOUNT_TRADE_MODE_DEMO,
         ACCOUNT_MARGIN_MODE_RETAIL_HEDGING,QSMC_REAL_ACK_TOKEN,why),"Gate 1 required");
      r.Check(!CQSMCExecutionGates::Policy(true,false,false,ACCOUNT_TRADE_MODE_REAL,
         ACCOUNT_MARGIN_MODE_RETAIL_HEDGING,QSMC_REAL_ACK_TOKEN,why),"live-account gate required");
      r.Check(!CQSMCExecutionGates::Policy(true,true,false,ACCOUNT_TRADE_MODE_REAL,
         ACCOUNT_MARGIN_MODE_RETAIL_HEDGING,"",why),"exact acknowledgement required");
      r.Check(!CQSMCExecutionGates::Policy(true,true,true,ACCOUNT_TRADE_MODE_DEMO,
         ACCOUNT_MARGIN_MODE_RETAIL_NETTING,QSMC_REAL_ACK_TOKEN,why),"netting refused even in tester");
      r.Check(CQSMCExecutionGates::Policy(true,false,true,ACCOUNT_TRADE_MODE_REAL,
         ACCOUNT_MARGIN_MODE_RETAIL_HEDGING,QSMC_REAL_ACK_TOKEN,why),"pure tester exception is not arming");
      double budget=0,lots=0,peak=0,dd=0;
      r.Check(CQSMCRiskMath::Budget(10000,0.5,budget) && budget==50,"equity budget");
      r.Check(!CQSMCRiskMath::Budget(10000,2.01,budget),"hard risk cap");
      r.Check(CQSMCRiskMath::FloorLots(50,100,0.25,10,0.25,10,lots) && lots==0.5,"quarter-lot floor");
      r.Check(!CQSMCRiskMath::FloorLots(24,100,0.25,10,0.25,10,lots) && lots==0,"minimum above budget rejects");
      r.Check(CQSMCRiskMath::FloorLots(1000,100,0.25,1.1,0.25,0.9,lots) && lots==0.75,"nonaligned caps floor again");
      r.Check(CQSMCRiskMath::Peak(true,0,10000,peak,dd) && peak==10000,"pure initial peak arithmetic");
      r.Check(CQSMCRiskMath::Peak(false,10000,11000,peak,dd) && peak==11000,"peak increases");
      r.Check(CQSMCRiskMath::Peak(false,11000,9000,peak,dd) && MathAbs(dd-18.1818181818)<1e-8,"peak retained through drawdown");
      r.Check(!CQSMCRiskMath::Peak(false,0,9000,peak,dd),"missing reviewed peak refuses");
      r.Check(CQSMCRiskMath::Margin(10000,1200,200,50) && !CQSMCRiskMath::Margin(10000,1199,200,50),"margin reserve boundary");
      r.Check(CQSMCBrokerRules::Classify(TRADE_RETCODE_DONE_PARTIAL)==QSMC_BROKER_PARTIAL,"partial fill distinct");
      r.Check(CQSMCBrokerRules::Classify(TRADE_RETCODE_PLACED)==QSMC_BROKER_PENDING,"placed is pending");
      r.Check(CQSMCBrokerRules::Classify(TRADE_RETCODE_TIMEOUT)==QSMC_BROKER_UNCERTAIN,"timeout uncertain");
      r.Check(CQSMCBrokerRules::Classify(0)==QSMC_BROKER_UNCERTAIN,"unknown retcode uncertain");
      ENUM_ORDER_TYPE_FILLING filling=ORDER_FILLING_FOK;
      r.Check(!CQSMCBrokerRules::Filling(0,SYMBOL_TRADE_EXECUTION_MARKET,filling,why),"market execution cannot fall back to RETURN");
      r.Check(CQSMCBrokerRules::Filling((long)SYMBOL_FILLING_IOC,SYMBOL_TRADE_EXECUTION_MARKET,filling,why) && filling==ORDER_FILLING_IOC,"runtime IOC selection");
      r.Check(CQSMCBrokerRules::OnTickGrid(2000.25,0.25) && !CQSMCBrokerRules::OnTickGrid(2000.26,0.25),"tick grid, not digits");
      r.Check(!CQSMCBrokerRules::Stops(QSMC_DIR_BUY,2000,2001,0,2004,0,why),"missing SL rejects");
      r.Check(!CQSMCBrokerRules::Stops(QSMC_DIR_SELL,2000,2001,2002,1998,2,why),"SELL stop uses Ask");
      r.Check(CQSMCEntryTimeRules::FromHourMinute(8,90)==-1,"invalid time component rejects");
      r.Check(CQSMCEntryTimeRules::Window(30,1380,60) && !CQSMCEntryTimeRules::Window(60,1380,60),"midnight window, exclusive end");
      r.Check(!CQSMCEntryTimeRules::Schedule(5,1200,1200,false,0,0,0,0,0,0,why),"Friday cutoff");
      r.Check(!CQSMCEntryTimeRules::Schedule(0,600,1200,false,0,0,0,0,0,0,why),"weekend entry block");
      r.Check(!CQSMCEntryTimeRules::Schedule(1,1425,1200,false,0,0,0,0,0,0,why) &&
         CQSMCEntryTimeRules::Schedule(1,75,1200,false,0,0,0,0,0,0,why),"rollover boundaries");
      r.Check(CQSMCNewsPolicy::Blackout(100000,101800) && !CQSMCNewsPolicy::Blackout(100000,101801),"inclusive news pre-window");
      r.Check(CQSMCNewsPolicy::Blackout(100000,98200) && !CQSMCNewsPolicy::Blackout(100000,98199),"inclusive news post-window");
      r.Check(CQSMCNewsPolicy::Covered(98200,102700,100000,100899) &&
         !CQSMCNewsPolicy::Covered(98200,102700,100000,100900),"cache expiry at fifteen minutes");
      string words;
      bool normalized=CQSMCNewsPolicy::Keywords(" cpi ;Fed;FOMC ",words);
      r.Check(normalized && CQSMCNewsPolicy::Relevant("USD",false,"fed chair speaks",words) &&
         !CQSMCNewsPolicy::Relevant("EUR",true,"CPI",words),"USD-scoped keyword matching");
      r.Check(!CQSMCNewsPolicy::Keywords("CPI;;FED",words),"empty keyword rejects");
      string scope=CQSMCOwnerScope::Raw(123,"FixtureBroker","XAUUSD.a",53000001);
      r.Check(StringLen(scope)>0 && scope==CQSMCOwnerScope::Raw(123,"FixtureBroker","XAUUSD.a",53000001),"stable raw ownership scope");
      r.Check(scope!=CQSMCOwnerScope::Raw(123,"OtherBroker","XAUUSD.a",53000001),"server distinguishes ownership");
      r.Check(!CQSMCStateCodec::Value("safety.kill","S","1") && CQSMCStateCodec::Value("safety.kill","B","1"),"typed safety flag");
      r.Check(!CQSMCStateCodec::Value("execution.pending_uid","S","broken"),"malformed pending UID rejects");
      r.Check(CQSMCStateCodec::Unsigned("18446744073709551615") && !CQSMCStateCodec::Unsigned("18446744073709551616"),"UID overflow rejects");
   }
};
#endif // QSMC_SAFETYSELFTEST_MQH
