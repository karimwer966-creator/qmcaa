//+------------------------------------------------------------------+
//|                                          QSMC_SvpVolumeProfile.mqh |
//|  Read-only interpretation layer over CQSMCSvpCore: value area stats, |
//|  price location and profile shape.  Keeps all derived presentation   |
//|  math in one place.                                                  |
//+------------------------------------------------------------------+
#ifndef QSMC_SVPVOLUMEPROFILE_MQH
#define QSMC_SVPVOLUMEPROFILE_MQH

#include "../Core/QSMC_Types.mqh"
#include "QSMC_SvpCore.mqh"

struct SQSMCValueStats
{
   bool            ready;
   double          poc;
   double          vah;
   double          val;
   double          width;        // absolute VAH-VAL
   double          widthPct;     // width / price * 100
   double          position;     // 0..1 inside value area
   int             hvnCount;
   int             lvnCount;
   ENUM_QSMC_BIAS  priceBias;
   string          shape;
   string          reason;

   void Reset()
   {
      ready     = false;
      poc       = 0.0;
      vah       = 0.0;
      val       = 0.0;
      width     = 0.0;
      widthPct  = 0.0;
      position  = 0.5;
      hvnCount  = 0;
      lvnCount  = 0;
      priceBias = QSMC_BIAS_NEUTRAL;
      shape     = "";
      reason    = "";
   }
};

class CQSMCSvpVolumeProfile
{
public:
   static bool Summarize(const CQSMCSvpCore &core, const double price,
                         SQSMCValueStats &out)
   {
      out.Reset();
      if(!core.IsReady() || price <= 0.0)
      {
         out.reason = "profile not ready";
         return false;
      }

      out.ready    = true;
      out.poc      = core.Poc();
      out.vah      = core.Vah();
      out.val      = core.Val();
      out.width    = MathMax(0.0, out.vah - out.val);
      out.widthPct = (price > QSMC_EPSILON ? out.width / price * 100.0 : 0.0);
      out.position = core.ValuePosition(price);

      int hvn = 0, lvn = 0;
      SQSMCProfileBin bin;
      for(int b = 0; b < core.BinCount(); b++)
      {
         if(!core.GetBin(b, bin)) continue;
         if(bin.hvn) hvn++;
         if(bin.lvn) lvn++;
      }
      out.hvnCount = hvn;
      out.lvnCount = lvn;

      if(core.IsAboveValue(price))      out.priceBias = QSMC_BIAS_BULLISH;
      else if(core.IsBelowValue(price)) out.priceBias = QSMC_BIAS_BEARISH;
      else                              out.priceBias = QSMC_BIAS_NEUTRAL;

      out.shape  = DescribeShape(core, price);
      out.reason = StringFormat("price %s value area (pos %.2f, width %.2f%%)",
                                (out.priceBias == QSMC_BIAS_BULLISH ? "above" :
                                 out.priceBias == QSMC_BIAS_BEARISH ? "below" : "inside"),
                                out.position, out.widthPct);
      return true;
   }

   // Coarse, human readable classification of the profile shape.
   static string DescribeShape(const CQSMCSvpCore &core, const double price)
   {
      if(!core.IsReady()) return "unknown";

      double width = MathMax(core.Vah() - core.Val(), QSMC_EPSILON);
      double total = MathMax(core.ProfileHigh() - core.ProfileLow(), QSMC_EPSILON);
      double share = width / total;

      if(share > 0.80) return "flat / distribution";
      if(share < 0.35) return "trending / elongated";

      double pocPos = (core.Poc() - core.ProfileLow()) / total;
      if(pocPos > 0.65) return "upper-skewed";
      if(pocPos < 0.35) return "lower-skewed";
      return "balanced";
   }

   static string Describe(const SQSMCValueStats &s)
   {
      if(!s.ready) return "value: not ready";
      return StringFormat("value poc=%.5f vah=%.5f val=%.5f pos=%.2f shape=%s",
                          s.poc, s.vah, s.val, s.position, s.shape);
   }
};

#endif // QSMC_SVPVOLUMEPROFILE_MQH
