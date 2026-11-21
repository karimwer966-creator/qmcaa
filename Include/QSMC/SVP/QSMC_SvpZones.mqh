//+------------------------------------------------------------------+
//|                                                  QSMC_SvpZones.mqh |
//|  Converts high-volume nodes into support/resistance style zones so   |
//|  that SVP evidence can enter the same zone-ranking pipeline as       |
//|  structure-derived supply/demand zones.                              |
//+------------------------------------------------------------------+
#ifndef QSMC_SVPZONES_MQH
#define QSMC_SVPZONES_MQH

#include "../Core/QSMC_Constants.mqh"
#include "../Core/QSMC_Types.mqh"
#include "../Analysis/QSMC_Zones.mqh"
#include "QSMC_SvpCore.mqh"

class CQSMCSvpZones
{
private:
   SQSMCZone m_zones[QSMC_MAX_ZONES];
   int       m_count;
   double    m_atr;

public:
   CQSMCSvpZones() { Reset(); }

   void Reset()
   {
      m_count = 0;
      m_atr   = 0.0;
      for(int i = 0; i < QSMC_MAX_ZONES; i++) m_zones[i].Reset();
   }

   int    Count() const { return m_count; }
   double Atr()   const { return m_atr; }

   bool Get(const int index, SQSMCZone &out) const
   {
      if(index < 0 || index >= m_count) return false;
      out = m_zones[index];
      return true;
   }

   //+---------------------------------------------------------------+
   //| Cluster consecutive HVN bins into zones.                        |
   //+---------------------------------------------------------------+
   bool Build(const CQSMCSvpCore &core, const double price, const double atr)
   {
      Reset();
      if(!core.IsReady() || price <= 0.0) return false;

      m_atr = atr;

      int firstHvn = -1;
      int lastHvn  = -1;
      double volumeSum = 0.0;
      SQSMCProfileBin bin;

      for(int b = 0; b <= core.BinCount(); b++)
      {
         bool isHvn = false;
         if(b < core.BinCount() && core.GetBin(b, bin))
         {
            isHvn = bin.hvn;
            if(isHvn)
            {
               if(firstHvn < 0) firstHvn = b;
               lastHvn   = b;
               volumeSum += bin.pct;
            }
         }

         bool flush = (!isHvn && firstHvn >= 0);
         if(flush && m_count < QSMC_MAX_ZONES)
         {
            SQSMCProfileBin loBin, hiBin;
            if(core.GetBin(firstHvn, loBin) && core.GetBin(lastHvn, hiBin))
            {
               SQSMCZone zone;
               zone.Reset();
               zone.bottom = loBin.low;
               zone.top    = hiBin.high;
               zone.type   = (zone.Mid() <= price ? QSMC_ZONE_SUPPORT
                                                  : QSMC_ZONE_RESISTANCE);
               zone.bias   = (zone.type == QSMC_ZONE_SUPPORT ? QSMC_BIAS_BULLISH
                                                             : QSMC_BIAS_BEARISH);
               zone.created      = core.To();
               zone.createdShift = 0;
               zone.touches      = 1;
               zone.ageBars      = 0;
               zone.mitigated    = false;
               zone.displacement = 0.0;
               // value-area nodes are strong evidence; convert % share to 0..1
               zone.score        = MathMin(1.0, 0.35 + volumeSum / 20.0);
               zone.origin       = "SVP HVN cluster";
               zone.id           = m_count + 1;
               m_zones[m_count]  = zone;
               m_count++;
            }
            firstHvn  = -1;
            lastHvn   = -1;
            volumeSum = 0.0;
         }
      }

      return (m_count > 0);
   }

   // Nearest SVP zone containing or surrounding the price.
   bool ZoneAt(const double price, SQSMCZone &out) const
   {
      for(int i = 0; i < m_count; i++)
         if(m_zones[i].Contains(price)) { out = m_zones[i]; return true; }
      return false;
   }

   bool HasConfluence(const double zoneBottom, const double zoneTop,
                      double &bestScore) const
   {
      bestScore = 0.0;
      bool found = false;
      for(int i = 0; i < m_count; i++)
      {
         double overlapTop = MathMin(m_zones[i].top, zoneTop);
         double overlapBottom = MathMax(m_zones[i].bottom, zoneBottom);
         if(overlapTop <= overlapBottom) continue;
         found = true;
         if(m_zones[i].score > bestScore) bestScore = m_zones[i].score;
      }
      return found;
   }

   string Describe() const
   {
      return StringFormat("svp zones=%d", m_count);
   }
};

#endif // QSMC_SVPZONES_MQH
