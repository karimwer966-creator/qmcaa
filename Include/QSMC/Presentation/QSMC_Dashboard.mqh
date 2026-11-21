//+------------------------------------------------------------------+
//|                                            QSMC_Dashboard.mqh |
//|  Read-only, instance-namespaced panel. It displays computed state; |
//|  it has no controls that can change execution permissions.         |
//+------------------------------------------------------------------+
#ifndef QSMC_DASHBOARD_MQH
#define QSMC_DASHBOARD_MQH
#include "../Core/QSMC_Types.mqh"
#include "../Core/QSMC_Root.mqh"
#include "../Core/QSMC_InputFingerprint.mqh"

struct SQSMCDashboardData
{
   string state;
   string mode;
   string instance;
   string health;
   string readiness;
   string analysis;
   string sessions;
   string ict;
   string opportunities;
   string orderFlow;
   string elliott;
   string decision;
   string safety;
   string execution;
   string diagnostics;
};

class CQSMCDashboard
{
private:
   long m_chart;
   bool m_enabled;
   string m_prefix;
   string m_panel;
   string m_label;
   string m_lastText;

   void EnsureObjects()
   {
      if(ObjectFind(m_chart,m_panel)<0)ObjectCreate(m_chart,m_panel,OBJ_RECTANGLE_LABEL,0,0,0);
      ObjectSetInteger(m_chart,m_panel,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(m_chart,m_panel,OBJPROP_XDISTANCE,10);
      ObjectSetInteger(m_chart,m_panel,OBJPROP_YDISTANCE,18);
      ObjectSetInteger(m_chart,m_panel,OBJPROP_XSIZE,590);
      ObjectSetInteger(m_chart,m_panel,OBJPROP_YSIZE,270);
      ObjectSetInteger(m_chart,m_panel,OBJPROP_BGCOLOR,C'18,22,28');
      ObjectSetInteger(m_chart,m_panel,OBJPROP_COLOR,clrDimGray);
      ObjectSetInteger(m_chart,m_panel,OBJPROP_BORDER_TYPE,BORDER_FLAT);
      ObjectSetInteger(m_chart,m_panel,OBJPROP_BACK,true);
      ObjectSetInteger(m_chart,m_panel,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(m_chart,m_panel,OBJPROP_HIDDEN,true);

      if(ObjectFind(m_chart,m_label)<0)ObjectCreate(m_chart,m_label,OBJ_LABEL,0,0,0);
      ObjectSetInteger(m_chart,m_label,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(m_chart,m_label,OBJPROP_XDISTANCE,20);
      ObjectSetInteger(m_chart,m_label,OBJPROP_YDISTANCE,25);
      ObjectSetInteger(m_chart,m_label,OBJPROP_COLOR,clrWhiteSmoke);
      ObjectSetInteger(m_chart,m_label,OBJPROP_FONTSIZE,9);
      ObjectSetInteger(m_chart,m_label,OBJPROP_ANCHOR,ANCHOR_LEFT_UPPER);
      ObjectSetInteger(m_chart,m_label,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(m_chart,m_label,OBJPROP_HIDDEN,true);
      ObjectSetString(m_chart,m_label,OBJPROP_FONT,"Consolas");
   }

public:
   CQSMCDashboard()
   {
      m_chart=0;m_enabled=true;m_prefix="";m_panel="";m_label="";m_lastText="";
   }
   void Init(const long chart,const string instance,const bool enabled)
   {
      m_chart=chart;
      m_enabled=enabled;
      m_prefix="QSMC_DASH_"+QSMC_UlongToHex(QSMC_HashString(instance));
      m_panel=m_prefix+"_PANEL";
      m_label=m_prefix+"_TEXT";
      m_lastText="";
      if(m_enabled)EnsureObjects();
   }
   void Render(const SQSMCDashboardData &d)
   {
      if(!m_enabled)return;
      string text="QSMC  |  "+d.state+"  |  "+d.mode+"\n"+
                   "Health: "+d.health+"  |  Data: "+d.readiness+"\n"+
                   "Bias: "+d.analysis+"\n"+
                   "Session: "+d.sessions+"\n"+
                   "Setups: "+d.ict+"\n"+
                   "Opportunity audit: "+d.opportunities+"\n"+
                   "Tick-volume proxy: "+d.orderFlow+"\n"+
                   "Elliott guide: "+d.elliott+"\n"+
                   "Decision: "+d.decision+"\n"+
                   "Safety: "+d.safety+"  |  Exec: "+d.execution+"\n"+
                   "Diag: "+d.diagnostics;
      if(text!=m_lastText || ObjectFind(m_chart,m_panel)<0 || ObjectFind(m_chart,m_label)<0)
      {
         EnsureObjects();
         ObjectSetString(m_chart,m_label,OBJPROP_TEXT,text);
         m_lastText=text;
      }
   }
   void Clear()
   {
      if(m_chart>=0)
      {
         if(ObjectFind(m_chart,m_panel)>=0)ObjectDelete(m_chart,m_panel);
         if(ObjectFind(m_chart,m_label)>=0)ObjectDelete(m_chart,m_label);
      }
      m_lastText="";
   }
};
#endif // QSMC_DASHBOARD_MQH
