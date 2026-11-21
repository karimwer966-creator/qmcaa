//+------------------------------------------------------------------+
//|                                            QSMC_AlertManager.mqh |
//|  Rate-limited terminal alerts for critical system events.           |
//+------------------------------------------------------------------+
#ifndef QSMC_ALERTMANAGER_MQH
#define QSMC_ALERTMANAGER_MQH
class CQSMCAlertManager
{
private:
   datetime m_lastAlert;
   int m_minInterval;
public:
   CQSMCAlertManager(){m_lastAlert=0;m_minInterval=30;}
   void SetInterval(const int seconds){if(seconds>=0)m_minInterval=seconds;}
   bool Notify(const string message,const bool critical=false)
   {
      datetime now=TimeCurrent();
      if(!critical && m_lastAlert>0 && now-m_lastAlert<m_minInterval)return false;
      Alert("QSMC: ",message);
      m_lastAlert=now;
      return true;
   }
};
#endif // QSMC_ALERTMANAGER_MQH
