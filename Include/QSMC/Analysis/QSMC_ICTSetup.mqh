//+------------------------------------------------------------------+
//|                                                  QSMC_ICTSetup.mqh |
//| Explicit ICT-inspired candidate sequence selected by the user:     |
//| prior session liquidity raid -> displacement/MSS -> post-MSS FVG   |
//| retest. This is a watch condition, not an entry instruction.        |
//+------------------------------------------------------------------+
#ifndef QSMC_ICTSETUP_MQH
#define QSMC_ICTSETUP_MQH
#include "../Core/QSMC_Types.mqh"
#include "../Data/QSMC_MarketSnapshot.mqh"
#include "QSMC_Structure.mqh"
#include "QSMC_Sessions.mqh"
#include "QSMC_FairValueGaps.mqh"
#include "QSMC_CandlePatterns.mqh"

enum ENUM_QSMC_ICT_STAGE
{
   QSMC_ICT_UNAVAILABLE=0,
   QSMC_ICT_WAIT_KILLZONE,
   QSMC_ICT_WAIT_SWEEP,
   QSMC_ICT_WAIT_MSS,
   QSMC_ICT_WAIT_FVG,
   QSMC_ICT_WATCH_CANDIDATE,
   QSMC_ICT_AMBIGUOUS
};
struct SQSMCICTSetup
{
   bool ready;
   bool candidate;
   ENUM_QSMC_ICT_STAGE stage;
   ENUM_QSMC_DIRECTION direction;
   double confluenceScore; // 0..100; explicitly NOT a win probability
   string session;
   string sweepSource;
   double sweepLevel;
   datetime sweepTime;
   double mssLevel;
   datetime mssTime;
   double fvgTop;
   double fvgBottom;
   datetime fvgTime;
   double displacementAtr;
   string explanation;
   void Reset()
   {
      ready=false;candidate=false;stage=QSMC_ICT_UNAVAILABLE;
      direction=QSMC_DIR_NONE;confluenceScore=0.0;session="";
      sweepSource="";sweepLevel=0.0;sweepTime=0;mssLevel=0.0;mssTime=0;
      fvgTop=0.0;fvgBottom=0.0;fvgTime=0;displacementAtr=0.0;explanation="";
   }
};

