//+------------------------------------------------------------------+
//|                                      QSMC_BreakOrderBlock.mqh |
//| Secondary heuristic: confirmed BOS/CHoCH -> prior-origin zone retest.|
//| A zone is an order-block proxy from the existing swing/displacement  |
//| detector, not a canonical institutional order-block definition.      |
//+------------------------------------------------------------------+
#ifndef QSMC_BREAKORDERBLOCK_MQH
#define QSMC_BREAKORDERBLOCK_MQH
#include "../Core/QSMC_Types.mqh"
#include "../Data/QSMC_MarketSnapshot.mqh"
#include "QSMC_Structure.mqh"
#include "QSMC_Zones.mqh"
#include "QSMC_CandlePatterns.mqh"

struct SQSMCBreakOrderBlock
{
   bool ready;
   bool candidate;
   ENUM_QSMC_DIRECTION direction;
   string stage;
   string breakKind;
   double breakLevel;
   int breakShift;
   double displacementAtr;
   SQSMCZone orderBlock;
   string explanation;
   void Reset()
   {
      ready=false;candidate=false;direction=QSMC_DIR_NONE;stage="UNAVAILABLE";
      breakKind="";breakLevel=0.0;breakShift=-1;displacementAtr=0.0;
      orderBlock.Reset();explanation="";
   }
};

class CQSMCBreakOrderBlockModel
{
private:
   static int ContinuationClass(const CQSMCStructure &structure,const int breakShift,
                                const int right,const bool bullish)
   {
      double newestHigh=0.0,olderHigh=0.0,newestLow=0.0,olderLow=0.0;
      int h1Shift=2147483647,h2Shift=2147483647;
      int l1Shift=2147483647,l2Shift=2147483647;
      for(int i=0;i<structure.Count();i++)
      {
         SQSMCStructurePoint p;if(!structure.Get(i,p))continue;
         // Only use pivots already confirmed at the historical break bar.
         if(p.shift<=breakShift || p.shift-right<breakShift)continue;
         if(p.type==QSMC_SWING_HIGH)
         {
            if(p.shift<h1Shift){h2Shift=h1Shift;olderHigh=newestHigh;h1Shift=p.shift;newestHigh=p.price;}
            else if(p.shift<h2Shift){h2Shift=p.shift;olderHigh=p.price;}
         }
         else if(p.type==QSMC_SWING_LOW)
         {
            if(p.shift<l1Shift){l2Shift=l1Shift;olderLow=newestLow;l1Shift=p.shift;newestLow=p.price;}
            else if(p.shift<l2Shift){l2Shift=p.shift;olderLow=p.price;}
         }
      }
      if(h2Shift==2147483647 || l2Shift==2147483647)return -1;
      bool priorBull=(newestHigh>olderHigh+QSMC_EPSILON &&
                      newestLow>olderLow+QSMC_EPSILON);
      bool priorBear=(newestHigh<olderHigh-QSMC_EPSILON &&
                      newestLow<olderLow-QSMC_EPSILON);
      if(bullish && priorBull)return 1;
      if(bullish && priorBear)return 0;
      if(!bullish && priorBear)return 1;
      if(!bullish && priorBull)return 0;
      return -1;
   }

public:
   static bool Evaluate(const CQSMCMarketSnapshot &snap,const int slot,
                        const CQSMCStructure &structure,const CQSMCZones &zones,
                        const int right,const int lookback,
                        const double minDisplacementAtr,
                        SQSMCBreakOrderBlock &out)
   {
      out.Reset();
      int newest=snap.NewestIndex(),count=snap.BarCount(slot);
      if(structure.Count()<2 || zones.Count()==0 || count<=newest+right+3)
      {out.explanation="alternate model lacks confirmed structure/zones";return false;}
      out.ready=true;
      int maxShift=MathMin(count-2,newest+MathMin(lookback,40));

      // Series arrays: search older bars from the current closed bar outward;
      // the current bar is the later retest, never the original break.
      for(int k=newest+1;k<=maxShift;k++)
      {
         double atr=snap.Atr(slot,14,k);
         if(atr<=0.0)continue;
         double body=CQSMCCandlePatterns::Body(snap,slot,k);
         double ratio=body/atr;
         if(ratio<minDisplacementAtr)continue;
         bool bullish=CQSMCCandlePatterns::IsBullish(snap,slot,k);
         bool bearish=CQSMCCandlePatterns::IsBearish(snap,slot,k);
         if(!bullish && !bearish)continue;
         int wanted=(bullish?QSMC_SWING_HIGH:QSMC_SWING_LOW);
         double level=0.0;int nearestShift=2147483647;
         for(int p=0;p<structure.Count();p++)
         {
            SQSMCStructurePoint point;if(!structure.Get(p,point))continue;
            if(point.type!=wanted || point.shift<=k || point.shift-right<k)continue;
            if(point.shift<nearestShift){nearestShift=point.shift;level=point.price;}
         }
         if(level<=0.0)continue;
         double close=snap.Close(slot,k);
         bool broke=(bullish?close>level+QSMC_EPSILON:close<level-QSMC_EPSILON);
         if(!broke)continue;

         out.direction=(bullish?QSMC_DIR_BUY:QSMC_DIR_SELL);
         out.breakLevel=level;out.breakShift=k;out.displacementAtr=ratio;
         int classification=ContinuationClass(structure,k,right,bullish);
         out.breakKind=(classification<0?"STRUCTURE_BREAK":
                        (classification==1?"BOS":"CHoCH"));

         double currentHigh=snap.High(slot,newest),currentLow=snap.Low(slot,newest);
         int bestObShift=2147483647;
         SQSMCZone chosenOb;chosenOb.Reset();
         for(int z=0;z<zones.Count();z++)
         {
            SQSMCZone zone;if(!zones.Get(z,zone))continue;
            bool correctSide=(bullish?zone.IsDemandLike():zone.IsSupplyLike());
            if(!correctSide || zone.mitigated)continue;
            // The origin pivot predates the break and was already confirmed.
            if(zone.createdShift<=k || zone.createdShift-right<k ||
               zone.createdShift>k+right+8)continue;
            bool overlap=(currentLow<=zone.top+QSMC_EPSILON &&
                          currentHigh>=zone.bottom-QSMC_EPSILON);
            if(!overlap || zone.createdShift>=bestObShift)continue;
            chosenOb=zone;bestObShift=zone.createdShift;
         }
         if(bestObShift<2147483647)
         {
            out.orderBlock=chosenOb;out.candidate=true;out.stage="WATCH_CANDIDATE";
            out.explanation=StringFormat("%s close through confirmed swing %.5f (%.2f ATR), then retest of %s proxy [%.5f..%.5f]",
                                         out.breakKind,level,ratio,chosenOb.Name(),chosenOb.bottom,chosenOb.top);
            return true;
         }
         out.stage="WAIT_OB_RETEST";
         out.explanation=StringFormat("%s at %.5f confirmed; waiting for unmitigated %s proxy retest",
                                      out.breakKind,level,(bullish?"demand":"supply"));
         return true;
      }
      out.stage="WAIT_BREAK";
      out.explanation="no recent displacement-confirmed BOS/CHoCH with a later retest";
      return true;
   }
};
#endif // QSMC_BREAKORDERBLOCK_MQH
