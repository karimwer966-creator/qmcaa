//+------------------------------------------------------------------+
//|                                                 QSMC_Sessions.mqh |
//| Broker-server session ranges and recent liquidity raids. Session    |
//| windows are minute-of-day inputs; DST/server offset is operator     |
//| configured. This module uses closed bars only.                      |
//+------------------------------------------------------------------+
#ifndef QSMC_SESSIONS_MQH
#define QSMC_SESSIONS_MQH

#include "../Core/QSMC_Constants.mqh"
#include "../Data/QSMC_MarketSnapshot.mqh"

#define QSMC_SESSION_ASIA   0
#define QSMC_SESSION_LONDON 1
#define QSMC_SESSION_NY     2
#define QSMC_SESSION_COUNT  3

struct SQSMCSessionRange
{
   string name;
   int startMinute;
   int endMinute;
   bool activeNow;
   bool currentReady;
   bool previousReady;
   double currentHigh;
   double currentLow;
   double previousHigh;
   double previousLow;

   void Reset()
   {
      name="";startMinute=0;endMinute=0;activeNow=false;
      currentReady=false;previousReady=false;
      currentHigh=0.0;currentLow=0.0;previousHigh=0.0;previousLow=0.0;
   }
};

struct SQSMCSessionContext
{
   bool ready;
   datetime evaluatedBar;
   int serverMinute;
   string activeSession;
   bool inLondonOrNewYork;
   bool sweptHigh;
   bool sweptLow;
   double sweptHighLevel;
   double sweptLowLevel;
   int sweptHighShift;
   int sweptLowShift;
   string sweptHighSource;
   string sweptLowSource;
   SQSMCSessionRange ranges[QSMC_SESSION_COUNT];
   string diagnostic;

   void Reset()
   {
      ready=false;evaluatedBar=0;serverMinute=0;activeSession="OFF";
      inLondonOrNewYork=false;sweptHigh=false;sweptLow=false;
      sweptHighLevel=0.0;sweptLowLevel=0.0;
      sweptHighShift=-1;sweptLowShift=-1;
      sweptHighSource="";sweptLowSource="";diagnostic="";
      for(int i=0;i<QSMC_SESSION_COUNT;i++)ranges[i].Reset();
   }
};

class CQSMCSessions
{
private:
   static int MinuteOfDay(const datetime when)
   {
      MqlDateTime dt;TimeToStruct(when,dt);
      return dt.hour*60+dt.min;
   }

   static datetime DayStart(const datetime when)
   {
      MqlDateTime dt;TimeToStruct(when,dt);
      dt.hour=0;dt.min=0;dt.sec=0;
      return StructToTime(dt);
   }

   static datetime SessionDay(const datetime when,const int startMinute,const int endMinute)
   {
      datetime day=DayStart(when);
      int minute=MinuteOfDay(when);
      // For a window crossing midnight, post-midnight bars belong to the
      // session that began on the preceding server day.
      if(startMinute>endMinute && minute<endMinute)day-=86400;
      return day;
   }

   static bool InWindow(const int minute,const int startMinute,const int endMinute)
   {
      if(startMinute==endMinute)return false;
      if(startMinute<endMinute)return(minute>=startMinute && minute<endMinute);
      return(minute>=startMinute || minute<endMinute);
   }

   static void SetWindow(SQSMCSessionRange &r,const int index,
                         const int asiaStart,const int asiaEnd,
                         const int londonStart,const int londonEnd,
                         const int nyStart,const int nyEnd)
   {
      r.Reset();
      if(index==QSMC_SESSION_ASIA){r.name="ASIA";r.startMinute=asiaStart;r.endMinute=asiaEnd;}
      else if(index==QSMC_SESSION_LONDON){r.name="LONDON";r.startMinute=londonStart;r.endMinute=londonEnd;}
      else {r.name="NEW_YORK";r.startMinute=nyStart;r.endMinute=nyEnd;}
   }

   static void IncludeBar(SQSMCSessionRange &range,const bool previous,
                         const double high,const double low)
   {
      if(previous)
      {
         if(!range.previousReady){range.previousHigh=high;range.previousLow=low;range.previousReady=true;}
         else {range.previousHigh=MathMax(range.previousHigh,high);range.previousLow=MathMin(range.previousLow,low);}
      }
      else
      {
         if(!range.currentReady){range.currentHigh=high;range.currentLow=low;range.currentReady=true;}
         else {range.currentHigh=MathMax(range.currentHigh,high);range.currentLow=MathMin(range.currentLow,low);}
      }
   }

