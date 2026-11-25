// Schema 2: scoped common-files alternating sealed snapshots, exclusive writer.
// Interrupted/invalid artifacts FAIL CLOSED; no silent rollback or legacy import.
#ifndef QSMC_STATESTORE_MQH
#define QSMC_STATESTORE_MQH
#include "../Core/QSMC_Constants.mqh"
#include "../Core/QSMC_InputFingerprint.mqh"
#include "../Core/QSMC_OwnerScope.mqh"
#include "QSMC_StateCodec.mqh"

class CQSMCStateStore
{
private:
   string m_file,m_scope,m_error,m_symbol;
   bool m_ready,m_dirty,m_readOnly,m_fault,m_existing;
   long m_generation;
   ulong m_magic;
   int m_count,m_lock;
   string m_keys[QSMC_MAX_STORE_KEYS],m_vals[QSMC_MAX_STORE_KEYS],m_types[QSMC_MAX_STORE_KEYS];
   int Find(const string key) const
   {for(int i=0;i<m_count;i++)if(m_keys[i]==key)return i;return -1;}
   bool Fail(const string reason){m_error=reason;m_fault=true;return false;}
   bool Upsert(const string key,const string type,const string value)
   {
      if(!IsWritable() || !CQSMCStateCodec::Value(key,type,value))return false;
      int i=Find(key);bool inserted=(i<0);
      if(i<0){if(m_count>=QSMC_MAX_STORE_KEYS){m_error="state capacity exceeded";return false;}i=m_count++;m_keys[i]=key;}
      if(!inserted && m_types[i]==type && m_vals[i]==value)return true;
      m_types[i]=type;m_vals[i]=value;m_dirty=true;return true;
   }
   string Payload(const long generation) const
   {
      string text="#QSMC_STATE_V2\r\nscope="+m_scope+"\r\ngeneration="+IntegerToString(generation)+
                  "\r\ncount="+IntegerToString(m_count)+"\r\n";
      for(int i=0;i<m_count;i++)text+=m_keys[i]+"="+m_types[i]+":"+m_vals[i]+"\r\n";
      return text;
   }
   bool Parse(const string path,string &keys[],string &vals[],string &types[],long &generation,int &count)
   {
      generation=0;count=0;
      int h=FileOpen(path,FILE_READ|FILE_TXT|FILE_UNICODE|FILE_COMMON|FILE_SHARE_READ);
      if(h==INVALID_HANDLE){m_error="snapshot open failed";return false;}
      ResetLastError();
      bool ok=(FileSize(h)>0 && FileSize(h)<=1048576);
      string header=FileReadString(h),scope=FileReadString(h),gen=FileReadString(h),cnt=FileReadString(h);
      string payload=header+"\r\n"+scope+"\r\n"+gen+"\r\n"+cnt+"\r\n";
      if(header!="#QSMC_STATE_V2" || scope!="scope="+m_scope || StringFind(gen,"generation=")!=0 ||
         StringFind(cnt,"count=")!=0)ok=false;
      string gs=StringSubstr(gen,11),cs=StringSubstr(cnt,6);
      if(!CQSMCStateCodec::Integer(gs) || !CQSMCStateCodec::Integer(cs))ok=false;
      generation=StringToInteger(gs);long entries=StringToInteger(cs);
      if(generation<1 || entries<0 || entries>QSMC_MAX_STORE_KEYS)ok=false;
      ArrayResize(keys,QSMC_MAX_STORE_KEYS);ArrayResize(vals,QSMC_MAX_STORE_KEYS);ArrayResize(types,QSMC_MAX_STORE_KEYS);
      for(int i=0;ok && i<(int)entries;i++)
      {
         if(FileIsEnding(h)){ok=false;break;}
         string line=FileReadString(h);int eq=StringFind(line,"=");
         if(eq<1 || StringSubstr(line,eq+2,1)!=":"){ok=false;break;}
         string key=StringSubstr(line,0,eq),type=StringSubstr(line,eq+1,1),value=StringSubstr(line,eq+3);
         if(!CQSMCStateCodec::Value(key,type,value)){ok=false;break;}
         for(int j=0;j<i;j++)if(keys[j]==key)ok=false;
         keys[i]=key;types[i]=type;vals[i]=value;count++;payload+=line+"\r\n";
      }
      if(ok)
      {
         string seal=FileReadString(h);
         if(seal!="#END="+QSMC_UlongToHex(QSMC_HashString(payload)) || !FileIsEnding(h))ok=false;
      }
      if(GetLastError()!=0)ok=false;
      FileClose(h);
      if(!ok)m_error="invalid schema/scope/seal/duplicate or incomplete snapshot: "+path;
      return ok;
   }
public:
   CQSMCStateStore(){m_ready=false;m_dirty=false;m_readOnly=true;m_fault=false;m_existing=false;m_generation=0;m_magic=0;m_count=0;m_lock=INVALID_HANDLE;}
   ~CQSMCStateStore(){Close();}
   void Close(){if(m_lock!=INVALID_HANDLE)FileClose(m_lock);m_lock=INVALID_HANDLE;m_ready=false;}
   bool Init(const ulong magic,const bool readOnly=false)
   {return InitScoped(AccountInfoInteger(ACCOUNT_LOGIN),AccountInfoString(ACCOUNT_SERVER),_Symbol,magic,readOnly);}
   bool InitScoped(const long login,const string server,const string symbol,const ulong magic,const bool readOnly=false)
   {
      Close();m_fault=false;m_error="";m_count=0;m_generation=0;m_dirty=false;m_existing=false;
      m_symbol=symbol;m_scope=CQSMCOwnerScope::Raw(login,server,symbol,magic);m_magic=magic;m_readOnly=readOnly;
      if(StringLen(m_scope)==0)return Fail("invalid raw owner scope");
      FolderCreate("QSMC",FILE_COMMON);
      m_file=QSMC_FILE_FOLDER+"v2_"+QSMC_UlongToHex(QSMC_HashString(m_scope));
      if(!readOnly)
      {
         // No share flags: OS-held file handle, no time-based stale-lock stealing.
         m_lock=FileOpen(m_file+".lock",FILE_READ|FILE_WRITE|FILE_BIN|FILE_COMMON);
         if(m_lock==INVALID_HANDLE)return Fail("exclusive owner claim unavailable");
      }
      m_ready=true;
      if(!Load()){m_ready=false;return false;}
      return true;
   }
   bool IsReady() const{return m_ready && !m_fault && m_scope==CQSMCOwnerScope::Raw(AccountInfoInteger(ACCOUNT_LOGIN),AccountInfoString(ACCOUNT_SERVER),m_symbol,m_magic);}
   bool IsWritable() const{return IsReady() && !m_readOnly && m_lock!=INVALID_HANDLE;}
   bool HasSnapshot() const{return m_existing;}
   string Scope() const{return m_scope;}
   string FileName() const{return m_file;}
   string LastError() const{return m_error;}
   int Count() const{return m_count;}
   ulong Magic() const{return m_magic;}
   bool IsDirty() const{return m_dirty;}
   bool Exists(const string key) const{return Find(key)>=0;}
   bool SetString(const string key,const string value){return Upsert(key,"S",value);}
   bool SetInt(const string key,const long value){return Upsert(key,"I",IntegerToString(value));}
   bool SetDouble(const string key,const double value)
   {if(!MathIsValidNumber(value))return false;return Upsert(key,"D",DoubleToString(value,16));}
   bool SetBool(const string key,const bool value){return Upsert(key,"B",value?"1":"0");}
   string GetString(const string key,const string def="") const
   {int i=Find(key);return i<0?def:m_vals[i];}
   long GetInt(const string key,const long def=0) const
   {int i=Find(key);return (i<0 || m_types[i]!="I")?def:StringToInteger(m_vals[i]);}
   double GetDouble(const string key,const double def=0.0) const
   {int i=Find(key);return (i<0 || m_types[i]!="D")?def:StringToDouble(m_vals[i]);}
   bool GetBool(const string key,const bool def=false) const
   {int i=Find(key);return i<0?def:(m_types[i]!="B" || m_vals[i]!="0");}
   bool Remove(const string key)
   {
      if(!IsWritable())return false;int i=Find(key);if(i<0)return false;
      for(int j=i;j<m_count-1;j++){m_keys[j]=m_keys[j+1];m_vals[j]=m_vals[j+1];m_types[j]=m_types[j+1];}
      m_count--;m_dirty=true;return true;
   }
   string KillGvName() const{return QSMC_GV_PREFIX+"V2_"+QSMC_UlongToHex(QSMC_HashString(m_scope))+"_kill";}
   bool KillSwitchActive() const
   {
      if(!IsReady() || GetBool("kill",false))return true;
      return GlobalVariableCheck(KillGvName()) && GlobalVariableGet(KillGvName())!=0.0;
   }
   string KillSwitchReason() const{return GetString("kill_reason","");}
   bool SetKillSwitch(const bool active,const string reason="")
   {
      // A read-only diagnostic observer cannot release or engage another owner.
      if(m_readOnly || m_lock==INVALID_HANDLE)return false;
      bool a=SetBool("kill",active),b=true;
      if(active)b=SetString("kill_reason",reason);
      else if(Exists("kill_reason"))b=Remove("kill_reason");
      bool c=Save();bool d=(GlobalVariableSet(KillGvName(),active?1.0:0.0)!=0);GlobalVariablesFlush();
      if(!a || !b || !c || !d)
      {
         SetBool("kill",true);GlobalVariableSet(KillGvName(),1.0);GlobalVariablesFlush();
         if(IsWritable())Save();return false;
      }
      return true;
   }
   bool Save()
   {
      if(!IsWritable())return false;
      if(m_generation>=2147483646)return Fail("snapshot generation exhausted");
      string tmp=m_file+".tmp";
      if(FileIsExist(tmp,FILE_COMMON))return Fail("unresolved prior staging file");
      long next=m_generation+1;
      string payload=Payload(next),text=payload+"#END="+QSMC_UlongToHex(QSMC_HashString(payload))+"\r\n";
      int h=FileOpen(tmp,FILE_WRITE|FILE_TXT|FILE_UNICODE|FILE_COMMON);
      if(h==INVALID_HANDLE)return Fail("snapshot staging open failed");
      ResetLastError();uint written=FileWriteString(h,text);int writeError=GetLastError();
      ResetLastError();FileFlush(h);int flushError=GetLastError();FileClose(h);
      if(written!=(uint)(2*StringLen(text)) || writeError!=0 || flushError!=0)return Fail("snapshot short write/flush failed; staging preserved");
      string keys[],vals[],types[];long verified=0;int count=0;
      if(!Parse(tmp,keys,vals,types,verified,count) || verified!=next || count!=m_count)
         return Fail("staging validation failed; preserved for review");
      string slot=m_file+(next%2==1?".a.state":".b.state");
      // Never delete a valid snapshot or fall back to writing it in place.
      if(!FileMove(tmp,FILE_COMMON,slot,FILE_COMMON|FILE_REWRITE))return Fail("snapshot replace failed; prior slots/staging preserved");
      m_generation=next;m_existing=true;m_dirty=false;return true;
   }
   bool Load()
   {
      if(!m_ready || m_dirty)return false;
      if(FileIsExist(m_file+".tmp",FILE_COMMON))return Fail("interrupted commit staging exists; manual recovery required");
      long best=0,lowest=0;int count=0,slots=0;string keys[],vals[],types[];
      for(int slot=0;slot<2;slot++)
      {
         string path=m_file+(slot==0?".a.state":".b.state");
         if(!FileIsExist(path,FILE_COMMON))continue;
         long generation=0;
         if(!Parse(path,keys,vals,types,generation,count))return Fail(m_error);
         if((generation%2==1)!=(slot==0) || generation==best)return Fail("snapshot generation/slot conflict");
         slots++;if(lowest==0 || generation<lowest)lowest=generation;
         if(generation>best)
         {
            best=generation;m_count=count;
            for(int i=0;i<count;i++){m_keys[i]=keys[i];m_vals[i]=vals[i];m_types[i]=types[i];}
         }
      }
      if((slots==1 && best!=1) || (slots==2 && best-lowest!=1))return Fail("snapshot generation continuity missing");
      m_generation=best;m_existing=best>0;m_dirty=false;return true;
   }
   string Describe() const{return "scoped schema=2 file="+m_file+" writable="+(IsWritable()?"yes":"no")+" error="+m_error;}
};
#endif // QSMC_STATESTORE_MQH
