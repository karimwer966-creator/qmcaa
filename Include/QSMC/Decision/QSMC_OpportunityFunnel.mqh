//+------------------------------------------------------------------+
//|                                      QSMC_OpportunityFunnel.mqh |
//|  Maps completed analysis evidence into explicit candidates.          |
//|  These reference weights are a replaceable heuristic, not a claimed  |
//|  proprietary QSMC setup definition.                                  |
//+------------------------------------------------------------------+
#ifndef QSMC_OPPORTUNITYFUNNEL_MQH
#define QSMC_OPPORTUNITYFUNNEL_MQH
#include "../Analysis/QSMC_Scanners.mqh"
#include "QSMC_SignalRegistry.mqh"

class CQSMCOpportunityFunnel
{
public:
   static int Build(const SQSMCScanContext &c,CQSMCSignalRegistry &registry)
   {
      registry.Reset();
      if(!c.valid) return 0; // absent data is never a signal

      // Confirmed zone reaction has highest evidential weight.
      if(c.reactionOk && c.reactionDir!=QSMC_DIR_NONE)
      {
         double score=MathMin(1.0,0.45+0.30*c.reactionScore+0.15*c.zoneScore);
         registry.Add(c.reactionDir,score,"zone-reaction",c.reactionNote);
      }

      // Displacement break is independent evidence, not auto-trading.
      if(c.breakDetected && c.breakDir!=QSMC_DIR_NONE)
      {
         double score=MathMin(1.0,0.40+MathMin(0.30,c.breakDisplacement*0.12)+
                             (c.bias==QSMC_BIAS_NEUTRAL?0.0:0.15));
         registry.Add(c.breakDir,score,"structure-break",
                      StringFormat("%s level %.5f displacement %.2f ATR",
                                   QSMC_DirectionToString(c.breakDir),c.breakLevel,c.breakDisplacement));
      }

      // Value-area position is contextual only and is intentionally not
      // emitted as a candidate by itself.
      return registry.Count();
   }
};
#endif // QSMC_OPPORTUNITYFUNNEL_MQH
