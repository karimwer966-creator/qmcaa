// Central fail-closed entry checks. No price/SL/volume mutation is permitted.
#ifndef QSMC_EXECUTIONPREFLIGHT_MQH
#define QSMC_EXECUTIONPREFLIGHT_MQH
#include "../Core/QSMC_Config.mqh"
#include "../Core/QSMC_Types.mqh"
#include "../Data/QSMC_MarketSnapshot.mqh"
#include "../Safety/QSMC_SafetyController.mqh"
#include "QSMC_RiskManager.mqh"
#include "QSMC_BrokerRules.mqh"

class CQSMCExecutionPreflight
{
public:
   static bool Validate(const SQSMCOrderIntent &intent,const SQSMCConfig &cfg,
                        const CQSMCMarketSnapshot &snap,const CQSMCRoot &root,
                        CQSMCSafetyController &safety,const SQSMCAccountState &account,
                        const ulong expectedMagic,string &why)
   {
      why="";
      if(cfg.mode==QSMC_MODE_REAL)
      {
         if(!CQSMCExecutionGates::EnvironmentPermits(cfg.real_ack,why))return false;
         if(!CQSMCExecutionGates::ReleaseApproved())
         {why=CQSMCExecutionGates::ReleaseReason();return false;}
      }
      if(intent.direction!=QSMC_DIR_BUY && intent.direction!=QSMC_DIR_SELL)
      {why="intent direction is not BUY/SELL";return false;}
      if(intent.symbol!=cfg.symbol || intent.symbol!=snap.Symbol())
      {why="intent symbol does not match configured snapshot symbol";return false;}
      if(intent.magic==0 || expectedMagic==0 || intent.magic!=expectedMagic)
      {why="intent magic does not belong to this QSMC instance";return false;}
      if(!root.CanOperate()){why="root is not RUNNING";return false;}
      if(intent.uid==0){why="zero intent uid";return false;}
      if(!CQSMCRiskMath::Positive(intent.volume) || !CQSMCRiskMath::Positive(intent.price) ||
         !CQSMCRiskMath::Positive(intent.sl) || !CQSMCRiskMath::Positive(intent.tp) ||
         !CQSMCRiskMath::Nonnegative(intent.riskAmount) || !MathIsValidNumber(intent.confidence) ||
         intent.confidence<cfg.min_confidence || intent.confidence>1.0 ||
         intent.deviationPoints<0 || intent.deviationPoints>cfg.deviation_points)
      {why="invalid intent numeric values/deviation/confidence";return false;}
      // Prime potentially blocking calendar/CSV I/O BEFORE fresh financial checks.
      if(!safety.CanSubmit(root,why))return false;
      CQSMCRiskManager risk;risk.Init(cfg);
      if(!risk.ValidateAccount(account,why))return false;

      MqlTick tick;ZeroMemory(tick);
      double point=0.0,tickSize=0.0,minimum=0.0,maximum=0.0,step=0.0;
      long stops=0,freeze=0,mode=0;
      if(!SymbolInfoTick(intent.symbol,tick) ||
         !SymbolInfoDouble(intent.symbol,SYMBOL_POINT,point) ||
         !SymbolInfoDouble(intent.symbol,SYMBOL_TRADE_TICK_SIZE,tickSize) ||
         !SymbolInfoDouble(intent.symbol,SYMBOL_VOLUME_MIN,minimum) ||
         !SymbolInfoDouble(intent.symbol,SYMBOL_VOLUME_MAX,maximum) ||
         !SymbolInfoDouble(intent.symbol,SYMBOL_VOLUME_STEP,step) ||
         !SymbolInfoInteger(intent.symbol,SYMBOL_TRADE_STOPS_LEVEL,stops) ||
         !SymbolInfoInteger(intent.symbol,SYMBOL_TRADE_FREEZE_LEVEL,freeze) ||
         !SymbolInfoInteger(intent.symbol,SYMBOL_TRADE_MODE,mode) ||
         !CQSMCRiskMath::Positive(point) || !CQSMCRiskMath::Positive(tickSize) ||
         !CQSMCRiskMath::Positive(minimum) || !CQSMCRiskMath::Positive(maximum) ||
         maximum<minimum || !CQSMCRiskMath::Positive(step) || stops<0 || freeze<0)
      {why="fresh quote/contract metadata unavailable or invalid";return false;}
      datetime now=TimeTradeServer();
      if(now<=0 || tick.time<=0 || tick.time>now || now-tick.time>5)
      {why="quote timestamp invalid or older than five seconds";return false;}
      if(mode!=SYMBOL_TRADE_MODE_FULL &&
         !(mode==SYMBOL_TRADE_MODE_LONGONLY && intent.direction==QSMC_DIR_BUY) &&
         !(mode==SYMBOL_TRADE_MODE_SHORTONLY && intent.direction==QSMC_DIR_SELL))
      {why="symbol permissions disallow requested direction";return false;}
      if(!CQSMCBrokerRules::Stops(intent.direction,tick.bid,tick.ask,intent.sl,intent.tp,
                                  (double)stops*point,why))return false;
      // Freeze distance is read/validated, but applies to modifications/deletions,
      // not this new-entry-only path. No close/modify API exists in this module.
      double quote=(intent.direction==QSMC_DIR_BUY?tick.ask:tick.bid);
      if((intent.direction==QSMC_DIR_BUY && (intent.sl>=MathMin(intent.price,quote) || intent.tp<=MathMax(intent.price,quote))) ||
         (intent.direction==QSMC_DIR_SELL && (intent.sl<=MathMax(intent.price,quote) || intent.tp>=MathMin(intent.price,quote))))
      {why="SL/TP on wrong side of reference or fresh entry";return false;}
      double drift=(double)intent.deviationPoints*point;
      if(!CQSMCRiskMath::Nonnegative(drift) || MathAbs(intent.price-quote)>drift)
      {why="reference price outside exact deviation bound";return false;}
      if(!CQSMCBrokerRules::OnTickGrid(intent.price,tickSize) ||
         !CQSMCBrokerRules::OnTickGrid(intent.sl,tickSize) ||
         !CQSMCBrokerRules::OnTickGrid(intent.tp,tickSize))
      {why="price/SL/TP is not tick aligned";return false;}
      if(intent.volume<minimum || intent.volume>maximum ||
         MathAbs(intent.volume/step-MathRound(intent.volume/step))>1e-6)
      {why="volume outside runtime bounds/step";return false;}
      if(cfg.max_spread_points<=0 || (tick.ask-tick.bid)/point>(double)cfg.max_spread_points)
      {why="positive spread cap required and fresh spread must fit";return false;}
      if(account.exposureLots+intent.volume>cfg.max_total_exposure_lots)
      {why="post-entry exposure cap exceeded";return false;}
      // Bound loss at the worse of reference and fresh price, including the
      // configured adverse deviation. Broker gaps may still exceed this bound.
      double worst=(intent.direction==QSMC_DIR_BUY?
                    MathMax(intent.price,quote)+drift:MathMin(intent.price,quote)-drift);
      double loss=0.0,budget=0.0;
      double equity=AccountInfoDouble(ACCOUNT_EQUITY);
      if(!CQSMCRiskMath::Positive(equity))
      {why="fresh equity unavailable";return false;}
      equity=MathMin(equity,account.equity);
      if(!CQSMCRiskMath::Budget(equity,cfg.risk_percent,budget))
      {why="invalid equity risk budget";return false;}
      if(!CQSMCRiskManager::LossPerLot(intent.symbol,intent.direction,worst,intent.sl,loss,why))return false;
      double plannedRisk=loss*intent.volume;
      if(!CQSMCRiskMath::Positive(plannedRisk) || plannedRisk>budget)
      {why="stop risk including adverse deviation exceeds equity budget";return false;}
      ENUM_ORDER_TYPE type=(intent.direction==QSMC_DIR_BUY?ORDER_TYPE_BUY:ORDER_TYPE_SELL);
      double marginRequired=0.0;
      double freeMargin=AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      if(!MathIsValidNumber(freeMargin) ||
         !OrderCalcMargin(type,intent.symbol,intent.volume,worst,marginRequired) ||
         !CQSMCRiskMath::Margin(equity,MathMin(freeMargin,account.freeMargin),marginRequired,plannedRisk))
      {why="margin calculation/reserve failed: require max(10% equity, stop risk) after entry";return false;}
      if(!safety.CanSubmit(root,why))return false;
      datetime finished=TimeTradeServer();
      if(finished<now || finished-tick.time>5 || account.captured>TimeCurrent() || TimeCurrent()-account.captured>5)
      {why="quote/account aged during entry checks; rebuild snapshot before retry";return false;}
      return true;
   }
};
#endif // QSMC_EXECUTIONPREFLIGHT_MQH
