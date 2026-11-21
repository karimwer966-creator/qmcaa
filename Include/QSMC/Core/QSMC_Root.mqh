//+------------------------------------------------------------------+
//|                                                     QSMC_Root.mqh |
//|  Core context: configuration, fingerprint, identity and the        |
//|  lifecycle state machine.  Root has NO dependencies on upper       |
//|  layers; it is a passive, inspectable object owned by the App      |
//|  composition root.  There is deliberately no global singleton.     |
//+------------------------------------------------------------------+
#ifndef QSMC_ROOT_MQH
#define QSMC_ROOT_MQH

#include "QSMC_Version.mqh"
#include "QSMC_Constants.mqh"
#include "QSMC_Types.mqh"
#include "QSMC_Config.mqh"
#include "QSMC_Preset.mqh"
#include "QSMC_StateMachine.mqh"
#include "QSMC_InstanceIdentity.mqh"
#include "QSMC_InputFingerprint.mqh"

class CQSMCRoot
{
private:
   SQSMCConfig           m_cfg;
   CQSMCInstanceIdentity m_identity;
   CQSMCInputFingerprint m_fingerprint;
   CQSMCStateMachine     m_fsm;
   string                m_safeReason;
   bool                  m_initialised;

public:
   CQSMCRoot()
   {
      m_cfg.SetDefaults();
      m_safeReason  = "";
      m_initialised = false;
   }

   //+---------------------------------------------------------------+
   //| Initialise.  Duplicate initialisation while active is refused.  |
   //+---------------------------------------------------------------+
   bool Init(const SQSMCConfig &cfg, SQSMCResult &res)
   {
      res.Clear();

      if(m_fsm.Is(QSMC_STATE_RUNNING) || m_fsm.Is(QSMC_STATE_INITIALIZING) ||
         m_fsm.Is(QSMC_STATE_READY))
      {
         res.Set(QSMC_ERR_ALREADY_INITIALIZED,
                 "init rejected: instance is already active (" +
                 QSMC_StateToString(m_fsm.State()) + ")");
         return false;
      }

      string err;
      if(!m_fsm.Transition(QSMC_STATE_INITIALIZING, err))
      {
         res.Set(QSMC_ERR_INVALID_STATE, err);
         return false;
      }

      m_cfg = cfg;
      if(!m_cfg.Validate(err))
      {
         res.Set(QSMC_ERR_INVALID_CONFIG, err);
         m_fsm.Transition(QSMC_STATE_FAILED, err);
         return false;
      }

      m_fingerprint.Reset();
      m_fingerprint.AddConfig(m_cfg);

      if(!m_identity.Build(m_cfg.symbol, m_cfg.exec_tf, m_fingerprint.Hex(),
                           m_cfg.magic_offset))
      {
         res.Set(QSMC_ERR_MODULE_INIT, "identity build failed");
         m_fsm.Transition(QSMC_STATE_FAILED, err);
         return false;
      }

      m_safeReason = "";
      if(!m_fsm.Transition(QSMC_STATE_READY, err))
      {
         res.Set(QSMC_ERR_INVALID_STATE, err);
         return false;
      }

      m_initialised = true;
      res.Set(QSMC_OK, "initialised: " + m_identity.Id());
      return true;
   }

   //+---------------------------------------------------------------+
   //| READY -> RUNNING.  Requires a completed Init().                 |
   //+---------------------------------------------------------------+
   bool Start(SQSMCResult &res)
   {
      res.Clear();
      if(!m_initialised)
      {
         res.Set(QSMC_ERR_NOT_INITIALIZED, "start rejected: root not initialised");
         return false;
      }

      string err;

      // A live instance must never start with the emergency brake engaged.
      if(m_cfg.mode == QSMC_MODE_REAL && QSMC_ALLOW_REAL != 1)
      {
         m_safeReason = "REAL mode refused by build gate";
         m_fsm.Transition(QSMC_STATE_SAFE_MODE, err);
         res.Set(QSMC_ERR_EXECUTION_DISABLED, m_safeReason);
         return false;
      }

      if(!m_fsm.Transition(QSMC_STATE_RUNNING, err))
      {
         res.Set(QSMC_ERR_INVALID_STATE, err);
         return false;
      }

      res.Set(QSMC_OK, "running");
      return true;
   }

