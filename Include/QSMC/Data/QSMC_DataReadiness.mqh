//+------------------------------------------------------------------+
//|                                             QSMC_DataReadiness.mqh |
//|  Gates the pipeline: no readiness, no analysis, no decision.        |
//+------------------------------------------------------------------+
#ifndef QSMC_DATAREADINESS_MQH
#define QSMC_DATAREADINESS_MQH

#include "../Core/QSMC_Types.mqh"
#include "QSMC_MarketSnapshot.mqh"
#include "QSMC_DataValidator.mqh"
#include "QSMC_TimeframeManager.mqh"

enum ENUM_QSMC_READY
{
   QSMC_READY_UNKNOWN   = 0,
   QSMC_READY_READY     = 1,
   QSMC_READY_NOT_READY = 2
};

class CQSMCDataReadiness
{
private:
   int             m_minBars;
   bool            m_initialised;
   ENUM_QSMC_READY m_state;
   string          m_reason;
   datetime        m_checked;
   int             m_execBarsBehind;
   int             m_htfBarsBehind;
   int             m_ltfBarsBehind;

public:
   CQSMCDataReadiness()
   {
      m_minBars        = 100;
      m_initialised    = false;
      m_state          = QSMC_READY_UNKNOWN;
      m_reason         = "not evaluated";
      m_checked        = 0;
      m_execBarsBehind = 0;
      m_htfBarsBehind  = 0;
      m_ltfBarsBehind  = 0;
   }

   bool Init(const int minBars)
   {
      if(minBars < 20) return false;
      m_minBars     = minBars;
      m_initialised = true;
      m_state       = QSMC_READY_UNKNOWN;
      return true;
   }

   int  MinBars() const { return m_minBars; }
   ENUM_QSMC_READY State() const { return m_state; }
   bool IsReady() const { return (m_state == QSMC_READY_READY); }
   string Reason() const { return m_reason; }
   datetime Checked() const { return m_checked; }

   //+---------------------------------------------------------------+
   //| Evaluate readiness from a snapshot.  Never throws, always sets  |
   //| an explanatory reason (used verbatim in the dashboard/log).     |
   //+---------------------------------------------------------------+
   bool Evaluate(const CQSMCMarketSnapshot &snap, string &why)
   {
      why       = "";
      m_checked = TimeCurrent();

      if(!m_initialised)
      {
         m_state  = QSMC_READY_NOT_READY;
         m_reason = "readiness module not initialised";
         why      = m_reason;
         return false;
      }

      if(!snap.IsUsable())
      {
         m_state  = QSMC_READY_NOT_READY;
         m_reason = "snapshot unusable (no quote or too few bars)";
         why      = m_reason;
         return false;
      }

      if(snap.BarCount(QSMC_SNAP_EXEC) < m_minBars ||
         snap.BarCount(QSMC_SNAP_HTF)  < 50 ||
         snap.BarCount(QSMC_SNAP_LTF)  < 50)
      {
         m_state  = QSMC_READY_NOT_READY;
         m_reason = StringFormat("insufficient history (%d/%d/%d, need %d/50/50)",
                                 snap.BarCount(QSMC_SNAP_EXEC),
                                 snap.BarCount(QSMC_SNAP_HTF),
                                 snap.BarCount(QSMC_SNAP_LTF), m_minBars);
         why      = m_reason;
         return false;
      }

      string err;
      if(!CQSMCDataValidator::ValidateSnapshot(snap, err))
      {
         m_state  = QSMC_READY_NOT_READY;
         m_reason = err;
         why      = m_reason;
         return false;
      }

      //--- staleness: exec may be 3 bars behind at most -----------------
      datetime now = TimeCurrent();
      if(CQSMCDataValidator::IsBarStale(snap.LastBarTime(QSMC_SNAP_EXEC),
                                        snap.Tf(QSMC_SNAP_EXEC), now, 3,
                                        m_execBarsBehind))
      {
         m_state  = QSMC_READY_NOT_READY;
         m_reason = "exec data stale (" + IntegerToString(m_execBarsBehind) + " bars behind)";
         why      = m_reason;
         return false;
      }

      if(CQSMCDataValidator::IsBarStale(snap.LastBarTime(QSMC_SNAP_HTF),
                                        snap.Tf(QSMC_SNAP_HTF), now, 3,
                                        m_htfBarsBehind))
      {
         m_state  = QSMC_READY_NOT_READY;
         m_reason = "htf data stale";
         why      = m_reason;
         return false;
      }

      if(CQSMCDataValidator::IsBarStale(snap.LastBarTime(QSMC_SNAP_LTF),
                                        snap.Tf(QSMC_SNAP_LTF), now, 10,
                                        m_ltfBarsBehind))
      {
         m_state  = QSMC_READY_NOT_READY;
         m_reason = "ltf data stale";
         why      = m_reason;
         return false;
      }

      //--- ATR must be computable: analysis cannot work without it ------
      if(snap.Atr(QSMC_SNAP_EXEC, 14, snap.NewestIndex()) <= 0.0)
      {
         m_state  = QSMC_READY_NOT_READY;
         m_reason = "ATR unavailable (flat or insufficient data)";
         why      = m_reason;
         return false;
      }

      m_state  = QSMC_READY_READY;
      m_reason = "ready";
      why      = m_reason;
      return true;
   }

   string Describe() const
   {
      return StringFormat("readiness=%s reason=%s behind=%d/%d/%d",
                          EnumToString(m_state), m_reason,
                          m_execBarsBehind, m_htfBarsBehind, m_ltfBarsBehind);
   }
};

#endif // QSMC_DATAREADINESS_MQH
