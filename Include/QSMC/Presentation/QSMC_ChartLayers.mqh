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
      if(zone.id<=0)return;
      DrawBand("Z_"+IntegerToString(zone.id),zone.created,zone.top,until,zone.bottom,clr);
   }
   void DrawBand(const string key,const datetime from,const double top,
                 const datetime until,const double bottom,const color clr)
   {
      if(!m_enabled || from<=0 || until<=0 || top<=bottom)return;
      string name=m_prefix+key;
      if(ObjectFind(m_chart,name)<0)
         ObjectCreate(m_chart,name,OBJ_RECTANGLE,0,from,top,until,bottom);
      else
      {
         ObjectMove(m_chart,name,0,from,top);
         ObjectMove(m_chart,name,1,until,bottom);
      }
      ObjectSetInteger(m_chart,name,OBJPROP_COLOR,clr);
      ObjectSetInteger(m_chart,name,OBJPROP_BACK,true);
      ObjectSetInteger(m_chart,name,OBJPROP_FILL,true);
      ObjectSetInteger(m_chart,name,OBJPROP_SELECTABLE,false);
   }
   void DrawLevel(const string key,const double price,const color clr,
                  const ENUM_LINE_STYLE style=STYLE_DOT)
   {
      if(!m_enabled || price<=0.0)return;
      string name=m_prefix+key;
      if(ObjectFind(m_chart,name)<0)ObjectCreate(m_chart,name,OBJ_HLINE,0,0,price);
      else ObjectSetDouble(m_chart,name,OBJPROP_PRICE,price);
      ObjectSetInteger(m_chart,name,OBJPROP_COLOR,clr);
      ObjectSetInteger(m_chart,name,OBJPROP_STYLE,style);
      ObjectSetInteger(m_chart,name,OBJPROP_WIDTH,1);
      ObjectSetInteger(m_chart,name,OBJPROP_BACK,true);
      ObjectSetInteger(m_chart,name,OBJPROP_SELECTABLE,false);
   }
   void DrawText(const string key,const datetime when,const double price,
                 const string text,const color clr,const int fontSize=9)
   {
      if(!m_enabled || when<=0 || price<=0.0)return;
      string name=m_prefix+key;
      if(ObjectFind(m_chart,name)<0)ObjectCreate(m_chart,name,OBJ_TEXT,0,when,price);
      else ObjectMove(m_chart,name,0,when,price);
      ObjectSetString(m_chart,name,OBJPROP_TEXT,text);
      ObjectSetString(m_chart,name,OBJPROP_FONT,"Arial");
      ObjectSetInteger(m_chart,name,OBJPROP_FONTSIZE,fontSize);
      ObjectSetInteger(m_chart,name,OBJPROP_COLOR,clr);
      ObjectSetInteger(m_chart,name,OBJPROP_ANCHOR,ANCHOR_CENTER);
      ObjectSetInteger(m_chart,name,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(m_chart,name,OBJPROP_BACK,false);
   }
   void Clear(){DeleteOwned();}
   void Deinit(){if(m_enabled)DeleteOwned();}
};
#endif // QSMC_CHARTLAYERS_MQH
