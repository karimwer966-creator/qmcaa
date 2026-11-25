//+------------------------------------------------------------------+
//|                                            QSMC_RiskManager.mqh |
//|  Risk sizing and ownership-scoped account limits. Daily loss is     |
//|  derived from current server-day deal history plus floating P/L.   |
//+------------------------------------------------------------------+
#ifndef QSMC_RISKMANAGER_MQH
#define QSMC_RISKMANAGER_MQH
#include "../Core/QSMC_Config.mqh"
#include "../Core/QSMC_Types.mqh"
#include "../Infrastructure/QSMC_StateStore.mqh"
#include "QSMC_RiskMath.mqh"
#include "QSMC_TradeReconciler.mqh"
#include "QSMC_RiskRecovery.mqh"

class CQSMCRiskManager
{
private:
   SQSMCConfig m_cfg;

public:
   void Init(const SQSMCConfig &cfg){m_cfg=cfg;}

   bool CaptureAccount(SQSMCAccountState &out,const ulong magic,
                       CQSMCStateStore &store) const
   {
      out.Reset();
      out.balance=AccountInfoDouble(ACCOUNT_BALANCE);
      out.equity=AccountInfoDouble(ACCOUNT_EQUITY);
      out.margin=AccountInfoDouble(ACCOUNT_MARGIN);
      out.freeMargin=AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      out.captured=TimeCurrent();
      if(!store.IsReady() || store.Magic()!=magic || magic==0 || out.captured<=0 ||
         !CQSMCRiskMath::Positive(out.balance) || !CQSMCRiskMath::Positive(out.equity) ||
         !CQSMCRiskMath::Nonnegative(out.margin) || !MathIsValidNumber(out.freeMargin))return false;

      // Account-wide peak is shared across owner scopes, with a short-held
      // exclusive common-file claim. Missing enrollment is NEVER auto-seeded.
      CQSMCStateStore accountStore;
      if(!accountStore.InitScoped(AccountInfoInteger(ACCOUNT_LOGIN),AccountInfoString(ACCOUNT_SERVER),
                                 "__ACCOUNT_RISK__",1) || !accountStore.GetBool("risk.enrolled",false) ||
         accountStore.GetBool("risk.review_required",false))return false;
      datetime enrollment=(datetime)accountStore.GetInt("risk.baseline_time",0);
      if(enrollment<=0 || enrollment>out.captured || !store.GetBool("risk.enrolled",false))return false;
      MqlDateTime dt;if(!TimeToStruct(out.captured,dt))return false;
      dt.hour=0;dt.min=0;dt.sec=0;datetime day=StructToTime(dt);
      long ownerBaseline=store.GetInt("risk.baseline_time",0);
      if(ownerBaseline<(long)day || ownerBaseline>(long)out.captured ||
         !store.Exists("risk.day_floating") || store.GetInt("risk.day",0)!=(long)day ||
         !CQSMCRiskMath::Positive(store.GetDouble("risk.day_equity",0.0)) ||
         !MathIsValidNumber(store.GetDouble("risk.day_floating",0.0)))return false;
      double priorPeak=accountStore.GetDouble("risk.peak_equity",0.0);
      if(!CQSMCRiskMath::Peak(false,priorPeak,out.equity,out.peakEquity,out.drawdownPct))return false;
      if(out.peakEquity>priorPeak)
         if(!accountStore.SetDouble("risk.peak_equity",out.peakEquity) || !accountStore.Save())return false;
      SQSMCRecoveredRisk recovered;string recoveryWhy;
      if(!CQSMCRiskRecovery::Replay(m_cfg.symbol,magic,enrollment,day,recovered,recoveryWhy))
      {
         bool recorded=accountStore.SetBool("risk.review_required",true) &&
            accountStore.SetString("risk.review_reason",recoveryWhy) && accountStore.Save();
         Print("QSMC risk recovery refused: ",recoveryWhy," account review marker persisted=",recorded);
         return false;
      }

      SQSMCBrokerObservation observed;string why;
      if(!CQSMCTradeReconciler::Capture(m_cfg.symbol,magic,observed,why))return false;
      double dayNet=observed.realizedNet;
      int total=PositionsTotal();
      for(int i=0;i<total;i++)
      {
         ulong ticket=PositionGetTicket(i);long owner=0;string symbol="";
         if(ticket==0 || !PositionSelectByTicket(ticket) ||
            !PositionGetInteger(POSITION_MAGIC,owner) || !PositionGetString(POSITION_SYMBOL,symbol))return false;
         if((ulong)owner!=magic || symbol!=m_cfg.symbol)continue;
         double volume=0.0,profit=0.0,swap=0.0,sl=0.0;
         if(!PositionGetDouble(POSITION_VOLUME,volume) || !PositionGetDouble(POSITION_PROFIT,profit) ||
            !PositionGetDouble(POSITION_SWAP,swap) || !PositionGetDouble(POSITION_SL,sl) ||
            !CQSMCRiskMath::Positive(volume) || !CQSMCRiskMath::Positive(sl) ||
            !MathIsValidNumber(profit) || !MathIsValidNumber(swap))return false;
         out.openPositions++;out.exposureLots+=volume;dayNet+=profit+swap;
      }
      if(total!=PositionsTotal() || out.openPositions!=observed.positions ||
         !MathIsValidNumber(dayNet) || !CQSMCRiskMath::Nonnegative(out.exposureLots))return false;
      double baseline=store.GetDouble("risk.day_equity",0.0);
      double dailyChange=dayNet-store.GetDouble("risk.day_floating",0.0);
      out.dailyLossPct=(dailyChange<0.0?-dailyChange/baseline*100.0:0.0);
      if(!store.SetInt("risk.closed_today",recovered.closedToday) ||
         !store.SetInt("risk.loss_streak",recovered.lossStreak) ||
         !store.SetInt("risk.sl_today",recovered.slToday) || !store.SetInt("risk.tp_today",recovered.tpToday) ||
         !store.SetInt("risk.entry_orders",observed.entryOrders) ||
         !store.SetInt("risk.last_entry_time",(long)recovered.lastEntry) || !store.SetDouble("risk.daily_net",dailyChange) ||
         (store.IsDirty() && !store.Save()))return false;
      if(!CQSMCRiskMath::Nonnegative(out.dailyLossPct) ||
         !CQSMCRiskMath::Nonnegative(out.drawdownPct))return false;
      return true;
   }

