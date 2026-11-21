//+------------------------------------------------------------------+
//|                                          QSMC_FairValueGaps.mqh |
//| Three-bar fair-value-gap geometry using closed, series-ordered bars.|
//| The model reports unfilled gaps and current-bar retests; a gap by    |
//| itself is not an entry signal.                                      |
//+------------------------------------------------------------------+
#ifndef QSMC_FAIRVALUEGAPS_MQH
#define QSMC_FAIRVALUEGAPS_MQH

#include "../Core/QSMC_Constants.mqh"
#include "../Core/QSMC_Types.mqh"
#include "../Data/QSMC_MarketSnapshot.mqh"

enum ENUM_QSMC_FVG_DIRECTION
{
   QSMC_FVG_BEARISH=-1,
   QSMC_FVG_BULLISH=1
};

struct SQSMCFairValueGap
{
   int direction;
   double top;
   double bottom;
   double sizeAtr;
   datetime formed;
   int formedShift;
   int ageBars;
   bool retested;
   bool currentRetest;
   bool filled;
   double fillFraction;
   double score;

   void Reset()
   {
      direction=0;top=0.0;bottom=0.0;sizeAtr=0.0;formed=0;
      formedShift=0;ageBars=0;retested=false;currentRetest=false;
      filled=false;fillFraction=0.0;score=0.0;
   }
   double Mid() const{return(top+bottom)*0.5;}
   bool Contains(const double price) const{return(price>=bottom-QSMC_EPSILON && price<=top+QSMC_EPSILON);}
   string Name() const{return(direction==QSMC_FVG_BULLISH?"bullish FVG":"bearish FVG");}
};

class CQSMCFairValueGaps
{
private:
   SQSMCFairValueGap m_gaps[QSMC_MAX_ZONES];
   int m_count;
   double m_atr;
   int m_scanned;

   void Add(const SQSMCFairValueGap &gap)
   {
      if(m_count>=QSMC_MAX_ZONES)return;
      m_gaps[m_count]=gap;
      m_count++;
   }

public:
   CQSMCFairValueGaps(){Reset();}
   void Reset()
   {
      m_count=0;m_atr=0.0;m_scanned=0;
      for(int i=0;i<QSMC_MAX_ZONES;i++)m_gaps[i].Reset();
   }
   int Count() const{return m_count;}
   double Atr() const{return m_atr;}
   int ScannedBars() const{return m_scanned;}
   bool Get(const int index,SQSMCFairValueGap &out) const
   {
      if(index<0 || index>=m_count)return false;
      out=m_gaps[index];return true;
   }

   bool Build(const CQSMCMarketSnapshot &snap,const int slot,
              const int lookback,const double minGapAtr)
   {
      Reset();
      if(lookback<10 || minGapAtr<0.0)return false;
      int newest=snap.NewestIndex();
      int count=snap.BarCount(slot);
      if(count<newest+10)return false;
      double atr=snap.Atr(slot,14,newest);
      if(atr<=0.0)return false;
      m_atr=atr;
      int oldest=MathMin(count-3,newest+lookback-1);
      m_scanned=MathMax(0,oldest-newest+1);
      double currentLow=snap.Low(slot,newest);
      double currentHigh=snap.High(slot,newest);

      // Scan newest-first. Every candidate uses three completed candles:
      // newer=i, middle=i+1, older=i+2.
      for(int i=newest;i<=oldest && m_count<QSMC_MAX_ZONES;i++)
      {
         double newerHigh=snap.High(slot,i);
         double newerLow=snap.Low(slot,i);
         double olderHigh=snap.High(slot,i+2);
         double olderLow=snap.Low(slot,i+2);
         SQSMCFairValueGap gap;gap.Reset();
         double width=0.0;

         if(olderLow>newerHigh+QSMC_EPSILON)
         {
            gap.direction=QSMC_FVG_BULLISH;
            gap.bottom=newerHigh;
            gap.top=olderLow;
            width=gap.top-gap.bottom;
         }
         else if(olderHigh<newerLow-QSMC_EPSILON)
         {
            gap.direction=QSMC_FVG_BEARISH;
            gap.bottom=olderHigh;
            gap.top=newerLow;
            width=gap.top-gap.bottom;
         }
         if(width<=0.0 || width/atr<minGapAtr)continue;

         gap.sizeAtr=width/atr;
         gap.formed=snap.BarTime(slot,i);
         gap.formedShift=i;
         gap.ageBars=i-newest;
         gap.score=MathMin(1.0,gap.sizeAtr/1.5);

         // Inspect only later closed bars, never bars older than formation.
         for(int k=i-1;k>=newest;k--)
         {
            double lo=snap.Low(slot,k);
            double hi=snap.High(slot,k);
            bool overlap=(lo<=gap.top+QSMC_EPSILON && hi>=gap.bottom-QSMC_EPSILON);
            if(overlap)gap.retested=true;
            if(gap.direction==QSMC_FVG_BULLISH)
            {
               if(lo<=gap.bottom+QSMC_EPSILON)gap.filled=true;
               if(overlap && hi>gap.bottom)
                  gap.fillFraction=MathMax(gap.fillFraction,
                     MathMin(1.0,MathMax(0.0,(gap.top-MathMax(lo,gap.bottom))/width)));
            }
            else
            {
               if(hi>=gap.top-QSMC_EPSILON)gap.filled=true;
               if(overlap && lo<gap.top)
                  gap.fillFraction=MathMax(gap.fillFraction,
                     MathMin(1.0,MathMax(0.0,(MathMin(hi,gap.top)-gap.bottom)/width)));
            }
         }

         // A retest must occur after the three-bar gap has already formed;
         // the newest candle that creates the gap is not itself a retest.
         gap.currentRetest=(i>newest && currentLow<=gap.top+QSMC_EPSILON &&
                            currentHigh>=gap.bottom-QSMC_EPSILON && !gap.filled);
         if(gap.currentRetest)gap.score=MathMin(1.0,gap.score+0.20);
         if(!gap.filled)Add(gap);
      }
      return(m_count>0);
   }

   // Return the highest-score unfilled FVG that is currently being retested
   // and agrees with requested direction (+1 bullish, -1 bearish).
   bool BestCurrentRetest(const int direction,SQSMCFairValueGap &out) const
   {
      return BestCurrentRetestAfter(direction,2147483647,out);
   }

   // `formedBeforeShift` is the MSS bar in series indexing. A valid
   // post-MSS retest gap must have a smaller shift (formed later).
   bool BestCurrentRetestAfter(const int direction,const int formedBeforeShift,
                               SQSMCFairValueGap &out) const
   {
      int best=-1;
      for(int i=0;i<m_count;i++)
      {
         if(!m_gaps[i].currentRetest || m_gaps[i].filled)continue;
         if(direction!=0 && m_gaps[i].direction!=direction)continue;
         if(m_gaps[i].formedShift>=formedBeforeShift)continue;
         if(best<0 || m_gaps[i].score>m_gaps[best].score)best=i;
      }
      if(best<0)return false;
      out=m_gaps[best];return true;
   }

   int CurrentRetests(const int direction=0) const
   {
      int n=0;
      for(int i=0;i<m_count;i++)
         if(m_gaps[i].currentRetest && !m_gaps[i].filled &&
            (direction==0 || m_gaps[i].direction==direction))n++;
      return n;
   }
};

#endif // QSMC_FAIRVALUEGAPS_MQH
