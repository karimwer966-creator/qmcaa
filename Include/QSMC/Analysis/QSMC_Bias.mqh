//+------------------------------------------------------------------+
//|                                                     QSMC_Bias.mqh |
//|  Directional bias from three independent, auditable components:     |
//|    1. exec EMA fast/slow relation                                   |
//|    2. HTF close vs HTF EMA                                          |
//|    3. swing sequence (higher highs + higher lows vs the inverse)    |
//|                                                                     |
//|  SPEC NOTE: the weights below are reference heuristics chosen for    |
//|  transparency/testability.  They are NOT claimed to be an official   |
//|  QSMC specification; replace Compute() to change the model.          |
//+------------------------------------------------------------------+
#ifndef QSMC_BIAS_MQH
#define QSMC_BIAS_MQH

#include "../Core/QSMC_Types.mqh"
#include "../Data/QSMC_MarketSnapshot.mqh"
#include "QSMC_Structure.mqh"

struct SQSMCBiasResult
{
   ENUM_QSMC_BIAS bias;
   double         score;        // -1..+1
   double         emaFast;
   double         emaSlow;
   double         htfEma;
   double         htfClose;
   int            higherHighs;
   int            higherLows;
   double         confidence;   // 0..1 (|score| normalised)
   string         reason;

   void Reset()
   {
      bias        = QSMC_BIAS_NEUTRAL;
      score       = 0.0;
      emaFast     = 0.0;
      emaSlow     = 0.0;
      htfEma      = 0.0;
      htfClose    = 0.0;
      higherHighs = 0;
      higherLows  = 0;
      confidence  = 0.0;
      reason      = "";
   }
};

class CQSMCBias
{
public:
   static bool Compute(const CQSMCMarketSnapshot &snap,
                       const CQSMCStructure &structure,
                       SQSMCBiasResult &out)
   {
      out.Reset();

      int idx = snap.NewestIndex();
      double emaFast = snap.Ema(QSMC_SNAP_EXEC, 20, idx);
      double emaSlow = snap.Ema(QSMC_SNAP_EXEC, 50, idx);
      double htfEma  = snap.Ema(QSMC_SNAP_HTF, 50, snap.NewestIndex());
      double htfClose= snap.Close(QSMC_SNAP_HTF, snap.NewestIndex());

      if(emaFast <= 0.0 || emaSlow <= 0.0 || htfEma <= 0.0 || htfClose <= 0.0)
      {
         out.reason = "bias: insufficient data for EMA components";
         return false;
      }

      out.emaFast  = emaFast;
      out.emaSlow  = emaSlow;
      out.htfEma   = htfEma;
      out.htfClose = htfClose;

      double score = 0.0;

      //--- component 1: exec trend (weight 0.40) ----------------------
      double sep = (emaFast - emaSlow) / MathMax(emaSlow, QSMC_EPSILON);
      if(sep > 0.0002)      score += 0.40;
      else if(sep < -0.0002) score -= 0.40;

      //--- component 2: HTF context (weight 0.30) ---------------------
      double htfSep = (htfClose - htfEma) / MathMax(htfEma, QSMC_EPSILON);
      if(htfSep > 0.0002)      score += 0.30;
      else if(htfSep < -0.0002) score -= 0.30;

      //--- component 3: swing sequence (weight up to 0.30) ------------
      double h1 = 0.0, h2 = 0.0, l1 = 0.0, l2 = 0.0;
      if(structure.LastTwoHighs(h1, h2))
      {
         if(h1 > h2 + QSMC_EPSILON) { score += 0.15; out.higherHighs = 1; }
         else if(h1 < h2 - QSMC_EPSILON) { score -= 0.15; }
      }
      if(structure.LastTwoLows(l1, l2))
      {
         if(l1 > l2 + QSMC_EPSILON) { score += 0.15; out.higherLows = 1; }
         else if(l1 < l2 - QSMC_EPSILON) { score -= 0.15; }
      }

      if(score > 1.0)  score = 1.0;
      if(score < -1.0) score = -1.0;

      out.score      = score;
      out.confidence = MathMin(1.0, MathAbs(score) / 0.7);

      if(score >= 0.20)       out.bias = QSMC_BIAS_BULLISH;
      else if(score <= -0.20) out.bias = QSMC_BIAS_BEARISH;
      else                    out.bias = QSMC_BIAS_NEUTRAL;

      out.reason = StringFormat("ema %.5f/%.5f htf %.5f/%.5f swings HH=%d HL=%d score=%.2f",
                                emaFast, emaSlow, htfClose, htfEma,
                                out.higherHighs, out.higherLows, score);
      return true;
   }

   static string Describe(const SQSMCBiasResult &r)
   {
      return QSMC_BiasToString(r.bias) + " (" + r.reason + ")";
   }
};

#endif // QSMC_BIAS_MQH
