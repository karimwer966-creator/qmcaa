//+------------------------------------------------------------------+
//|                                                   QSMC_Preset.mqh |
//|  Risk presets.  Contract: ApplyPreset() is called on a defaulted   |
//|  configuration BEFORE explicit user inputs are applied, so an      |
//|  explicit input always wins.  Presets never touch mode/identity.   |
//+------------------------------------------------------------------+
#ifndef QSMC_PRESET_MQH
#define QSMC_PRESET_MQH

#include "QSMC_Config.mqh"

void QSMC_ApplyPreset(SQSMCConfig &cfg, const ENUM_QSMC_PRESET preset)
{
   cfg.preset = preset;

   switch(preset)
   {
      case QSMC_PRESET_CONSERVATIVE:
         cfg.risk_percent             = 0.25;
         cfg.max_daily_loss_pct       = 1.0;
         cfg.max_spread_points        = 20;
         cfg.max_positions            = 1;
         cfg.max_total_exposure_lots  = 1.0;
         cfg.max_daily_trades         = 3;
         cfg.cooldown_seconds         = 900;
         cfg.max_drawdown_pct         = 6.0;
         cfg.sl_atr_mult              = 1.8;
         cfg.min_rr                   = 2.0;
         cfg.tp_rr                    = 2.5;
         cfg.min_confidence           = 0.65;
         break;

      case QSMC_PRESET_BALANCED:
         cfg.risk_percent             = 0.50;
         cfg.max_daily_loss_pct       = 2.0;
         cfg.max_spread_points        = 30;
         cfg.max_positions            = 1;
         cfg.max_total_exposure_lots  = 2.0;
         cfg.max_daily_trades         = 5;
         cfg.cooldown_seconds         = 300;
         cfg.max_drawdown_pct         = 10.0;
         cfg.sl_atr_mult              = 1.5;
         cfg.min_rr                   = 1.5;
         cfg.tp_rr                    = 2.0;
         cfg.min_confidence           = 0.55;
         break;

      case QSMC_PRESET_AGGRESSIVE:
         cfg.risk_percent             = 1.00;
         cfg.max_daily_loss_pct       = 4.0;
         cfg.max_spread_points        = 45;
         cfg.max_positions            = 2;
         cfg.max_total_exposure_lots  = 4.0;
         cfg.max_daily_trades         = 10;
         cfg.cooldown_seconds         = 120;
         cfg.max_drawdown_pct         = 15.0;
         cfg.sl_atr_mult              = 1.2;
         cfg.min_rr                   = 1.2;
         cfg.tp_rr                    = 1.8;
         cfg.min_confidence           = 0.50;
         break;

      case QSMC_PRESET_CUSTOM:
      default:
         break; // keep whatever the caller already configured
   }
}

bool QSMC_PresetFromString(const string text, ENUM_QSMC_PRESET &out)
{
   string t = text;
   StringToUpper(t);
   StringTrimLeft(t);
   StringTrimRight(t);

   if(t == "CONSERVATIVE") { out = QSMC_PRESET_CONSERVATIVE; return true; }
   if(t == "BALANCED")     { out = QSMC_PRESET_BALANCED;     return true; }
   if(t == "AGGRESSIVE")   { out = QSMC_PRESET_AGGRESSIVE;   return true; }
   if(t == "CUSTOM")       { out = QSMC_PRESET_CUSTOM;       return true; }
   return false;
}

string QSMC_Describepreset(const ENUM_QSMC_PRESET preset)
{
   switch(preset)
   {
      case QSMC_PRESET_CONSERVATIVE: return "0.25% risk, 1% daily loss, RR >= 2.0";
      case QSMC_PRESET_BALANCED:     return "0.50% risk, 2% daily loss, RR >= 1.5";
      case QSMC_PRESET_AGGRESSIVE:   return "1.00% risk, 4% daily loss, RR >= 1.2";
      case QSMC_PRESET_CUSTOM:       return "user supplied values";
   }
   return "unknown preset";
}

#endif // QSMC_PRESET_MQH
