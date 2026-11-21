//+------------------------------------------------------------------+
//|                                        QSMC_OrderFlowProxy.mqh |
//| Candle/tick-volume participation proxy. It is NOT exchange order  |
//| flow, aggressor delta, CVD or a footprint chart.                   |
//+------------------------------------------------------------------+
#ifndef QSMC_ORDERFLOWPROXY_MQH
#define QSMC_ORDERFLOWPROXY_MQH
#include "../Core/QSMC_Constants.mqh"
#include "../Data/QSMC_MarketSnapshot.mqh"

struct SQSMCOrderFlowProxyResult
{
   bool ready;
   int barsUsed;
   double averageTickVolume;
   double currentTickVolume;
   double relativeVolume;
   double estimatedBuyShare;
   double estimatedSellShare;
   double pressure; // -1..+1, candle-location-weighted tick volume
   string label;
   string diagnostic;
   void Reset()
   {
      ready=false;barsUsed=0;averageTickVolume=0.0;currentTickVolume=0.0;
      relativeVolume=0.0;estimatedBuyShare=0.5;estimatedSellShare=0.5;
      pressure=0.0;label="unavailable";diagnostic="";
   }
};

class CQSMCOrderFlowProxy
{
public:
   static bool Calculate(const CQSMCMarketSnapshot &snap,const int slot,
                         const int bars,SQSMCOrderFlowProxyResult &out)
   {
      out.Reset();
      int newest=snap.NewestIndex();
      int count=snap.BarCount(slot);
      int window=MathMin(bars,count-newest);
      if(window<5){out.diagnostic="insufficient bars for tick-volume proxy";return false;}

      double volSum=0.0,buySum=0.0,sellSum=0.0;
      for(int i=newest;i<newest+window;i++)
      {
         double volume=(double)snap.Volume(slot,i);
         double range=snap.High(slot,i)-snap.Low(slot,i);
         if(volume<0.0)continue;
         if(range<=QSMC_EPSILON){buySum+=volume*0.5;sellSum+=volume*0.5;volSum+=volume;continue;}
         // Close-location split is a candle statistic, not aggressor flow.
         double buyFraction=(snap.Close(slot,i)-snap.Low(slot,i))/range;
         if(buyFraction<0.0)buyFraction=0.0;
         if(buyFraction>1.0)buyFraction=1.0;
         buySum+=volume*buyFraction;
         sellSum+=volume*(1.0-buyFraction);
         volSum+=volume;
      }
      if(volSum<=0.0){out.diagnostic="tick volume missing/zero";return false;}

      out.ready=true;
      out.barsUsed=window;
      out.averageTickVolume=volSum/(double)window;
      out.currentTickVolume=(double)snap.Volume(slot,newest);
      out.relativeVolume=(out.averageTickVolume>0.0?out.currentTickVolume/out.averageTickVolume:0.0);
      double total=buySum+sellSum;
      out.estimatedBuyShare=(total>0.0?buySum/total:0.5);
      out.estimatedSellShare=(total>0.0?sellSum/total:0.5);
      out.pressure=out.estimatedBuyShare-out.estimatedSellShare;
      if(out.relativeVolume>=1.5 && out.pressure>0.15)out.label="elevated bullish tick-volume proxy";
      else if(out.relativeVolume>=1.5 && out.pressure< -0.15)out.label="elevated bearish tick-volume proxy";
      else if(out.relativeVolume>=1.5)out.label="elevated but direction-neutral tick volume";
      else out.label="normal tick-volume proxy";
      out.diagnostic="approximation only; no centralized aggressor data";
      return true;
   }
};
#endif // QSMC_ORDERFLOWPROXY_MQH
