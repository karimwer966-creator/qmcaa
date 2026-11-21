//+------------------------------------------------------------------+
//|                                               QSMC_Bootstrap.mqh |
//|  Creates and validates core identity before upper-layer startup.    |
//+------------------------------------------------------------------+
#ifndef QSMC_BOOTSTRAP_MQH
#define QSMC_BOOTSTRAP_MQH
#include "../Core/QSMC_Root.mqh"
#include "../Infrastructure/QSMC_StateStore.mqh"
#include "../Safety/QSMC_Diagnostics.mqh"

class CQSMCBootstrap
{
public:
   static bool Start(CQSMCRoot &root,const SQSMCConfig &cfg,
                     CQSMCStateStore &store,CQSMDiagnostics &diag,
                     SQSMCResult &result)
   {
      if(!root.Init(cfg,result))
      {diag.Critical("ROOT_INIT",result.message);return false;}

      if(!store.Init(root.Magic()))
      {
         result.Set(QSMC_ERR_MODULE_INIT,"state store init failed: "+store.LastError());
         diag.Critical("STORE_INIT",result.message);
         root.Fail(result.message);
         return false;
      }

      // Detect modulo-hash collisions and conflicting reuse of a magic file.
      string oldFingerprint=store.GetString("identity.fingerprint","");
      string oldIdentity=store.GetString("identity.id","");
      if((StringLen(oldFingerprint)>0 && oldFingerprint!=root.FingerprintHex()) ||
         (StringLen(oldIdentity)>0 && oldIdentity!=root.InstanceId()))
      {
         result.Set(QSMC_ERR_IDENTITY_COLLISION,
                    "magic identity already claimed by another configuration or instance");
         diag.Critical("IDENTITY_COLLISION",result.message);
         root.Fail(result.message);
         return false;
      }

      if(!store.SetString("identity.fingerprint",root.FingerprintHex()) ||
         !store.SetString("identity.id",root.InstanceId()) || !store.Save())
      {
         result.Set(QSMC_ERR_MODULE_INIT,"could not persist instance identity claim");
         diag.Critical("IDENTITY_CLAIM",result.message);
         root.Fail(result.message);
         return false;
      }

      if(store.KillSwitchActive())
         diag.Warn("KILL_SWITCH","persisted emergency stop is engaged: "+store.KillSwitchReason());
      diag.ReportModule("root",true,root.InstanceId());
      diag.ReportModule("state-store",store.IsReady(),store.FileName());
      return true;
   }
};
#endif // QSMC_BOOTSTRAP_MQH
