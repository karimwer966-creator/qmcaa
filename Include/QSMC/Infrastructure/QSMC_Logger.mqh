//+------------------------------------------------------------------+
//|                                                   QSMC_Logger.mqh |
//|  Level-filtered logger with an in-memory ring buffer (inspectable  |
//|  from the dashboard and the self-test) and optional append-only    |
//|  text file.  File I/O failures never break the trading pipeline:   |
//|  they downgrade to terminal-only logging and are reported once.    |
//+------------------------------------------------------------------+
#ifndef QSMC_LOGGER_MQH
#define QSMC_LOGGER_MQH

#include "../Core/QSMC_Constants.mqh"
#include "../Core/QSMC_Types.mqh"

class CQSMCLogger
{
private:
   ENUM_QSMC_LOG_LEVEL m_level;
   bool                m_fileEnabled;
   bool                m_fileHealthy;
   bool                m_initialised;
   string              m_file;
   string              m_tag;
   int                 m_count;
   int                 m_head;                  // next write slot
   string              m_ring[QSMC_MAX_LOG_ENTRIES];
   int                 m_writes;
   int                 m_suppressed;
   string              m_lastError;

   void Push(const string line)
   {
      m_ring[m_head] = line;
      m_head = (m_head + 1) % QSMC_MAX_LOG_ENTRIES;
      if(m_count < QSMC_MAX_LOG_ENTRIES) m_count++;

      if(m_fileEnabled)
         WriteFile(line);
   }

   void WriteFile(const string line)
   {
      if(!m_fileHealthy) return;

      int h = FileOpen(m_file, FILE_READ | FILE_WRITE | FILE_TXT | FILE_ANSI);
      if(h == INVALID_HANDLE)
      {
         m_fileHealthy  = false;
         m_lastError    = "log file open failed: " + IntegerToString(GetLastError());
         return;
      }
      FileSeek(h, 0, SEEK_END);
      FileWriteString(h, line + "\r\n");
      FileClose(h);
   }

public:
   CQSMCLogger()
   {
      m_level       = QSMC_LOG_INFO;
      m_fileEnabled = false;
      m_fileHealthy = false;
      m_initialised = false;
      m_file        = "";
      m_tag         = "";
      m_count       = 0;
      m_head        = 0;
      m_writes      = 0;
      m_suppressed  = 0;
      m_lastError   = "";
      for(int i = 0; i < QSMC_MAX_LOG_ENTRIES; i++) m_ring[i] = "";
   }

   bool Init(const ENUM_QSMC_LOG_LEVEL level,
             const bool enableFile,
             const string fileName,
             const string instanceTag)
   {
      m_level       = level;
      m_tag         = instanceTag;
      m_fileEnabled = enableFile && StringLen(fileName) > 0;
      m_fileHealthy = m_fileEnabled;
      m_file        = (m_fileEnabled ? fileName : "");

      if(m_fileEnabled)
      {
         // Probe the log file once so a bad path is reported immediately.
         int h = FileOpen(m_file, FILE_READ | FILE_WRITE | FILE_TXT | FILE_ANSI);
         if(h == INVALID_HANDLE)
         {
            m_fileHealthy  = false;
            m_lastError    = "log file unavailable, terminal-only logging";
         }
         else
         {
            FileSeek(h, 0, SEEK_END);
            FileWriteString(h, "--- " + TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS) +
                               " session start ---\r\n");
            FileClose(h);
         }
      }

      m_initialised = true;
      return true;
   }

   void SetLevel(const ENUM_QSMC_LOG_LEVEL level) { m_level = level; }
   ENUM_QSMC_LOG_LEVEL Level() const { return m_level; }
   string LastError()           const { return m_lastError; }
   bool   FileHealthy()         const { return m_fileHealthy; }

   void Log(const ENUM_QSMC_LOG_LEVEL level, const string tag, const string msg)
   {
      if(!m_levelEnabled(level)) { m_suppressed++; return; }

      string line = StringFormat("%s [%s] %s%s%s",
                                 TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS),
                                 QSMC_LogLevelToString(level),
                                 (StringLen(m_tag) > 0 ? m_tag + " " : ""),
                                 (StringLen(tag) > 0 ? tag + ": " : ""),
                                 msg);

      Print(line);
      Push(line);
      m_writes++;
   }

   bool m_levelEnabled(const ENUM_QSMC_LOG_LEVEL level) const
   {
      if(m_level == QSMC_LOG_NONE) return false;
      return ((int)level >= (int)m_level);
   }

   void Debug(const string tag, const string msg) { Log(QSMC_LOG_DEBUG, tag, msg); }
   void Info (const string tag, const string msg) { Log(QSMC_LOG_INFO,  tag, msg); }
   void Warn (const string tag, const string msg) { Log(QSMC_LOG_WARN,  tag, msg); }
   void Error(const string tag, const string msg) { Log(QSMC_LOG_ERROR, tag, msg); }

   //+---------------------------------------------------------------+
   //| Last n lines, oldest first (dashboard / self-test inspection).  |
   //+---------------------------------------------------------------+
   string Tail(const int n) const
   {
      if(m_count == 0 || n <= 0) return "";
      int want = (n < m_count ? n : m_count);
      int start = (m_head - want + QSMC_MAX_LOG_ENTRIES * 2) % QSMC_MAX_LOG_ENTRIES;
      string out = "";
      for(int i = 0; i < want; i++)
      {
         int idx = (start + i) % QSMC_MAX_LOG_ENTRIES;
         if(i > 0) out += "\n";
         out += m_ring[idx];
      }
      return out;
   }

   string Last() const
   {
      if(m_count == 0) return "";
      int idx = (m_head - 1 + QSMC_MAX_LOG_ENTRIES) % QSMC_MAX_LOG_ENTRIES;
      return m_ring[idx];
   }

   int Count()      const { return m_count; }
   int Writes()     const { return m_writes; }
   int Suppressed() const { return m_suppressed; }

   string Stats() const
   {
      return StringFormat("log writes=%d buffered=%d suppressed=%d file=%s",
                          m_writes, m_count, m_suppressed,
                          (m_fileEnabled ? (m_fileHealthy ? m_file : m_file + " (FAILED)") : "off"));
   }
};

#endif // QSMC_LOGGER_MQH