   static void DetectSweepLevel(const CQSMCMarketSnapshot &snap,const int slot,
                                const double level,const bool upper,const int newest,
                                const int londonStart,const int londonEnd,
                                const int nyStart,const int nyEnd,
                                const string source,SQSMCSessionContext &out)
   {
      if(level<=0.0)return;
      for(int i=newest;i<newest+4 && i<snap.BarCount(slot);i++)
      {
         datetime sweepBar=snap.BarTime(slot,i);
         int sweepMinute=MinuteOfDay(sweepBar);
         if(!InWindow(sweepMinute,londonStart,londonEnd) &&
            !InWindow(sweepMinute,nyStart,nyEnd))continue;
         if(upper && snap.High(slot,i)>level+QSMC_EPSILON && snap.Close(slot,i)<level)
         {
            if(!out.sweptHigh){out.sweptHigh=true;out.sweptHighLevel=level;out.sweptHighSource=source;out.sweptHighShift=i;}
            return;
         }
         if(!upper && snap.Low(slot,i)<level-QSMC_EPSILON && snap.Close(slot,i)>level)
         {
            if(!out.sweptLow){out.sweptLow=true;out.sweptLowLevel=level;out.sweptLowSource=source;out.sweptLowShift=i;}
            return;
         }
      }
   }

public:
   static bool Evaluate(const CQSMCMarketSnapshot &snap,const int slot,
                        const bool enabled,
                        const int asiaStart,const int asiaEnd,
                        const int londonStart,const int londonEnd,
                        const int nyStart,const int nyEnd,
                        SQSMCSessionContext &out)
   {
      out.Reset();
      if(!enabled){out.diagnostic="session analysis disabled";return false;}
      int newest=snap.NewestIndex();
      datetime evaluated=snap.BarTime(slot,newest);
      if(evaluated<=0 || snap.BarCount(slot)<=newest+5)
      {out.diagnostic="insufficient closed bars for session analysis";return false;}

      SetWindow(out.ranges[QSMC_SESSION_ASIA],QSMC_SESSION_ASIA,asiaStart,asiaEnd,
                londonStart,londonEnd,nyStart,nyEnd);
      SetWindow(out.ranges[QSMC_SESSION_LONDON],QSMC_SESSION_LONDON,asiaStart,asiaEnd,
                londonStart,londonEnd,nyStart,nyEnd);
      SetWindow(out.ranges[QSMC_SESSION_NY],QSMC_SESSION_NY,asiaStart,asiaEnd,
                londonStart,londonEnd,nyStart,nyEnd);

      datetime currentDay=DayStart(evaluated);
      datetime previousDay=currentDay-86400;
      int minute=MinuteOfDay(evaluated);
      out.evaluatedBar=evaluated;
      out.serverMinute=minute;

      int starts[QSMC_SESSION_COUNT];
      int ends[QSMC_SESSION_COUNT];
      starts[0]=asiaStart;starts[1]=londonStart;starts[2]=nyStart;
      ends[0]=asiaEnd;ends[1]=londonEnd;ends[2]=nyEnd;

      for(int s=0;s<QSMC_SESSION_COUNT;s++)
      {
         out.ranges[s].activeNow=InWindow(minute,starts[s],ends[s]);
         if(out.ranges[s].activeNow)
         {
            if(s==QSMC_SESSION_ASIA)out.activeSession="ASIA";
            else if(s==QSMC_SESSION_LONDON){out.activeSession="LONDON";out.inLondonOrNewYork=true;}
            else {out.activeSession="NEW_YORK";out.inLondonOrNewYork=true;}
         }
      }

      // Two-day rolling ranges are enough for the selected session-sweep
      // setup and bound the historical scan cost.
      for(int i=newest;i<snap.BarCount(slot);i++)
      {
         datetime t=snap.BarTime(slot,i);
         if(t<=0)continue;
         for(int s=0;s<QSMC_SESSION_COUNT;s++)
         {
            if(starts[s]==ends[s] || !InWindow(MinuteOfDay(t),starts[s],ends[s]))continue;
            datetime key=SessionDay(t,starts[s],ends[s]);
            if(key!=currentDay && key!=previousDay)continue;
            IncludeBar(out.ranges[s],key==previousDay,snap.High(slot,i),snap.Low(slot,i));
         }
      }

      // Sweep references: completed earlier sessions today and all prior
      // server-day sessions. Current-session extremes are not treated as a
      // valid prior liquidity pool.
      for(int s=0;s<QSMC_SESSION_COUNT;s++)
      {
         bool completedToday=(out.ranges[s].currentReady && ends[s]!=starts[s] &&
                              (starts[s]<ends[s]?minute>=ends[s]:minute<starts[s] && minute>=ends[s]));
         if(completedToday)
         {
            DetectSweepLevel(snap,slot,out.ranges[s].currentHigh,true,newest,
                             londonStart,londonEnd,nyStart,nyEnd,out.ranges[s].name+" high",out);
            DetectSweepLevel(snap,slot,out.ranges[s].currentLow,false,newest,
                             londonStart,londonEnd,nyStart,nyEnd,out.ranges[s].name+" low",out);
         }
         if(out.ranges[s].previousReady)
         {
            DetectSweepLevel(snap,slot,out.ranges[s].previousHigh,true,newest,
                             londonStart,londonEnd,nyStart,nyEnd,"previous-day "+out.ranges[s].name+" high",out);
            DetectSweepLevel(snap,slot,out.ranges[s].previousLow,false,newest,
                             londonStart,londonEnd,nyStart,nyEnd,"previous-day "+out.ranges[s].name+" low",out);
         }
      }

      out.ready=true;
      out.diagnostic=StringFormat("server %02d:%02d session=%s, sweeps H=%s L=%s",
                                  minute/60,minute%60,out.activeSession,
                                  (out.sweptHigh?out.sweptHighSource:"no"),
                                  (out.sweptLow?out.sweptLowSource:"no"));
      return true;
   }
};

#endif // QSMC_SESSIONS_MQH
