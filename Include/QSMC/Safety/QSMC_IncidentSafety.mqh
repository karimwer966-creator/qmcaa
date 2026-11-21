//+------------------------------------------------------------------+
//|                                         QSMC_IncidentSafety.mqh |
//|  Persistent incident latch.  Uncertain restart state remains blocked |
//|  until an explicit operator acknowledgement is made.               |
//+------------------------------------------------------------------+
#ifndef QSMC_INCIDENTSAFETY_MQH
#define QSMC_INCIDENTSAFETY_MQH
#include "../Core/QSMC_Types.mqh"
#include "../Infrastructure/QSMC_StateStore.mqh"

class CQSMCIncidentSafety
{
private:
   bool m_latched;
   bool m_recoveryUncertain;
   datetime m_time;
   string m_reason;
public:
   CQSMCIncidentSafety(){Reset();}
   void Reset(){m_latched=false;m_recoveryUncertain=false;m_time=0;m_reason="";}
   bool Restore(CQSMCStateStore &store)
   {
      bool latch=false, uncertain=false;
      store.GetBool("safety.kill",latch);
      store.GetBool("safety.uncertain",uncertain);
      m_latched=latch || uncertain || store.KillSwitchActive();
      m_recoveryUncertain=uncertain;
      m_reason=store.GetString("safety.reason",store.KillSwitchReason());
      m_time=(datetime)store.GetInt("safety.time",0);
      if(m_latched && StringLen(m_reason)==0) m_reason="recovered safety latch";
      return !m_latched;
   }
   bool Latch(CQSMCStateStore &store,const string reason,const bool uncertain=false)
   {
      m_latched=true;
      m_recoveryUncertain=uncertain;
      m_time=TimeCurrent();
      m_reason=reason;
      store.SetBool("safety.kill",true);
      store.SetBool("safety.uncertain",uncertain);
      store.SetString("safety.reason",reason);
      store.SetInt("safety.time",(long)m_time);
      store.SetKillSwitch(true,reason);
      store.Save();
      return true;
   }
   bool Acknowledge(CQSMCStateStore &store,const bool operatorConfirmed)
   {
      if(!operatorConfirmed || !m_latched) return false;
      m_latched=false;
      m_recoveryUncertain=false;
      m_reason="operator acknowledged at "+TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS);
      store.SetBool("safety.kill",false);
      store.SetBool("safety.uncertain",false);
      store.SetString("safety.reason",m_reason);
      store.SetKillSwitch(false);
      store.Save();
      return true;
   }
   bool IsLatched() const {return m_latched;}
   bool RecoveryUncertain() const {return m_recoveryUncertain;}
   datetime Time() const {return m_time;}
   string Reason() const {return m_reason;}
};
#endif // QSMC_INCIDENTSAFETY_MQH
