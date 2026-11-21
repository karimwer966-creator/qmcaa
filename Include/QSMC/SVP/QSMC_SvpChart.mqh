//+------------------------------------------------------------------+
//|                                                QSMC_SvpChart.mqh |
//|  SVP presentation summary. It is deliberately read-only and does not |
//|  control the decision or execution layers.                         |
//+------------------------------------------------------------------+
#ifndef QSMC_SVPCHART_MQH
#define QSMC_SVPCHART_MQH
#include "QSMC_SvpCore.mqh"
class CQSMCSvpChart
{
public:
   static string Summary(const CQSMCSvpCore &profile)
   {
      if(!profile.IsReady())return "SVP: not ready";
      return StringFormat("SVP POC %.5f | VAH %.5f | VAL %.5f | %d bins",
                          profile.Poc(),profile.Vah(),profile.Val(),profile.BinCount());
   }
};
#endif // QSMC_SVPCHART_MQH
