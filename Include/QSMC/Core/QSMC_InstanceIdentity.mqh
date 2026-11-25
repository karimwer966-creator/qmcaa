//+------------------------------------------------------------------+
//|                                        QSMC_InstanceIdentity.mqh |
//| Stable operator magic; configuration/chart/version are diagnostics. |
//+------------------------------------------------------------------+
#ifndef QSMC_INSTANCEIDENTITY_MQH
#define QSMC_INSTANCEIDENTITY_MQH

#include "QSMC_Constants.mqh"
#include "QSMC_Version.mqh"
#include "QSMC_InputFingerprint.mqh"
#include "QSMC_OwnerScope.mqh"

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
   string          m_scope;
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

   // magicOffset retained only for callers; it no longer changes ownership.
   bool Build(const string symbol,
              const ENUM_TIMEFRAMES period,
              const string fingerprintHex,
              const long magicOffset,
              const ulong explicitMagic=53000001)
   {
      m_built=false;m_magic=0;m_scope="";m_id="";
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

      m_scope=CQSMCOwnerScope::Raw(m_account,AccountInfoString(ACCOUNT_SERVER),symbol,explicitMagic);
      if(StringLen(m_scope)==0)return false;
      m_magic=explicitMagic;

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
      m_scope = "";
   }

   string Scope() const{return m_scope;}
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
      return "v2_"+QSMC_UlongToHex(QSMC_HashString(m_scope))+"_";
   }

   string GvKey(const string name) const
   {
      return QSMC_GV_PREFIX+"V2_"+QSMC_UlongToHex(QSMC_HashString(m_scope))+"_"+name;
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
