//+------------------------------------------------------------------+
//|                                        QSMC_EventDispatcher.mqh |
//|  Thin event accounting/ordering boundary. App owns the handlers;    |
//|  this class ensures callbacks are consistently sequenced and that  |
//|  shutdown ignores late platform events.                             |
//+------------------------------------------------------------------+
#ifndef QSMC_EVENTDISPATCHER_MQH
#define QSMC_EVENTDISPATCHER_MQH
class CQSMCEventDispatcher
{
private:
   bool m_accepting;
   ulong m_ticks,m_timers,m_trades;
public:
   CQSMCEventDispatcher(){m_accepting=false;m_ticks=0;m_timers=0;m_trades=0;}
   void Start(){m_accepting=true;}
   void Stop(){m_accepting=false;}
   bool Accepting() const{return m_accepting;}
   bool Tick(){if(!m_accepting)return false;m_ticks++;return true;}
   bool Timer(){if(!m_accepting)return false;m_timers++;return true;}
   bool Trade(){if(!m_accepting)return false;m_trades++;return true;}
   ulong Ticks() const{return m_ticks;}
   ulong Timers() const{return m_timers;}
   ulong Trades() const{return m_trades;}
};
#endif // QSMC_EVENTDISPATCHER_MQH
