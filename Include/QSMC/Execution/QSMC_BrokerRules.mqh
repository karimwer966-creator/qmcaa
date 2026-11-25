// QSMC-001/012/013: documented broker contract helpers, no submission authority.
#ifndef QSMC_BROKERRULES_MQH
#define QSMC_BROKERRULES_MQH
#include "../Core/QSMC_Types.mqh"

enum ENUM_QSMC_BROKER_OUTCOME
{
   QSMC_BROKER_NOT_SENT=0,
   QSMC_BROKER_FILLED,
   QSMC_BROKER_PARTIAL,
   QSMC_BROKER_PENDING,
   QSMC_BROKER_RETRYABLE,
   QSMC_BROKER_REJECTED,
   QSMC_BROKER_UNCERTAIN
};
class CQSMCBrokerRules
{
public:
   static ENUM_QSMC_BROKER_OUTCOME Classify(const uint retcode)
   {
      switch(retcode)
      {
         case TRADE_RETCODE_DONE:return QSMC_BROKER_FILLED;
         case TRADE_RETCODE_DONE_PARTIAL:return QSMC_BROKER_PARTIAL;
         case TRADE_RETCODE_PLACED:return QSMC_BROKER_PENDING;
         case TRADE_RETCODE_REQUOTE:
         case TRADE_RETCODE_PRICE_CHANGED:
         case TRADE_RETCODE_PRICE_OFF:
         case TRADE_RETCODE_TOO_MANY_REQUESTS:return QSMC_BROKER_RETRYABLE;
         case TRADE_RETCODE_REJECT:
         case TRADE_RETCODE_CANCEL:
         case TRADE_RETCODE_INVALID:
         case TRADE_RETCODE_INVALID_VOLUME:
         case TRADE_RETCODE_INVALID_PRICE:
         case TRADE_RETCODE_INVALID_STOPS:
         case TRADE_RETCODE_TRADE_DISABLED:
         case TRADE_RETCODE_MARKET_CLOSED:
         case TRADE_RETCODE_NO_MONEY:
         case TRADE_RETCODE_INVALID_FILL:return QSMC_BROKER_REJECTED;
         // Includes timeout, connection loss, unspecified ERROR and unknown codes.
         // A new/unknown retcode never authorizes an automatic retry.
         default:return QSMC_BROKER_UNCERTAIN;
      }
   }
   static bool Filling(const long flags,const ENUM_SYMBOL_TRADE_EXECUTION execution,
                       ENUM_ORDER_TYPE_FILLING &filling,string &why)
   {
      why="";
      // Prefer all-or-nothing when supported, but still reconcile partial results.
      if((flags & (long)SYMBOL_FILLING_FOK)!=0){filling=ORDER_FILLING_FOK;return true;}
      if((flags & (long)SYMBOL_FILLING_IOC)!=0){filling=ORDER_FILLING_IOC;return true;}
      if(execution!=SYMBOL_TRADE_EXECUTION_MARKET)
      {filling=ORDER_FILLING_RETURN;return true;}
      why="market execution has no supported FOK/IOC filling flag";
      return false;
   }
   static bool OnTickGrid(const double value,const double tickSize)
   {
      if(!MathIsValidNumber(value) || !MathIsValidNumber(tickSize) ||
         value<=0.0 || tickSize<=0.0)return false;
      double ticks=value/tickSize;
      return (MathIsValidNumber(ticks) && MathAbs(ticks-MathRound(ticks))<=1e-6);
   }
   static bool Stops(const ENUM_QSMC_DIRECTION direction,const double bid,
                     const double ask,const double sl,const double tp,
                     const double minimum,string &why)
   {
      why="";
      if(!MathIsValidNumber(bid) || !MathIsValidNumber(ask) ||
         !MathIsValidNumber(sl) || !MathIsValidNumber(tp) ||
         !MathIsValidNumber(minimum) || bid<=0.0 || ask<bid ||
         sl<=0.0 || tp<=0.0 || minimum<0.0)
      {why="invalid fresh quote/SL/TP/stops metadata";return false;}
      if(direction==QSMC_DIR_BUY)
      {
         if(sl>=bid || tp<=bid || bid-sl<minimum || tp-bid<minimum)
         {why="BUY protective stops violate fresh Bid distance";return false;}
      }
      else if(direction==QSMC_DIR_SELL)
      {
         if(sl<=ask || tp>=ask || sl-ask<minimum || ask-tp<minimum)
         {why="SELL protective stops violate fresh Ask distance";return false;}
      }
      else {why="invalid direction";return false;}
      return true;
   }
};
#endif // QSMC_BROKERRULES_MQH
