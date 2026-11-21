//+------------------------------------------------------------------+
//|                                                   QSMC_SvpCore.mqh |
//|  SVP = Session Volume Profile.  Builds a fixed-bin histogram from    |
//|  closed bars, distributing each bar's volume across the price bins    |
//|  it covers.  Derives POC, value area (VAH/VAL), HVN and LVN.         |
//|                                                                      |
//|  Volume source: tick_volume carried by the snapshot. This is a        |
//|  bar-level approximation, not exchange volume-at-price. If no ticks   |
//|  are present it falls back to normalized time-at-price contribution.  |
//+------------------------------------------------------------------+
#ifndef QSMC_SVPCORE_MQH
#define QSMC_SVPCORE_MQH

#include "../Core/QSMC_Constants.mqh"
#include "../Core/QSMC_Types.mqh"
#include "../Data/QSMC_MarketSnapshot.mqh"

struct SQSMCProfileBin
{
   double low;
   double high;
   double mid;
   double volume;
   double pct;          // share of total volume (0..100)
   bool   inValueArea;
   bool   hvn;          // high volume node
   bool   lvn;          // low volume node
};

class CQSMCSvpCore
{
private:
   SQSMCProfileBin m_bins[QSMC_MAX_PROFILE_BINS];
   int      m_binCount;
   double   m_profileLow;
   double   m_profileHigh;
   double   m_binSize;
   double   m_poc;
   double   m_vah;
   double   m_val;
   double   m_totalVolume;
   double   m_valueAreaPct;
   bool     m_ready;
   int      m_barsUsed;
   datetime m_from;
   datetime m_to;

   int BinIndex(const double price) const
   {
      if(m_binSize <= QSMC_EPSILON) return 0;
      int idx = (int)((price - m_profileLow) / m_binSize);
      if(idx < 0) idx = 0;
      if(idx >= m_binCount) idx = m_binCount - 1;
      return idx;
   }

public:
   CQSMCSvpCore() { Reset(); }

   void Reset()
   {
      m_binCount      = 0;
      m_profileLow    = 0.0;
      m_profileHigh   = 0.0;
      m_binSize       = 0.0;
      m_poc           = 0.0;
      m_vah           = 0.0;
      m_val           = 0.0;
      m_totalVolume   = 0.0;
      m_valueAreaPct  = 70.0;
      m_ready         = false;
      m_barsUsed      = 0;
      m_from          = 0;
      m_to            = 0;
      for(int i = 0; i < QSMC_MAX_PROFILE_BINS; i++)
      {
         m_bins[i].low         = 0.0;
         m_bins[i].high        = 0.0;
         m_bins[i].mid         = 0.0;
         m_bins[i].volume      = 0.0;
         m_bins[i].pct         = 0.0;
         m_bins[i].inValueArea = false;
         m_bins[i].hvn         = false;
         m_bins[i].lvn         = false;
      }
   }

   bool   IsReady()       const { return m_ready; }
   int    BinCount()      const { return m_binCount; }
   double Poc()           const { return m_poc; }
   double Vah()           const { return m_vah; }
   double Val()           const { return m_val; }
   double TotalVolume()   const { return m_totalVolume; }
   double BinSize()       const { return m_binSize; }
   double ProfileLow()    const { return m_profileLow; }
   double ProfileHigh()   const { return m_profileHigh; }
   double ValueAreaPct()  const { return m_valueAreaPct; }
   int    BarsUsed()      const { return m_barsUsed; }
   datetime From()        const { return m_from; }
   datetime To()          const { return m_to; }

   bool GetBin(const int index, SQSMCProfileBin &out) const
   {
      if(index < 0 || index >= m_binCount) return false;
      out = m_bins[index];
      return true;
   }

