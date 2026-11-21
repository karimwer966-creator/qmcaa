//+------------------------------------------------------------------+
//|                                         QSMC_CandlePatterns.mqh |
//|  Deterministic, hand-computable candle geometry.  No indicator      |
//|  handles, no chart objects, no hidden state.                        |
//|  All indices are series indices (0 = newest bar).                   |
//+------------------------------------------------------------------+
#ifndef QSMC_CANDLEPATTERNS_MQH
#define QSMC_CANDLEPATTERNS_MQH

#include "../Core/QSMC_Types.mqh"
#include "../Data/QSMC_MarketSnapshot.mqh"

enum ENUM_QSMC_PATTERN
{
   QSMC_PATTERN_NONE = 0,
   QSMC_PATTERN_BULL_ENGULF,
   QSMC_PATTERN_BEAR_ENGULF,
   QSMC_PATTERN_BULL_PIN,
   QSMC_PATTERN_BEAR_PIN,
   QSMC_PATTERN_INSIDE,
   QSMC_PATTERN_DOJI,
   QSMC_PATTERN_DISPLACEMENT
};

class CQSMCCandlePatterns
{
public:
   static double Range(const CQSMCMarketSnapshot &snap, const int slot, const int i)
   {
      return (snap.High(slot, i) - snap.Low(slot, i));
   }

   static double Body(const CQSMCMarketSnapshot &snap, const int slot, const int i)
   {
      return MathAbs(snap.Close(slot, i) - snap.Open(slot, i));
   }

   static bool IsBullish(const CQSMCMarketSnapshot &snap, const int slot, const int i)
   {
      return (snap.Close(slot, i) > snap.Open(slot, i));
   }

   static bool IsBearish(const CQSMCMarketSnapshot &snap, const int slot, const int i)
   {
      return (snap.Close(slot, i) < snap.Open(slot, i));
   }

   // body / range; 0 when the bar has no range (flat/open==high==low).
   static double BodyRatio(const CQSMCMarketSnapshot &snap, const int slot, const int i)
   {
      double range = Range(snap, slot, i);
      if(range <= QSMC_EPSILON) return 0.0;
      return Body(snap, slot, i) / range;
   }

   static bool IsDoji(const CQSMCMarketSnapshot &snap, const int slot, const int i,
                      const double maxBodyRatio = 0.10)
   {
      return (BodyRatio(snap, slot, i) <= maxBodyRatio);
   }

   static bool IsInsideBar(const CQSMCMarketSnapshot &snap, const int slot, const int i)
   {
      if(i + 1 >= snap.BarCount(slot)) return false;
      return (snap.High(slot, i) <= snap.High(slot, i + 1) &&
              snap.Low(slot, i)  >= snap.Low(slot, i + 1));
   }

   static bool IsBullishEngulfing(const CQSMCMarketSnapshot &snap, const int slot, const int i)
   {
      if(i + 1 >= snap.BarCount(slot)) return false;
      if(!IsBullish(snap, slot, i) || !IsBearish(snap, slot, i + 1)) return false;
      return (snap.Close(slot, i) >= snap.Open(slot, i + 1) &&
              snap.Open(slot, i)  <= snap.Close(slot, i + 1) &&
              Body(snap, slot, i) > Body(snap, slot, i + 1));
   }

   static bool IsBearishEngulfing(const CQSMCMarketSnapshot &snap, const int slot, const int i)
   {
      if(i + 1 >= snap.BarCount(slot)) return false;
      if(!IsBearish(snap, slot, i) || !IsBullish(snap, slot, i + 1)) return false;
      return (snap.Close(slot, i) <= snap.Open(slot, i + 1) &&
              snap.Open(slot, i)  >= snap.Close(slot, i + 1) &&
              Body(snap, slot, i) > Body(snap, slot, i + 1));
   }

   // Long lower wick, small body in the upper third.
   static bool IsBullishPin(const CQSMCMarketSnapshot &snap, const int slot, const int i,
                            const double wickToBody = 2.0)
   {
      double range = Range(snap, slot, i);
      double body  = Body(snap, slot, i);
      if(range <= QSMC_EPSILON || body <= QSMC_EPSILON) return false;

      double lower = MathMin(snap.Open(slot, i), snap.Close(slot, i)) - snap.Low(slot, i);
      double upper = snap.High(slot, i) - MathMax(snap.Open(slot, i), snap.Close(slot, i));

      return (lower >= body * wickToBody && upper <= body * 1.2 &&
              (snap.Close(slot, i) - snap.Low(slot, i)) > range * 0.55);
   }

   // Long upper wick, small body in the lower third.
   static bool IsBearishPin(const CQSMCMarketSnapshot &snap, const int slot, const int i,
                            const double wickToBody = 2.0)
   {
      double range = Range(snap, slot, i);
      double body  = Body(snap, slot, i);
      if(range <= QSMC_EPSILON || body <= QSMC_EPSILON) return false;

      double upper = snap.High(slot, i) - MathMax(snap.Open(slot, i), snap.Close(slot, i));
      double lower = MathMin(snap.Open(slot, i), snap.Close(slot, i)) - snap.Low(slot, i);

      return (upper >= body * wickToBody && lower <= body * 1.2 &&
              (snap.High(slot, i) - snap.Close(slot, i)) > range * 0.55);
   }

   // Momentum bar: body at least `mult` x ATR, in the given direction.
   static bool IsDisplacement(const CQSMCMarketSnapshot &snap, const int slot, const int i,
                              const double atr, const double mult,
                              const int direction)
   {
      if(atr <= QSMC_EPSILON) return false;
      double body = Body(snap, slot, i);
      if(body < atr * mult) return false;
      if(direction > 0) return IsBullish(snap, slot, i);
      if(direction < 0) return IsBearish(snap, slot, i);
      return true;
   }

   static ENUM_QSMC_PATTERN Detect(const CQSMCMarketSnapshot &snap, const int slot,
                                   const int i, const double atr)
   {
      if(IsBullishEngulfing(snap, slot, i)) return QSMC_PATTERN_BULL_ENGULF;
      if(IsBearishEngulfing(snap, slot, i)) return QSMC_PATTERN_BEAR_ENGULF;
      if(IsBullishPin(snap, slot, i))       return QSMC_PATTERN_BULL_PIN;
      if(IsBearishPin(snap, slot, i))       return QSMC_PATTERN_BEAR_PIN;
      if(IsInsideBar(snap, slot, i))        return QSMC_PATTERN_INSIDE;
      if(IsDoji(snap, slot, i))             return QSMC_PATTERN_DOJI;
      if(IsDisplacement(snap, slot, i, atr, 1.2, 0)) return QSMC_PATTERN_DISPLACEMENT;
      return QSMC_PATTERN_NONE;
   }

   static string Name(const ENUM_QSMC_PATTERN p)
   {
      switch(p)
      {
         case QSMC_PATTERN_NONE:         return "none";
         case QSMC_PATTERN_BULL_ENGULF:  return "bullish engulfing";
         case QSMC_PATTERN_BEAR_ENGULF:  return "bearish engulfing";
         case QSMC_PATTERN_BULL_PIN:     return "bullish pin";
         case QSMC_PATTERN_BEAR_PIN:     return "bearish pin";
         case QSMC_PATTERN_INSIDE:       return "inside bar";
         case QSMC_PATTERN_DOJI:         return "doji";
         case QSMC_PATTERN_DISPLACEMENT: return "displacement";
      }
      return "unknown";
   }
};

#endif // QSMC_CANDLEPATTERNS_MQH