   // Loss tick value is required, not the generic/profit-side tick value.
   // Fallback probes a valid runtime volume rather than assuming one lot is legal.
   static bool LossPerLot(const string symbol,const ENUM_QSMC_DIRECTION direction,
                          const double entry,const double stop,double &loss,string &why)
   {
      loss=0.0;why="";
      if(!CQSMCRiskMath::Positive(entry) || !CQSMCRiskMath::Positive(stop) ||
         (direction!=QSMC_DIR_BUY && direction!=QSMC_DIR_SELL) ||
         (direction==QSMC_DIR_BUY && stop>=entry) ||
         (direction==QSMC_DIR_SELL && stop<=entry))
      {why="invalid entry/stop/direction";return false;}
      double tickValue=0.0,tickSize=0.0;
      if(SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_VALUE_LOSS,tickValue) &&
         SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE,tickSize) &&
         CQSMCRiskMath::Positive(tickValue) && CQSMCRiskMath::Positive(tickSize))
         loss=MathAbs(entry-stop)/tickSize*tickValue;
      if(CQSMCRiskMath::Positive(loss))return true;
      double probe=0.0,pnl=0.0;
      ENUM_ORDER_TYPE type=(direction==QSMC_DIR_BUY?ORDER_TYPE_BUY:ORDER_TYPE_SELL);
      if(!SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN,probe) || !CQSMCRiskMath::Positive(probe) ||
         !OrderCalcProfit(type,symbol,probe,entry,stop,pnl) ||
         !MathIsValidNumber(pnl) || pnl>=0.0)
      {why="loss tick value and OrderCalcProfit fallback unavailable";return false;}
      loss=-pnl/probe;
      if(!CQSMCRiskMath::Positive(loss)){why="invalid fallback loss";return false;}
      return true;
   }

   bool SizeLots(const string symbol,const double entry,const double stop,
                 const double riskPercent,double &lots,double &riskMoney,string &why) const
   {
      lots=0.0;riskMoney=0.0;why="";
      double budget=0.0,loss=0.0,minimum=0.0,maximum=0.0,step=0.0;
      ENUM_QSMC_DIRECTION direction=(stop<entry?QSMC_DIR_BUY:QSMC_DIR_SELL);
      if(!CQSMCRiskMath::Budget(AccountInfoDouble(ACCOUNT_EQUITY),riskPercent,budget) ||
         !MathIsValidNumber(m_cfg.risk_percent) || riskPercent>m_cfg.risk_percent)
      {why="invalid equity or risk percentage above configured/hard cap";return false;}
      if(!LossPerLot(symbol,direction,entry,stop,loss,why))return false;
      if(!SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN,minimum) ||
         !SymbolInfoDouble(symbol,SYMBOL_VOLUME_MAX,maximum) ||
         !SymbolInfoDouble(symbol,SYMBOL_VOLUME_STEP,step) ||
         !CQSMCRiskMath::FloorLots(budget,loss,minimum,maximum,step,m_cfg.max_total_exposure_lots,lots))
      {why="invalid contract or no step-aligned volume within risk budget/cap";return false;}
      riskMoney=lots*loss; // Actual planned stop loss, never the unused budget.
      return true;
   }

   bool ValidateAccount(const SQSMCAccountState &a,string &why) const
   {
      why="";
      if(!CQSMCRiskMath::Positive(m_cfg.max_daily_loss_pct) || m_cfg.max_daily_loss_pct>QSMC_DAILY_LOSS_MAX_PCT ||
         !CQSMCRiskMath::Positive(m_cfg.max_drawdown_pct) || m_cfg.max_drawdown_pct>50.0 ||
         !CQSMCRiskMath::Positive(m_cfg.max_total_exposure_lots) ||
         m_cfg.max_total_exposure_lots>QSMC_MAX_TOTAL_EXPOSURE ||
         m_cfg.max_positions<1 || m_cfg.max_positions>QSMC_MAX_POSITIONS)
      {why="invalid runtime risk limits";return false;}
      if(!CQSMCRiskMath::Positive(a.balance) || !CQSMCRiskMath::Positive(a.equity) ||
         !CQSMCRiskMath::Positive(a.peakEquity) || a.peakEquity<a.equity ||
         !CQSMCRiskMath::Nonnegative(a.margin) || !MathIsValidNumber(a.freeMargin) ||
         !CQSMCRiskMath::Nonnegative(a.dailyLossPct) || !CQSMCRiskMath::Nonnegative(a.drawdownPct) ||
         !CQSMCRiskMath::Nonnegative(a.exposureLots) || a.openPositions<0 ||
         a.captured<=0 || a.captured>TimeCurrent() || TimeCurrent()-a.captured>5)
      {why="invalid/stale account risk snapshot";return false;}
      if(a.dailyLossPct>=m_cfg.max_daily_loss_pct){why="daily loss limit reached";return false;}
      if(a.drawdownPct>=m_cfg.max_drawdown_pct){why="equity high-water drawdown limit reached";return false;}
      if(a.openPositions>=m_cfg.max_positions){why="position count limit reached";return false;}
      if(a.exposureLots>=m_cfg.max_total_exposure_lots){why="exposure limit reached";return false;}
      if(a.freeMargin<=0.0){why="no free margin";return false;}
      return true;
   }
};
#endif // QSMC_RISKMANAGER_MQH
