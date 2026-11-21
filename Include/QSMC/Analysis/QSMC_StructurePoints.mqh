//+------------------------------------------------------------------+
//|                                           QSMC_StructurePoints.mqh |
//|  Contract-focused facade for confirmed swing extraction.            |
//|  CQSMCStructure owns the canonical algorithm; this facade exposes   |
//|  a stable output set for tests and downstream modules.               |
//+------------------------------------------------------------------+
#ifndef QSMC_STRUCTUREPOINTS_MQH
#define QSMC_STRUCTUREPOINTS_MQH

#include "QSMC_Structure.mqh"

struct SQSMCStructureSet
{
   int                 count;
   SQSMCStructurePoint points[QSMC_MAX_STRUCT_POINTS];
   double              lastHigh;
   double              lastLow;
   string              diagnostic;

   void Reset()
   {
      count = 0;
      lastHigh = 0.0;
      lastLow = 0.0;
      diagnostic = "";
      for(int i = 0; i < QSMC_MAX_STRUCT_POINTS; i++)
      {
         points[i].time = 0;
         points[i].price = 0.0;
         points[i].shift = 0;
         points[i].type = QSMC_SWING_NONE;
         points[i].strength = 0;
      }
   }
};

class CQSMCStructurePoints
{
public:
   static bool Extract(const CQSMCMarketSnapshot &snap, const int slot,
                       const int lookback, const int left, const int right,
                       SQSMCStructureSet &out)
   {
      out.Reset();
      CQSMCStructure structure;
      if(!structure.Detect(snap, slot, lookback, left, right))
      {
         out.diagnostic = "structure points unavailable: insufficient bars or no confirmed swings";
         return false;
      }
      out.count = structure.Count();
      out.lastHigh = structure.LastSwingHigh();
      out.lastLow = structure.LastSwingLow();
      for(int i = 0; i < out.count; i++) structure.Get(i, out.points[i]);
      out.diagnostic = structure.Describe();
      return true;
   }
};

#endif // QSMC_STRUCTUREPOINTS_MQH
