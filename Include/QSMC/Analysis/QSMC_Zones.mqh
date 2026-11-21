//+------------------------------------------------------------------+
//|                                                    QSMC_Zones.mqh |
//|  Supply/demand zones derived from confirmed swings plus a           |
//|  displacement filter, and support/resistance zones from clustered   |
//|  swing extremes.  Zones are plain data; scoring lives in            |
//|  ZoneScorer so that the zone model and the ranking model can be     |
//|  replaced independently.                                            |
//+------------------------------------------------------------------+
#ifndef QSMC_ZONES_MQH
#define QSMC_ZONES_MQH

#include "../Core/QSMC_Constants.mqh"
#include "../Core/QSMC_Types.mqh"
#include "../Data/QSMC_MarketSnapshot.mqh"
#include "QSMC_Structure.mqh"
#include "QSMC_CandlePatterns.mqh"

enum ENUM_QSMC_ZONE_TYPE
{
   QSMC_ZONE_SUPPLY    = 0,
   QSMC_ZONE_DEMAND    = 1,
   QSMC_ZONE_SUPPORT   = 2,
   QSMC_ZONE_RESISTANCE= 3
};

struct SQSMCZone
{
   int                 id;
   ENUM_QSMC_ZONE_TYPE type;
   double              top;
   double              bottom;
   datetime            created;
   int                 createdShift;
   int                 touches;
   int                 ageBars;
   bool                mitigated;
   double              displacement;   // ATR multiples of the origin impulse
   double              score;          // filled by CQSMCZoneScorer
   ENUM_QSMC_BIAS      bias;
   string              origin;

   void Reset()
   {
      id           = 0;
      type         = QSMC_ZONE_SUPPORT;
      top          = 0.0;
      bottom       = 0.0;
      created      = 0;
      createdShift = 0;
      touches      = 0;
      ageBars      = 0;
      mitigated    = false;
      displacement = 0.0;
      score        = 0.0;
      bias         = QSMC_BIAS_NEUTRAL;
      origin       = "";
   }

   double Mid()    const { return (top + bottom) * 0.5; }
   double Height() const { return MathMax(0.0, top - bottom); }
   bool   IsDemandLike() const
   {
      return (type == QSMC_ZONE_DEMAND || type == QSMC_ZONE_SUPPORT);
   }
   bool   IsSupplyLike() const
   {
      return (type == QSMC_ZONE_SUPPLY || type == QSMC_ZONE_RESISTANCE);
   }
   bool   Contains(const double price) const
   {
      return (price >= bottom - QSMC_EPSILON && price <= top + QSMC_EPSILON);
   }
   string Name() const
   {
      switch(type)
      {
         case QSMC_ZONE_SUPPLY:     return "supply";
         case QSMC_ZONE_DEMAND:     return "demand";
         case QSMC_ZONE_SUPPORT:    return "support";
         case QSMC_ZONE_RESISTANCE: return "resistance";
      }
      return "zone";
   }
};

class CQSMCZones
{
private:
   SQSMCZone m_zones[QSMC_MAX_ZONES];
   int       m_count;
   int       m_lookback;
   double    m_atr;

   bool OverlapsSameType(const SQSMCZone &a, const SQSMCZone &b) const
   {
      if(a.type != b.type) return false;
      double overlapTop = MathMin(a.top, b.top);
      double overlapBot = MathMax(a.bottom, b.bottom);
      if(overlapTop <= overlapBot) return false;
      double smaller = MathMin(a.Height(), b.Height());
      if(smaller <= QSMC_EPSILON) return false;
      return ((overlapTop - overlapBot) / smaller > 0.6);
   }

   void AddOrMerge(const SQSMCZone &zone)
   {
      for(int i = 0; i < m_count; i++)
      {
         if(!OverlapsSameType(m_zones[i], zone)) continue;
         // keep the newer zone geometry, accumulate interaction history
         m_zones[i].top          = zone.top;
         m_zones[i].bottom       = zone.bottom;
         m_zones[i].created      = zone.created;
         m_zones[i].createdShift = zone.createdShift;
         m_zones[i].ageBars      = zone.ageBars;
         m_zones[i].displacement = MathMax(m_zones[i].displacement, zone.displacement);
         m_zones[i].touches      = MathMax(m_zones[i].touches, zone.touches) + 1;
         m_zones[i].origin       = zone.origin;
         return;
      }

      if(m_count >= QSMC_MAX_ZONES) return;
      m_zones[m_count]        = zone;
      m_zones[m_count].id     = m_count + 1;
      m_count++;
   }

