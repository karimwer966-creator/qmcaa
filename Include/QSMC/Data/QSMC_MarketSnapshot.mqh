//+------------------------------------------------------------------+
//|                                            QSMC_MarketSnapshot.mqh |
//|  Immutable view of the market at decision time: three bar series    |
//|  (exec / htf / ltf), quote, spread and symbol contract metadata.    |
//|  Arrays are stored series-ordered: index 0 == most recent bar.      |
//|  Read-only helpers (ATR/EMA/range) live here so that analysis       |
//|  modules never re-implement basic math differently.                 |
//+------------------------------------------------------------------+
#ifndef QSMC_MARKETSNAPSHOT_MQH
#define QSMC_MARKETSNAPSHOT_MQH

#include "../Core/QSMC_Constants.mqh"
#include "../Core/QSMC_Types.mqh"

#define QSMC_SNAP_EXEC  0
#define QSMC_SNAP_HTF   1
#define QSMC_SNAP_LTF   2
#define QSMC_SNAP_SLOTS 3

class CQSMCMarketSnapshot
{
private:
   string           m_symbol;
   ENUM_TIMEFRAMES  m_tf[QSMC_SNAP_SLOTS];
   MqlRates         m_exec[];
   MqlRates         m_htf[];
   MqlRates         m_ltf[];
   int              m_count[QSMC_SNAP_SLOTS];

   datetime         m_captured;
   datetime         m_lastBarTime[QSMC_SNAP_SLOTS];
   double           m_bid;
   double           m_ask;
   long             m_spreadPoints;
   double           m_point;
   int              m_digits;
   double           m_tickValue;
   double           m_tickSize;
   double           m_volumeMin;
   double           m_volumeMax;
   double           m_volumeStep;
   long             m_stopsLevel;
   long             m_freezeLevel;
   bool             m_closedOnly;

   bool ValidSlot(const int slot) const
   {
      return (slot >= 0 && slot < QSMC_SNAP_SLOTS);
   }

   int CountOf(const int slot) const
   {
      if(slot == QSMC_SNAP_EXEC) return ArraySize(m_exec);
      if(slot == QSMC_SNAP_HTF)  return ArraySize(m_htf);
      if(slot == QSMC_SNAP_LTF)  return ArraySize(m_ltf);
      return 0;
   }

public:
   CQSMCMarketSnapshot()
   {
      m_symbol     = "";
      m_captured   = 0;
      m_bid        = 0.0;
      m_ask        = 0.0;
      m_spreadPoints = 0;
      m_point      = 0.0;
      m_digits     = 0;
      m_tickValue  = 0.0;
      m_tickSize   = 0.0;
      m_volumeMin  = 0.0;
      m_volumeMax  = 0.0;
      m_volumeStep = 0.0;
      m_stopsLevel = 0;
      m_freezeLevel= 0;
      m_closedOnly = true;
      for(int i = 0; i < QSMC_SNAP_SLOTS; i++)
      {
         m_tf[i]          = PERIOD_CURRENT;
         m_count[i]       = 0;
         m_lastBarTime[i] = 0;
      }
   }

   //--- construction (used only by CQSMCMarketData) -------------------
   bool AttachBars(const int slot, const MqlRates &rates[], const int count)
   {
      if(!ValidSlot(slot) || count < 0) return false;

      if(slot == QSMC_SNAP_EXEC) ArrayResize(m_exec, count);
      if(slot == QSMC_SNAP_HTF)  ArrayResize(m_htf, count);
      if(slot == QSMC_SNAP_LTF)  ArrayResize(m_ltf, count);

      for(int i = 0; i < count; i++)
      {
         if(slot == QSMC_SNAP_EXEC) m_exec[i] = rates[i];
         if(slot == QSMC_SNAP_HTF)  m_htf[i]  = rates[i];
         if(slot == QSMC_SNAP_LTF)  m_ltf[i]  = rates[i];
      }
      m_count[slot] = count;
      if(count > 0) m_lastBarTime[slot] = rates[0].time;
      return true;
   }

