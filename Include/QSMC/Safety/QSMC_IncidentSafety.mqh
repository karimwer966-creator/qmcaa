// Fail-closed incident latch. File atomicity/scoping remains Phase 6 work.
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
   bool ValidFlag(CQSMCStateStore &store,const string key) const
   {
      return (!store.Exists(key) || store.GetString(key)=="0" || store.GetString(key)=="1");
   }
public:
   CQSMCIncidentSafety(){Reset();}
   void Reset(){m_latched=false;m_recoveryUncertain=false;m_time=0;m_reason="";}
   bool Restore(CQSMCStateStore &store)
   {
      Reset();
      if(!store.IsReady() || !ValidFlag(store,"safety.kill") ||
         !ValidFlag(store,"safety.uncertain") || !ValidFlag(store,"kill"))
      {
         m_latched=true;m_recoveryUncertain=true;m_reason="safety state unavailable/malformed";
         return false;
      }
      // GetBool RETURNS the value; its second argument is a default, not an out parameter.
      bool latch=store.GetBool("safety.kill",false);
      bool uncertain=store.GetBool("safety.uncertain",false);
      bool pending=(StringLen(store.GetString("execution.pending_uid",""))>0);
      m_latched=latch || uncertain || pending || store.KillSwitchActive();
      m_recoveryUncertain=uncertain || pending;
      m_reason=store.GetString("safety.reason",store.KillSwitchReason());
      m_time=(datetime)store.GetInt("safety.time",0);
      if(m_latched && StringLen(m_reason)==0)m_reason="recovered safety latch";
      return !m_latched;
   }
   bool Latch(CQSMCStateStore &store,const string reason,const bool uncertain=false)
   {
      m_latched=true;
      m_recoveryUncertain=m_recoveryUncertain || uncertain;
      m_time=TimeCurrent();m_reason=reason;
      // Evaluate every write independently so a full store cannot skip the GV brake.
      bool a=store.SetBool("safety.kill",true);
      bool b=store.SetBool("safety.uncertain",m_recoveryUncertain);
      bool c=store.SetString("safety.reason",reason);
      bool d=store.SetInt("safety.time",(long)m_time);
      bool e=store.SetKillSwitch(true,reason);
      bool ok=a && b && c && d && e;
      if(!ok){m_recoveryUncertain=true;m_reason=reason+"; safety persistence failed";}
      Print("QSMC SAFETY LATCH: ",m_reason," persisted=",ok);
      return ok; // In-memory latch remains engaged even on persistence failure.
   }
   bool Acknowledge(CQSMCStateStore &store,const bool operatorConfirmed)
   {
      if(!operatorConfirmed || !m_latched || !store.IsReady() ||
         StringLen(store.GetString("execution.pending_uid",""))>0)return false;
      string reason="operator acknowledged at "+TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS);
      bool a=store.SetBool("safety.kill",false);
      bool b=store.SetBool("safety.uncertain",false);
      bool c=store.SetString("safety.reason",reason);
      bool d=store.SetKillSwitch(false);
      if(!a || !b || !c || !d)
      {
         Latch(store,"acknowledgement persistence failed",true);return false;
      }
      // Clear memory only AFTER all file/GV operations report success.
      m_latched=false;m_recoveryUncertain=false;m_reason=reason;
      Print("QSMC SAFETY: ",reason);
      return true;
   }
   bool IsLatched() const{return m_latched;}
   bool RecoveryUncertain() const{return m_recoveryUncertain;}
   datetime Time() const{return m_time;}
   string Reason() const{return m_reason;}
};
#endif // QSMC_INCIDENTSAFETY_MQH
