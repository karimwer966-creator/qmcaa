#ifndef QSMC_PRESET_MQH
#define QSMC_PRESET_MQH

#include "QSMC_Config.mqh"

void QSMC_ApplyPreset(SQSMCConfig &cfg, const ENUM_QSMC_PRESET preset)
{
   cfg.preset = preset;
   switch(preset)
   {
      case QSMC_PRESET_CONSERVATIVE:
         cfg.risk_percent       = 0.25;
         cfg.max_daily_loss_pct = 1.0;
         cfg.max_spread_points  = 20;
         cfg.max_positions      = 1;
         break;

      case QSMC_PRESET_BALANCED:
         cfg.risk_percent       = 0.5;
         cfg.max_daily_loss_pct = 2.0;
         cfg.max_spread_points  = 30;
         cfg.max_positions      = 2;
         break;

      case QSMC_PRESET_AGGRESSIVE:
         cfg.risk_percent       = 1.0;
         cfg.max_daily_loss_pct = 4.0;
         cfg.max_spread_points  = 45;
         cfg.max_positions      = 3;
         break;

      case QSMC_PRESET_CUSTOM:
      default:
         break; // keep user values
   }
}

string QSMC_PresetToString(const ENUM_QSMC_PRESET p)
{
   switch(p)
   {
      case QSMC_PRESET_CONSERVATIVE: return "CONSERVATIVE";
      case QSMC_PRESET_BALANCED:     return "BALANCED";
      case QSMC_PRESET_AGGRESSIVE:   return "AGGRESSIVE";
      case QSMC_PRESET_CUSTOM:       return "CUSTOM";
   }
   return "UNKNOWN";
}

#endif