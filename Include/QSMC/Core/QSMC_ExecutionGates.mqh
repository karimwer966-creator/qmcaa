// QSMC-001: independent build, account, acknowledgement and release barriers.
#ifndef QSMC_EXECUTIONGATES_MQH
#define QSMC_EXECUTIONGATES_MQH
#include "QSMC_Constants.mqh"
#include "QSMC_Types.mqh"

// Deliberately ship BOTH switches commented out. Do not enable during hardening.
// #define QSMC_ENABLE_REAL_TRADING
// #define QSMC_ALLOW_LIVE_ACCOUNT

class CQSMCExecutionGates
{
public:
   static bool BuildEnabled()
   {
#ifdef QSMC_ENABLE_REAL_TRADING
      return true;
#else
      return false;
#endif
   }
   static bool LiveAccountBuildEnabled()
   {
#ifdef QSMC_ALLOW_LIVE_ACCOUNT
      return true;
#else
      return false;
#endif
   }
   // Pure policy function: inputs can be exercised without a broker connection.
   static bool Policy(const bool enabled,const bool allowLive,const bool tester,
                      const ENUM_ACCOUNT_TRADE_MODE accountMode,
                      const ENUM_ACCOUNT_MARGIN_MODE marginMode,
                      const string ack,string &why)
   {
      why="";
      if(!enabled){why="Gate 1: QSMC_ENABLE_REAL_TRADING is not defined";return false;}
      if(marginMode!=ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
      {why="hedging accounts only; netting/exchange accounts are not supported";return false;}
      if(!allowLive && !tester && accountMode!=ACCOUNT_TRADE_MODE_DEMO)
      {why="Gate 2: live/contest account refused without QSMC_ALLOW_LIVE_ACCOUNT";return false;}
      if(ack!=QSMC_REAL_ACK_TOKEN)
      {why="Gate 3: exact acknowledgement required";return false;}
      return true;
   }
   static bool EnvironmentPermits(const string ack,string &why)
   {
      return Policy(BuildEnabled(),LiveAccountBuildEnabled(),
                    (MQLInfoInteger(MQL_TESTER)!=0),
                    (ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE),
                    (ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE),ack,why);
   }
   // Separate, non-input release interlock. No define or acknowledgement bypasses
   // this. Phases 4-7 and explicit release approval are still outstanding.
   static bool ReleaseApproved(){return false;}
   static string ReleaseReason()
   {return "RELEASE BLOCKED: risk, news, persistence and terminal verification incomplete";}
};
#endif // QSMC_EXECUTIONGATES_MQH
