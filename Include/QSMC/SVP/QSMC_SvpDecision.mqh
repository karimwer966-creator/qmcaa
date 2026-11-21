//+------------------------------------------------------------------+
//||                                             QSMC_SvpDecision.mqh |
//|  Value-area permission model: where is price relative to value, and |
//|  does that permit longs, shorts or neither?                         |
//|                                                                     |
//|  SPEC NOTE: these are conservative, documented reference rules:      |
//|    above VAH  -> longs favoured, shorts discouraged                  |
//|    below VAL  -> shorts favoured, longs discouraged                  |
//|    inside VA  -> both permitted at reduced score                    |
//|  They are not presented as an official QSMC specification.           |
//+------------------------------------------------------------------+
#ifndef QSMC_SVPDECISION_MQH
#define QSMC_SVPDECISION_MQH

#include "../Core/QSMC_Types.mqh"
#include "QSMC_SvpCore.mqh"

struct SQSMCValueDecision
{
   bool            ready;
   bool            longPermitted;
   bool            shortPermitted;
   ENUM_QSMC_BIAS  bias;
   double          score;        // 0..1 conviction
   double          pocDistance;  // signed distance from POC (price units)
   string          reason;

   void Reset()
   {
      ready          = false;
      longPermitted  = false;
      shortPermitted = false;
      bias           = QSMC_BIAS_NEUTRAL;
      score          = 0.0;
      pocDistance    = 0.0;
      reason         = "";
   }
};

class CQSMCSvpDecision
{
public:
   static bool Evaluate(const CQSMCSvpCore &core, const double price,
                        SQSMCValueDecision &out)
   {
      out.Reset();
      if(!core.IsReady() || price <= 0.0)
      {
         out.reason = "value model unavailable";
         return false;
      }

      out.ready       = true;
      out.pocDistance = price - core.Poc();

      if(core.IsAboveValue(price))
      {
         out.bias           = QSMC_BIAS_BULLISH;
         out.longPermitted  = true;
         out.shortPermitted = false;
         out.score          = 0.70;
         out.reason         = "price above value area (acceptance above value)";
      }
      else if(core.IsBelowValue(price))
      {
         out.bias           = QSMC_BIAS_BEARISH;
         out.longPermitted  = false;
         out.shortPermitted = true;
         out.score          = 0.70;
         out.reason         = "price below value area (acceptance below value)";
      }
      else
      {
         out.bias           = QSMC_BIAS_NEUTRAL;
         out.longPermitted  = true;
         out.shortPermitted = true;
         out.score          = 0.40;
         out.reason         = "price inside value area (rotational context)";
      }

      //--- POC proximity dampens conviction: the market is at fair value
      double binSize = MathMax(core.BinSize(), QSMC_EPSILON);
      if(MathAbs(out.pocDistance) <= binSize * 1.5)
      {
         out.score -= 0.10;
         if(out.score < 0.0) out.score = 0.0;
         out.reason += "; at POC";
      }

      return true;
   }

   static string Describe(const SQSMCValueDecision &d)
   {
      if(!d.ready) return "value: " + d.reason;
      return StringFormat("value %s long=%s short=%s score=%.2f",
                          QSMC_BiasToString(d.bias),
                          (d.longPermitted ? "yes" : "no"),
                          (d.shortPermitted ? "yes" : "no"),
                          d.score);
   }
};

#endif // QSMC_SVPDECISION_MQH
