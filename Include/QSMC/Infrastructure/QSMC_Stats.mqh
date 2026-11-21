//+------------------------------------------------------------------+
//|                                                    QSMC_Stats.mqh |
//|  Monotonic runtime counters.  Used for diagnostics, the dashboard  |
//|  footer and the self-test.  No logic depends on these values.      |
//+------------------------------------------------------------------+
#ifndef QSMC_STATS_MQH
#define QSMC_STATS_MQH

#include "../Core/QSMC_Types.mqh"

class CQSMCStats
{
private:
   datetime m_since;

public:
   long ticks;
   long timerTicks;
   long newBars;
   long scans;
   long candidates;
   long rejections;
   long decisions;
   long noTrades;
   long preflightOk;
   long preflightRejected;
   long safetyBlocked;
   long ordersSubmitted;
   long ordersFilled;
   long ordersRejected;
   long duplicatesBlocked;
   long errors;
   long safeModeEntries;
   long incidents;

   CQSMCStats() { Reset(); }

   void Reset()
   {
      m_since           = TimeCurrent();
      ticks             = 0;
      timerTicks        = 0;
      newBars           = 0;
      scans             = 0;
      candidates        = 0;
      rejections        = 0;
      decisions         = 0;
      noTrades          = 0;
      preflightOk       = 0;
      preflightRejected = 0;
      safetyBlocked     = 0;
      ordersSubmitted   = 0;
      ordersFilled      = 0;
      ordersRejected    = 0;
      duplicatesBlocked = 0;
      errors            = 0;
      safeModeEntries   = 0;
      incidents         = 0;
   }

   datetime Since() const { return m_since; }

   string Report() const
   {
      return StringFormat("ticks=%d bars=%d scans=%d cand=%d rej=%d dec=%d noTrade=%d pf=%d pfr=%d safe=%d ord=%d/%d/%d dup=%d err=%d",
                          (int)ticks, (int)newBars, (int)scans, (int)candidates,
                          (int)rejections, (int)decisions, (int)noTrades,
                          (int)preflightOk, (int)preflightRejected,
                          (int)safetyBlocked, (int)ordersSubmitted,
                          (int)ordersFilled, (int)ordersRejected,
                          (int)duplicatesBlocked, (int)errors);
   }

   string ReportMultiline() const
   {
      return "ticks=" + IntegerToString(ticks) +
             " timer=" + IntegerToString(timerTicks) +
             " newBars=" + IntegerToString(newBars) +
             "\nscans=" + IntegerToString(scans) +
             " candidates=" + IntegerToString(candidates) +
             " rejections=" + IntegerToString(rejections) +
             " decisions=" + IntegerToString(decisions) +
             " noTrade=" + IntegerToString(noTrades) +
             "\npreflight ok/rej=" + IntegerToString(preflightOk) + "/" +
             IntegerToString(preflightRejected) +
             " safetyBlocked=" + IntegerToString(safetyBlocked) +
             "\norders submitted/filled/rejected=" + IntegerToString(ordersSubmitted) +
             "/" + IntegerToString(ordersFilled) + "/" + IntegerToString(ordersRejected) +
             " duplicates=" + IntegerToString(duplicatesBlocked) +
             "\nerrors=" + IntegerToString(errors) +
             " incidents=" + IntegerToString(incidents) +
             " safeMode=" + IntegerToString(safeModeEntries);
   }
};

#endif // QSMC_STATS_MQH
