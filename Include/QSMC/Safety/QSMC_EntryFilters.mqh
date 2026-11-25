// Entry-only schedule/news composition; never gate risk/reconciliation with this.
#ifndef QSMC_ENTRYFILTERS_MQH
#define QSMC_ENTRYFILTERS_MQH
#include "../Core/QSMC_Config.mqh"
#include "QSMC_EntryTimeRules.mqh"
#include "QSMC_NewsFilter.mqh"
class CQSMCEntryFilters
{
private:
   SQSMCConfig m_cfg;
   CQSMCNewsFilter m_news;
   bool m_ready;
   bool m_haveOffset;
   int m_offset;
   datetime m_lastServer;
   string m_status;
   bool Report(const bool allowed,const string reason,string &why)
   {
      why=reason;
      if(m_status!=reason)Print("QSMC ENTRY FILTER: ",reason);
      m_status=reason;return allowed;
   }
public:
   CQSMCEntryFilters(){m_ready=false;m_haveOffset=false;m_offset=0;m_lastServer=0;m_status="not evaluated";}
   bool Init(const SQSMCConfig &cfg)
   {
      m_ready=false;m_haveOffset=false;m_lastServer=0;m_status="not evaluated";m_cfg=cfg;
      if(cfg.friday_cutoff_minute<0 || cfg.friday_cutoff_minute>=1440 ||
         !m_news.Init(cfg.news_keywords,cfg.tester_news_csv))return false;
      m_ready=true;
      double point=0.0,tick=0.0,lossTick=0.0,contract=0.0,vmin=0.0,vmax=0.0,step=0.0;
      long digits=0,stops=0,freeze=0,filling=0;
      bool metadata=SymbolInfoDouble(cfg.symbol,SYMBOL_POINT,point) &&
         SymbolInfoDouble(cfg.symbol,SYMBOL_TRADE_TICK_SIZE,tick) &&
         SymbolInfoDouble(cfg.symbol,SYMBOL_TRADE_TICK_VALUE_LOSS,lossTick) &&
         SymbolInfoDouble(cfg.symbol,SYMBOL_TRADE_CONTRACT_SIZE,contract) &&
         SymbolInfoDouble(cfg.symbol,SYMBOL_VOLUME_MIN,vmin) &&
         SymbolInfoDouble(cfg.symbol,SYMBOL_VOLUME_MAX,vmax) &&
         SymbolInfoDouble(cfg.symbol,SYMBOL_VOLUME_STEP,step) &&
         SymbolInfoInteger(cfg.symbol,SYMBOL_DIGITS,digits) &&
         SymbolInfoInteger(cfg.symbol,SYMBOL_TRADE_STOPS_LEVEL,stops) &&
         SymbolInfoInteger(cfg.symbol,SYMBOL_TRADE_FREEZE_LEVEL,freeze) &&
         SymbolInfoInteger(cfg.symbol,SYMBOL_FILLING_MODE,filling);
      Print("QSMC CONTRACT (diagnostic only): symbol=",cfg.symbol," readsComplete=",metadata,
         " digits=",digits," point=",DoubleToString(point,8)," tickSize=",DoubleToString(tick,8),
         " lossTickValue=",DoubleToString(lossTick,8)," contractSize=",DoubleToString(contract,8),
         " volume min/step/max=",DoubleToString(vmin,8),"/",DoubleToString(step,8),"/",DoubleToString(vmax,8),
         " stops/freeze points=",stops,"/",freeze," fillFlags=",filling);
      Print("QSMC EFFECTIVE UNITS: spread cap points=",cfg.max_spread_points," price=",DoubleToString(cfg.max_spread_points*point,8),
         "; deviation points=",cfg.deviation_points," price=",DoubleToString(cfg.deviation_points*point,8),
         "; zone tolerance points=",cfg.zone_tolerance_points," price=",DoubleToString(cfg.zone_tolerance_points*point,8),
         "; thresholds NOT converted/changed; confirm broker symbol/suffix and server clock");
      Print("QSMC ENTRY: rollover 23:45-01:15, weekends, Friday cutoff minute=",cfg.friday_cutoff_minute,
            "; current-session union; NO forced closes; server-time windows require manual DST review");
      if(MQLInfoInteger(MQL_TESTER)!=0)
         Print("QSMC CLOCK: tester UTC offset diagnostics unavailable; CSV timestamps MUST already use historical broker-server time");
      return true;
   }
   // Timer diagnostics only; no news outage or blackout may stop risk monitoring.
   void ObserveClock()
   {
      if(!m_ready)return;
      datetime server=TimeTradeServer();
      if(server<=0)return;
      if(m_lastServer>0 && server<m_lastServer)
      {
         Print("QSMC CLOCK WARNING: server clock moved backwards; news cache invalidated");
         m_news.Invalidate();
      }
      m_lastServer=server;
      if(MQLInfoInteger(MQL_TESTER)!=0)return;
      datetime utc=TimeGMT();
      if(utc<=0)return;
      int offset=(int)MathRound((double)((long)server-(long)utc)/60.0);
      if(!m_haveOffset)
      {
         m_haveOffset=true;m_offset=offset;
         Print("QSMC CLOCK: observed server-UTC offset=",offset," minutes; no automatic DST session adjustment");
      }
      else if(MathAbs(offset-m_offset)>=2)
      {
         Print("QSMC CLOCK WARNING: server-UTC offset changed from ",m_offset," to ",offset,
               " minutes; review DST/session inputs; news cache invalidated, sessions NOT shifted");
         m_offset=offset;m_news.Invalidate();
      }
   }
   bool Check(string &why)
   {
      if(!m_ready)return Report(false,"entry filters uninitialized",why);
      ObserveClock();
      datetime now=TimeTradeServer();MqlDateTime dt;
      if(now<=0 || !TimeToStruct(now,dt))return Report(false,"broker-server clock unavailable",why);
      string reason;
      if(!CQSMCEntryTimeRules::Schedule(dt.day_of_week,dt.hour*60+dt.min,m_cfg.friday_cutoff_minute,
         m_cfg.sessions_enabled,m_cfg.asia_start_minute,m_cfg.asia_end_minute,
         m_cfg.london_start_minute,m_cfg.london_end_minute,m_cfg.new_york_start_minute,
         m_cfg.new_york_end_minute,reason))return Report(false,reason,why);
      if(!m_news.Check(now,reason))return Report(false,reason,why);
      // A calendar fetch must not carry a pre-cutoff permission past the cutoff.
      datetime finalNow=TimeTradeServer();
      if(finalNow<now || !TimeToStruct(finalNow,dt))return Report(false,"clock changed during entry-filter check",why);
      string scheduleReason;
      if(!CQSMCEntryTimeRules::Schedule(dt.day_of_week,dt.hour*60+dt.min,m_cfg.friday_cutoff_minute,
         m_cfg.sessions_enabled,m_cfg.asia_start_minute,m_cfg.asia_end_minute,
         m_cfg.london_start_minute,m_cfg.london_end_minute,m_cfg.new_york_start_minute,
         m_cfg.new_york_end_minute,scheduleReason))return Report(false,scheduleReason,why);
      return Report(true,reason,why);
   }
   string Status() const{return m_status;}
};
#endif // QSMC_ENTRYFILTERS_MQH
