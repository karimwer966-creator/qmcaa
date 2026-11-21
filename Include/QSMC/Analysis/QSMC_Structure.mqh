//+------------------------------------------------------------------+
//|                                                QSMC_Structure.mqh |
//|  Market structure: confirmed fractal swing points, running bias      |
//|  bookkeeping and break-of-structure detection.                      |
//|                                                                     |
//|  SPEC NOTE: the swing definition (n-bar fractal) is an explicit      |
//|  modelling choice, not an unpublished proprietary rule.  It is       |
//|  isolated here so that a different structure definition can be       |
//|  substituted without touching the rest of the pipeline.              |
//+------------------------------------------------------------------+
#ifndef QSMC_STRUCTURE_MQH
#define QSMC_STRUCTURE_MQH

#include "../Core/QSMC_Constants.mqh"
#include "../Core/QSMC_Types.mqh"
#include "../Data/QSMC_MarketSnapshot.mqh"

#define QSMC_SWING_NONE  0
#define QSMC_SWING_LOW  (-1)
#define QSMC_SWING_HIGH  1

struct SQSMCStructurePoint
{
   datetime time;
   double   price;
   int      shift;      // bars back from the newest bar
   int      type;       // QSMC_SWING_HIGH / QSMC_SWING_LOW
   int      strength;   // number of confirming bars on each side
};

class CQSMCStructure
{
private:
   SQSMCStructurePoint m_points[QSMC_MAX_STRUCT_POINTS];
   int      m_count;
   int      m_slot;
   int      m_scanned;
   double   m_lastHigh;
   double   m_lastLow;
   datetime m_lastHighTime;
   datetime m_lastLowTime;
   int      m_window;

public:
   CQSMCStructure()
   {
      Reset();
   }

   void Reset()
   {
      m_count        = 0;
      m_slot         = QSMC_SNAP_EXEC;
      m_scanned      = 0;
      m_lastHigh     = 0.0;
      m_lastLow      = 0.0;
      m_lastHighTime = 0;
      m_lastLowTime  = 0;
      m_window       = 0;
      for(int i = 0; i < QSMC_MAX_STRUCT_POINTS; i++)
      {
         m_points[i].time     = 0;
         m_points[i].price    = 0.0;
         m_points[i].shift    = 0;
         m_points[i].type     = QSMC_SWING_NONE;
         m_points[i].strength = 0;
      }
   }

   //+---------------------------------------------------------------+
   //| Detect swing points.  Points are stored newest-first.            |
   //+---------------------------------------------------------------+
   bool Detect(const CQSMCMarketSnapshot &snap,
               const int slot,
               const int lookback,
               const int left,
               const int right)
   {
      Reset();
      if(left < 1 || right < 1) return false;

      int available = snap.BarCount(slot);
      int newest    = snap.NewestIndex();
      int limit     = MathMin(lookback, available - left - 1);
      int firstCandidate = newest + right;
      if(limit <= firstCandidate + left) return false;

      m_slot    = slot;
      m_window  = limit;
      m_scanned = MathMax(0,limit-firstCandidate+1);

      // Never confirm a swing using the still-forming candle when closed-only
      // mode is active: the newest comparison index is `newest`, not zero.
      for(int i = limit; i >= firstCandidate; i--)
      {
         if(m_count >= QSMC_MAX_STRUCT_POINTS) break;

         double hi = snap.High(slot, i);
         double lo = snap.Low(slot, i);
         bool isHigh = true;
         bool isLow  = true;

         for(int k = 1; k <= left && (isHigh || isLow); k++)
         {
            int older = i + k;
            if(older >= available) { isHigh = false; isLow = false; break; }
            if(hi <= snap.High(slot, older) + QSMC_EPSILON) isHigh = false;
            if(lo >= snap.Low(slot, older) - QSMC_EPSILON) isLow = false;
         }
         for(int k = 1; k <= right && (isHigh || isLow); k++)
         {
            int newer = i - k;
            if(newer < 0) { isHigh = false; isLow = false; break; }
            if(hi <= snap.High(slot, newer) + QSMC_EPSILON) isHigh = false;
            if(lo >= snap.Low(slot, newer) - QSMC_EPSILON) isLow = false;
         }

         // A bar can only be one kind of swing; resolves ties deterministically
         // in favour of the closer extreme.
         if(isHigh && isLow)
         {
            if(MathAbs(hi - snap.Close(slot, i)) >= MathAbs(lo - snap.Close(slot, i)))
               isLow = false;
            else
               isHigh = false;
         }

         if(isHigh)
         {
            m_points[m_count].time     = snap.BarTime(slot, i);
            m_points[m_count].price    = hi;
            m_points[m_count].shift    = i;
            m_points[m_count].type     = QSMC_SWING_HIGH;
            m_points[m_count].strength = left;
            m_count++;
         }
         else if(isLow)
         {
            m_points[m_count].time     = snap.BarTime(slot, i);
            m_points[m_count].price    = lo;
            m_points[m_count].shift    = i;
            m_points[m_count].type     = QSMC_SWING_LOW;
            m_points[m_count].strength = left;
            m_count++;
         }
      }

      //--- remember the newest extremes (points are newest-first) ------
      for(int p = 0; p < m_count; p++)
      {
         if(m_points[p].type == QSMC_SWING_HIGH && m_lastHigh == 0.0)
         {
            m_lastHigh     = m_points[p].price;
            m_lastHighTime = m_points[p].time;
         }
         if(m_points[p].type == QSMC_SWING_LOW && m_lastLow == 0.0)
         {
            m_lastLow     = m_points[p].price;
            m_lastLowTime = m_points[p].time;
         }
      }

      return (m_count > 0);
   }

