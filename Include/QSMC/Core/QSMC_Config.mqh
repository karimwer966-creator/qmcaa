//+------------------------------------------------------------------+
//|                                                   QSMC_Config.mqh |
//|  Immutable-by-convention configuration object plus strict          |
//|  validation.  Every numeric boundary is enforced here so that no   |
//|  downstream module has to re-check ranges (they still re-check     |
//|  state and market conditions).                                     |
//+------------------------------------------------------------------+
#ifndef QSMC_CONFIG_MQH
#define QSMC_CONFIG_MQH

#include "QSMC_Constants.mqh"
#include "QSMC_Types.mqh"

struct SQSMCConfig
{
   //--- identity / behaviour
   ENUM_QSMC_MODE       mode;
   ENUM_QSMC_PRESET     preset;
   ENUM_QSMC_LOG_LEVEL  log_level;

   string               symbol;
   ENUM_TIMEFRAMES      exec_tf;
   ENUM_TIMEFRAMES      htf;
   ENUM_TIMEFRAMES      ltf;

   //--- runtime
   int                  timer_ms;
   bool                 enable_dashboard;
   bool                 enable_chart_layers;
   bool                 enable_log_file;
   bool                 use_closed_bars_only;
   string               real_ack;           // required token for REAL mode

   //--- risk (hard-capped)
   double               risk_percent;
   double               max_daily_loss_pct;
   int                  max_spread_points;  // 0 = no limit
   int                  max_positions;
   double               max_total_exposure_lots;
   int                  max_daily_trades;
   int                  cooldown_seconds;
   double               max_drawdown_pct;   // equity high-water guard

   //--- strategy parameters (documented heuristics, see ARCHITECTURE.md)
   int                  swing_left;
   int                  swing_right;
   int                  structure_lookback;
   int                  zone_lookback;
   int                  zone_tolerance_points;
   int                  svp_lookback;
   int                  svp_bins;
   double               svp_value_area_pct;
   double               sl_atr_mult;
   double               min_rr;
   double               tp_rr;
   double               min_confidence;     // 0..1
   int                  deviation_points;

   long                 magic_offset;
   int                  bars_back;

   //+---------------------------------------------------------------+
   //| Defaults: ANALYSIS mode, live trading impossible, safe values  |
   //+---------------------------------------------------------------+
   void SetDefaults()
   {
      mode                 = QSMC_MODE_ANALYSIS;
      preset               = QSMC_PRESET_BALANCED;
      log_level            = QSMC_LOG_INFO;

      symbol               = _Symbol;
      exec_tf              = PERIOD_M15;
      htf                  = PERIOD_H4;
      ltf                  = PERIOD_M5;

      timer_ms             = QSMC_TIMER_DEFAULT_MS;
      enable_dashboard     = true;
      enable_chart_layers  = true;
      enable_log_file      = false;
      use_closed_bars_only = true;
      real_ack             = "";

      risk_percent         = QSMC_RISK_DEFAULT_PERCENT;
      max_daily_loss_pct   = 2.0;
      max_spread_points    = 30;
      max_positions        = 1;
      max_total_exposure_lots = 2.0;
      max_daily_trades     = 5;
      cooldown_seconds     = 300;
      max_drawdown_pct     = 10.0;

      swing_left           = 2;
      swing_right          = 2;
      structure_lookback   = 300;
      zone_lookback        = 200;
      zone_tolerance_points= 150;
      svp_lookback         = 240;
      svp_bins             = 40;
      svp_value_area_pct   = 70.0;
      sl_atr_mult          = 1.5;
      min_rr               = 1.5;
      tp_rr                = 2.0;
      min_confidence       = 0.55;
      deviation_points     = 10;

      magic_offset         = 0;
      bars_back            = 600;
   }

