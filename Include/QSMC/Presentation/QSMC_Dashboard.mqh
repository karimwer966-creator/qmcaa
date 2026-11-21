//+------------------------------------------------------------------+
//|                                            QSMC_Dashboard.mqh |
//|  State-only dashboard renderer. It displays decisions and safety   |
//|  facts but has no controls that can modify permissions.             |
//+------------------------------------------------------------------+
#ifndef QSMC_DASHBOARD_MQH
#define QSMC_DASHBOARD_MQH
#include "../Core/QSMC_Types.mqh"
#include "../Core/QSMC_Root.mqh"

struct SQSMCDashboardData
{
   string state;
   string mode;
   string instance;
   string health;
   string readiness;
   string analysis;
   string decision;
   string safety;
   string execution;
   string diagnostics;
};
class CQSMCDashboard
{
private:
   bool m_enabled;
   string m_lastText;
public:
   CQSMCDashboard(){m_enabled=true;m_lastText="";}
   void Init(const bool enabled){m_enabled=enabled;}
   void Render(const SQSMCDashboardData &d)
   {
      if(!m_enabled)return;
      string text="QSMC | "+d.state+" | "+d.mode+"\n"+
                   "Instance: "+d.instance+"\n"+
                   "Health: "+d.health+" | Data: "+d.readiness+"\n"+
                   "Analysis: "+d.analysis+"\n"+
                   "Decision: "+d.decision+"\n"+
                   "Safety: "+d.safety+" | Exec: "+d.execution+"\n"+
                   "Diagnostics: "+d.diagnostics;
      if(text!=m_lastText){Comment(text);m_lastText=text;}
   }
   void Clear(){if(m_enabled)Comment("");m_lastText="";}
};
#endif // QSMC_DASHBOARD_MQH
