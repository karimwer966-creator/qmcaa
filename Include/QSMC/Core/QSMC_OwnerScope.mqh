// Stable raw owner scope. Hashes are filenames only, never ownership proof.
#ifndef QSMC_OWNERSCOPE_MQH
#define QSMC_OWNERSCOPE_MQH
class CQSMCOwnerScope
{
public:
   static bool Safe(const string value)
   {
      if(StringLen(value)==0 || StringLen(value)>256)return false;
      for(int i=0;i<StringLen(value);i++)if(StringGetCharacter(value,i)<32)return false;
      return true;
   }
   static string Raw(const long login,const string server,const string symbol,const ulong magic)
   {
      if(login<=0 || magic==0 || magic>2147483647 || !Safe(server) || !Safe(symbol))return "";
      return IntegerToString(login)+"|"+IntegerToString(StringLen(server))+":"+server+"|"+
             IntegerToString(StringLen(symbol))+":"+symbol+"|"+StringFormat("%I64u",magic);
   }
};
#endif // QSMC_OWNERSCOPE_MQH
