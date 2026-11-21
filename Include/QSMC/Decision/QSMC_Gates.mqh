//+------------------------------------------------------------------+
//|                                                    QSMC_Gates.mqh |
//|  Fail-closed gates applied before candidate arbitration.            |
//+------------------------------------------------------------------+
#ifndef QSMC_GATES_MQH
#define QSMC_GATES_MQH
#include "../Core/QSMC_Types.mqh"
#include "../Data/QSMC_MarketSnapshot.mqh"
#include "QSMC_UnifiedDecision.mqh"

class CQSMCGates
{
public:
   static bool ValidateSnapshot(const CQSMCMarketSnapshot &snap,
                                SQSMCUnifiedDecision &decision)
   {
      bool ok = true;
      if(!snap.IsUsable())
      {
         decision.Reject(QSMC_ERR_DATA_NOT_READY,"data","snapshot missing bars or quote");
         ok = false;
      }
      if(snap.Bid() <= 0.0 || snap.Ask() <= 0.0 || snap.Ask() < snap.Bid())
      {
         decision.Reject(QSMC_ERR_DATA_INVALID,"quote","invalid bid/ask quote");
         ok = false;
      }
      if(snap.BarTime(QSMC_SNAP_EXEC,snap.NewestIndex()) <= 0)
      {
         decision.Reject(QSMC_ERR_DATA_NOT_READY,"data","closed execution bar unavailable");
         ok = false;
      }
      return ok;
   }

   static bool ValidateConfidence(const double confidence, const double minimum,
                                  SQSMCUnifiedDecision &decision)
   {
      if(confidence < minimum)
      {
         decision.Reject(QSMC_ERR_NO_DECISION,"confidence",
                         StringFormat("confidence %.2f below threshold %.2f",confidence,minimum));
         return false;
      }
      return true;
   }
};
#endif // QSMC_GATES_MQH
