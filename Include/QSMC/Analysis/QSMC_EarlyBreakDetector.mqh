//+------------------------------------------------------------------+
//|                                        QSMC_EarlyBreakDetector.mqh |
//|  Break-of-structure / range break with displacement confirmation.   |
//|  A break requires: close beyond a confirmed swing level AND a body   |
//|  of at least `mult` x ATR.  Wicks alone never qualify.               |
//+------------------------------------------------------------------+
#ifndef QSMC_EARLYBREAKDETECTOR_MQH
#define QSMC_EARLYBREAKDETECTOR_MQH

#include "../Core/QSMC_Types.mqh"
#include "../Data/QSMC_MarketSnapshot.mqh"
#include "QSMC_Structure.mqh"
#include "QSMC_CandlePatterns.mqh"

struct SQSMCBreakResult
{
   bool                detected;
   ENUM_QSMC_DIRECTION direction;
   double              level;
   double              displacement;   // ATR multiples
   int                 barsAgo;
   string              note;

   void Reset()
   {
      detected     = false;
      direction    = QSMC_DIR_NONE;
      level        = 0.0;
      displacement = 0.0;
      barsAgo      = -1;
      note         = "";
   }
};

class CQSMCBreakDetector
{
public:
   static bool Detect(const CQSMCMarketSnapshot &snap,
                      const CQSMCStructure &structure,
                      const int slot,
                      const double atr,
                      const double mult,
                      SQSMCBreakResult &out)
   {
      out.Reset();
      if(atr <= QSMC_EPSILON) return false;

      const int newest = snap.NewestIndex();
      double close = snap.Close(slot, newest);
      double body  = CQSMCCandlePatterns::Body(snap, slot, newest);
      if(close <= 0.0 || body <= 0.0) return false;

      double ratio = body / atr;
      if(ratio < mult) return false;

      //--- close above the most recent swing high -> bullish break -----
      double lastHigh = structure.LastSwingHigh();
      double lastLow  = structure.LastSwingLow();

      if(lastHigh > 0.0 && close > lastHigh + QSMC_EPSILON &&
         CQSMCCandlePatterns::IsBullish(snap, slot, newest))
      {
         out.detected     = true;
         out.direction    = QSMC_DIR_BUY;
         out.level        = lastHigh;
         out.displacement = ratio;
         out.barsAgo      = 0;
         out.note         = "close above last swing high with displacement";
         return true;
      }

      if(lastLow > 0.0 && close < lastLow - QSMC_EPSILON &&
         CQSMCCandlePatterns::IsBearish(snap, slot, newest))
      {
         out.detected     = true;
         out.direction    = QSMC_DIR_SELL;
         out.level        = lastLow;
         out.displacement = ratio;
         out.barsAgo      = 0;
         out.note         = "close below last swing low with displacement";
         return true;
      }

      out.note = "no confirmed break";
      return false;
   }
};

#endif // QSMC_EARLYBREAKDETECTOR_MQH
