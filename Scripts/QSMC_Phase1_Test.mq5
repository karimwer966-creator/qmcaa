#property script_show_inputs
#include <QSMC/QSMC.mqh>

input ENUM_QSMC_PRESET InpPreset = QSMC_PRESET_BALANCED;

void OnStart()
{
   SQSMCConfig cfg;
   cfg.SetDefaults();
   QSMC_ApplyPreset(cfg, InpPreset);

   SQSMCResult res;
   CQSMCRoot root;
   if(!root.Init(cfg, res))
   {
      PrintFormat("QSMC init failed [%d]: %s", (int)res.code, res.message);
      return;
   }
   Print(root.Summary());
   root.Shutdown();
}
