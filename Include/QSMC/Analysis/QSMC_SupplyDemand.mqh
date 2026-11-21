//+------------------------------------------------------------------+
//|                                             QSMC_SupplyDemand.mqh |
//|  Explicit contract facade for supply/demand.  It delegates zone     |
//|  construction to CQSMCZones and returns a bounded copy set.         |
//|  The formation heuristic (swing + >=0.6 ATR opposite displacement)  |
//|  is a transparent model choice, not an asserted QSMC strategy rule.  |
//+------------------------------------------------------------------+
#ifndef QSMC_SUPPLYDEMAND_MQH
#define QSMC_SUPPLYDEMAND_MQH

#include "QSMC_Zones.mqh"

struct SQSMCSupplyDemandSet
{
   int       count;
   SQSMCZone zones[QSMC_MAX_ZONES];
   string    diagnostic;

   void Reset()
   {
      count = 0;
      diagnostic = "";
      for(int i = 0; i < QSMC_MAX_ZONES; i++) zones[i].Reset();
   }
};

class CQSMCSupplyDemand
{
public:
   static bool Build(const CQSMCMarketSnapshot &snap,
                     const CQSMCStructure &structure,
                     const int slot, const int lookback,
                     const double tolerance, const double atr,
                     SQSMCSupplyDemandSet &out)
   {
      out.Reset();
      CQSMCZones zones;
      if(!zones.Build(snap, structure, slot, lookback, tolerance, atr))
      {
         out.diagnostic = "no supply/demand or clustered S/R zones";
         return false;
      }
      out.count = zones.Count();
      for(int i = 0; i < out.count; i++) zones.Get(i, out.zones[i]);
      out.diagnostic = zones.Describe();
      return true;
   }
};

#endif // QSMC_SUPPLYDEMAND_MQH