   int CountTouches(const CQSMCMarketSnapshot &snap, const int slot,
                    const int fromIndex, const double top, const double bottom,
                    const bool demandLike, bool &mitigated) const
   {
      int touches  = 0;
      bool inside  = false;
      mitigated    = false;

      for(int i = fromIndex - 1; i >= snap.NewestIndex(); i--)
      {
         double lo = snap.Low(slot, i);
         double hi = snap.High(slot, i);
         double cl = snap.Close(slot, i);

         if(lo <= top + QSMC_EPSILON && hi >= bottom - QSMC_EPSILON)
         {
            if(!inside) { touches++; inside = true; }
         }
         else
         {
            inside = false;
         }

         if(demandLike && cl < bottom - QSMC_EPSILON) { mitigated = true; break; }
         if(!demandLike && cl > top + QSMC_EPSILON)   { mitigated = true; break; }
      }

      return touches;
   }

public:
   CQSMCZones() { Reset(); }

   void Reset()
   {
      m_count    = 0;
      m_lookback = 0;
      m_atr      = 0.0;
      for(int i = 0; i < QSMC_MAX_ZONES; i++) m_zones[i].Reset();
   }

   int Count()      const { return m_count; }
   double Atr()     const { return m_atr; }
   int Lookback()   const { return m_lookback; }

   bool Get(const int index, SQSMCZone &out) const
   {
      if(index < 0 || index >= m_count) return false;
      out = m_zones[index];
      return true;
   }

   // Cache a computed score on the stored zone (scoring itself lives in
   // CQSMCZoneScorer so the ranking model stays replaceable).
   bool ApplyScore(const int index, const double score)
   {
      if(index < 0 || index >= m_count) return false;
      m_zones[index].score = score;
      return true;
   }

   //+---------------------------------------------------------------+
   //| Build zones from structure.  Returns false when there is not    |
   //| enough data or no valid zone.                                   |
   //+---------------------------------------------------------------+
   bool Build(const CQSMCMarketSnapshot &snap,
              const CQSMCStructure &structure,
              const int slot,
              const int lookback,
              const double tolerancePrice,
              const double atr)
   {
      Reset();
      if(atr <= 0.0 || lookback < 20) return false;
      if(structure.Count() <= 0) return false;

      m_lookback = lookback;
      m_atr      = atr;

      const int newest = snap.NewestIndex();
      SQSMCStructurePoint point;

      for(int p = 0; p < structure.Count(); p++)
      {
         if(!structure.Get(p, point)) continue;
         if(point.shift > lookback) continue;

         bool isHigh = (point.type == QSMC_SWING_HIGH);

         //--- locate a displacement candle within 3 bars after the swing
         double bestDisp = 0.0;
         int    dispIdx  = -1;
         for(int k = point.shift - 1; k >= MathMax(newest, point.shift - 3); k--)
         {
            double body = CQSMCCandlePatterns::Body(snap, slot, k);
            if(body <= 0.0) continue;
            bool aligned = isHigh ? CQSMCCandlePatterns::IsBearish(snap, slot, k)
                                  : CQSMCCandlePatterns::IsBullish(snap, slot, k);
            if(!aligned) continue;
            double ratio = body / atr;
            if(ratio > bestDisp) { bestDisp = ratio; dispIdx = k; }
         }

         if(dispIdx < 0 || bestDisp < 0.6) continue;   // no impulse: not a zone

         SQSMCZone zone;
         zone.Reset();
         zone.created      = point.time;
         zone.createdShift = point.shift;
         zone.displacement = bestDisp;

         if(isHigh)
         {
            zone.type   = QSMC_ZONE_SUPPLY;
            zone.top    = point.price;
            zone.bottom = point.price - MathMax(atr * 0.5, point.price * 0.0002);
            zone.bias   = QSMC_BIAS_BEARISH;
            zone.origin = "swing high + bearish displacement";
         }
         else
         {
            zone.type   = QSMC_ZONE_DEMAND;
            zone.top    = point.price + MathMax(atr * 0.5, point.price * 0.0002);
            zone.bottom = point.price;
            zone.bias   = QSMC_BIAS_BULLISH;
            zone.origin = "swing low + bullish displacement";
         }

         bool mitigated = false;
         int touches = CountTouches(snap, slot, point.shift, zone.top, zone.bottom,
                                    zone.IsDemandLike(), mitigated);
         zone.touches   = touches;
         zone.ageBars   = MathMax(0, point.shift - newest);
         zone.mitigated = mitigated;

         AddOrMerge(zone);
      }

      //--- clustered swing extremes -> support / resistance -------------
      SQSMCStructurePoint a, b;
      for(int i = 0; i < structure.Count() && m_count < QSMC_MAX_ZONES; i++)
      {
         if(!structure.Get(i, a)) continue;
         for(int j = i + 1; j < structure.Count(); j++)
         {
            if(!structure.Get(j, b)) continue;
            if(a.type != b.type) continue;
            if(MathAbs(a.price - b.price) > tolerancePrice) continue;

            SQSMCZone zone;
            zone.Reset();
            zone.type         = (a.type == QSMC_SWING_HIGH ? QSMC_ZONE_RESISTANCE
                                                           : QSMC_ZONE_SUPPORT);
            zone.top          = MathMax(a.price, b.price);
            zone.bottom       = MathMin(a.price, b.price);
            if(zone.Height() <= QSMC_EPSILON)
            {
               zone.top    += tolerancePrice * 0.05;
               zone.bottom -= tolerancePrice * 0.05;
            }
            zone.created      = MathMax(a.time, b.time);
            zone.createdShift = MathMin(a.shift, b.shift);
            zone.bias         = (a.type == QSMC_SWING_HIGH ? QSMC_BIAS_BEARISH
                                                           : QSMC_BIAS_BULLISH);
            zone.displacement = 0.0;
            zone.ageBars      = MathMax(0, zone.createdShift - newest);
            zone.origin       = "swing cluster (" + IntegerToString(j - i) + ")";

            bool mitigated = false;
            zone.touches   = CountTouches(snap, slot, zone.createdShift, zone.top,
                                          zone.bottom, zone.IsDemandLike(), mitigated) + 1;
            zone.mitigated = mitigated;

            AddOrMerge(zone);
            if(m_count >= QSMC_MAX_ZONES) break;
         }
      }

      return (m_count > 0);
   }

