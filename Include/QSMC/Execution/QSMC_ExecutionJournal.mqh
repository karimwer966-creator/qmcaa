//+------------------------------------------------------------------+
//|                                          QSMC_ExecutionJournal.mqh |
//|  Fixed-size runtime audit journal plus persisted UID duplicate guard.|
//+------------------------------------------------------------------+
#ifndef QSMC_EXECUTIONJOURNAL_MQH
#define QSMC_EXECUTIONJOURNAL_MQH
#include "../Core/QSMC_Constants.mqh"
#include "../Core/QSMC_Types.mqh"
#include "../Infrastructure/QSMC_StateStore.mqh"
#include "QSMC_ExecutionAdapter.mqh"

struct SQSMCJournalEntry
{
   datetime time;
   ulong uid;
   ENUM_QSMC_RESULT code;
   string symbol;
   ulong magic;
   string reason;
   string result;
};
class CQSMCExecutionJournal
{
private:
   SQSMCJournalEntry m_entries[QSMC_MAX_JOURNAL];
   int m_count;
   int m_next;
public:
   CQSMCExecutionJournal(){m_count=0;m_next=0;}
   void Record(const SQSMCOrderIntent &intent,const ENUM_QSMC_RESULT code,
               const string reason,const string result)
   {
      int i=m_next;
      m_entries[i].time=TimeCurrent();m_entries[i].uid=intent.uid;m_entries[i].code=code;
      m_entries[i].symbol=intent.symbol;m_entries[i].magic=intent.magic;
      m_entries[i].reason=reason;m_entries[i].result=result;
      PrintFormat("QSMC EXEC %s symbol=%s magic=%I64u intent=%I64u code=%d reason=%s result=%s",
                  TimeToString(m_entries[i].time,TIME_DATE|TIME_SECONDS),intent.symbol,
                  intent.magic,intent.uid,(int)code,reason,result);
      m_next=(m_next+1)%QSMC_MAX_JOURNAL;
      if(m_count<QSMC_MAX_JOURNAL)m_count++;
   }
   bool Seen(const ulong uid,CQSMCStateStore &store) const
   {
      if(uid==0)return true;
      string needle=StringFormat("%I64u",uid);
      if(store.GetString("execution.last_uid","")==needle)return true;
      for(int k=0;k<16;k++)
         if(store.GetString("execution.uid."+IntegerToString(k),"")==needle)return true;
      for(int n=0;n<m_count;n++)
      {
         int i=(m_next-1-n+QSMC_MAX_JOURNAL)%QSMC_MAX_JOURNAL;
         if(m_entries[i].uid==uid)return true;
      }
      return false;
   }
   // QSMC-003: report EVERY mutation failure; caller can batch a single Save.
   // This does not fix StateStore's replacement/durability contract (Phase 6).
   bool MarkSubmitted(const ulong uid,CQSMCStateStore &store,const bool saveNow=true)
   {
      if(uid==0 || !store.IsReady())return false;
      for(int i=15;i>0;i--)
      {
         string older=store.GetString("execution.uid."+IntegerToString(i-1),"");
         if(!store.SetString("execution.uid."+IntegerToString(i),older))return false;
      }
      string value=StringFormat("%I64u",uid);
      if(!store.SetString("execution.uid.0",value) ||
         !store.SetString("execution.last_uid",value))return false;
      return (!saveNow || store.Save());
   }
   int Count() const{return m_count;}
   bool GetNewest(const int index,SQSMCJournalEntry &out) const
   {
      if(index<0 || index>=m_count)return false;
      int i=(m_next-1-index+QSMC_MAX_JOURNAL)%QSMC_MAX_JOURNAL;
      out=m_entries[i];return true;
   }
};
#endif // QSMC_EXECUTIONJOURNAL_MQH
