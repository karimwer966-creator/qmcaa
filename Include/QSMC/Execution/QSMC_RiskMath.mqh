// Pure fail-closed risk arithmetic; no broker or persistence authority.
#ifndef QSMC_RISKMATH_MQH
#define QSMC_RISKMATH_MQH
#include "../Core/QSMC_Constants.mqh"
class CQSMCRiskMath
{
public:
   static bool Positive(const double v){return MathIsValidNumber(v) && v>0.0;}
   static bool Nonnegative(const double v){return MathIsValidNumber(v) && v>=0.0;}
   static bool Peak(const bool missing,const double prior,const double equity,double &peak,double &dd)
   {
      peak=0.0;dd=0.0;
      if(!Positive(equity) || (!missing && !Positive(prior)))return false;
      peak=(missing?equity:MathMax(prior,equity));
      dd=MathMax(0.0,(peak-equity)/peak*100.0);
      return Nonnegative(dd);
   }
   static bool Budget(const double equity,const double percent,double &money)
   {
      money=0.0;
      if(!Positive(equity) || !Positive(percent) || percent>QSMC_RISK_MAX_PERCENT)return false;
      money=equity*percent/100.0;
      return Positive(money);
   }
   static bool FloorLots(const double budget,const double lossPerLot,const double minimum,
                         const double maximum,const double step,const double cap,double &lots)
   {
      lots=0.0;
      if(!Positive(budget) || !Positive(lossPerLot) || !Positive(minimum) ||
         !Positive(maximum) || maximum<minimum || !Positive(step) || !Positive(cap))return false;
      double ceiling=MathMin(MathMin(budget/lossPerLot,maximum),cap);
      if(!Positive(ceiling))return false;
      // No fixed decimal precision, epsilon uplift or rounding toward more risk.
      lots=MathFloor(ceiling/step)*step;
      if(!Positive(lots) || lots<minimum || lots>ceiling || !Positive(lots*lossPerLot) ||
         lots*lossPerLot>budget){lots=0.0;return false;}
      return true;
   }
   // User-approved reserve: max(10% of equity, planned stop risk).
   static bool Margin(const double equity,const double freeMargin,const double required,
                      const double stopRisk)
   {
      if(!Positive(equity) || !Positive(freeMargin) || !Nonnegative(required) || !Positive(stopRisk))return false;
      double reserve=MathMax(equity*0.10,stopRisk);
      return (Positive(reserve) && freeMargin>=required && freeMargin-required>=reserve);
   }
};
#endif // QSMC_RISKMATH_MQH
