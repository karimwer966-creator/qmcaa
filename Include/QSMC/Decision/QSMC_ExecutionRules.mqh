//+------------------------------------------------------------------+
//|                                          QSMC_ExecutionRules.mqh |
//|  Decision-side geometry checks only. This module cannot submit       |
//|  orders and does not claim that a strategy setup is profitable.      |
//+------------------------------------------------------------------+
#ifndef QSMC_EXECUTIONRULES_MQH
#define QSMC_EXECUTIONRULES_MQH
#include "../Core/QSMC_Config.mqh"
#include "QSMC_UnifiedDecision.mqh"

struct SQSMCTradeGeometry
{
   double entry;
   double stop;
   double target;
   double rr;
   double riskDistance;
   void Reset(){entry=0.0;stop=0.0;target=0.0;rr=0.0;riskDistance=0.0;}
};

class CQSMCExecutionRules
{
public:
   // Calculate candidate geometry using recent structure. It is only an
   // analytical proposal; centralized preflight and disabled execution
   // remain mandatory before any order could be sent.
   static bool Geometry(const ENUM_QSMC_DIRECTION direction,const double entry,
                        const double swingOpposite,const double atr,
                        const SQSMCConfig &cfg,SQSMCTradeGeometry &out,string &why)
   {
      out.Reset(); why="";
      if(direction==QSMC_DIR_NONE || entry<=0.0 || atr<=0.0)
      { why="missing direction, entry or ATR"; return false; }
      double stopDistance=MathMax(MathAbs(entry-swingOpposite),atr*cfg.sl_atr_mult);
      if(swingOpposite<=0.0) stopDistance=atr*cfg.sl_atr_mult;
      out.entry=entry;
      out.riskDistance=stopDistance;
      if(direction==QSMC_DIR_BUY)
      {
         out.stop=entry-stopDistance;
         out.target=entry+stopDistance*cfg.tp_rr;
      }
      else
      {
         out.stop=entry+stopDistance;
         out.target=entry-stopDistance*cfg.tp_rr;
      }
      out.rr=MathAbs(out.target-out.entry)/MathAbs(out.entry-out.stop);
      if(out.rr<cfg.min_rr || out.stop<=0.0 || out.target<=0.0)
      { why="proposed geometry violates configured RR/price bounds"; out.Reset(); return false; }
      return true;
   }
};
#endif // QSMC_EXECUTIONRULES_MQH
