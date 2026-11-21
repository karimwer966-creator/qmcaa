//+------------------------------------------------------------------+
//|                                               QSMC_StateStore.mqh |
//|  Small, typed persistence layer used for restart recovery.         |
//|  Storage:  MQL5/Files/QSMC/state_<magic>.state  ("key=value" lines)|
//|  The emergency stop (kill switch) is additionally mirrored into a  |
//|  terminal GlobalVariable so it survives even if the file layer is   |
//|  unavailable (sandboxed tester, read-only data folder, ...).        |
//+------------------------------------------------------------------+
#ifndef QSMC_STATESTORE_MQH
#define QSMC_STATESTORE_MQH

#include "../Core/QSMC_Constants.mqh"
#include "../Core/QSMC_Types.mqh"
#include "../Core/QSMC_Version.mqh"

class CQSMCStateStore
{
private:
   string m_file;
   bool   m_ready;
   bool   m_dirty;
   int    m_count;
   string m_keys[QSMC_MAX_STORE_KEYS];
   string m_vals[QSMC_MAX_STORE_KEYS];
   string m_lastError;
   ulong  m_magic;

   int Find(const string key) const
   {
      for(int i = 0; i < m_count; i++)
         if(m_keys[i] == key) return i;
      return QSMC_INVALID_INDEX;
   }

   bool Upsert(const string key, const string value)
   {
      if(!m_ready || StringLen(key) == 0) return false;

      int idx = Find(key);
      if(idx == QSMC_INVALID_INDEX)
      {
         if(m_count >= QSMC_MAX_STORE_KEYS)
         {
            m_lastError = "state store full";
            return false;
         }
         idx = m_count;
         m_count++;
         m_keys[idx] = key;
      }
      m_vals[idx] = value;
      m_dirty     = true;
      return true;
   }

public:
   CQSMCStateStore()
   {
      m_file      = "";
      m_ready     = false;
      m_dirty     = false;
      m_count     = 0;
      m_lastError = "";
      m_magic     = 0;
      for(int i = 0; i < QSMC_MAX_STORE_KEYS; i++)
      {
         m_keys[i] = "";
         m_vals[i] = "";
      }
   }

   bool Init(const ulong magic)
   {
      m_magic = magic;
      FolderCreate("QSMC");
      m_file  = QSMC_FILE_FOLDER + "state_" + IntegerToString((long)magic) + ".state";
      m_ready = true;
      m_count = 0;
      m_dirty = false;
      if(!Load())
      {
         m_ready=false;
         return false;
      }
      return true;
   }

   bool   IsReady()    const { return m_ready; }
   string FileName()   const { return m_file; }
   string LastError()  const { return m_lastError; }
   int    Count()      const { return m_count; }
   ulong  Magic()      const { return m_magic; }

   //--- raw access ---------------------------------------------------
   bool SetString(const string key, const string value) { return Upsert(key, value); }

   string GetString(const string key, const string def = "") const
   {
      int idx = Find(key);
      return (idx == QSMC_INVALID_INDEX ? def : m_vals[idx]);
   }

   bool SetInt(const string key, const long value)
   {
      return Upsert(key, IntegerToString(value));
   }

   long GetInt(const string key, const long def = 0) const
   {
      int idx = Find(key);
      if(idx == QSMC_INVALID_INDEX) return def;
      return StringToInteger(m_vals[idx]);
   }

   bool SetDouble(const string key, const double value)
   {
      return Upsert(key, DoubleToString(value, 8));
   }

   double GetDouble(const string key, const double def = 0.0) const
   {
      int idx = Find(key);
      if(idx == QSMC_INVALID_INDEX) return def;
      return StringToDouble(m_vals[idx]);
   }

   bool SetBool(const string key, const bool value)
   {
      return Upsert(key, value ? "1" : "0");
   }

   bool GetBool(const string key, const bool def = false) const
   {
      int idx = Find(key);
      if(idx == QSMC_INVALID_INDEX) return def;
      return (m_vals[idx] == "1");
   }

   bool Exists(const string key) const { return (Find(key) != QSMC_INVALID_INDEX); }

