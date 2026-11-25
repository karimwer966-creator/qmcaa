// QSMC-001/012/013. Gated broker foundation; RELEASE BLOCKED in this phase.
#ifndef QSMC_REALADAPTER_MQH
#define QSMC_REALADAPTER_MQH
#include "QSMC_ExecutionAdapter.mqh"
#include "../Core/QSMC_ExecutionGates.mqh"

class CQSMCBrokerExecutor
{
private:
   bool m_armed;
   ulong m_magic;
   string m_symbol;
   ENUM_QSMC_MODE m_mode;
   string m_reason;

#ifdef QSMC_ENABLE_REAL_TRADING
   bool BuildRequest(const SQSMCOrderIntent &intent,const SQSMCConfig &cfg,
                     MqlTradeRequest &request,string &why)
   {
      ZeroMemory(request);why="";
      MqlTick tick;ZeroMemory(tick);
      double point=0.0,tickSize=0.0;
      long stops=0,flags=0,execution=0;
      if(!SymbolInfoTick(intent.symbol,tick) ||
         !SymbolInfoDouble(intent.symbol,SYMBOL_POINT,point) ||
         !SymbolInfoDouble(intent.symbol,SYMBOL_TRADE_TICK_SIZE,tickSize) ||
         !SymbolInfoInteger(intent.symbol,SYMBOL_TRADE_STOPS_LEVEL,stops) ||
         !SymbolInfoInteger(intent.symbol,SYMBOL_FILLING_MODE,flags) ||
         !SymbolInfoInteger(intent.symbol,SYMBOL_TRADE_EXEMODE,execution) ||
         point<=0.0 || tickSize<=0.0 || stops<0)
      {why="fresh broker contract/tick unavailable";return false;}
      datetime now=TimeTradeServer();
      if(now<=0 || tick.time<=0 || tick.time>now || now-tick.time>5)
      {why="fresh broker tick is stale or has an invalid timestamp";return false;}
      if(!CQSMCBrokerRules::Stops(intent.direction,tick.bid,tick.ask,intent.sl,intent.tp,
                                  (double)stops*point,why))return false;
      double price=(intent.direction==QSMC_DIR_BUY?tick.ask:tick.bid);
      // Reject instead of moving/widening SL or rounding lots upward.
      if(!CQSMCBrokerRules::OnTickGrid(price,tickSize) ||
         !CQSMCBrokerRules::OnTickGrid(intent.sl,tickSize) ||
         !CQSMCBrokerRules::OnTickGrid(intent.tp,tickSize))
      {why="fresh price/SL/TP not tick aligned; request not changed";return false;}
      if(intent.deviationPoints<0 || intent.deviationPoints>cfg.deviation_points ||
         MathAbs(intent.price-price)>(double)intent.deviationPoints*point+QSMC_EPSILON)
      {why="fresh price outside configured intent deviation";return false;}
      if(cfg.max_spread_points<=0 || (tick.ask-tick.bid)/point>(double)cfg.max_spread_points)
      {why="broker entries require a positive spread cap and fresh spread within cap";return false;}
      ENUM_ORDER_TYPE_FILLING filling=ORDER_FILLING_FOK;
      if(!CQSMCBrokerRules::Filling(flags,(ENUM_SYMBOL_TRADE_EXECUTION)execution,filling,why))return false;
      request.action=TRADE_ACTION_DEAL;
      request.magic=intent.magic;request.symbol=intent.symbol;request.volume=intent.volume;
      request.type=(intent.direction==QSMC_DIR_BUY?ORDER_TYPE_BUY:ORDER_TYPE_SELL);
      request.price=price;request.sl=intent.sl;request.tp=intent.tp;
      request.deviation=(ulong)intent.deviationPoints;request.type_filling=filling;
      request.comment="QSMC:"+StringFormat("%I64u",intent.uid);
      return true;
   }
#endif

public:
   CQSMCBrokerExecutor(){m_armed=false;m_magic=0;m_symbol="";m_mode=QSMC_MODE_OFF;m_reason="not configured";}
   bool Init(const SQSMCConfig &cfg,const ulong magic)
   {
      Disarm();m_magic=magic;m_symbol=cfg.symbol;m_mode=cfg.mode;
      m_reason="configured, disarmed";
      return (magic>0 && StringLen(cfg.symbol)>0);
   }
   bool Arm(const string ack)
   {
      Disarm();
      if(m_mode!=QSMC_MODE_REAL){m_reason="broker arm not requested in analysis/off/paper mode";return false;}
      if(!CQSMCExecutionGates::EnvironmentPermits(ack,m_reason))return false;
      if(!CQSMCExecutionGates::ReleaseApproved())
      {m_reason=CQSMCExecutionGates::ReleaseReason();return false;}
      m_armed=true;m_reason="armed";return true;
   }
   void Disarm(){m_armed=false;m_reason="disarmed";}
   bool IsArmed() const{return m_armed;}
   string Status() const{return m_reason;}
   bool SubmitChecked(const SQSMCOrderIntent &intent,const SQSMCConfig &cfg,
                      const CQSMCMarketSnapshot &snap,const CQSMCRoot &root,
                      CQSMCSafetyController &safety,const SQSMCAccountState &account,
                      const ulong expectedMagic,CQSMCStateStore &store,
                      SQSMCExecutionResult &result)
   {
      result.Reset();result.intentUid=intent.uid;
      string why;
      if(!CQSMCExecutionGates::EnvironmentPermits(cfg.real_ack,why))
      {result.message=why;return false;}
      if(!CQSMCExecutionGates::ReleaseApproved())
      {result.message=CQSMCExecutionGates::ReleaseReason();return false;}
      if(!m_armed || m_mode!=QSMC_MODE_REAL || cfg.mode!=QSMC_MODE_REAL ||
         m_magic!=expectedMagic || intent.magic!=m_magic || intent.symbol!=m_symbol ||
         store.Magic()!=m_magic || !store.IsWritable())
      {result.message="unarmed broker or mismatched context";return false;}
      // No context-free broker Submit can bypass centralized preflight.
      if(!CQSMCExecutionPreflight::Validate(intent,cfg,snap,root,safety,account,expectedMagic,why))
      {result.code=QSMC_ERR_PREFLIGHT_REJECTED;result.message=why;return false;}
      string uid=StringFormat("%I64u",intent.uid);
      if(store.GetString("execution.pending_uid","")!=uid ||
         store.GetString("execution.last_uid","")!=uid || store.IsDirty())
      {result.code=QSMC_ERR_SAFETY_BLOCKED;result.message="no committed pending-intent guard";return false;}
#ifdef QSMC_ENABLE_REAL_TRADING
      MqlTradeRequest request;MqlTradeCheckResult check;MqlTradeResult reply;
      ZeroMemory(check);ZeroMemory(reply);
      if(!BuildRequest(intent,cfg,request,why))
      {result.code=QSMC_ERR_PREFLIGHT_REJECTED;result.message=why;return false;}
      ResetLastError();
      if(!OrderCheck(request,check))
      {
         result.code=QSMC_ERR_PREFLIGHT_REJECTED;result.terminalError=GetLastError();
         result.message="broker OrderCheck rejected: "+check.comment;return false;
      }
      // OrderCheck can block or cross a blackout/session boundary. Recheck
      // context and entry guards immediately before the sole send boundary.
      if(!CQSMCExecutionPreflight::Validate(intent,cfg,snap,root,safety,account,expectedMagic,why))
      {result.code=QSMC_ERR_PREFLIGHT_REJECTED;result.message=why;return false;}
      ResetLastError();
      bool sent=OrderSend(request,reply);
      result.terminalError=GetLastError();result.submitted=true;
      result.brokerRetcode=reply.retcode;result.requestId=reply.request_id;
      result.orderTicket=reply.order;result.dealTicket=reply.deal;
      result.ticket=(reply.order>0?reply.order:reply.deal);
      result.outcome=(sent?CQSMCBrokerRules::Classify(reply.retcode):QSMC_BROKER_UNCERTAIN);
      result.accepted=(result.outcome==QSMC_BROKER_FILLED ||
                       result.outcome==QSMC_BROKER_PARTIAL || result.outcome==QSMC_BROKER_PENDING);
      result.uncertain=(result.outcome==QSMC_BROKER_UNCERTAIN || result.outcome==QSMC_BROKER_PENDING);
      // PLACED is accepted but has no confirmed fill volume.
      if(result.outcome==QSMC_BROKER_FILLED || result.outcome==QSMC_BROKER_PARTIAL)
      {result.filledVolume=reply.volume;result.filledPrice=reply.price;}
      result.code=(result.accepted?QSMC_OK:
                   (result.uncertain?QSMC_ERR_SAFETY_BLOCKED:QSMC_ERR_ORDER_REJECTED));
      result.message="broker outcome="+EnumToString(result.outcome)+" "+reply.comment;
      // No automatic retry, re-arm or pending-guard clearance. Reconciliation
      // and durable lifecycle recovery must first be completed and verified.
      Disarm();m_reason="broker attempt consumed; explicit reconciliation required";
      return result.accepted;
#else
      result.message="Gate 1 disabled; broker API excluded from this build";
      return false;
#endif
   }
};

