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

class CQSMCRiskManager
{
private:
   SQSMCConfig m_cfg;

   datetime ServerDayStart() const
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(),dt);
      dt.hour=0;dt.min=0;dt.sec=0;
      return StructToTime(dt);
   }

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
      if(out.balance<=0.0 || out.equity<=0.0 || magic==0)return false;

      string peakKey="risk.peak_equity";
      double priorPeak=store.GetDouble(peakKey,out.equity);
      out.peakEquity=MathMax(priorPeak,out.equity);
      if(out.peakEquity>priorPeak)
      {
         if(!store.SetDouble(peakKey,out.peakEquity) || !store.Save()) return false;
      }
      out.drawdownPct=(out.peakEquity>0.0?MathMax(0.0,(out.peakEquity-out.equity)/out.peakEquity*100.0):0.0);

      for(int i=PositionsTotal()-1;i>=0;i--)
      {
         ulong ticket=PositionGetTicket(i);
         if(ticket==0 || !PositionSelectByTicket(ticket)) continue;
         if((ulong)PositionGetInteger(POSITION_MAGIC)!=magic) continue;
         out.openPositions++;
         out.exposureLots+=PositionGetDouble(POSITION_VOLUME);
      }

      // Include only deals bearing this QSMC instance magic. Net daily P/L
      // includes commissions, swaps and current floating position P/L.
      datetime from=ServerDayStart();
      if(!HistorySelect(from,TimeCurrent())) return false;
      double dayNet=0.0;
      int deals=HistoryDealsTotal();
      for(int i=0;i<deals;i++)
      {
         ulong deal=HistoryDealGetTicket(i);
         if(deal==0)continue;
         if((ulong)HistoryDealGetInteger(deal,DEAL_MAGIC)!=magic)continue;
         dayNet+=HistoryDealGetDouble(deal,DEAL_PROFIT);
         dayNet+=HistoryDealGetDouble(deal,DEAL_SWAP);
         dayNet+=HistoryDealGetDouble(deal,DEAL_COMMISSION);
         dayNet+=HistoryDealGetDouble(deal,DEAL_FEE);
      }
      for(int j=PositionsTotal()-1;j>=0;j--)
      {
         ulong ticket=PositionGetTicket(j);
         if(ticket==0 || !PositionSelectByTicket(ticket))continue;
         if((ulong)PositionGetInteger(POSITION_MAGIC)!=magic)continue;
         dayNet+=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);
      }
      out.dailyLossPct=(dayNet<0.0?(-dayNet/out.balance*100.0):0.0);
      return true;
   }

   bool SizeLots(const string symbol,const double entry,const double stop,
                 const double riskPercent,double &lots,double &riskMoney,string &why) const
   {
      lots=0.0;riskMoney=0.0;why="";
      if(entry<=0.0 || stop<=0.0 || MathAbs(entry-stop)<=QSMC_EPSILON)
      {why="invalid entry/stop distance";return false;}
      if(riskPercent<=0.0 || riskPercent>QSMC_RISK_MAX_PERCENT)
      {why="risk percentage outside hard cap";return false;}
      double balance=AccountInfoDouble(ACCOUNT_BALANCE);
      double tickValue=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_VALUE);
      double tickSize=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);
      double volMin=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN);
      double volMax=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MAX);
      double volStep=SymbolInfoDouble(symbol,SYMBOL_VOLUME_STEP);
      if(balance<=0.0 || tickValue<=0.0 || tickSize<=0.0 || volMin<=0.0 || volStep<=0.0)
      {why="account or symbol contract metadata unavailable";return false;}
      riskMoney=balance*riskPercent/100.0;
      double oneLotRisk=MathAbs(entry-stop)/tickSize*tickValue;
      if(oneLotRisk<=0.0){why="cannot calculate one-lot stop risk";return false;}
      double raw=riskMoney/oneLotRisk;
      int precision=2;
      if(volStep<0.01)precision=3;
      if(volStep<0.001)precision=4;
      lots=NormalizeDouble(MathFloor(raw/volStep)*volStep,precision);
      if(lots<volMin){why="risk-sized volume below symbol minimum";lots=0.0;return false;}
      if(lots>volMax)lots=volMax;
      if(lots>m_cfg.max_total_exposure_lots)lots=m_cfg.max_total_exposure_lots;
      lots=NormalizeDouble(MathFloor(lots/volStep)*volStep,precision);
      if(lots<volMin){why="volume cap below symbol minimum";lots=0.0;return false;}
      return true;
   }

   bool ValidateAccount(const SQSMCAccountState &a,string &why) const
   {
      why="";
      if(a.balance<=0.0 || a.equity<=0.0){why="invalid account balance/equity";return false;}
      if(a.dailyLossPct>=m_cfg.max_daily_loss_pct){why="daily loss limit reached";return false;}
      if(a.drawdownPct>=m_cfg.max_drawdown_pct){why="equity high-water drawdown limit reached";return false;}
      if(a.openPositions>=m_cfg.max_positions){why="position count limit reached";return false;}
      if(a.exposureLots>=m_cfg.max_total_exposure_lots){why="exposure limit reached";return false;}
      if(a.freeMargin<=0.0){why="no free margin";return false;}
      return true;
   }
};
#endif // QSMC_RISKMANAGER_MQH
