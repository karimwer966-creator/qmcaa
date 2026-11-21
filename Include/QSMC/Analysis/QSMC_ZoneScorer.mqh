//+------------------------------------------------------------------+
//|                                               QSMC_ZoneScorer.mqh |
//|  Zone ranking.  Every term is explicit and bounded so the final     |
//|  score is auditable from the dashboard/log.                         |
//|                                                                     |
//|  score = base 0.30                                                  |
//|        + bias alignment            0.20                             |
//|        + displacement quality      0.15                             |
//|        + freshness (age < 20)      0.15                             |
//|        + proximity to price        0.15  (0.20 when inside)          |
//|        + touch count               0.05 / 0.10                      |
//|        - over-touched (> 4)        0.10                             |
//|        - mitigated                 0.40                             |
//+------------------------------------------------------------------+
#ifndef QSMC_ZONESCORER_MQH
#define QSMC_ZONESCORER_MQH

#include "../Core/QSMC_Types.mqh"
#include "../Data/QSMC_MarketSnapshot.mqh"
#include "QSMC_Zones.mqh"

class CQSMCZoneScorer
{
public:
   static double Score(const SQSMCZone &zone,
                       const CQSMCMarketSnapshot &snap,
                       const ENUM_QSMC_BIAS bias,
                       const double price,
                       const double atr)
   {
      double score = 0.30;

      //--- bias alignment ---------------------------------------------
      bool demandLike = zone.IsDemandLike();
      if((demandLike && bias == QSMC_BIAS_BULLISH) ||
         (!demandLike && bias == QSMC_BIAS_BEARISH))
         score += 0.20;
      else if(bias != QSMC_BIAS_NEUTRAL)
         score -= 0.10;

      //--- displacement quality ---------------------------------------
      if(zone.displacement >= 1.0)      score += 0.15;
      else if(zone.displacement >= 0.6) score += 0.08;

      //--- freshness ---------------------------------------------------
      if(zone.ageBars <= 20)       score += 0.15;
      else if(zone.ageBars <= 60)  score += 0.07;

      //--- proximity ----------------------------------------------------
      if(atr > QSMC_EPSILON)
      {
         if(zone.Contains(price))
         {
            score += 0.20;
         }
         else
         {
            double distance = 0.0;
            if(demandLike) distance = MathMax(0.0, price - zone.top);
            else           distance = MathMax(0.0, zone.bottom - price);
            double atrDistance = distance / atr;
            if(atrDistance <= 1.0)      score += 0.15;
            else if(atrDistance <= 2.5) score += 0.07;
            else                        score -= 0.05;
         }
      }

      //--- interaction history ------------------------------------------
      if(zone.touches == 1)      score += 0.05;
      else if(zone.touches == 2) score += 0.10;
      else if(zone.touches > 4)  score -= 0.10;

      //--- mitigation ----------------------------------------------------
      if(zone.mitigated) score -= 0.40;

      if(score < 0.0) score = 0.0;
      if(score > 1.0) score = 1.0;
      return score;
   }

   // Convenience: score in place and return it.
   static double Apply(SQSMCZone &zone,
                       const CQSMCMarketSnapshot &snap,
                       const ENUM_QSMC_BIAS bias,
                       const double price,
                       const double atr)
   {
      zone.score = Score(zone, snap, bias, price, atr);
      return zone.score;
   }
};

#endif // QSMC_ZONESCORER_MQH