class CQSMCRealAdapter : public CQSMCExecutionAdapter
{
private:
   CQSMCBrokerExecutor m_broker;
public:
   bool Init(const SQSMCConfig &cfg,const ulong magic){return m_broker.Init(cfg,magic);}
   bool Arm(const string ack){return m_broker.Arm(ack);}
   void Disarm(){m_broker.Disarm();}
   string ArmStatus() const{return m_broker.Status();}
   bool IsArmed() const{return m_broker.IsArmed();}
   bool Submit(const SQSMCOrderIntent &intent,SQSMCExecutionResult &result)
   {
      result.Reset();result.intentUid=intent.uid;
      result.message="context-free broker Submit forbidden; use checked manager path";return false;
   }
   bool SubmitChecked(const SQSMCOrderIntent &intent,const SQSMCConfig &cfg,
                      const CQSMCMarketSnapshot &snap,const CQSMCRoot &root,
                      CQSMCSafetyController &safety,const SQSMCAccountState &account,
                      const ulong expectedMagic,CQSMCStateStore &store,
                      SQSMCExecutionResult &result)
   {return m_broker.SubmitChecked(intent,cfg,snap,root,safety,account,expectedMagic,store,result);}
   bool IsLive() const{return m_broker.IsArmed();}
   bool IsBroker() const{return true;}
};
#endif // QSMC_REALADAPTER_MQH
