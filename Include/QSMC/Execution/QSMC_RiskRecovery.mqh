// Bounded replay of owned hedging position lifecycles. No pending UID is cleared.
#ifndef QSMC_RISKRECOVERY_MQH
#define QSMC_RISKRECOVERY_MQH
#include "../Infrastructure/QSMC_StateStore.mqh"
struct SQSMCRecoveredRisk
{
   int closedToday,lossStreak,slToday,tpToday;
   double realizedToday;
   datetime lastEntry;
   void Reset(){closedToday=0;lossStreak=0;slToday=0;tpToday=0;realizedToday=0.0;lastEntry=0;}
};
class CQSMCRiskRecovery
{
public:
   static bool Replay(const string symbol,const ulong magic,const datetime enrollment,
                      const datetime day,SQSMCRecoveredRisk &out,string &why)
   {
      out.Reset();why="";datetime now=TimeCurrent();
      if(enrollment<=0 || enrollment>now || day<=0 || !HistorySelect(0,now))
      {why="risk history/enrollment unavailable";return false;}
      int total=HistoryDealsTotal();
      if(total>100000){why="history replay bound exceeded";return false;}
      ulong ids[QSMC_MAX_JOURNAL],lastDeal[QSMC_MAX_JOURNAL];
      double net[QSMC_MAX_JOURNAL],volume[QSMC_MAX_JOURNAL];
      datetime closed[QSMC_MAX_JOURNAL];
      long exitReason[QSMC_MAX_JOURNAL];bool seenEntry[QSMC_MAX_JOURNAL];
      int count=0;long previousTime=0;
      for(int i=0;i<total;i++)
      {
         ulong ticket=HistoryDealGetTicket(i);long owner=0,type=0,entry=0,position=0,time=0,reason=0;string sym="";
         double profit=0.0,swap=0.0,fee=0.0,commission=0.0,lots=0.0;
         if(ticket==0 || !HistoryDealGetInteger(ticket,DEAL_TIME,time) || !HistoryDealGetInteger(ticket,DEAL_TYPE,type))
         {why="deal type/time unavailable";return false;}
         if(time<=0 || time>(long)now || time<previousTime){why="history time invalid/not chronological";return false;}
         previousTime=time;
         if((datetime)time>=enrollment && type!=DEAL_TYPE_BUY && type!=DEAL_TYPE_SELL)
         {why="account cash-flow/nontrade deal since enrollment requires review";return false;}
         if(!HistoryDealGetInteger(ticket,DEAL_MAGIC,owner) || !HistoryDealGetString(ticket,DEAL_SYMBOL,sym))
         {why="deal ownership unavailable";return false;}
         if((ulong)owner!=magic || sym!=symbol || (type!=DEAL_TYPE_BUY && type!=DEAL_TYPE_SELL))continue;
         if(!HistoryDealGetInteger(ticket,DEAL_ENTRY,entry) || !HistoryDealGetInteger(ticket,DEAL_POSITION_ID,position) ||
            !HistoryDealGetInteger(ticket,DEAL_REASON,reason) || position<=0 ||
            !HistoryDealGetDouble(ticket,DEAL_VOLUME,lots) || !HistoryDealGetDouble(ticket,DEAL_PROFIT,profit) ||
            !HistoryDealGetDouble(ticket,DEAL_SWAP,swap) || !HistoryDealGetDouble(ticket,DEAL_FEE,fee) ||
            !HistoryDealGetDouble(ticket,DEAL_COMMISSION,commission) || !MathIsValidNumber(lots) || lots<=0 ||
            !MathIsValidNumber(profit) || !MathIsValidNumber(swap) || !MathIsValidNumber(fee) || !MathIsValidNumber(commission))
         {why="owned deal invalid/incomplete";return false;}
         double amount=profit+swap+fee+commission;
         if(time>=(long)day)out.realizedToday+=amount;
         int p=-1;for(int j=0;j<count;j++)if(ids[j]==(ulong)position){p=j;break;}
         if(p<0)
         {
            if(count>=QSMC_MAX_JOURNAL){why="lifecycle replay capacity exceeded";return false;}
            p=count++;ids[p]=(ulong)position;net[p]=0;volume[p]=0;closed[p]=0;lastDeal[p]=0;exitReason[p]=0;seenEntry[p]=false;
         }
         net[p]+=amount;
         if(entry==DEAL_ENTRY_IN)
         {
            if(closed[p]>0){why="position identifier reused after closure";return false;}
            seenEntry[p]=true;volume[p]+=lots;
            if((datetime)time>out.lastEntry)out.lastEntry=(datetime)time;
         }
         else if(entry==DEAL_ENTRY_OUT || entry==DEAL_ENTRY_OUT_BY)
         {
            if(!seenEntry[p] || lots>volume[p]+1e-8){why="missing entry history/overclosed lifecycle";return false;}
            volume[p]-=lots;
            if(MathAbs(volume[p])<=1e-8){volume[p]=0;closed[p]=(datetime)time;lastDeal[p]=ticket;exitReason[p]=reason;}
         }
         else {why="unsupported reversal/unknown entry mode";return false;}
         if(!MathIsValidNumber(net[p]) || !MathIsValidNumber(volume[p]))return false;
      }
      if(HistoryDealsTotal()!=total || !MathIsValidNumber(out.realizedToday))return false;
      // Remaining lifecycle volumes must match owned open positions by identifier.
      int positions=PositionsTotal(),matched=0,expected=0;
      for(int p=0;p<count;p++)if(volume[p]>0)expected++;
      for(int i=0;i<positions;i++)
      {
         ulong ticket=PositionGetTicket(i);long owner=0,identifier=0;string sym="";double lots=0;
         if(ticket==0 || !PositionGetInteger(POSITION_MAGIC,owner) || !PositionGetString(POSITION_SYMBOL,sym))return false;
         if((ulong)owner!=magic || sym!=symbol)continue;
         if(!PositionGetInteger(POSITION_IDENTIFIER,identifier) || !PositionGetDouble(POSITION_VOLUME,lots))return false;
         int found=-1;for(int p=0;p<count;p++)if(ids[p]==(ulong)identifier){found=p;break;}
         if(found<0 || !MathIsValidNumber(lots) || MathAbs(volume[found]-lots)>1e-8)
         {why="open position does not match replayed lifecycle";return false;}
         matched++;
      }
      if(matched!=expected || positions!=PositionsTotal())return false;
      // Sort completed positions by final exit time/ticket, not deal count.
      // Partial exits contribute P/L but do not independently increment streaks.
      for(int n=0;n<count;n++)
      {
         int next=-1;
         for(int p=0;p<count;p++)if(closed[p]>0 && (next<0 || closed[p]<closed[next] ||
            (closed[p]==closed[next] && lastDeal[p]<lastDeal[next])))next=p;
         if(next<0)break;
         if(net[next]<0)out.lossStreak++;else out.lossStreak=0;
         if(closed[next]>=day)
         {
            out.closedToday++;
            if(exitReason[next]==DEAL_REASON_SL)out.slToday++;
            if(exitReason[next]==DEAL_REASON_TP)out.tpToday++;
         }
         closed[next]=0;
      }
      return true;
   }
};
#endif // QSMC_RISKRECOVERY_MQH
