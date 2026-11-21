//+------------------------------------------------------------------+
//|                                        QSMC_InstanceIdentity.mqh |
//|  Per-instance identity.  The magic number is derived from         |
//|  account + chart + symbol + period + configuration fingerprint,   |
//|  so two differently configured instances can never share an       |
//|  order magic silently.  Collision can still occur through the     |
//|  1e6 modulo space; that is detected at claim time by the App      |
//|  layer (see QSMC_Bootstrap) and treated as a hard error.          |
//+------------------------------------------------------------------+
#ifndef QSMC_INSTANCEIDENTITY_MQH
#define QSMC_INSTANCEIDENTITY_MQH

#include "QSMC_Constants.mqh"
#include "QSMC_Version.mqh"
#include "QSMC_InputFingerprint.mqh"

class CQSMCInstanceIdentity
{
private:
   string          m_symbol;
   ENUM_TIMEFRAMES m_period;
   long            m_chartId;
   long            m_account;
   ulong           m_magic;
   string          m_id;
   string          m_fingerprint;
   datetime        m_started;
   bool            m_built;

public:
   CQSMCInstanceIdentity()
   {
      m_symbol      = "";
      m_period      = PERIOD_CURRENT;
      m_chartId     = 0;
      m_account     = 0;
      m_magic       = 0;
      m_id          = "";
      m_fingerprint = "";
      m_started     = 0;
      m_built       = false;
   }

   //+---------------------------------------------------------------+
   //| Build identity.  magic_offset is clamped by config validation;  |
   //| it only perturbs the final magic inside the reserved band.      |
   //+---------------------------------------------------------------+
   bool Build(const string symbol,
              const ENUM_TIMEFRAMES period,
              const string fingerprintHex,
              const long magicOffset)
   {
      if(StringLen(symbol) == 0 || StringLen(fingerprintHex) == 0)
         return false;
      if(magicOffset < 0 || magicOffset >= QSMC_MAGIC_RANGE)
         return false;

      m_symbol      = symbol;
      m_period      = period;
      m_chartId     = ChartID();
      m_account     = AccountInfoInteger(ACCOUNT_LOGIN);
      m_started     = TimeCurrent();
      m_fingerprint = fingerprintHex;

      ulong h = QSMC_HashString("v" + QSMC_VersionTag());
      h = QSMC_HashString(symbol, h);
      h = QSMC_HashString(IntegerToString((long)period), h);
      h = QSMC_HashString(IntegerToString(m_account), h);
      h = QSMC_HashString(IntegerToString(m_chartId), h);
      h = QSMC_HashString(fingerprintHex, h);

      ulong span = (ulong)QSMC_MAGIC_RANGE - (ulong)magicOffset;
      m_magic = (ulong)QSMC_MAGIC_BASE + (ulong)magicOffset + (h % span);
      if(m_magic >= (ulong)(QSMC_MAGIC_BASE + QSMC_MAGIC_RANGE))
         m_magic = (ulong)QSMC_MAGIC_BASE + (h % (ulong)QSMC_MAGIC_RANGE);

      m_id = StringFormat("%s-%s-%s-%s", QSMC_NAME, symbol,
                          QSMC_TfToString(period), IntegerToString((long)m_magic));
      m_built = true;
      return true;
   }

   void Invalidate()
   {
      m_built = false;
      m_magic = 0;
      m_id    = "";
   }

   bool   IsBuilt()      const { return m_built; }
   string Id()           const { return m_id; }
   string Symbol()       const { return m_symbol; }
   ENUM_TIMEFRAMES Period() const { return m_period; }
   long   ChartIdVal()   const { return m_chartId; }
   long   Account()      const { return m_account; }
   ulong  Magic()        const { return m_magic; }
   datetime Started()    const { return m_started; }
   string Fingerprint()  const { return m_fingerprint; }

   //--- persistent key namespace for this instance (state store / files)
   string StorePrefix() const
   {
      return "state_" + IntegerToString((long)m_magic) + "_";
   }

   string GvKey(const string name) const
   {
      return QSMC_GV_PREFIX + IntegerToString((long)m_magic) + "_" + name;
   }

   string ObjName(const string name) const
   {
      return QSMC_OBJ_PREFIX + IntegerToString(m_chartId) + "_" +
             IntegerToString((long)m_magic) + "_" + name;
   }

   string Describe() const
   {
      return StringFormat("%s magic=%s chart=%s account=%s fp=%s",
                          m_id,
                          IntegerToString((long)m_magic),
                          IntegerToString(m_chartId),
                          IntegerToString(m_account),
                          m_fingerprint);
   }
};

#endif // QSMC_INSTANCEIDENTITY_MQH
