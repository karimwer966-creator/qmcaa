//+------------------------------------------------------------------+
//|                                           QSMC_ChartLayers.mqh |
//|  Minimal namespaced levels. Presentation only: no trading calls.    |
//+------------------------------------------------------------------+
#ifndef QSMC_CHARTLAYERS_MQH
#define QSMC_CHARTLAYERS_MQH
#include "../Core/QSMC_Constants.mqh"
#include "../Core/QSMC_InputFingerprint.mqh"
#include "../Analysis/QSMC_Zones.mqh"

class CQSMCChartLayers
{
private:
   long m_chart;
   string m_prefix;
   bool m_enabled;
   void DeleteOwned()
   {
      int total=ObjectsTotal(m_chart,0,-1);
      for(int i=total-1;i>=0;i--)
      {
         string name=ObjectName(m_chart,i,0,-1);
         if(StringFind(name,m_prefix)==0)ObjectDelete(m_chart,name);
      }
   }
public:
   CQSMCChartLayers(){m_chart=0;m_prefix="";m_enabled=false;}
   void Init(const long chart,const string instance,const bool enabled)
   {
      m_chart=chart;
      m_prefix=QSMC_OBJ_PREFIX+QSMC_UlongToHex(QSMC_HashString(instance))+"_";
      m_enabled=enabled;
   }
   void DrawZone(const SQSMCZone &zone,const color clr,const datetime until)
   {
      if(!m_enabled || zone.top<=zone.bottom || zone.created<=0)return;
      string name=m_prefix+"Z_"+IntegerToString(zone.id);
      if(ObjectFind(m_chart,name)<0)
         ObjectCreate(m_chart,name,OBJ_RECTANGLE,0,zone.created,zone.top,until,zone.bottom);
      else
      {
         ObjectMove(m_chart,name,0,zone.created,zone.top);
         ObjectMove(m_chart,name,1,until,zone.bottom);
      }
      ObjectSetInteger(m_chart,name,OBJPROP_COLOR,clr);
      ObjectSetInteger(m_chart,name,OBJPROP_BACK,true);
      ObjectSetInteger(m_chart,name,OBJPROP_FILL,true);
      ObjectSetInteger(m_chart,name,OBJPROP_SELECTABLE,false);
   }
   void Clear(){DeleteOwned();}
   void Deinit(){if(m_enabled)DeleteOwned();}
};
#endif // QSMC_CHARTLAYERS_MQH
