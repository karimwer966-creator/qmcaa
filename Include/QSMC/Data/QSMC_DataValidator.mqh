//+------------------------------------------------------------------+
//|                                             QSMC_DataValidator.mqh |
//|  Structural validation of bar series and snapshots.  A failed      |
//|  validation must always mean "do not analyse, do not trade".       |
//+------------------------------------------------------------------+
#ifndef QSMC_DATAVALIDATOR_MQH
#define QSMC_DATAVALIDATOR_MQH

#include "../Core/QSMC_Types.mqh"
#include "QSMC_MarketSnapshot.mqh"

class CQSMCDataValidator
{
public:
   //+---------------------------------------------------------------+
   //| Bars are expected in series order (index 0 = newest).           |
   //+---------------------------------------------------------------+
   static bool ValidateBars(const MqlRates &rates[], const int count,
                            const string label, string &err)
   {
      err = "";
      if(count <= 0)
      {
         err = label + ": no bars";
         return false;
      }

      for(int i = 0; i < count; i++)
      {
         if(rates[i].high <= 0.0 || rates[i].low <= 0.0 ||
            rates[i].open <= 0.0 || rates[i].close <= 0.0)
         {
            err = label + ": non-positive price at bar " + IntegerToString(i);
            return false;
         }
         if(rates[i].high < rates[i].low)
         {
            err = label + ": high < low at bar " + IntegerToString(i);
            return false;
         }
         if(rates[i].high < rates[i].open - 1e-10 ||
            rates[i].high < rates[i].close - 1e-10 ||
            rates[i].low  > rates[i].open + 1e-10 ||
            rates[i].low  > rates[i].close + 1e-10)
         {
            err = label + ": OHLC relationship broken at bar " + IntegerToString(i);
            return false;
         }
         if(rates[i].time <= 0)
         {
            err = label + ": zero timestamp at bar " + IntegerToString(i);
            return false;
         }
         if(i > 0 && rates[i].time >= rates[i - 1].time)
         {
            err = label + ": timestamps not strictly decreasing at bar " + IntegerToString(i);
            return false;
         }
         if(rates[i].tick_volume < 0 || rates[i].real_volume < 0)
         {
            err = label + ": negative volume at bar " + IntegerToString(i);
            return false;
         }
      }
      return true;
   }

   //+---------------------------------------------------------------+
   //| Contract-level sanity for the snapshot used by analysis.        |
   //+---------------------------------------------------------------+
   static bool ValidateSnapshot(const CQSMCMarketSnapshot &snap, string &err)
   {
      err = "";
      if(!snap.IsUsable())
      {
         err = "snapshot: bid/ask/point missing or too few bars";
         return false;
      }

      if(snap.Ask() < snap.Bid())
      {
         err = "snapshot: ask below bid";
         return false;
      }

      if(snap.Point() <= 0.0)
      {
         err = "snapshot: invalid point size";
         return false;
      }

      if(snap.SpreadPoints() < 0)
      {
         err = "snapshot: negative spread";
         return false;
      }

      //--- each slot must carry a usable series and pass bar validation
      const int slots[3] = { QSMC_SNAP_EXEC, QSMC_SNAP_HTF, QSMC_SNAP_LTF };
      const string names[3] = { "exec", "htf", "ltf" };

      for(int s = 0; s < 3; s++)
      {
         int count = snap.BarCount(slots[s]);
         if(count < 20)
         {
            err = names[s] + ": fewer than 20 bars";
            return false;
         }

         MqlRates tmp[];
         ArrayResize(tmp, count);
         for(int i = 0; i < count; i++)
         {
            if(!snap.Bar(slots[s], i, tmp[i]))
            {
               err = names[s] + ": bar access failed";
               return false;
            }
         }
         if(!ValidateBars(tmp, count, names[s], err))
            return false;
      }

      return true;
   }

   // A bar is stale when it is older than `maxBarsBehind` periods.
   static bool IsBarStale(const datetime barTime, const ENUM_TIMEFRAMES tf,
                          const datetime now, const int maxBarsBehind,
                          int &barsBehind)
   {
      barsBehind = 0;
      int periodSeconds = (int)PeriodSeconds(tf);
      if(barTime <= 0 || periodSeconds <= 0) return true;

      long age = (long)now - (long)barTime;
      if(age < 0) return false;                   // clock skew: not stale
      barsBehind = (int)(age / periodSeconds);
      return (barsBehind > maxBarsBehind);
   }

   // Gap detection between consecutive bars (weekends excluded upstream).
   static bool HasGap(const MqlRates &rates[], const int count,
                      const ENUM_TIMEFRAMES tf, const int maxPeriodsPerGap)
   {
      int periodSeconds = (int)PeriodSeconds(tf);
      if(periodSeconds <= 0) return true;
      for(int i = 1; i < count; i++)
      {
         long delta = (long)rates[i - 1].time - (long)rates[i].time;
         if(delta > (long)periodSeconds * (long)maxPeriodsPerGap)
            return true;
      }
      return false;
   }
};

#endif // QSMC_DATAVALIDATOR_MQH