   //+---------------------------------------------------------------+
   //| Build the profile.                                              |
   //+---------------------------------------------------------------+
   bool Build(const CQSMCMarketSnapshot &snap,
              const int slot,
              const int lookback,
              const int bins,
              const double valueAreaPct)
   {
      Reset();
      if(bins < 10 || bins > QSMC_MAX_PROFILE_BINS) return false;
      if(valueAreaPct <= 0.0 || valueAreaPct >= 100.0) return false;

      const int newest = snap.NewestIndex();
      int window = MathMin(lookback, snap.BarCount(slot) - newest);
      if(window < 20) return false;

      double hi = snap.HighestHigh(slot, newest, window);
      double lo = snap.LowestLow(slot, newest, window);
      double range = hi - lo;
      if(range <= QSMC_EPSILON) return false;

      m_binCount     = bins;
      m_profileLow   = lo;
      m_profileHigh  = hi;
      m_binSize      = range / (double)bins;
      m_valueAreaPct = valueAreaPct;
      m_barsUsed     = window;
      m_from         = snap.BarTime(slot, newest + window - 1);
      m_to           = snap.BarTime(slot, newest);

      for(int b = 0; b < m_binCount; b++)
      {
         m_bins[b].low         = m_profileLow + m_binSize * (double)b;
         m_bins[b].high        = (b == m_binCount - 1 ? m_profileHigh
                                                      : m_bins[b].low + m_binSize);
         m_bins[b].mid         = (m_bins[b].low + m_bins[b].high) * 0.5;
         m_bins[b].volume      = 0.0;
         m_bins[b].pct         = 0.0;
         m_bins[b].inValueArea = false;
         m_bins[b].hvn         = false;
         m_bins[b].lvn         = false;
      }

      //--- distribute volume -------------------------------------------
      double total = 0.0;
      for(int i = newest; i < newest + window; i++)
      {
         double vol = (double)snap.Volume(slot, i);
         if(vol < 0.0) vol = 0.0;

         double barLo = snap.Low(slot, i);
         double barHi = snap.High(slot, i);

         int b1 = BinIndex(barLo);
         int b2 = BinIndex(barHi);
         if(b2 < b1) { int t = b1; b1 = b2; b2 = t; }

         int span = b2 - b1 + 1;
         double share = vol / (double)span;
         for(int b = b1; b <= b2; b++)
            m_bins[b].volume += share;

         total += vol;
      }

      //--- symbols without volume data: fall back to time-at-price -------
      if(total <= 0.0)
      {
         for(int j = newest; j < newest + window; j++)
         {
            int b1 = BinIndex(snap.Low(slot, j));
            int b2 = BinIndex(snap.High(slot, j));
            if(b2 < b1) { int t = b1; b1 = b2; b2 = t; }
            int span = b2 - b1 + 1;
            for(int b = b1; b <= b2; b++) m_bins[b].volume += 1.0 / (double)span;
            total += 1.0;
         }
      }

      if(total <= 0.0) { Reset(); return false; }
      m_totalVolume = total;

      double average = total / (double)m_binCount;
      int pocBin = 0;
      for(int b = 0; b < m_binCount; b++)
      {
         m_bins[b].pct = m_bins[b].volume / total * 100.0;
         m_bins[b].hvn = (m_bins[b].volume >= average * 1.5);
         m_bins[b].lvn = (m_bins[b].volume <= average * 0.5);
         if(m_bins[b].volume > m_bins[pocBin].volume) pocBin = b;
      }

      m_poc = m_bins[pocBin].mid;

      //--- value area: expand from the POC over the highest volumes -----
      bool used[QSMC_MAX_PROFILE_BINS];
      for(int u=0;u<QSMC_MAX_PROFILE_BINS;u++) used[u]=false;
      used[pocBin] = true;
      m_bins[pocBin].inValueArea = true;
      double accumulated = m_bins[pocBin].volume;
      double target = total * (m_valueAreaPct / 100.0);

      while(accumulated < target)
      {
         int bestBin = -1;
         // nearest unused neighbour above and below the current area
         for(int step = 1; step < m_binCount; step++)
         {
            int up   = pocBin + step;
            int down = pocBin - step;
            bool upOk   = (up   >= 0 && up   < m_binCount && !used[up]);
            bool downOk = (down >= 0 && down < m_binCount && !used[down]);
            if(!upOk && !downOk) break;

            if(upOk && (!downOk || m_bins[up].volume >= m_bins[down].volume))
            { bestBin = up; break; }
            if(downOk)
            { bestBin = down; break; }
         }

         if(bestBin < 0) break;
         used[bestBin] = true;
         m_bins[bestBin].inValueArea = true;
         accumulated += m_bins[bestBin].volume;
      }

      //--- VAH / VAL from the value area boundaries ---------------------
      int lowestVa  = -1;
      int highestVa = -1;
      for(int b = 0; b < m_binCount; b++)
      {
         if(!m_bins[b].inValueArea) continue;
         if(lowestVa  < 0) lowestVa  = b;
         highestVa = b;
      }
      m_val = (lowestVa  >= 0 ? m_bins[lowestVa].low   : m_profileLow);
      m_vah = (highestVa >= 0 ? m_bins[highestVa].high : m_profileHigh);

      m_ready = true;
      return true;
   }

   //--- price relative to the value area -----------------------------
   bool IsAboveValue(const double price) const { return (m_ready && price > m_vah); }
   bool IsBelowValue(const double price) const { return (m_ready && price < m_val); }
   bool IsInsideValue(const double price) const
   {
      return (m_ready && price >= m_val && price <= m_vah);
   }

   // 0 = at VAL, 1 = at VAH (clamped).
   double ValuePosition(const double price) const
   {
      double span = m_vah - m_val;
      if(!m_ready || span <= QSMC_EPSILON) return 0.5;
      double p = (price - m_val) / span;
      if(p < 0.0) p = 0.0;
      if(p > 1.0) p = 1.0;
      return p;
   }

   // Nearest high-volume node to `price`, optionally restricted to nodes
   // strictly above/below the price (0 = unrestricted).
   bool NearestHvn(const double price, const int side, double &level) const
   {
      bool found = false;
      double best = 0.0;
      for(int b = 0; b < m_binCount; b++)
      {
         if(!m_bins[b].hvn) continue;
         if(side > 0 && m_bins[b].mid <= price) continue;
         if(side < 0 && m_bins[b].mid >= price) continue;

         double dist = MathAbs(m_bins[b].mid - price);
         if(!found || dist < best) { found = true; best = dist; level = m_bins[b].mid; }
      }
      return found;
   }

   string Describe() const
   {
      if(!m_ready) return "svp: not ready";
      return StringFormat("svp bins=%d bars=%d poc=%.5f vah=%.5f val=%.5f vol=%.0f",
                          m_binCount, m_barsUsed, m_poc, m_vah, m_val, m_totalVolume);
   }
};

#endif // QSMC_SVPCORE_MQH