   //+---------------------------------------------------------------+
   //| Nearest unmitigated demand-like zone at or below `price`.       |
   //+---------------------------------------------------------------+
   bool NearestDemand(const double price, SQSMCZone &out, double &distance) const
   {
      bool found = false;
      distance = 0.0;
      for(int i = 0; i < m_count; i++)
      {
         if(!m_zones[i].IsDemandLike() || m_zones[i].mitigated) continue;
         if(m_zones[i].Contains(price)) { out=m_zones[i]; distance=0.0; return true; }
         if(m_zones[i].top > price + QSMC_EPSILON) continue;   // price already below

         double dist = price - m_zones[i].top;
         if(!found || dist < distance)
         {
            found    = true;
            distance = dist;
            out      = m_zones[i];
         }
      }
      return found;
   }

   //+---------------------------------------------------------------+
   //| Nearest unmitigated supply-like zone at or above `price`.       |
   //+---------------------------------------------------------------+
   bool NearestSupply(const double price, SQSMCZone &out, double &distance) const
   {
      bool found = false;
      distance = 0.0;
      for(int i = 0; i < m_count; i++)
      {
         if(!m_zones[i].IsSupplyLike() || m_zones[i].mitigated) continue;
         if(m_zones[i].Contains(price)) { out=m_zones[i]; distance=0.0; return true; }
         if(m_zones[i].bottom < price - QSMC_EPSILON) continue; // price already above

         double dist = m_zones[i].bottom - price;
         if(!found || dist < distance)
         {
            found    = true;
            distance = dist;
            out      = m_zones[i];
         }
      }
      return found;
   }

   //+---------------------------------------------------------------+
   //| Zone containing the price, if any.                              |
   //+---------------------------------------------------------------+
   bool ZoneAt(const double price, SQSMCZone &out) const
   {
      for(int i = 0; i < m_count; i++)
      {
         if(m_zones[i].mitigated) continue;
         if(m_zones[i].Contains(price)) { out = m_zones[i]; return true; }
      }
      return false;
   }

   string Describe() const
   {
      int supply = 0, demand = 0, sr = 0;
      for(int i = 0; i < m_count; i++)
      {
         if(m_zones[i].type == QSMC_ZONE_SUPPLY) supply++;
         else if(m_zones[i].type == QSMC_ZONE_DEMAND) demand++;
         else sr++;
      }
      return StringFormat("zones=%d (supply=%d demand=%d s/r=%d)",
                          m_count, supply, demand, sr);
   }
};

#endif // QSMC_ZONES_MQH
