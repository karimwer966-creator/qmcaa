// Explicit NEW/clean-day baseline enrollment. NEVER clears safety or pending state.
#property script_show_inputs
#property strict
#include <QSMC/QSMC.mqh>
input ulong InpEnrollmentMagic=53000001;
input string InpEnrollmentSymbol="";
input string InpEnrollmentAcknowledgement="";
void OnStart()
{
   if(InpEnrollmentAcknowledgement!="I-REVIEWED-CLEAN-ACCOUNT-AND-DAY")
   {Print("Enrollment refused: explicit review token required");return;}
   string symbol=(StringLen(InpEnrollmentSymbol)>0?InpEnrollmentSymbol:_Symbol);
   if(symbol=="__ACCOUNT_RISK__")return;
   if(CQSMCBootstrap::LegacyFiles() || PositionsTotal()!=0 || OrdersTotal()!=0)
   {Print("Enrollment refused: legacy artifacts or account not flat/order-free");return;}
   datetime now=TimeCurrent();MqlDateTime dt;
   if(now<=0 || !TimeToStruct(now,dt))return;
   dt.hour=0;dt.min=0;dt.sec=0;datetime day=StructToTime(dt);
   if(!HistorySelect(day,now) || HistoryDealsTotal()!=0)
   {Print("Enrollment refused: clean server day with no account deals required");return;}
   CQSMCStateStore owner,account;
   long login=AccountInfoInteger(ACCOUNT_LOGIN);string server=AccountInfoString(ACCOUNT_SERVER);
   if(!owner.InitScoped(login,server,symbol,InpEnrollmentMagic) ||
      !account.InitScoped(login,server,"__ACCOUNT_RISK__",1))
   {Print("Enrollment refused: claims/snapshots unavailable: ",owner.LastError()," ",account.LastError());return;}
   if(StringLen(owner.GetString("execution.pending_uid",""))>0)
   {Print("Enrollment refused: pending intent requires manual reconciliation");return;}
   if(account.GetBool("risk.review_required",false))
   {Print("Enrollment refused: persistent account review marker requires separate recovery review");return;}
   double equity=AccountInfoDouble(ACCOUNT_EQUITY);
   if(!CQSMCRiskMath::Positive(equity))return;
   if(owner.GetBool("risk.enrolled",false) && owner.GetInt("risk.day",0)==(long)day)
   {Print("Enrollment refused: current-day baseline already exists; no reset permitted");return;}
   if(account.HasSnapshot() && !account.GetBool("risk.enrolled",false))
   {Print("Enrollment refused: ambiguous existing account baseline");return;}
   double peak=account.GetDouble("risk.peak_equity",equity);
   if(!CQSMCRiskMath::Positive(peak))return;
   // Never overwrite enrollment time on subsequent clean-day reviews. Cash-flow
   // review is a separate migration procedure, NOT an automatic adjustment.
   bool ok=true;
   if(!account.HasSnapshot())
      ok=account.SetInt("risk.baseline_time",(long)now) && account.SetBool("risk.enrolled",true);
   ok=ok && account.SetDouble("risk.peak_equity",MathMax(peak,equity)) && account.Save();
   if(!ok){Print("Account baseline commit failed; no owner baseline released");return;}
   if(PositionsTotal()!=0 || OrdersTotal()!=0 || !HistorySelect(day,TimeCurrent()) || HistoryDealsTotal()!=0)
   {Print("Enrollment interrupted by account activity; owner baseline NOT committed");return;}
   string scope=CQSMCOwnerScope::Raw(login,server,symbol,InpEnrollmentMagic);
   ok=owner.SetString("identity.scope",scope) && owner.SetInt("risk.day",(long)day) &&
      owner.SetDouble("risk.day_equity",equity) && owner.SetDouble("risk.day_floating",0.0) &&
      owner.SetInt("risk.baseline_time",(long)now) && owner.SetBool("risk.enrolled",true) && owner.Save();
   Print("QSMC reviewed clean-day enrollment committed=",ok,
         "; existing safety latch unchanged, no entry permission or pending clearance granted");
}
