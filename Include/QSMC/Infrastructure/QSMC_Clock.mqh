//+------------------------------------------------------------------+
//|                                                    QSMC_Clock.mqh |
//|  Single time authority.  All trading logic uses SERVER time        |
//|  (TimeCurrent); UTC is exposed only for diagnostics.  Also owns    |
//|  per-timeframe new-bar detection so that no module re-implements   |
//|  it (and accidentally introduces a second definition of "bar").    |
//+------------------------------------------------------------------+
#ifndef QSMC_CLOCK_MQH
#define QSMC_CLOCK_MQH

#include "../Core/QSMC_Constants.mqh"
#include "../Core/QSMC_Types.mqh"

class CQSMCClock
{
private:
   string           m_symbol;
   datetime         m_now;
   datetime         m_gmt;
   datetime         m_dayStart;
   int              m_dayStamp;
   bool             m_initialised;

   int              m_tfCount;
   ENUM_TIMEFRAMES  m_tfs[QSMC_MAX_TIMEFRAMES];
   datetime         m_lastBar[QSMC_MAX_TIMEFRAMES];

   int IndexOf(const ENUM_TIMEFRAMES tf) const
   {
      for(int i = 0; i < m_tfCount; i++)
         if(m_tfs[i] == tf) return i;
      return QSMC_INVALID_INDEX;
   }

   void RecomputeDay()
   {
      MqlDateTime dt;
      TimeToStruct(m_now, dt);
      int stamp = dt.year * 10000 + dt.mon * 100 + dt.day;
      if(stamp != m_dayStamp)
      {
         m_dayStamp   = stamp;
         dt.hour      = 0;
         dt.min       = 0;
         dt.sec       = 0;
         m_dayStart   = StructToTime(dt);
      }
   }

public:
   CQSMCClock()
   {
      m_symbol      = "";
      m_now         = 0;
      m_gmt         = 0;
      m_dayStart    = 0;
      m_dayStamp    = 0;
      m_initialised = false;
      m_tfCount     = 0;
      ArrayInitialize(m_lastBar, 0);
   }

   bool Init(const string symbol)
   {
      if(StringLen(symbol) == 0) return false;
      m_symbol      = symbol;
      m_tfCount     = 0;
      m_initialised = true;
      Update();
      return true;
   }

   void Update()
   {
      if(!m_initialised) return;
      m_now = TimeCurrent();
      m_gmt = TimeGMT();
      RecomputeDay();
   }

   //--- registration -------------------------------------------------
   bool TrackTimeframe(const ENUM_TIMEFRAMES tf)
   {
      if(IndexOf(tf) != QSMC_INVALID_INDEX) return true;
      if(m_tfCount >= QSMC_MAX_TIMEFRAMES)  return false;
      m_tfs[m_tfCount]     = tf;
      m_lastBar[m_tfCount] = 0;
      m_tfCount++;
      return true;
   }

   //+---------------------------------------------------------------+
   //| True exactly once per new bar of the given timeframe.  Returns  |
   //| true on the first observation (so callers can warm up).         |
   //+---------------------------------------------------------------+
   bool IsNewBar(const ENUM_TIMEFRAMES tf)
   {
      int idx = IndexOf(tf);
      if(idx == QSMC_INVALID_INDEX)
      {
         if(!TrackTimeframe(tf)) return false;
         idx = IndexOf(tf);
         if(idx == QSMC_INVALID_INDEX) return false;
      }

      datetime barTime = (datetime)SeriesInfoInteger(m_symbol, tf, SERIES_LASTBAR_DATE);
      if(barTime == 0) return false;                 // history not available yet
      if(barTime == m_lastBar[idx]) return false;

      m_lastBar[idx] = barTime;
      return true;
   }

   //--- accessors ----------------------------------------------------
   datetime Now()             const { return m_now; }
   datetime Gmt()             const { return m_gmt; }
   datetime DayStart()        const { return m_dayStart; }
   int      DayStamp()        const { return m_dayStamp; }
   int      SecondsIntoDay()  const
   {
      long diff = (long)m_now - (long)m_dayStart;
      if(diff < 0) return 0;
      if(diff > 86400) return 86400;
      return (int)diff;
   }

   int ServerUtcOffsetMinutes() const
   {
      return (int)(((long)m_now - (long)m_gmt) / 60);
   }

   bool IsWithinWindow(const int fromHour, const int toHour) const
   {
      MqlDateTime dt;
      TimeToStruct(m_now, dt);
      if(fromHour == toHour) return true;
      if(fromHour < toHour)
         return (dt.hour >= fromHour && dt.hour < toHour);
      // window crosses midnight
      return (dt.hour >= fromHour || dt.hour < toHour);
   }

   bool IsWeekend() const
   {
      MqlDateTime dt;
      TimeToStruct(m_now, dt);
      return (dt.day_of_week == 0 || dt.day_of_week == 6);
   }

   string Describe() const
   {
      return StringFormat("server=%s utc=%s dayStart=%s offset=%dmin",
                          TimeToString(m_now, TIME_DATE | TIME_SECONDS),
                          TimeToString(m_gmt, TIME_DATE | TIME_SECONDS),
                          TimeToString(m_dayStart, TIME_DATE | TIME_MINUTES),
                          ServerUtcOffsetMinutes());
   }
};

#endif // QSMC_CLOCK_MQH
