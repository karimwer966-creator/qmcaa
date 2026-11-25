//+------------------------------------------------------------------+
//|                                          QSMC_InputFingerprint.mqh |
//|  Stable, order-sensitive fingerprint of every behaviour-affecting  |
//|  input.  Used for (a) identity/magic derivation, (b) detecting      |
//|  configuration drift across restarts.                              |
//|  Encoding is length-prefixed to make concatenation unambiguous.    |
//+------------------------------------------------------------------+
#ifndef QSMC_INPUTFINGERPRINT_MQH
#define QSMC_INPUTFINGERPRINT_MQH

#include "QSMC_Config.mqh"

#define QSMC_FNV_OFFSET  0xcbf29ce484222325
#define QSMC_FNV_PRIME   0x100000001b3

//+------------------------------------------------------------------+
//| FNV-1a 64 over the UTF-16 code units of a string, seeded.          |
//+------------------------------------------------------------------+
ulong QSMC_HashString(const string s, const ulong seed = QSMC_FNV_OFFSET)
{
   ulong h = seed;
   int n = StringLen(s);
   for(int i = 0; i < n; i++)
   {
      ushort c = StringGetCharacter(s, i);
      h ^= (ulong)(c & 0xFF);
      h *= QSMC_FNV_PRIME;
      h ^= (ulong)((c >> 8) & 0xFF);
      h *= QSMC_FNV_PRIME;
   }
   return h;
}

// Manual hex conversion: avoids relying on printf width/64-bit modifiers.
string QSMC_UlongToHex(ulong v)
{
   const string digits = "0123456789ABCDEF";
   string out = "";
   for(int i = 0; i < 16; i++)
   {
      int nib = (int)(v & 0xF);
      out = StringSubstr(digits, nib, 1) + out;
      v >>= 4;
   }
   return out;
}

class CQSMCInputFingerprint
{
private:
   ulong m_hash;
   int   m_count;

public:
   CQSMCInputFingerprint() { Reset(); }

   void Reset()
   {
      m_hash  = QSMC_FNV_OFFSET;
      m_count = 0;
   }

   // key/value pair with explicit lengths (no delimiter ambiguity).
   void AddString(const string key, const string v)
   {
      string enc = IntegerToString(StringLen(key)) + ":" + key +
                   "=" + IntegerToString(StringLen(v)) + ":" + v + ";";
      m_hash = QSMC_HashString(enc, m_hash);
      m_count++;
   }

   void AddInt(const string key, const long v)
   {
      AddString(key, IntegerToString(v));
   }

   void AddBool(const string key, const bool v)
   {
      AddString(key, v ? "1" : "0");
   }

   void AddDouble(const string key, const double v, const int digits = 8)
   {
      AddString(key, DoubleToString(v, digits));
   }

   void AddEnum(const string key, const int v)
   {
      AddInt(key, (long)v);
   }

   //+---------------------------------------------------------------+
   //| Every configured input that can change runtime behavior or       |
   //| instance ownership, including presentation and timer settings.    |
   //+---------------------------------------------------------------+
   void AddConfig(const SQSMCConfig &c)
   {
      AddEnum("mode",   (int)c.mode);
      AddEnum("preset", (int)c.preset);
      AddEnum("log_level",(int)c.log_level);
      AddString("real_ack",c.real_ack);
      AddInt("timer_ms",c.timer_ms);
      AddBool("dashboard",c.enable_dashboard);
      AddBool("chart_layers",c.enable_chart_layers);
      AddBool("log_file",c.enable_log_file);

      AddString("symbol",  c.symbol);
      AddEnum("exec_tf",   (int)c.exec_tf);
      AddEnum("htf",       (int)c.htf);
      AddEnum("ltf",       (int)c.ltf);

      AddBool("closed_only",   c.use_closed_bars_only);
      AddInt("bars_back",      c.bars_back);

      AddDouble("risk",        c.risk_percent, 4);
      AddDouble("daily_loss",  c.max_daily_loss_pct, 4);
      AddInt("spread",         c.max_spread_points);
      AddInt("max_pos",        c.max_positions);
      AddDouble("max_exposure",c.max_total_exposure_lots, 4);
      AddInt("max_trades",     c.max_daily_trades);
      AddInt("cooldown",       c.cooldown_seconds);
      AddDouble("max_dd",      c.max_drawdown_pct, 4);

      AddInt("swing_l",        c.swing_left);
      AddInt("swing_r",        c.swing_right);
      AddInt("struct_lb",      c.structure_lookback);
      AddInt("zone_lb",        c.zone_lookback);
      AddInt("zone_tol",       c.zone_tolerance_points);
      AddInt("svp_lb",         c.svp_lookback);
      AddInt("svp_bins",       c.svp_bins);
      AddDouble("svp_va",      c.svp_value_area_pct, 4);
      AddDouble("sl_atr",      c.sl_atr_mult, 4);
      AddDouble("min_rr",      c.min_rr, 4);
      AddDouble("tp_rr",       c.tp_rr, 4);
      AddDouble("min_conf",    c.min_confidence, 4);
      AddInt("deviation",      c.deviation_points);

      AddBool("sessions_enabled",c.sessions_enabled);
      AddInt("asia_start",c.asia_start_minute);
      AddInt("asia_end",c.asia_end_minute);
      AddInt("london_start",c.london_start_minute);
      AddInt("london_end",c.london_end_minute);
      AddInt("ny_start",c.new_york_start_minute);
      AddInt("ny_end",c.new_york_end_minute);
      AddDouble("min_fvg_atr",c.min_fvg_atr,4);
      AddInt("max_chart_zones",c.max_chart_zones);
      AddBool("draw_elliott",c.draw_elliott_labels);
      AddBool("draw_fvg",c.draw_fvg_zones);

      AddInt("friday_cutoff",c.friday_cutoff_minute);
      AddString("news_keywords",c.news_keywords);
      AddString("tester_news_csv",c.tester_news_csv);
      AddString("owner_magic",StringFormat("%I64u",c.owner_magic));
      AddInt("magic_offset",   c.magic_offset);
   }

   ulong  Value() const { return m_hash; }
   int    Count() const { return m_count; }
   string Hex()   const { return QSMC_UlongToHex(m_hash); }

   bool Equals(const CQSMCInputFingerprint &other) const
   {
      return (m_hash == other.m_hash && m_count == other.m_count);
   }

   bool EqualsHex(const string hex) const
   {
      return (Hex() == hex);
   }
};

#endif // QSMC_INPUTFINGERPRINT_MQH
