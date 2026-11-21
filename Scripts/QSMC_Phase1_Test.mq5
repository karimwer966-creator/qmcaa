#property script_show_inputs
#include <QSMC/QSMC_Root.mqh>

input ENUM_QSMC_PRESET InpPreset = QSMC_PRESET_BALANCED;

void OnStart()
{
   SQSMCConfig cfg;
   cfg.SetDefaults();
   QSMC_ApplyPreset(cfg, InpPreset);

   SQSMCResult res;
   if(!QSMC_Root().Init(cfg, res))
   {
      PrintFormat("QSMC init failed: %s", res.message);
      return;
   }
   Print(QSMC_Root().Summary());
}