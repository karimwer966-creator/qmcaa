// QSMC-013/014/016: read-only, replay-safe server-day broker observations.
// These are NOT authoritative risk counters until Phase 6 persistence is complete.
#ifndef QSMC_TRADERECONCILER_MQH
#define QSMC_TRADERECONCILER_MQH
#include "../Core/QSMC_Constants.mqh"
#include "../Core/QSMC_Types.mqh"

struct SQSMCBrokerObservation
{
   datetime day;
   int entryOrders;
   int entryDeals;
   int exitDeals;
   int slExitDeals;
   int tpExitDeals;
   int positions;
   int unprotectedPositions;
   double entryVolume;
   double exitVolume;
   double realizedNet;
   void Reset()
   {
      day=0;entryOrders=0;entryDeals=0;exitDeals=0;slExitDeals=0;tpExitDeals=0;
      positions=0;unprotectedPositions=0;entryVolume=0.0;exitVolume=0.0;realizedNet=0.0;
   }
};
class CQSMCTradeReconciler
{
public:
   static bool Capture(const string symbol,const ulong magic,SQSMCBrokerObservation &out,string &why)
   {
      out.Reset();why="";
      if(StringLen(symbol)==0 || magic==0){why="invalid reconciliation identity";return false;}
      if((ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE)!=ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
      {why="hedging-only reconciliation; netting ownership unsupported";return false;}
      MqlDateTime dt;
      datetime now=TimeCurrent();
      if(now<=0 || !TimeToStruct(now,dt)){why="server clock unavailable";return false;}
      dt.hour=0;dt.min=0;dt.sec=0;out.day=StructToTime(dt);
      if(!HistorySelect(out.day,now)){why="server-day history unavailable";return false;}
      ulong orders[QSMC_MAX_JOURNAL];
      int orderCount=0;
      int deals=HistoryDealsTotal();
      for(int i=0;i<deals;i++)
      {
         ulong deal=HistoryDealGetTicket(i);
         if(deal==0){why="history deal enumeration failed";return false;}
         long dealMagic=0,entry=0,type=0,reason=0,order=0;
         string dealSymbol="";
         if(!HistoryDealGetInteger(deal,DEAL_MAGIC,dealMagic) ||
            !HistoryDealGetString(deal,DEAL_SYMBOL,dealSymbol))
         {why="history ownership read failed";return false;}
         if((ulong)dealMagic!=magic || dealSymbol!=symbol)continue;
         if(!HistoryDealGetInteger(deal,DEAL_TYPE,type) ||
            !HistoryDealGetInteger(deal,DEAL_ENTRY,entry) ||
            !HistoryDealGetInteger(deal,DEAL_REASON,reason) ||
            !HistoryDealGetInteger(deal,DEAL_ORDER,order))
         {why="owned deal metadata unavailable";return false;}
         double profit=0.0,swap=0.0,commission=0.0,fee=0.0,volume=0.0;
         if(!HistoryDealGetDouble(deal,DEAL_PROFIT,profit) ||
            !HistoryDealGetDouble(deal,DEAL_SWAP,swap) ||
            !HistoryDealGetDouble(deal,DEAL_COMMISSION,commission) ||
            !HistoryDealGetDouble(deal,DEAL_FEE,fee) ||
            !HistoryDealGetDouble(deal,DEAL_VOLUME,volume) ||
            !MathIsValidNumber(profit) || !MathIsValidNumber(swap) ||
            !MathIsValidNumber(commission) || !MathIsValidNumber(fee) ||
            !MathIsValidNumber(volume) || volume<0.0)
         {why="owned deal numeric data invalid";return false;}
         out.realizedNet+=profit+swap+commission+fee;
         if(type!=DEAL_TYPE_BUY && type!=DEAL_TYPE_SELL)continue;
         if(entry==DEAL_ENTRY_INOUT)
         {why="unexpected reversal deal in hedging-only history";return false;}
         if(entry==DEAL_ENTRY_IN)
         {
            if(order<=0){why="entry deal has no order identity";return false;}
            out.entryDeals++;out.entryVolume+=volume;
            bool found=false;
            for(int j=0;j<orderCount;j++)if(orders[j]==(ulong)order){found=true;break;}
            if(!found)
            {
               if(orderCount>=QSMC_MAX_JOURNAL){why="entry order observation capacity exceeded";return false;}
               orders[orderCount++]=(ulong)order;
            }
         }
         else if(entry==DEAL_ENTRY_OUT || entry==DEAL_ENTRY_OUT_BY)
         {
            out.exitDeals++;out.exitVolume+=volume;
            if(reason==DEAL_REASON_SL)out.slExitDeals++;
            if(reason==DEAL_REASON_TP)out.tpExitDeals++;
         }
         else {why="unknown owned trade entry type";return false;}
      }
      out.entryOrders=orderCount;
      int positions=PositionsTotal();
      for(int p=0;p<positions;p++)
      {
         ulong ticket=PositionGetTicket(p);
         long positionMagic=0;string positionSymbol="";
         if(ticket==0 || !PositionSelectByTicket(ticket) ||
            !PositionGetInteger(POSITION_MAGIC,positionMagic) ||
            !PositionGetString(POSITION_SYMBOL,positionSymbol))
         {why="position ownership enumeration incomplete";return false;}
         if((ulong)positionMagic!=magic || positionSymbol!=symbol)continue;
         double sl=0.0;
         if(!PositionGetDouble(POSITION_SL,sl) || !MathIsValidNumber(sl))
         {why="owned position protection unreadable";return false;}
         out.positions++;
         if(sl<=0.0)out.unprotectedPositions++;
      }
      // Broker data can change during capture: never certify a visibly torn scan.
      if(PositionsTotal()!=positions || HistoryDealsTotal()!=deals)
      {why="broker collections changed during observation; retry required";return false;}
      if(out.unprotectedPositions>0)
      {why="owned positions without broker SL observed; operator action required";return false;}
      why="read-only observation; pending intents/risk state NOT cleared";
      return true;
   }
};
#endif // QSMC_TRADERECONCILER_MQH
