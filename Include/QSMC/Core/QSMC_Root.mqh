#ifndef QSMC_ROOT_MQH
#define QSMC_ROOT_MQH

#include "QSMC_Version.mqh"
#include "QSMC_Constants.mqh"
#include "QSMC_Types.mqh"
#include "QSMC_Config.mqh"
#include "QSMC_Preset.mqh"
#include "QSMC_InstanceIdentity.mqh"
#include "QSMC_InputFingerprint.mqh"

class CQSMCRoot
{
private:
   SQSMCConfig           m_cfg;
   CQSMCInstanceIdentity m_identity;
   CQSMCInputFingerprint m_fingerprint;
   ENUM_QSMC_STATE       m_state;

public:
   CQSMCRoot() : m_state(QSMC_STATE_CREATED) { m_cfg.SetDefaults(); }

   bool Init(const SQSMCConfig &cfg, SQSMCResult &res)
   {
      m_state = QSMC_STATE_INITIALIZING;
      m_cfg   = cfg;

      string err;
      if(!m_cfg.Validate(err))
      {
         res.Set(QSMC_ERR_INVALID_CONFIG, err);
         m_state = QSMC_STATE_FAILED;
         return false;
      }

      m_identity.Build(m_cfg.symbol, m_cfg.exec_tf, m_cfg.magic_offset);
      m_fingerprint.Reset();
      m_fingerprint.AddConfig(m_cfg);

      m_state = QSMC_STATE_READY;
      res.Set(QSMC_OK, "initialized");
      return true;
   }

   void Shutdown() { m_state = QSMC_STATE_STOPPED; }

   ENUM_QSMC_STATE       State()       const { return m_state; }
   const SQSMCConfig*    Config()      const { return &m_cfg; }
   string                Summary()     const
   {
      return StringFormat("%s | id=%s | mode=%s | preset=%s | fp=%s",
                          QSMC_VersionFull(), m_identity.Id(),
                          QSMC_ModeToString(m_cfg.mode),
                          QSMC_PresetToString(m_cfg.preset),
                          m_fingerprint.Hex());
   }
   ulong  Magic()       const { return m_identity.Magic(); }
   string Fingerprint() const { return m_fingerprint.Hex(); }
};

CQSMCRoot g_QSMCRoot;
CQSMCRoot *QSMC_Root() { return &g_QSMCRoot; }

#endif