   int    Count()        const { return m_count; }
   int    Slot()         const { return m_slot; }
   int    ScannedBars()  const { return m_scanned; }
   int    Window()       const { return m_window; }
   double LastSwingHigh()const { return m_lastHigh; }
   double LastSwingLow() const { return m_lastLow; }
   datetime LastSwingHighTime() const { return m_lastHighTime; }
   datetime LastSwingLowTime()  const { return m_lastLowTime; }

   bool Get(const int index, SQSMCStructurePoint &out) const
   {
      if(index < 0 || index >= m_count) return false;
      out = m_points[index];
      return true;
   }

   //--- simple derived structure ------------------------------------
   int CountType(const int type) const
   {
      int n = 0;
      for(int i = 0; i < m_count; i++)
         if(m_points[i].type == type) n++;
      return n;
   }

   // h1 = newest swing high, h2 = the previous one.
   bool LastTwoHighs(double &h1, double &h2) const
   {
      h1 = 0.0;
      h2 = 0.0;
      int found = 0;
      for(int i = 0; i < m_count && found < 2; i++)
      {
         if(m_points[i].type != QSMC_SWING_HIGH) continue;
         if(found == 0) h1 = m_points[i].price;
         else           h2 = m_points[i].price;
         found++;
      }
      return (found == 2);
   }

   // l1 = newest swing low, l2 = the previous one.
   bool LastTwoLows(double &l1, double &l2) const
   {
      l1 = 0.0;
      l2 = 0.0;
      int found = 0;
      for(int i = 0; i < m_count && found < 2; i++)
      {
         if(m_points[i].type != QSMC_SWING_LOW) continue;
         if(found == 0) l1 = m_points[i].price;
         else           l2 = m_points[i].price;
         found++;
      }
      return (found == 2);
   }

   // Nearest swing high strictly above `price`.
   bool NearestHighAbove(const double price, double &level) const
   {
      level = 0.0;
      for(int i = 0; i < m_count; i++)
      {
         if(m_points[i].type != QSMC_SWING_HIGH) continue;
         if(m_points[i].price <= price) continue;
         if(level == 0.0 || m_points[i].price < level) level = m_points[i].price;
      }
      return (level > 0.0);
   }

   // Nearest swing low strictly below `price`.
   bool NearestLowBelow(const double price, double &level) const
   {
      level = 0.0;
      for(int i = 0; i < m_count; i++)
      {
         if(m_points[i].type != QSMC_SWING_LOW) continue;
         if(m_points[i].price >= price) continue;
         if(level == 0.0 || m_points[i].price > level) level = m_points[i].price;
      }
      return (level > 0.0);
   }

   string Describe() const
   {
      return StringFormat("structure points=%d highs=%d lows=%d lastHigh=%.5f lastLow=%.5f",
                          m_count, CountType(QSMC_SWING_HIGH), CountType(QSMC_SWING_LOW),
                          m_lastHigh, m_lastLow);
   }
};

#endif // QSMC_STRUCTURE_MQH
