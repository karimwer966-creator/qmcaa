//+------------------------------------------------------------------+
//|                                                        QSMC.mq5 |
//|  QSMC Expert Advisor. Default ANALYSIS mode does not submit orders. |
//+------------------------------------------------------------------+
#property copyright "QSMC"
#property version   "0.90"
#property strict
#property description "QSMC modular analysis EA. REAL trading is compile-time disabled."

#include <QSMC/QSMC.mqh>

input ENUM_QSMC_MODE      InpMode                 = QSMC_MODE_ANALYSIS;
input ENUM_QSMC_PRESET    InpPreset               = QSMC_PRESET_BALANCED;
input ENUM_QSMC_LOG_LEVEL InpLogLevel             = QSMC_LOG_INFO;
input string              InpSymbol               = ""; // empty = chart symbol
input ENUM_TIMEFRAMES     InpExecutionTimeframe   = PERIOD_M15;
input ENUM_TIMEFRAMES     InpHigherTimeframe      = PERIOD_H4;
input ENUM_TIMEFRAMES     InpLowerTimeframe       = PERIOD_M5;
input int                 InpTimerMilliseconds    = 1000;
input int                 InpBarsBack             = 600;
input bool                InpDashboard            = true;
input bool                InpChartLayers          = true;
input bool                InpLogFile              = false;
input bool                InpClosedBarsOnly       = true;
input bool                InpOverridePresetRisk   = false;
input double              InpRiskPercent          = 0.50;
input double              InpDailyLossLimitPct     = 2.00;
input int                 InpMaxSpreadPoints      = 30;
input int                 InpMaxPositions         = 1;
input double              InpMaxExposureLots      = 2.00;
input int                 InpMaxDailyTrades       = 5;
input int                 InpCooldownSeconds      = 300;
input double              InpMaxDrawdownPct       = 10.0;
input int                 InpSwingLeft            = 2;
input int                 InpSwingRight           = 2;
input int                 InpStructureLookback    = 300;
input int                 InpZoneLookback         = 200;
input int                 InpZoneTolerancePoints  = 150;
input int                 InpSvpLookback           = 240;
input int                 InpSvpBins               = 40;
input double              InpSvpValueAreaPct       = 70.0;
input double              InpStopAtrMultiplier     = 1.5;
input double              InpMinimumRR             = 1.5;
input double              InpTargetRR              = 2.0;
input double              InpMinimumConfidence     = 0.55;
input int                 InpDeviationPoints       = 10;
input long                InpMagicOffset           = 0;
input string              InpRealAcknowledgement  = "";

CQSMCOrchestrator g_qsmc;
bool g_qsmcStarted=false;

void QSMC_BuildConfig(SQSMCConfig &cfg)
{
   cfg.SetDefaults();
   cfg.mode=InpMode;
   cfg.preset=InpPreset;
   QSMC_ApplyPreset(cfg,InpPreset);

   // Explicit user inputs are applied after the preset. Risk values only
   // override preset risk when the opt-in override is enabled.
   cfg.log_level=InpLogLevel;
   cfg.symbol=(StringLen(InpSymbol)>0?InpSymbol:_Symbol);
   cfg.exec_tf=InpExecutionTimeframe;
   cfg.htf=InpHigherTimeframe;
   cfg.ltf=InpLowerTimeframe;
   cfg.timer_ms=InpTimerMilliseconds;
   cfg.bars_back=InpBarsBack;
   cfg.enable_dashboard=InpDashboard;
   cfg.enable_chart_layers=InpChartLayers;
   cfg.enable_log_file=InpLogFile;
   cfg.use_closed_bars_only=InpClosedBarsOnly;
   if(InpOverridePresetRisk)
   {
      cfg.risk_percent=InpRiskPercent;
      cfg.max_daily_loss_pct=InpDailyLossLimitPct;
      cfg.max_spread_points=InpMaxSpreadPoints;
      cfg.max_positions=InpMaxPositions;
      cfg.max_total_exposure_lots=InpMaxExposureLots;
      cfg.max_daily_trades=InpMaxDailyTrades;
      cfg.cooldown_seconds=InpCooldownSeconds;
      cfg.max_drawdown_pct=InpMaxDrawdownPct;
      cfg.sl_atr_mult=InpStopAtrMultiplier;
      cfg.min_rr=InpMinimumRR;
      cfg.tp_rr=InpTargetRR;
      cfg.min_confidence=InpMinimumConfidence;
   }
   cfg.swing_left=InpSwingLeft;
   cfg.swing_right=InpSwingRight;
   cfg.structure_lookback=InpStructureLookback;
   cfg.zone_lookback=InpZoneLookback;
   cfg.zone_tolerance_points=InpZoneTolerancePoints;
   cfg.svp_lookback=InpSvpLookback;
   cfg.svp_bins=InpSvpBins;
   cfg.svp_value_area_pct=InpSvpValueAreaPct;
   cfg.deviation_points=InpDeviationPoints;
   cfg.magic_offset=InpMagicOffset;
   cfg.real_ack=InpRealAcknowledgement;
}

int OnInit()
{
   if(g_qsmcStarted)
   {
      Print("QSMC init rejected: duplicate initialization");
      return INIT_FAILED;
   }
   SQSMCConfig cfg;
   QSMC_BuildConfig(cfg);
   SQSMCResult result;
   if(!g_qsmc.Init(cfg,result))
   {
      Print("QSMC init failed [",(int)result.code,"]: ",result.message);
      return INIT_FAILED;
   }
   g_qsmcStarted=true;
   Print("QSMC: ",result.message);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_qsmcStarted)g_qsmc.Deinit(reason);
   g_qsmcStarted=false;
}

void OnTick()
{
   if(!g_qsmcStarted)return;
   g_qsmc.OnTick();
}

void OnTimer()
{
   if(!g_qsmcStarted)return;
   g_qsmc.OnTimer();
}

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   if(!g_qsmcStarted)return;
   g_qsmc.OnTradeTransaction(trans,request,result);
}
