#ifndef QSMC_INPUTFINGERPRINT_MQH
#define QSMC_INPUTFINGERPRINT_MQH

#include "QSMC_Config.mqh"

// FNV-1a 64-bit
#define QSMC_FNV_OFFSET  0xcbf29ce484222325
#define QSMC_FNV_PRIME   0x100000001b3

ulong QSMC_HashString(const string s, ulong h = QSMC_FNV_OFFSET)
{
   uchar buf[];
   int n = StringToCharArray(s, buf, 0, WHOLE_ARRAY, CP_UTF8) - 1; // drop terminating zero
   for(int i = 0; i < n; i++)
   {
      h ^= (ulong)buf[i];
      h *= QSMC_FNV_PRIME;
   }
   return h;
}

class CQSMCInputFingerprint
{
private:
   ulong m_hash;
   int   m_count;

public:
   CQSMCInputFingerprint() { Reset(); }

   void Reset() { m_hash = QSMC_FNV_OFFSET; m_count = 0; }

   void AddString(const string key, const string v)
   { m_hash = QSMC_HashString(key + "=" + v + ";", m_hash); m_count++; }

   void AddInt(const string key, const long v)
   { AddString(key, IntegerToString(v)); }

   void AddBool(const string key, const bool v)
   { AddString(key, v ? "1" : "0"); }

   void AddDouble(const string key, const double v, const int digits = 8)
   { AddString(key, DoubleToString(v, digits)); }

   void AddConfig(const SQSMCConfig &c)
   {
      AddInt("mode", c.mode);
      AddInt("preset", c.preset);
      AddInt("log", c.log_level);
      AddString("symbol", c.symbol);
      AddInt("exec_tf", c.exec_tf);
      AddInt("htf", c.htf);
      AddInt("ltf", c.ltf);
      AddInt("timer", c.timer_ms);
      AddDouble("risk", c.risk_percent);
      AddDouble("dd", c.max_daily_loss_pct);
      AddInt("spread", c.max_spread_points);
      AddInt("maxpos", c.max_positions);
      AddInt("magic_off", c.magic_offset);
      AddBool("dash", c.enable_dashboard);
      AddBool("layers", c.enable_chart_layers);
   }

   ulong  Value() const { return m_hash; }
   int    Count() const { return m_count; }
   string Hex()   const { return StringFormat("%016I64X", m_hash); }

   bool Equals(const CQSMCInputFingerprint &o) const { return m_hash == o.m_hash; }
};

#endif