class CQSMCICTSetupModel
{
private:
   static bool FindMss(const CQSMCMarketSnapshot &snap,const CQSMCStructure &structure,
                       const int slot,const int direction,const int sweepShift,
                       const int swingRight,const double minDisplacement,double &level,int &barShift,
                       double &displacement)
   {
      int newest=snap.NewestIndex();
      if(sweepShift<=newest)return false;
      // Prefer the latest valid post-sweep displacement/MSS candle.
      for(int k=newest;k<sweepShift;k++)
      {
         double atr=snap.Atr(slot,14,k);
         if(atr<=0.0)continue;
         double body=CQSMCCandlePatterns::Body(snap,slot,k);
         double ratio=body/atr;
         if(ratio<minDisplacement)continue;
         bool aligned=(direction==QSMC_DIR_BUY?
                       CQSMCCandlePatterns::IsBullish(snap,slot,k):
                       CQSMCCandlePatterns::IsBearish(snap,slot,k));
         if(!aligned)continue;
         double close=snap.Close(slot,k);
         int bestShift=2147483647;
         double swingLevel=0.0;
         for(int p=0;p<structure.Count();p++)
         {
            SQSMCStructurePoint point;
            if(!structure.Get(p,point))continue;
            if(point.shift<=k || point.shift>sweepShift || point.shift-swingRight<k)continue;
            bool wanted=(direction==QSMC_DIR_BUY?point.type==QSMC_SWING_HIGH:
                                                  point.type==QSMC_SWING_LOW);
            if(!wanted)continue;
            if(point.shift<bestShift){bestShift=point.shift;swingLevel=point.price;}
         }
         if(swingLevel<=0.0)continue;
         bool broke=(direction==QSMC_DIR_BUY?close>swingLevel+QSMC_EPSILON:
                                             close<swingLevel-QSMC_EPSILON);
         if(!broke)continue;
         level=swingLevel;barShift=k;displacement=ratio;return true;
      }
      return false;
   }

public:
   static bool Evaluate(const CQSMCMarketSnapshot &snap,const int slot,
                        const CQSMCStructure &structure,
                        const SQSMCSessionContext &sessions,
                        const CQSMCFairValueGaps &gaps,
                        const int swingRight,const double minDisplacementAtr,
                        SQSMCICTSetup &out)
   {
      out.Reset();
      if(!sessions.ready || structure.Count()==0)
      {out.explanation="ICT model lacks session or structure data";return false;}
      out.ready=true;
      out.session=sessions.activeSession;
      int direction=0,sweepShift=-1;
      if(sessions.sweptLow && sessions.sweptHigh)
      {
         out.stage=QSMC_ICT_AMBIGUOUS;
         out.explanation="both-side session raids detected; stand aside";
         return true;
      }
      if(sessions.sweptLow)
      {
         direction=QSMC_DIR_BUY;sweepShift=sessions.sweptLowShift;
         out.sweepLevel=sessions.sweptLowLevel;
         out.sweepSource=sessions.sweptLowSource;
      }
      else if(sessions.sweptHigh)
      {
         direction=QSMC_DIR_SELL;sweepShift=sessions.sweptHighShift;
         out.sweepLevel=sessions.sweptHighLevel;
         out.sweepSource=sessions.sweptHighSource;
      }

      if(!sessions.inLondonOrNewYork)
      {
         out.stage=QSMC_ICT_WAIT_KILLZONE;
         out.explanation="outside configured London/New York windows";
         return true;
      }
      if(direction==0)
      {
         out.stage=QSMC_ICT_WAIT_SWEEP;
         out.explanation="waiting for a recent completed-session liquidity raid";
         return true;
      }
      out.direction=(ENUM_QSMC_DIRECTION)direction;
      out.sweepTime=snap.BarTime(slot,sweepShift);

      double mssLevel=0.0,disp=0.0;
      int mssShift=-1;
      if(!FindMss(snap,structure,slot,direction,sweepShift,swingRight,
                  minDisplacementAtr,mssLevel,mssShift,disp))
      {
         out.stage=QSMC_ICT_WAIT_MSS;
         out.explanation=StringFormat("%s raid at %.5f; waiting for displacement close through opposing swing",
                                      out.sweepSource,out.sweepLevel);
         return true;
      }
      out.mssLevel=mssLevel;
      out.mssTime=snap.BarTime(slot,mssShift);
      out.displacementAtr=disp;

      SQSMCFairValueGap gap;
      int fvgDirection=(direction==QSMC_DIR_BUY?QSMC_FVG_BULLISH:QSMC_FVG_BEARISH);
      if(!gaps.BestCurrentRetestAfter(fvgDirection,mssShift,gap))
      {
         out.stage=QSMC_ICT_WAIT_FVG;
         out.explanation=StringFormat("MSS confirmed at %.5f; waiting for unfilled post-MSS FVG retrace",
                                      mssLevel);
         return true;
      }

      out.candidate=true;
      out.stage=QSMC_ICT_WATCH_CANDIDATE;
      out.fvgTop=gap.top;out.fvgBottom=gap.bottom;out.fvgTime=gap.formed;
      // Transparent confluence points, deliberately not calibrated odds.
      out.confluenceScore=MathMin(100.0,35.0+
                                  MathMin(25.0,disp*12.0)+
                                  MathMin(20.0,gap.sizeAtr*10.0)+20.0);
      out.explanation=StringFormat("WATCH only: %s raid -> MSS %.5f (%.2f ATR) -> FVG retest [%.5f..%.5f]; confluence %.0f/100, not probability",
                                   QSMC_DirectionToString(out.direction),mssLevel,disp,
                                   gap.bottom,gap.top,out.confluenceScore);
      return true;
   }

   static string StageName(const ENUM_QSMC_ICT_STAGE stage)
   {
      switch(stage)
      {
         case QSMC_ICT_UNAVAILABLE:return "UNAVAILABLE";
         case QSMC_ICT_WAIT_KILLZONE:return "WAIT_SESSION";
         case QSMC_ICT_WAIT_SWEEP:return "WAIT_SWEEP";
         case QSMC_ICT_WAIT_MSS:return "WAIT_MSS";
         case QSMC_ICT_WAIT_FVG:return "WAIT_FVG_RETRACE";
         case QSMC_ICT_WATCH_CANDIDATE:return "WATCH_CANDIDATE";
         case QSMC_ICT_AMBIGUOUS:return "AMBIGUOUS";
      }
      return "UNKNOWN";
   }
};
#endif // QSMC_ICTSETUP_MQH
