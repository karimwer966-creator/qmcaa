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
   {m_dashboard.Init(chart,id,dashboard);m_layers.Init(chart,id,layers);}
   void Render(const SQSMCDashboardData &d){m_dashboard.Render(d);}
   void DrawZone(const SQSMCZone &zone,const color clr,const datetime until){m_layers.DrawZone(zone,clr,until);}
   void DrawBand(const string key,const datetime from,const double top,const datetime until,
                 const double bottom,const color clr)
   {m_layers.DrawBand(key,from,top,until,bottom,clr);}
   void DrawLevel(const string key,const double price,const color clr,
                  const ENUM_LINE_STYLE style=STYLE_DOT)
   {m_layers.DrawLevel(key,price,clr,style);}
   void DrawText(const string key,const datetime when,const double price,const string text,
                 const color clr,const int fontSize=9)
   {m_layers.DrawText(key,when,price,text,clr,fontSize);}
   void ClearLayers(){m_layers.Clear();}
   void Clear(){m_dashboard.Clear();m_layers.Clear();}
   void Deinit(){m_dashboard.Clear();m_layers.Deinit();}
};
#endif // QSMC_RENDERER_MQH
