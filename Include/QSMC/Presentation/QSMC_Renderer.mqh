//+------------------------------------------------------------------+
//|                                               QSMC_Renderer.mqh |
//|  Facade that composes a state-only dashboard and optional chart    |
//|  layers; never changes root, decision or safety state.               |
//+------------------------------------------------------------------+
#ifndef QSMC_RENDERER_MQH
#define QSMC_RENDERER_MQH
#include "QSMC_Dashboard.mqh"
#include "QSMC_ChartLayers.mqh"

class CQSMCRenderer
{
private:
   CQSMCDashboard m_dashboard;
   CQSMCChartLayers m_layers;
public:
   void Init(const long chart,const string id,const bool dashboard,const bool layers)
   {m_dashboard.Init(dashboard);m_layers.Init(chart,id,layers);}
   void Render(const SQSMCDashboardData &d){m_dashboard.Render(d);}
   void DrawZone(const SQSMCZone &zone,const color clr,const datetime until){m_layers.DrawZone(zone,clr,until);}
   void ClearLayers(){m_layers.Clear();}
   void Clear(){m_dashboard.Clear();m_layers.Clear();}
   void Deinit(){m_dashboard.Clear();m_layers.Deinit();}
};
#endif // QSMC_RENDERER_MQH
