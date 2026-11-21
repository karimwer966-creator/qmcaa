//+------------------------------------------------------------------+
//|                                      QSMC_ExecutionPreflight.mqh |
//|  Central, fail-closed preflight contract. Every adapter must call    |
//|  this before request construction/submission.                       |
//+------------------------------------------------------------------+
#ifndef QSMC_EXECUTIONPREFLIGHT_MQH
#define QSMC_EXECUTIONPREFLIGHT_MQH
#include "../Core/QSMC_Config.mqh"
#include "../Core/QSMC_Types.mqh"
#include "../Data/QSMC_MarketSnapshot.mqh"
#include "../Safety/QSMC_SafetyController.mqh"
#include "QSMC_RiskManager.mqh"

class CQSMCExecutionPreflight
{
public:
   static bool Validate(const SQSMCOrderIntent &intent,const SQSMCConfig &cfg,
                        const CQSMCMarketSnapshot &snap,const CQSMCRoot &root,
                        CQSMCSafetyController &safety,const SQSMCAccountState &account,
                        const ulong expectedMagic,string &why)
   {
      why="";
      if(intent.direction!=QSMC_DIR_BUY && intent.direction!=QSMC_DIR_SELL)
      {why="intent direction is not BUY/SELL";return false;}
      if(intent.symbol!=cfg.symbol || intent.symbol!=snap.Symbol())
      {why="intent symbol does not match configured snapshot symbol";return false;}
      if(intent.magic==0 || expectedMagic==0 || intent.magic!=expectedMagic)
      {why="intent magic does not belong to this QSMC instance";return false;}
      if(!root.CanOperate()){why="root is not RUNNING";return false;}
      if(intent.uid==0){why="zero intent uid";return false;}
      if(intent.volume<=0.0 || intent.price<=0.0 || intent.sl<=0.0 || intent.tp<=0.0)
      {why="volume/price/SL/TP must be positive";return false;}
      if(intent.confidence<cfg.min_confidence || intent.confidence>1.0)
      {why="confidence below configured limit or above one";return false;}
      if(snap.Point()<=0.0 || snap.TickSize()<=0.0 || snap.VolumeStep()<=0.0)
      {why="symbol contract metadata unavailable";return false;}
      ENUM_SYMBOL_TRADE_MODE tradeMode=(ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(intent.symbol,SYMBOL_TRADE_MODE);
      if(tradeMode==SYMBOL_TRADE_MODE_DISABLED || tradeMode==SYMBOL_TRADE_MODE_CLOSEONLY ||
         (tradeMode==SYMBOL_TRADE_MODE_LONGONLY && intent.direction==QSMC_DIR_SELL) ||
         (tradeMode==SYMBOL_TRADE_MODE_SHORTONLY && intent.direction==QSMC_DIR_BUY))
      {why="symbol permissions disallow requested direction";return false;}
      double quote=(intent.direction==QSMC_DIR_BUY?snap.Ask():snap.Bid());
      double maxPriceDrift=(double)MathMax(1,intent.deviationPoints)*snap.Point();
      if(quote<=0.0 || MathAbs(intent.price-quote)>maxPriceDrift+QSMC_EPSILON)
      {why="intent reference price is stale or outside deviation bound";return false;}
      if(MathAbs(intent.price/snap.TickSize()-MathRound(intent.price/snap.TickSize()))>1e-6 ||
         MathAbs(intent.sl/snap.TickSize()-MathRound(intent.sl/snap.TickSize()))>1e-6 ||
         MathAbs(intent.tp/snap.TickSize()-MathRound(intent.tp/snap.TickSize()))>1e-6)
      {why="price/SL/TP is not aligned to tick size";return false;}
      double minVol=snap.VolumeMin(),maxVol=snap.VolumeMax(),step=snap.VolumeStep();
      if(intent.volume<minVol-QSMC_EPSILON || intent.volume>maxVol+QSMC_EPSILON)
      {why="volume outside symbol bounds";return false;}
      double steps=intent.volume/step;
      if(MathAbs(steps-MathRound(steps))>1e-6)
      {why="volume is not aligned to symbol step";return false;}
      double minStop=(double)snap.StopsLevel()*snap.Point();
      if(intent.direction==QSMC_DIR_BUY)
      {
         if(intent.sl>=intent.price || intent.tp<=intent.price){why="BUY stop/target on wrong side";return false;}
         if(intent.price-intent.sl<minStop || intent.tp-intent.price<minStop)
         {why="BUY stop/target violates minimum stop distance";return false;}
      }
      else
      {
         if(intent.sl<=intent.price || intent.tp>=intent.price){why="SELL stop/target on wrong side";return false;}
         if(intent.sl-intent.price<minStop || intent.price-intent.tp<minStop)
         {why="SELL stop/target violates minimum stop distance";return false;}
      }
      if(cfg.max_spread_points>0 && snap.SpreadPoints()>cfg.max_spread_points)
      {why="spread exceeds configured maximum";return false;}
      if(account.dailyLossPct>=cfg.max_daily_loss_pct || account.drawdownPct>=cfg.max_drawdown_pct ||
         account.openPositions>=cfg.max_positions ||
         account.exposureLots+intent.volume>cfg.max_total_exposure_lots)
      {why="account risk limit reached";return false;}

      double tickValue=SymbolInfoDouble(intent.symbol,SYMBOL_TRADE_TICK_VALUE);
      double tickSize=SymbolInfoDouble(intent.symbol,SYMBOL_TRADE_TICK_SIZE);
      if(tickValue<=0.0 || tickSize<=0.0 || account.balance<=0.0)
      {why="risk contract metadata unavailable";return false;}
      double plannedRisk=MathAbs(intent.price-intent.sl)/tickSize*tickValue*intent.volume;
      double riskCap=account.balance*cfg.risk_percent/100.0;
      if(plannedRisk>riskCap+tickValue*intent.volume)
      {why="intent stop risk exceeds configured per-trade risk cap";return false;}

      ENUM_ORDER_TYPE orderType=(intent.direction==QSMC_DIR_BUY?ORDER_TYPE_BUY:ORDER_TYPE_SELL);
      double marginRequired=0.0;
      if(!OrderCalcMargin(orderType,intent.symbol,intent.volume,intent.price,marginRequired) || marginRequired<=0.0)
      {why="margin calculation failed";return false;}
      if(account.freeMargin<marginRequired)
      {why="insufficient free margin";return false;}

      if(!safety.CanSubmit(root,why)) return false;
      return true;
   }
};
#endif // QSMC_EXECUTIONPREFLIGHT_MQH