   void SetTimeframes(const ENUM_TIMEFRAMES execTf,
                      const ENUM_TIMEFRAMES htf,
                      const ENUM_TIMEFRAMES ltf)
   {
      m_tf[QSMC_SNAP_EXEC] = execTf;
      m_tf[QSMC_SNAP_HTF]  = htf;
      m_tf[QSMC_SNAP_LTF]  = ltf;
   }

   void SetSymbol(const string symbol) { m_symbol = symbol; }

   void SetQuote(const double bid, const double ask, const double point,
                 const long spreadPoints)
   {
      m_bid          = bid;
      m_ask          = ask;
      m_point        = point;
      m_spreadPoints = spreadPoints;
   }

   void SetContract(const int digits, const double tickValue, const double tickSize,
                    const double volMin, const double volMax, const double volStep,
                    const long stopsLevel, const long freezeLevel)
   {
      m_digits      = digits;
      m_tickValue   = tickValue;
      m_tickSize    = tickSize;
      m_volumeMin   = volMin;
      m_volumeMax   = volMax;
      m_volumeStep  = volStep;
      m_stopsLevel  = stopsLevel;
      m_freezeLevel = freezeLevel;
   }

   void SetClosedOnly(const bool closedOnly) { m_closedOnly = closedOnly; }
   void SetCaptured(const datetime when)     { m_captured = when; }

   void Reset()
   {
      ArrayFree(m_exec);
      ArrayFree(m_htf);
      ArrayFree(m_ltf);
      for(int i = 0; i < QSMC_SNAP_SLOTS; i++)
      {
         m_count[i]       = 0;
         m_lastBarTime[i] = 0;
      }
      m_captured = 0;
      m_bid      = 0.0;
      m_ask      = 0.0;
      m_spreadPoints = 0;
   }

   //--- basic accessors ---------------------------------------------
   string Symbol()            const { return m_symbol; }
   datetime Captured()        const { return m_captured; }
   double Bid()               const { return m_bid; }
   double Ask()               const { return m_ask; }
   double Point()             const { return m_point; }
   int    Digits()            const { return m_digits; }
   long   SpreadPoints()      const { return m_spreadPoints; }
   double TickValue()         const { return m_tickValue; }
   double TickSize()          const { return m_tickSize; }
   double VolumeMin()         const { return m_volumeMin; }
   double VolumeMax()         const { return m_volumeMax; }
   double VolumeStep()        const { return m_volumeStep; }
   long   StopsLevel()        const { return m_stopsLevel; }
   long   FreezeLevel()       const { return m_freezeLevel; }
   bool   ClosedOnly()        const { return m_closedOnly; }
   ENUM_TIMEFRAMES Tf(const int slot) const
   {
      return (ValidSlot(slot) ? m_tf[slot] : PERIOD_CURRENT);
   }

   int BarCount(const int slot) const { return CountOf(slot); }

   // Index of the newest bar analysis is allowed to use.
   int NewestIndex() const { return (m_closedOnly ? 1 : 0); }

   bool IsUsable() const
   {
      return (ArraySize(m_exec) > 10 && m_bid > 0.0 && m_ask > 0.0 && m_point > 0.0);
   }

   bool Bar(const int slot, const int index, MqlRates &out) const
   {
      if(!ValidSlot(slot) || index < 0) return false;
      if(slot == QSMC_SNAP_EXEC && index < ArraySize(m_exec)) { out = m_exec[index]; return true; }
      if(slot == QSMC_SNAP_HTF  && index < ArraySize(m_htf))  { out = m_htf[index];  return true; }
      if(slot == QSMC_SNAP_LTF  && index < ArraySize(m_ltf))  { out = m_ltf[index];  return true; }
      return false;
   }