   //+---------------------------------------------------------------+
   //| Full validation.  Returns false and a precise message.          |
   //+---------------------------------------------------------------+
   bool Validate(string &err) const
   {
      err = "";

      //--- mode -------------------------------------------------------
      if(mode != QSMC_MODE_OFF && mode != QSMC_MODE_ANALYSIS &&
         mode != QSMC_MODE_DEMO && mode != QSMC_MODE_REAL)
      { err = "mode: invalid value"; return false; }

      if(log_level < QSMC_LOG_DEBUG || log_level > QSMC_LOG_NONE)
      { err = "log_level: invalid value"; return false; }
      if(preset < QSMC_PRESET_CONSERVATIVE || preset > QSMC_PRESET_CUSTOM)
      { err = "preset: invalid value"; return false; }

      //--- symbol -----------------------------------------------------
      if(StringLen(symbol) == 0)
      { err = "symbol is empty"; return false; }

      if(SymbolInfoDouble(symbol, SYMBOL_POINT) <= 0.0)
      { err = "symbol is unknown to the terminal"; return false; }

      if(SymbolInfoInteger(symbol, SYMBOL_SELECT) == 0 &&
         !SymbolSelect(symbol, true))
      { err = "symbol is not available in Market Watch"; return false; }

      if((long)SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE) ==
         (long)SYMBOL_TRADE_MODE_DISABLED && mode != QSMC_MODE_ANALYSIS)
      { err = "symbol trading is disabled by the broker"; return false; }

      //--- timeframe ordering -----------------------------------------
      if(!QSMC_IsKnownTimeframe(exec_tf) || !QSMC_IsKnownTimeframe(htf) ||
         !QSMC_IsKnownTimeframe(ltf))
      { err = "timeframes: unknown timeframe value"; return false; }

      if(PeriodSeconds(htf) <= PeriodSeconds(exec_tf))
      { err = "htf must be strictly higher than exec_tf"; return false; }
      if(PeriodSeconds(ltf) >= PeriodSeconds(exec_tf))
      { err = "ltf must be strictly lower than exec_tf"; return false; }

      //--- runtime ----------------------------------------------------
      if(timer_ms < QSMC_TIMER_MIN_MS || timer_ms > QSMC_TIMER_MAX_MS)
      { err = "timer_ms outside [100,60000]"; return false; }

      if(bars_back < 100 || bars_back > QSMC_MAX_BARS)
      { err = "bars_back outside [100," + IntegerToString(QSMC_MAX_BARS) + "]"; return false; }

      if(structure_lookback < 50 || structure_lookback > bars_back)
      { err = "structure_lookback must be in [50,bars_back]"; return false; }

      if(zone_lookback < 50 || zone_lookback > bars_back)
      { err = "zone_lookback must be in [50,bars_back]"; return false; }

      if(svp_lookback < 50 || svp_lookback > bars_back)
      { err = "svp_lookback must be in [50,bars_back]"; return false; }

      if(svp_bins < 10 || svp_bins > QSMC_MAX_PROFILE_BINS)
      { err = "svp_bins outside [10," + IntegerToString(QSMC_MAX_PROFILE_BINS) + "]"; return false; }

      if(svp_value_area_pct <= 0.0 || svp_value_area_pct >= 100.0)
      { err = "svp_value_area_pct must be in (0,100)"; return false; }

      //--- all floating-point inputs must be finite ------------------
      if(!MathIsValidNumber(risk_percent) || !MathIsValidNumber(max_daily_loss_pct) ||
         !MathIsValidNumber(max_total_exposure_lots) || !MathIsValidNumber(max_drawdown_pct) ||
         !MathIsValidNumber(svp_value_area_pct) || !MathIsValidNumber(sl_atr_mult) ||
         !MathIsValidNumber(min_rr) || !MathIsValidNumber(tp_rr) || !MathIsValidNumber(min_confidence))
      { err = "configuration contains a non-finite numeric value"; return false; }

      //--- risk (hard caps, never bypassed) ---------------------------
      if(risk_percent <= 0.0 || risk_percent > QSMC_RISK_MAX_PERCENT)
      { err = "risk_percent must be in (0," + DoubleToString(QSMC_RISK_MAX_PERCENT, 1) + "]"; return false; }

