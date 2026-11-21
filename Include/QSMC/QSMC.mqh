//+------------------------------------------------------------------+
//|                                                      QSMC.mqh |
//|  Unified public include. Depend on this from EAs/scripts rather    |
//|  than manually maintaining a layer-specific include list.          |
//+------------------------------------------------------------------+
#ifndef QSMC_PUBLIC_MQH
#define QSMC_PUBLIC_MQH

// Core contracts
#include "Core/QSMC_Constants.mqh"
#include "Core/QSMC_Types.mqh"
#include "Core/QSMC_Version.mqh"
#include "Core/QSMC_Config.mqh"
#include "Core/QSMC_Preset.mqh"
#include "Core/QSMC_InputFingerprint.mqh"
#include "Core/QSMC_InstanceIdentity.mqh"
#include "Core/QSMC_StateMachine.mqh"
#include "Core/QSMC_Root.mqh"

// Infrastructure and safety
#include "Infrastructure/QSMC_Clock.mqh"
#include "Infrastructure/QSMC_Logger.mqh"
#include "Infrastructure/QSMC_StateStore.mqh"
#include "Infrastructure/QSMC_Stats.mqh"
#include "Safety/QSMC_Diagnostics.mqh"
#include "Safety/QSMC_HealthMonitor.mqh"
#include "Safety/QSMC_IncidentSafety.mqh"
#include "Safety/QSMC_SafetyController.mqh"

// Data and analysis
#include "Data/QSMC_MarketSnapshot.mqh"
#include "Data/QSMC_DataProvider.mqh"
#include "Data/QSMC_TimeframeManager.mqh"
#include "Data/QSMC_DataValidator.mqh"
#include "Data/QSMC_MarketData.mqh"
#include "Data/QSMC_DataReadiness.mqh"
#include "Analysis/QSMC_Structure.mqh"
#include "Analysis/QSMC_StructurePoints.mqh"
#include "Analysis/QSMC_Bias.mqh"
#include "Analysis/QSMC_CandlePatterns.mqh"
#include "Analysis/QSMC_Zones.mqh"
#include "Analysis/QSMC_ZoneScorer.mqh"
#include "Analysis/QSMC_SupplyDemand.mqh"
#include "Analysis/QSMC_LiquidityValue.mqh"
#include "Analysis/QSMC_Liquidity.mqh"
#include "Analysis/QSMC_Reaction.mqh"
#include "Analysis/QSMC_EarlyBreakDetector.mqh"
#include "Analysis/QSMC_Scanners.mqh"

// SVP
#include "SVP/QSMC_SvpCore.mqh"
#include "SVP/QSMC_SvpVolumeProfile.mqh"
#include "SVP/QSMC_SvpZones.mqh"
#include "SVP/QSMC_SvpLiquidity.mqh"
#include "SVP/QSMC_SvpDecision.mqh"
#include "SVP/QSMC_SvpChart.mqh"

// Decision and execution
#include "Decision/QSMC_UnifiedDecision.mqh"
#include "Decision/QSMC_SignalRegistry.mqh"
#include "Decision/QSMC_Gates.mqh"
#include "Decision/QSMC_OpportunityFunnel.mqh"
#include "Decision/QSMC_Arbiter.mqh"
#include "Decision/QSMC_ExecutionRules.mqh"
#include "Execution/QSMC_ExecutionMode.mqh"
#include "Execution/QSMC_ExecutionAdapter.mqh"
#include "Execution/QSMC_DemoAdapter.mqh"
#include "Execution/QSMC_RealAdapter.mqh"
#include "Execution/QSMC_ExecutionJournal.mqh"
#include "Execution/QSMC_RiskManager.mqh"
#include "Execution/QSMC_ExecutionPreflight.mqh"
#include "Execution/QSMC_OrderManager.mqh"
#include "Execution/QSMC_PositionManager.mqh"
#include "Execution/QSMC_ExecutionManager.mqh"
#include "Execution/QSMC_AlertManager.mqh"

// Presentation and application composition root
#include "Presentation/QSMC_Dashboard.mqh"
#include "Presentation/QSMC_ChartLayers.mqh"
#include "Presentation/QSMC_Renderer.mqh"
#include "App/QSMC_EventDispatcher.mqh"
#include "App/QSMC_Lifecycle.mqh"
#include "App/QSMC_Bootstrap.mqh"
#include "App/QSMC_Orchestrator.mqh"

#endif // QSMC_PUBLIC_MQH
