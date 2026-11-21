#ifndef QSMC_CONFIG_MQH
#define QSMC_CONFIG_MQH

#include "QSMC_Constants.mqh"
#include "QSMC_Types.mqh"

struct SQSMCConfig
{
   ENUM_QSMC_MODE       mode;
   ENUM_QSMC_PRESET     preset;
   ENUM_QSMC_LOG_LEVEL  log_level;

   string               symbol;
   ENUM_TIMEFRAMES      exec_tf;
   ENUM_TIMEFRAMES      htf;
   ENUM_TIMEFRAMES      ltf;

   int                  timer_ms;
   double               risk_percent;
   double               max_daily_loss_pct;
   int                  max_spread_points;
   int                  max_positions;
   long                 magic_offset;

   bool                 enable_dashboard;
   bool                 enable_chart_layers;

   void SetDefaults()
   {
      mode                = QSMC_MODE_ANALYSIS;
      preset              = QSMC_PRESET_BALANCED;
      log_level           = QSMC_LOG_INFO;
      symbol              = _Symbol;
      exec_tf             = PERIOD_M15;
      htf                 = PERIOD_H4;
      ltf                 = PERIOD_M5;
      timer_ms            = QSMC_TIMER_DEFAULT_MS;
      risk_percent        = 0.5;
      max_daily_loss_pct  = 2.0;
      max_spread_points   = 30;
      max_positions       = 1;
      magic_offset        = 0;
      enable_dashboard    = true;
      enable_chart_layers = true;
   }

   bool Validate(string &err) const
   {
      err = "";
      if(symbol == "")                         { err = "symbol is empty";               return false; }
      if(timer_ms < QSMC_TIMER_MIN_MS)         { err = "timer_ms too small";            return false; }
      if(risk_percent <= 0.0 || risk_percent > 10.0)
                                               { err = "risk_percent out of (0,10]";    return false; }
      if(max_daily_loss_pct <= 0.0 || max_daily_loss_pct > 50.0)
                                               { err = "max_daily_loss_pct invalid";    return false; }
      if(max_spread_points < 0)                { err = "max_spread_points negative";    return false; }
      if(max_positions < 1)                    { err = "max_positions < 1";             return false; }
      if(PeriodSeconds(htf) < PeriodSeconds(exec_tf))
                                               { err = "htf must be >= exec_tf";        return false; }
      if(PeriodSeconds(ltf) > PeriodSeconds(exec_tf))
                                               { err = "ltf must be <= exec_tf";        return false; }
      return true;
   }
};

#endif