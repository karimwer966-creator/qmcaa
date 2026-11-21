//+------------------------------------------------------------------+
//|                                              QSMC_Diagnostics.mqh |
//|  Structured, bounded diagnostic sink.  Modules report machine       |
//|  readable codes plus human readable detail; nothing here affects    |
//|  trading decisions, but CRITICAL entries are surfaced to safety.    |
//+------------------------------------------------------------------+
#ifndef QSMC_DIAGNOSTICS_MQH
#define QSMC_DIAGNOSTICS_MQH

#include "../Core/QSMC_Constants.mqh"
#include "../Core/QSMC_Types.mqh"

enum ENUM_QSMC_DIAG_SEVERITY
{
   QSMC_DIAG_INFO     = 0,
   QSMC_DIAG_WARN     = 1,
   QSMC_DIAG_CRITICAL = 2
};

struct SQSMCDiagnostic
{
   ENUM_QSMC_DIAG_SEVERITY severity;
   string                  code;
   string                  detail;
   datetime                when;
};

struct SQSMCDiagModule
{
   string   name;
   bool     ok;
   string   detail;
   datetime when;
};

class CQSMDiagnostics
{
private:
   SQSMCDiagnostic m_items[QSMC_MAX_DIAGNOSTICS];
   int             m_count;
   int             m_head;
   int             m_critical;
   int             m_warnings;
   int             m_total;

   SQSMCDiagModule m_modules[16];
   int             m_moduleCount;

   int FindModule(const string name) const
   {
      for(int i = 0; i < m_moduleCount; i++)
         if(m_modules[i].name == name) return i;
      return QSMC_INVALID_INDEX;
   }

public:
   CQSMDiagnostics() { Clear(); }

   void Clear()
   {
      for(int i = 0; i < QSMC_MAX_DIAGNOSTICS; i++)
      {
         m_items[i].severity = QSMC_DIAG_INFO;
         m_items[i].code     = "";
         m_items[i].detail   = "";
         m_items[i].when     = 0;
      }
      for(int j = 0; j < 16; j++)
      {
         m_modules[j].name   = "";
         m_modules[j].ok     = false;
         m_modules[j].detail = "";
         m_modules[j].when   = 0;
      }
      m_count       = 0;
      m_head        = 0;
      m_critical    = 0;
      m_warnings    = 0;
      m_total       = 0;
      m_moduleCount = 0;
   }

   void Add(const ENUM_QSMC_DIAG_SEVERITY severity,
            const string code,
            const string detail)
   {
      m_items[m_head].severity = severity;
      m_items[m_head].code     = code;
      m_items[m_head].detail   = detail;
      m_items[m_head].when     = TimeCurrent();
      m_head = (m_head + 1) % QSMC_MAX_DIAGNOSTICS;

      if(m_count < QSMC_MAX_DIAGNOSTICS) m_count++;
      if(severity == QSMC_DIAG_CRITICAL) m_critical++;
      if(severity == QSMC_DIAG_WARN)     m_warnings++;
      m_total++;
   }

   void Info(const string code, const string detail)     { Add(QSMC_DIAG_INFO, code, detail); }
   void Warn(const string code, const string detail)     { Add(QSMC_DIAG_WARN, code, detail); }
   void Critical(const string code, const string detail) { Add(QSMC_DIAG_CRITICAL, code, detail); }

   int  Count()        const { return m_count; }
   int  Total()        const { return m_total; }
   int  CriticalCount()const { return m_critical; }
   int  WarningCount() const { return m_warnings; }
   bool HasCritical()  const { return (m_critical > 0); }

   bool Get(const int backIndex, SQSMCDiagnostic &out) const
   {
      if(backIndex < 0 || backIndex >= m_count) return false;
      int idx = (m_head - 1 - backIndex + QSMC_MAX_DIAGNOSTICS * 2) % QSMC_MAX_DIAGNOSTICS;
      out = m_items[idx];
      return true;
   }

   string Last() const
   {
      SQSMCDiagnostic d;
      if(!Get(0, d)) return "";
      return "[" + d.code + "] " + d.detail;
   }

   //--- module readiness registry ------------------------------------
   void ReportModule(const string name, const bool ok, const string detail)
   {
      int idx = FindModule(name);
      if(idx == QSMC_INVALID_INDEX)
      {
         if(m_moduleCount >= 16) return;
         idx = m_moduleCount;
         m_moduleCount++;
         m_modules[idx].name = name;
      }
      m_modules[idx].ok     = ok;
      m_modules[idx].detail = detail;
      m_modules[idx].when   = TimeCurrent();

      if(!ok)
         Warn("MODULE_" + name, detail);
   }

   bool ModuleOk(const string name) const
   {
      int idx = FindModule(name);
      if(idx == QSMC_INVALID_INDEX) return false;
      return m_modules[idx].ok;
   }

   string ModuleReport() const
   {
      string out = "";
      for(int i = 0; i < m_moduleCount; i++)
      {
         if(i > 0) out += "\n";
         out += StringFormat("%-12s %-4s %s",
                             m_modules[i].name,
                             (m_modules[i].ok ? "OK" : "FAIL"),
                             m_modules[i].detail);
      }
      return out;
   }

   string Report(const int maxItems = 8) const
   {
      string out = StringFormat("diagnostics: total=%d warn=%d critical=%d stored=%d",
                                m_total, m_warnings, m_critical, m_count);
      int limit = (maxItems < m_count ? maxItems : m_count);
      SQSMCDiagnostic d;
      for(int i = 0; i < limit; i++)
      {
         if(!Get(i, d)) break;
         out += "\n  " + TimeToString(d.when, TIME_DATE | TIME_SECONDS) +
                " " + d.code + ": " + d.detail;
      }
      return out;
   }
};

#endif // QSMC_DIAGNOSTICS_MQH
