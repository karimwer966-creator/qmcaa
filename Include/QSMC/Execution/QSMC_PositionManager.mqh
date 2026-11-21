//+------------------------------------------------------------------+
//|                                          QSMC_PositionManager.mqh |
//|  Read-only ownership-aware position reconciliation. No position    |
//|  close/modify operation is implemented.                             |
//+------------------------------------------------------------------+
#ifndef QSMC_POSITIONMANAGER_MQH
#define QSMC_POSITIONMANAGER_MQH
#include "../Core/QSMC_Types.mqh"

struct SQSMCPositionSummary
{
   int count;
   double lots;
   double floatingProfit;
   bool ownershipCertain;
   void Reset(){count=0;lots=0.0;floatingProfit=0.0;ownershipCertain=true;}
};
class CQSMCPositionManager
{
public:
   bool Reconcile(const string symbol,const ulong magic,SQSMCPositionSummary &out) const
   {
      out.Reset();
      if(magic==0 || StringLen(symbol)==0){out.ownershipCertain=false;return false;}
      for(int i=PositionsTotal()-1;i>=0;i--)
      {
         ulong ticket=PositionGetTicket(i);
         if(ticket==0 || !PositionSelectByTicket(ticket))continue;
         if(PositionGetString(POSITION_SYMBOL)!=symbol)continue;
         if((ulong)PositionGetInteger(POSITION_MAGIC)!=magic)continue;
         out.count++;
         out.lots+=PositionGetDouble(POSITION_VOLUME);
         out.floatingProfit+=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);
      }
      return true;
   }
};
#endif // QSMC_POSITIONMANAGER_MQH
