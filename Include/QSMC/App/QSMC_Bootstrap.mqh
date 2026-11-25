// Stable raw ownership and explicit legacy refusal. No automatic migration.
#ifndef QSMC_BOOTSTRAP_MQH
#define QSMC_BOOTSTRAP_MQH
#include "../Core/QSMC_Root.mqh"
#include "../Infrastructure/QSMC_StateStore.mqh"
#include "../Safety/QSMC_Diagnostics.mqh"
class CQSMCBootstrap
{
public:
   static bool LegacyFiles()
   {
      string name;
      // Old terminal brakes lack account/server scope. Never silently ignore
      // an active legacy brake merely because its old file is missing.
      int globals=GlobalVariablesTotal();
      for(int i=0;i<globals;i++)
      {
         name=GlobalVariableName(i);int prefix=StringLen(QSMC_GV_PREFIX),length=StringLen(name);
         if(StringFind(name,QSMC_GV_PREFIX)!=0 || length<=prefix+5 ||
            StringSubstr(name,length-5)!="_kill")continue;
         string legacyMagic=StringSubstr(name,prefix,length-prefix-5);
         if(CQSMCStateCodec::Integer(legacyMagic) && StringToInteger(legacyMagic)>0 &&
            GlobalVariableGet(name)!=0.0)return true;
      }
      long h=FileFindFirst(QSMC_FILE_FOLDER+"state_*.state",name);
      if(h!=INVALID_HANDLE){FileFindClose(h);return true;}
      h=FileFindFirst(QSMC_FILE_FOLDER+"state_*.state",name,FILE_COMMON);
      if(h!=INVALID_HANDLE){FileFindClose(h);return true;}
      return false;
   }
   static bool ExposureCertain(const string symbol,const ulong magic,const bool hasState,string &why)
   {
      int positions=PositionsTotal(),orders=OrdersTotal();
      for(int i=0;i<positions;i++)
      {
         ulong ticket=PositionGetTicket(i);long owner=0;string sym="";
         if(ticket==0 || !PositionSelectByTicket(ticket) || !PositionGetInteger(POSITION_MAGIC,owner) ||
            !PositionGetString(POSITION_SYMBOL,sym)){why="position ownership unreadable";return false;}
         bool legacy=(owner>=QSMC_MAGIC_BASE && owner<QSMC_MAGIC_BASE+QSMC_MAGIC_RANGE && (ulong)owner!=magic);
         if(legacy || ((ulong)owner==magic && (sym!=symbol || !hasState)))
         {why="legacy/conflicting exposure or exposure without scoped state; manual migration required";return false;}
      }
      for(int i=0;i<orders;i++)
      {
         ulong ticket=OrderGetTicket(i);long owner=0;string sym="";
         if(ticket==0 || !OrderGetInteger(ORDER_MAGIC,owner) || !OrderGetString(ORDER_SYMBOL,sym))
         {why="order ownership unreadable";return false;}
         bool legacy=(owner>=QSMC_MAGIC_BASE && owner<QSMC_MAGIC_BASE+QSMC_MAGIC_RANGE && (ulong)owner!=magic);
         if(legacy || ((ulong)owner==magic && (sym!=symbol || !hasState)))
         {why="legacy/conflicting order or order without scoped state; manual migration required";return false;}
      }
      if(positions!=PositionsTotal() || orders!=OrdersTotal()){why="broker collections changed during ownership scan";return false;}
      return true;
   }
   static bool Start(CQSMCRoot &root,const SQSMCConfig &cfg,CQSMCStateStore &store,
                     CQSMDiagnostics &diag,SQSMCResult &result)
   {
      if(!root.Init(cfg,result)){diag.Critical("ROOT_INIT",result.message);return false;}
      bool readOnly=(cfg.mode==QSMC_MODE_ANALYSIS || cfg.mode==QSMC_MODE_OFF);
      if(!store.InitScoped(AccountInfoInteger(ACCOUNT_LOGIN),AccountInfoString(ACCOUNT_SERVER),cfg.symbol,root.Magic(),readOnly))
      {result.Set(QSMC_ERR_MODULE_INIT,store.LastError());root.Fail(result.message);return false;}
      if(store.Scope()!=root.OwnerScope())
      {result.Set(QSMC_ERR_IDENTITY_COLLISION,"raw ownership scope mismatch");root.Fail(result.message);return false;}
      string why;
      bool legacy=LegacyFiles();
      if(legacy)diag.Warn("LEGACY_STATE","legacy files preserved; operational migration review required");
      if(!readOnly)
      {
         if(legacy || !ExposureCertain(cfg.symbol,root.Magic(),store.HasSnapshot(),why))
         {result.Set(QSMC_ERR_SAFETY_BLOCKED,legacy?"legacy state/kill artifacts require manual migration":why);root.Fail(result.message);return false;}
         if(store.HasSnapshot() && store.GetString("identity.scope","")!=root.OwnerScope())
         {result.Set(QSMC_ERR_IDENTITY_COLLISION,"missing/mismatched raw identity in scoped snapshot");root.Fail(result.message);return false;}
         // Fingerprint changes are diagnostic drift, NEVER a new owner or reset.
         if(store.Exists("identity.fingerprint") && store.GetString("identity.fingerprint")!=root.FingerprintHex())
            diag.Warn("CONFIG_DRIFT","configuration changed; ownership and safety state retained");
         if(!store.SetString("identity.scope",root.OwnerScope()) ||
            !store.SetString("identity.fingerprint",root.FingerprintHex()) ||
            !store.SetString("identity.id",root.InstanceId()) || !store.Save())
         {result.Set(QSMC_ERR_MODULE_INIT,"scoped identity commit failed");root.Fail(result.message);return false;}
      }
      if(store.KillSwitchActive())diag.Warn("KILL_SWITCH",store.KillSwitchReason());
      diag.ReportModule("state-store",true,store.Describe());return true;
   }
};
#endif // QSMC_BOOTSTRAP_MQH