      if(max_daily_loss_pct <= 0.0 || max_daily_loss_pct > QSMC_DAILY_LOSS_MAX_PCT)
      { err = "max_daily_loss_pct must be in (0," + DoubleToString(QSMC_DAILY_LOSS_MAX_PCT, 1) + "]"; return false; }

      if(max_spread_points < 0 || max_spread_points > QSMC_MAX_SPREAD_POINTS_HARD)
      { err = "max_spread_points outside [0," + IntegerToString(QSMC_MAX_SPREAD_POINTS_HARD) + "]"; return false; }

      if(max_positions < 1 || max_positions > QSMC_MAX_POSITIONS)
      { err = "max_positions outside [1," + IntegerToString(QSMC_MAX_POSITIONS) + "]"; return false; }

      if(max_total_exposure_lots <= 0.0 || max_total_exposure_lots > QSMC_MAX_TOTAL_EXPOSURE)
      { err = "max_total_exposure_lots outside (0,100]"; return false; }

      if(max_daily_trades < 1 || max_daily_trades > 100)
      { err = "max_daily_trades outside [1,100]"; return false; }

      if(cooldown_seconds < 0 || cooldown_seconds > 86400)
      { err = "cooldown_seconds outside [0,86400]"; return false; }

      if(max_drawdown_pct <= 0.0 || max_drawdown_pct > 50.0)
      { err = "max_drawdown_pct outside (0,50]"; return false; }

      //--- strategy numbers -------------------------------------------
      if(swing_left < 1 || swing_left > 10 || swing_right < 1 || swing_right > 10)
      { err = "swing_left/swing_right outside [1,10]"; return false; }

      if(zone_tolerance_points < 0 || zone_tolerance_points > 10000)
      { err = "zone_tolerance_points outside [0,10000]"; return false; }

      if(sl_atr_mult <= 0.1 || sl_atr_mult > 10.0)
      { err = "sl_atr_mult outside (0.1,10]"; return false; }

      if(min_rr < QSMC_MIN_RR_FLOOR || min_rr > QSMC_MAX_RR)
      { err = "min_rr outside [1,10]"; return false; }

      if(tp_rr < min_rr || tp_rr > QSMC_MAX_RR)
      { err = "tp_rr must be >= min_rr and <= 10"; return false; }

      if(min_confidence < 0.0 || min_confidence > 0.95)
      { err = "min_confidence outside [0,0.95]"; return false; }

      if(deviation_points < 0 || deviation_points > 1000)
      { err = "deviation_points outside [0,1000]"; return false; }

      //--- magic ------------------------------------------------------
      if(magic_offset < 0 || magic_offset >= QSMC_MAGIC_RANGE)
      { err = "magic_offset outside [0," + IntegerToString(QSMC_MAGIC_RANGE - 1) + "]"; return false; }

      //--- REAL mode gate ---------------------------------------------
      if(mode == QSMC_MODE_REAL)
      {
         if(QSMC_ALLOW_REAL != 1)
         { err = "REAL mode is disabled in this build (QSMC_ALLOW_REAL=0)"; return false; }
         if(real_ack != QSMC_REAL_ACK_TOKEN)
         { err = "REAL mode requires the acknowledgement token"; return false; }
      }

      return true;
   }

   //+---------------------------------------------------------------+
   //| Chart/exec alignment is a warning, not an error: timing is      |
   //| driven by exec_tf new-bar detection, never by chart ticks.      |
   //+---------------------------------------------------------------+
   bool IsChartAligned() const { return (Period() == exec_tf); }

   string Summary() const
   {
      return StringFormat("%s %s/%s/%s mode=%s preset=%s risk=%.2f%% dd=%.1f%%",
                          symbol,
                          QSMC_TfToString(htf), QSMC_TfToString(exec_tf),
                          QSMC_TfToString(ltf),
                          QSMC_ModeToString(mode),
                          QSMC_PresetToString(preset),
                          risk_percent, max_daily_loss_pct);
   }
};

#endif // QSMC_CONFIG_MQH
