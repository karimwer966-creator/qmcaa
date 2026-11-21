#ifndef QSMC_INSTANCEIDENTITY_MQH
#define QSMC_INSTANCEIDENTITY_MQH

#include "QSMC_Constants.mqh"
#include "QSMC_InputFingerprint.mqh"

class CQSMCInstanceIdentity
{
private:
   string          m_symbol;
   ENUM_TIMEFRAMES m_period;
   long            m_chart_id;
   long            m_account;
   ulong           m_magic;
   string          m_id;
   datetime        m_started;

public:
   CQSMCInstanceIdentity() : m_symbol(""), m_period(PERIOD_CURRENT),
                             m_chart_id(0), m_account(0), m_magic(0),
                             m_id(""), m_started(0) {}

   void Build(const string symbol, const ENUM_TIMEFRAMES period, const long magic_offset)
   {
      m_symbol   = symbol;
      m_period   = period;
      m_chart_id = ChartID();
      m_account  = AccountInfoInteger(ACCOUNT_LOGIN);
      m_started  = TimeLocal();

      ulong h = QSMC_HashString(symbol);
      h = QSMC_HashString(IntegerToString((long)period), h);
      h = QSMC_HashString(IntegerToString(m_account), h);

      m_magic = (ulong)QSMC_MAGIC_BASE + (h % (ulong)QSMC_MAGIC_RANGE) + (ulong)magic_offset;
      m_id    = StringFormat("%s-%s-%d-%I64u", QSMC_NAME, symbol, (int)period, m_magic);
   }

   string          Id()        const { return m_id; }
   string          Symbol()    const { return m_symbol; }
   ENUM_TIMEFRAMES Period()    const { return m_period; }
   long            ChartIdVal()const { return m_chart_id; }
   long            Account()   const { return m_account; }
   ulong           Magic()     const { return m_magic; }
   datetime        Started()   const { return m_started; }

   string GvKey(const string name) const
   { return QSMC_GV_PREFIX + IntegerToString((long)m_magic) + "_" + name; }

   string ObjName(const string name) const
   { return QSMC_OBJ_PREFIX + IntegerToString(m_chart_id) + "_" + name; }
};

#endif