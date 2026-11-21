//+------------------------------------------------------------------+
//|                                                QSMC_Lifecycle.mqh |
//|  Idempotent timer and event lifecycle guard.                        |
//+------------------------------------------------------------------+
#ifndef QSMC_LIFECYCLE_MQH
#define QSMC_LIFECYCLE_MQH
#include "../Core/QSMC_Types.mqh"
class CQSMCLifecycle
{
private:
   bool m_initialised;
   bool m_timer;
   int m_ms;
public:
   CQSMCLifecycle(){m_initialised=false;m_timer=false;m_ms=0;}
   bool Start(const int timerMs,SQSMCResult &result)
   {
      result.Clear();
      if(m_initialised){result.Set(QSMC_ERR_ALREADY_INITIALIZED,"lifecycle already started");return false;}
      if(timerMs<100 || timerMs>60000){result.Set(QSMC_ERR_INVALID_CONFIG,"timer interval out of bounds");return false;}
      ResetLastError();
      if(!EventSetMillisecondTimer(timerMs))
      {result.Set(QSMC_ERR_TIMER,"EventSetMillisecondTimer failed: "+IntegerToString(GetLastError()));return false;}
      m_initialised=true;m_timer=true;m_ms=timerMs;result.Set(QSMC_OK,"timer started");return true;
   }
   bool Stop()
   {
      if(m_timer){EventKillTimer();m_timer=false;}
      bool was=m_initialised;m_initialised=false;m_ms=0;return was;
   }
   bool IsInitialised() const{return m_initialised;}
   bool TimerActive() const{return m_timer;}
   int TimerMs() const{return m_ms;}
};
#endif // QSMC_LIFECYCLE_MQH