   bool Remove(const string key)
   {
      int idx = Find(key);
      if(idx == QSMC_INVALID_INDEX) return false;
      for(int i = idx; i < m_count - 1; i++)
      {
         m_keys[i] = m_keys[i + 1];
         m_vals[i] = m_vals[i + 1];
      }
      m_count--;
      m_keys[m_count] = "";
      m_vals[m_count] = "";
      m_dirty = true;
      return true;
   }

   //+---------------------------------------------------------------+
   //| Emergency stop: persisted twice (file + GlobalVariable).        |
   //+---------------------------------------------------------------+
   bool SetKillSwitch(const bool active, const string reason = "")
   {
      bool okFile = SetBool("kill", active);
      if(active) SetString("kill_reason", reason);
      else       Remove("kill_reason");
      Save();

      if(GlobalVariableCheck(KillGvName()))
         GlobalVariableSet(KillGvName(), active ? 1.0 : 0.0);
      else
         GlobalVariableSet(KillGvName(), active ? 1.0 : 0.0);

      return okFile;
   }

   bool KillSwitchActive() const
   {
      if(GetBool("kill", false)) return true;
      if(GlobalVariableCheck(KillGvName()))
         return (GlobalVariableGet(KillGvName()) != 0.0);
      return false;
   }

   string KillSwitchReason() const { return GetString("kill_reason", ""); }

   string KillGvName() const
   {
      return QSMC_GV_PREFIX + IntegerToString((long)m_magic) + "_kill";
   }

   //--- persistence --------------------------------------------------
   bool Save()
   {
      if(!m_ready) return false;

      string tmp = m_file + ".tmp";
      int h = FileOpen(tmp, FILE_WRITE | FILE_TXT | FILE_ANSI);
      if(h == INVALID_HANDLE)
      {
         m_lastError = "state save failed: " + IntegerToString(GetLastError());
         return false;
      }

      FileWriteString(h, "#QSMC state format=" +
                      IntegerToString(QSMC_STATE_FORMAT_VERSION) +
                      " version=" + QSMC_VersionTag() + "\r\n");
      for(int i = 0; i < m_count; i++)
         FileWriteString(h, m_keys[i] + "=" + m_vals[i] + "\r\n");
      FileClose(h);

      ResetLastError();
      if(!FileMove(tmp, 0, m_file, FILE_REWRITE))
      {
         // Fall back to writing in place (some sandboxes forbid renames).
         FileDelete(m_file);
         if(!FileMove(tmp, 0, m_file, 0))
         {
            m_lastError = "state move failed: " + IntegerToString(GetLastError());
            FileDelete(tmp);
            return false;
         }
      }

      m_dirty = false;
      return true;
   }

   bool Load()
   {
      if(!m_ready) return false;
      if(!FileIsExist(m_file)) return true;   // first run

      int h = FileOpen(m_file, FILE_READ | FILE_TXT | FILE_ANSI);
      if(h == INVALID_HANDLE)
      {
         m_lastError = "state load failed: " + IntegerToString(GetLastError());
         return false;
      }

      m_count = 0;
      while(!FileIsEnding(h))
      {
         string line = FileReadString(h);
         StringTrimLeft(line);
         StringTrimRight(line);
         if(StringLen(line) == 0 || StringSubstr(line, 0, 1) == "#") continue;

         int sep = StringFind(line, "=");
         if(sep <= 0) continue;

         string key = StringSubstr(line, 0, sep);
         string val = StringSubstr(line, sep + 1);
         if(m_count < QSMC_MAX_STORE_KEYS)
         {
            m_keys[m_count] = key;
            m_vals[m_count] = val;
            m_count++;
         }
      }
      FileClose(h);
      m_dirty = false;
      return true;
   }

   bool IsDirty() const { return m_dirty; }

   string Describe() const
   {
      return StringFormat("state file=%s keys=%d ready=%s dirty=%s",
                          m_file, m_count, (m_ready ? "yes" : "no"),
                          (m_dirty ? "yes" : "no"));
   }
};

#endif // QSMC_STATESTORE_MQH
