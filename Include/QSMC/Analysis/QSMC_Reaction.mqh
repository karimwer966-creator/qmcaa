//+------------------------------------------------------------------+
//|                                                 QSMC_Reaction.mqh |
//|  Price reaction at a zone: did the market actually reject the       |
//|  level with a bullish/bearish candle, or is it just nearby?         |
//|  Returns an explicit direction and a bounded score.                 |
//+------------------------------------------------------------------+
#ifndef QSMC_REACTION_MQH
#define QSMC_REACTION_MQH

#include "../Core/QSMC_Types.mqh"
#include "../Data/QSMC_MarketSnapshot.mqh"
#include "QSMC_Zones.mqh"
#include "QSMC_CandlePatterns.mqh"

struct SQSMCReactionResult
{
   bool                 bullish;
   bool                 bearish;
   ENUM_QSMC_DIRECTION  direction;
   double               score;      // 0..1
   ENUM_QSMC_PATTERN    pattern;
   int                  barsAgo;
   bool                 touched;
   string               reason;

   void Reset()
   {
      bullish   = false;
      bearish   = false;
      direction = QSMC_DIR_NONE;
      score     = 0.0;
      pattern   = QSMC_PATTERN_NONE;
      barsAgo   = -1;
      touched   = false;
      reason    = "";
   }
};

class CQSMCReaction
{
public:
   //+---------------------------------------------------------------+
   //| Evaluate reaction at `zone` using the newest closed candles.    |
   //+---------------------------------------------------------------+
   static bool Evaluate(const CQSMCMarketSnapshot &snap,
                        const int slot,
                        const SQSMCZone &zone,
                        SQSMCReactionResult &out)
   {
      out.Reset();

      const int newest = snap.NewestIndex();
      if(newest + 3 >= snap.BarCount(slot)) return false;

      double atr = snap.Atr(slot, 14, newest);
      if(atr <= 0.0) return false;

      bool demandLike = zone.IsDemandLike();
      double bestScore = 0.0;

      //--- scan the last three closed bars for a rejection ------------
      for(int i = newest; i < newest + 3; i++)
      {
         double lo = snap.Low(slot, i);
         double hi = snap.High(slot, i);
         bool touched = (lo <= zone.top + QSMC_EPSILON && hi >= zone.bottom - QSMC_EPSILON);
         if(!touched) continue;

         out.touched = true;
         double score = 0.0;
         ENUM_QSMC_PATTERN pattern = QSMC_PATTERN_NONE;

         if(demandLike)
         {
            if(CQSMCCandlePatterns::IsBullishEngulfing(snap, slot, i))
            {
               pattern = QSMC_PATTERN_BULL_ENGULF;
               score   = 0.55;
            }
            else if(CQSMCCandlePatterns::IsBullishPin(snap, slot, i))
            {
               pattern = QSMC_PATTERN_BULL_PIN;
               score   = 0.50;
            }
            else if(CQSMCCandlePatterns::IsBullish(snap, slot, i))
            {
               score = 0.30;
            }

            // close back above the zone mid adds conviction
            if(snap.Close(slot, i) > zone.Mid()) score += 0.15;
         }
         else
         {
            if(CQSMCCandlePatterns::IsBearishEngulfing(snap, slot, i))
            {
               pattern = QSMC_PATTERN_BEAR_ENGULF;
               score   = 0.55;
            }
            else if(CQSMCCandlePatterns::IsBearishPin(snap, slot, i))
            {
               pattern = QSMC_PATTERN_BEAR_PIN;
               score   = 0.50;
            }
            else if(CQSMCCandlePatterns::IsBearish(snap, slot, i))
            {
               score = 0.30;
            }

            if(snap.Close(slot, i) < zone.Mid()) score += 0.15;
         }

         if(score > bestScore)
         {
            bestScore = score;
            out.pattern = pattern;
            out.barsAgo = i - newest;
         }
      }

      if(!out.touched)
      {
         out.reason = "price has not interacted with the zone";
         return false;
      }

      if(bestScore >= 0.45)
      {
         out.direction = (demandLike ? QSMC_DIR_BUY : QSMC_DIR_SELL);
         out.bullish   = demandLike;
         out.bearish   = !demandLike;
         out.score     = MathMin(1.0, bestScore / 0.70);
         out.reason    = StringFormat("%s at %s zone (%d bars ago, raw %.2f)",
                                      CQSMCCandlePatterns::Name(out.pattern),
                                      zone.Name(), out.barsAgo, bestScore);
         return true;
      }

      out.reason = "zone touched but no rejection pattern";
      return false;
   }
};

#endif // QSMC_REACTION_MQH
