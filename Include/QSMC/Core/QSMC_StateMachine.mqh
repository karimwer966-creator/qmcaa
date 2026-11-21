//+------------------------------------------------------------------+
//|                                            QSMC_StateMachine.mqh |
//|  Explicit lifecycle state machine.  Every transition is table-     |
//|  driven; anything not in the table is rejected with a result code. |
//|  Operational code must gate on CanOperate().                       |
//+------------------------------------------------------------------+
#ifndef QSMC_STATEMACHINE_MQH
#define QSMC_STATEMACHINE_MQH

#include "QSMC_Types.mqh"

class CQSMCStateMachine
{
private:
   ENUM_QSMC_STATE m_state;
   ENUM_QSMC_STATE m_previous;
   datetime        m_since;
   string          m_lastReject;
   int             m_transitions;

   bool IsAllowed(const ENUM_QSMC_STATE from, const ENUM_QSMC_STATE to) const
   {
      switch(from)
      {
         case QSMC_STATE_CREATED:
            return (to == QSMC_STATE_INITIALIZING || to == QSMC_STATE_STOPPED ||
                    to == QSMC_STATE_FAILED);

         case QSMC_STATE_INITIALIZING:
            // no re-entry, no direct jump to RUNNING: READY must be proved first
            return (to == QSMC_STATE_READY || to == QSMC_STATE_FAILED ||
                    to == QSMC_STATE_STOPPING);

         case QSMC_STATE_READY:
            return (to == QSMC_STATE_RUNNING || to == QSMC_STATE_STOPPING ||
                    to == QSMC_STATE_FAILED);

         case QSMC_STATE_RUNNING:
            return (to == QSMC_STATE_SAFE_MODE || to == QSMC_STATE_STOPPING ||
                    to == QSMC_STATE_FAILED);

         case QSMC_STATE_SAFE_MODE:
            // recovery must go back through READY, never straight to RUNNING
            return (to == QSMC_STATE_READY || to == QSMC_STATE_STOPPING ||
                    to == QSMC_STATE_FAILED);

         case QSMC_STATE_STOPPING:
            return (to == QSMC_STATE_STOPPED || to == QSMC_STATE_FAILED);

         case QSMC_STATE_STOPPED:
            // a stopped instance may only be re-initialised explicitly
            return (to == QSMC_STATE_INITIALIZING);

         case QSMC_STATE_FAILED:
            // failed instances require an explicit restart (re-Init)
            return (to == QSMC_STATE_STOPPING || to == QSMC_STATE_STOPPED ||
                    to == QSMC_STATE_INITIALIZING);
      }
      return false;
   }

public:
   CQSMCStateMachine() { Reset(); }

   void Reset()
   {
      m_state       = QSMC_STATE_CREATED;
      m_previous    = QSMC_STATE_CREATED;
      m_since       = TimeCurrent();
      m_lastReject  = "";
      m_transitions = 0;
   }

   ENUM_QSMC_STATE State()      const { return m_state; }
   ENUM_QSMC_STATE Previous()   const { return m_previous; }
   datetime        Since()      const { return m_since; }
   int             Transitions()const { return m_transitions; }
   string          LastReject() const { return m_lastReject; }

   bool Is(const ENUM_QSMC_STATE s) const { return (m_state == s); }

   // Only RUNNING permits operational work (analysis-driven execution,
   // order submission, risk mutation).  Everything else is read-only.
   bool CanOperate() const { return (m_state == QSMC_STATE_RUNNING); }

   // READY or RUNNING means the instance is healthy enough to render.
   bool IsHealthy() const
   {
      return (m_state == QSMC_STATE_READY || m_state == QSMC_STATE_RUNNING);
   }

   bool CanTransitionTo(const ENUM_QSMC_STATE to) const
   {
      if(to == m_state) return false;      // no self transitions
      return IsAllowed(m_state, to);
   }

   bool Transition(const ENUM_QSMC_STATE to, string &err)
   {
      err = "";
      if(to == m_state)
      {
         err = StringFormat("state %s cannot transition to itself",
                            QSMC_StateToString(m_state));
         m_lastReject = err;
         return false;
      }
      if(!IsAllowed(m_state, to))
      {
         err = StringFormat("illegal transition %s -> %s",
                            QSMC_StateToString(m_state), QSMC_StateToString(to));
         m_lastReject = err;
         return false;
      }

      m_previous = m_state;
      m_state    = to;
      m_since    = TimeCurrent();
      m_transitions++;
      return true;
   }

   string Describe() const
   {
      return StringFormat("%s (from %s, since %s, transitions=%d)",
                          QSMC_StateToString(m_state),
                          QSMC_StateToString(m_previous),
                          TimeToString(m_since, TIME_DATE | TIME_SECONDS),
                          m_transitions);
   }
};

#endif // QSMC_STATEMACHINE_MQH
