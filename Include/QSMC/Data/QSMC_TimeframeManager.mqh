//+------------------------------------------------------------------+
//|                                          QSMC_TimeframeManager.mqh |
//|  Timeframe arithmetic and ordering rules, in one place.            |
//+------------------------------------------------------------------+
#ifndef QSMC_TIMEFRAMEMANAGER_MQH
#define QSMC_TIMEFRAMEMANAGER_MQH

#include "../Core/QSMC_Types.mqh"

class CQSMCTimeframeManager
{
public:
   static bool IsValid(const ENUM_TIMEFRAMES tf)
   {
      return (tf != PERIOD_CURRENT && PeriodSeconds(tf) > 0);
   }

   static int Seconds(const ENUM_TIMEFRAMES tf)
   {
      return (int)PeriodSeconds(tf);
   }

   static string Name(const ENUM_TIMEFRAMES tf)
   {
      return QSMC_TfToString(tf);
   }

   // htf > exec > ltf, all distinct and valid.
   static bool ValidateOrdering(const ENUM_TIMEFRAMES htf,
                                const ENUM_TIMEFRAMES exec,
                                const ENUM_TIMEFRAMES ltf,
                                string &err)
   {
      err = "";
      if(!IsValid(htf) || !IsValid(exec) || !IsValid(ltf))
      {
         err = "timeframe: invalid value";
         return false;
      }
      if(Seconds(htf) <= Seconds(exec))
      {
         err = "timeframe: htf must be strictly higher than exec";
         return false;
      }
      if(Seconds(ltf) >= Seconds(exec))
      {
         err = "timeframe: ltf must be strictly lower than exec";
         return false;
      }
      if(htf == ltf)
      {
         err = "timeframe: htf and ltf must differ";
         return false;
      }
      return true;
   }

   // How many bars of `tf` fit into `seconds`.
   static int BarsForSpan(const ENUM_TIMEFRAMES tf, const int seconds)
   {
      int s = Seconds(tf);
      if(s <= 0 || seconds <= 0) return 0;
      return seconds / s;
   }

   // Human readable label for the chart's current period.
   static string ChartPeriodName()
   {
      return QSMC_TfToString((ENUM_TIMEFRAMES)Period());
   }

   static bool ChartMatches(const ENUM_TIMEFRAMES tf)
   {
      return (Period() == (int)tf);
   }
};

#endif // QSMC_TIMEFRAMEMANAGER_MQH