   double Open(const int slot, const int i) const
   {
      MqlRates r;
      return (Bar(slot, i, r) ? r.open : 0.0);
   }
   double High(const int slot, const int i) const
   {
      MqlRates r;
      return (Bar(slot, i, r) ? r.high : 0.0);
   }
   double Low(const int slot, const int i) const
   {
      MqlRates r;
      return (Bar(slot, i, r) ? r.low : 0.0);
   }
   double Close(const int slot, const int i) const
   {
      MqlRates r;
      return (Bar(slot, i, r) ? r.close : 0.0);
   }
   long Volume(const int slot, const int i) const
   {
      MqlRates r;
      return (Bar(slot, i, r) ? (long)r.tick_volume : 0);
   }
   datetime BarTime(const int slot, const int i) const
   {
      MqlRates r;
      return (Bar(slot, i, r) ? r.time : 0);
   }
   datetime LastBarTime(const int slot) const
   {
      return (ValidSlot(slot) ? m_lastBarTime[slot] : 0);
   }

   //+---------------------------------------------------------------+
   //| Read-only indicators computed from the stored series.           |
   //| (No indicator handles: no chart state, deterministic, testable.)|
   //+---------------------------------------------------------------+
   double Atr(const int slot, const int period, const int startIndex = 0) const
   {
      int count = CountOf(slot);
      if(period <= 0 || count < period + startIndex + 2) return 0.0;

      double sum = 0.0;
      for(int i = startIndex + 1; i <= startIndex + period; i++)
      {
         double h = High(slot, i);
         double l = Low(slot, i);
         double pc = Close(slot, i - 1);
         double tr = MathMax(h - l, MathMax(MathAbs(h - pc), MathAbs(l - pc)));
         sum += tr;
      }
      return sum / (double)period;
   }

   double Ema(const int slot, const int period, const int index = 0) const
   {
      int count = CountOf(slot);
      if(period <= 1 || count < period + index) return 0.0;

      double k = 2.0 / ((double)period + 1.0);
      // seed with simple average of the oldest `period` closes in the window
      int seedStart = index + period - 1;
      double ema = 0.0;
      for(int i = 0; i < period; i++)
         ema += Close(slot, seedStart - i);
      ema /= (double)period;

      for(int j = seedStart - 1; j >= index; j--)
         ema = Close(slot, j) * k + ema * (1.0 - k);

      return ema;
   }

   double HighestHigh(const int slot, const int fromIndex, const int count) const
   {
      int available = CountOf(slot);
      double best = -DBL_MAX;
      for(int i = fromIndex; i < fromIndex + count && i < available; i++)
         best = MathMax(best, High(slot, i));
      return (best == -DBL_MAX ? 0.0 : best);
   }

   double LowestLow(const int slot, const int fromIndex, const int count) const
   {
      int available = CountOf(slot);
      double best = DBL_MAX;
      for(int i = fromIndex; i < fromIndex + count && i < available; i++)
         best = MathMin(best, Low(slot, i));
      return (best == DBL_MAX ? 0.0 : best);
   }

   double AverageVolume(const int slot, const int fromIndex, const int count) const
   {
      int available = CountOf(slot);
      int used = 0;
      double sum = 0.0;
      for(int i = fromIndex; i < fromIndex + count && i < available; i++)
      {
         sum += (double)Volume(slot, i);
         used++;
      }
      return (used > 0 ? sum / (double)used : 0.0);
   }

   // 0..1 position of price inside a range (0 = at low, 1 = at high).
   double PriceLocation(const int slot, const double price,
                        const int fromIndex, const int count) const
   {
      double hi = HighestHigh(slot, fromIndex, count);
      double lo = LowestLow(slot, fromIndex, count);
      double span = hi - lo;
      if(span <= QSMC_EPSILON) return 0.5;
      double pos = (price - lo) / span;
      if(pos < 0.0) pos = 0.0;
      if(pos > 1.0) pos = 1.0;
      return pos;
    }

   string Describe() const
   {
      return StringFormat("%s %s/%s/%s bars=%d/%d/%d bid=%.5f ask=%.5f spread=%dpt",
                          m_symbol,
                          QSMC_TfToString(m_tf[QSMC_SNAP_HTF]),
                          QSMC_TfToString(m_tf[QSMC_SNAP_EXEC]),
                          QSMC_TfToString(m_tf[QSMC_SNAP_LTF]),
                          ArraySize(m_exec), ArraySize(m_htf), ArraySize(m_ltf),
                          m_bid, m_ask, (int)m_spreadPoints);
   }
};

#endif // QSMC_MARKETSNAPSHOT_MQH