   //+---------------------------------------------------------------+
   //| RUNNING -> SAFE_MODE (fail closed, keeps the object inspectable)|
   //+---------------------------------------------------------------+
   bool EnterSafeMode(const string reason, SQSMCResult &res)
   {
      res.Clear();
      string err;
      if(!m_fsm.Transition(QSMC_STATE_SAFE_MODE, err))
      {
         res.Set(QSMC_ERR_INVALID_STATE, err);
         return false;
      }
      m_safeReason = reason;
      res.Set(QSMC_OK, "safe mode: " + reason);
      return true;
   }

   //+---------------------------------------------------------------+
   //| SAFE_MODE -> READY.  Recovery never resumes automatically.      |
   //+---------------------------------------------------------------+
   bool Recover(SQSMCResult &res)
   {
      res.Clear();
      string err;
      if(!m_fsm.Transition(QSMC_STATE_READY, err))
      {
         res.Set(QSMC_ERR_INVALID_STATE, err);
         return false;
      }
      m_safeReason = "";
      res.Set(QSMC_OK, "recovered to READY; explicit start required");
      return true;
   }

   //+---------------------------------------------------------------+
   //| Controlled shutdown: STOPPING -> STOPPED (best effort).         |
   //+---------------------------------------------------------------+
   void Shutdown()
   {
      string err;
      if(m_fsm.Is(QSMC_STATE_STOPPED) || m_fsm.Is(QSMC_STATE_CREATED))
         return;
      if(!m_fsm.Is(QSMC_STATE_STOPPING))
         m_fsm.Transition(QSMC_STATE_STOPPING, err);
      m_fsm.Transition(QSMC_STATE_STOPPED, err);
      m_initialised = false;
      m_identity.Invalidate();
   }

   //+---------------------------------------------------------------+
   //| Bring the instance down on an unrecoverable error.              |
   //+---------------------------------------------------------------+
   void Fail(const string reason)
   {
      string err;
      m_safeReason = reason;
      m_fsm.Transition(QSMC_STATE_FAILED, err);
   }

   //--- accessors ---------------------------------------------------
   ENUM_QSMC_STATE State()       const { return m_fsm.State(); }
   bool  CanOperate()            const { return m_fsm.CanOperate(); }
   bool  IsHealthy()             const { return m_fsm.IsHealthy(); }
   bool  IsInitialised()         const { return m_initialised; }
   string SafeModeReason()       const { return m_safeReason; }
   ulong Magic()                 const { return m_identity.Magic(); }
   string InstanceId()           const { return m_identity.Id(); }
   string FingerprintHex()       const { return m_fingerprint.Hex(); }
   ulong  FingerprintValue()     const { return m_fingerprint.Value(); }
   int    FingerprintCount()     const { return m_fingerprint.Count(); }
   string Symbol()               const { return m_cfg.symbol; }
   ENUM_TIMEFRAMES ExecTf()      const { return m_cfg.exec_tf; }
   ENUM_TIMEFRAMES Htf()         const { return m_cfg.htf; }
   ENUM_TIMEFRAMES Ltf()         const { return m_cfg.ltf; }
   ENUM_QSMC_MODE  Mode()        const { return m_cfg.mode; }
   ENUM_QSMC_PRESET Preset()     const { return m_cfg.preset; }
   ENUM_QSMC_LOG_LEVEL LogLevel()const { return m_cfg.log_level; }
   int   TimerMs()               const { return m_cfg.timer_ms; }
   bool  IsRealMode()            const { return (m_cfg.mode == QSMC_MODE_REAL); }

   void CopyConfig(SQSMCConfig &out) const { out = m_cfg; }

   string Summary() const
   {
      return StringFormat("%s | %s | state=%s | fp=%s",
                          QSMC_VersionFull(),
                          m_identity.Describe(),
                          QSMC_StateToString(m_fsm.State()),
                          m_fingerprint.Hex());
   }

   string DescribeConfig() const
   {
      return m_cfg.Summary();
   }
};

#endif // QSMC_ROOT_MQH
