// Schema-2 scalar validation. Checksums detect corruption, not malicious edits.
#ifndef QSMC_STATECODEC_MQH
#define QSMC_STATECODEC_MQH
class CQSMCStateCodec
{
public:
   static bool Text(const string text,const int limit)
   {
      if(StringLen(text)>limit)return false;
      for(int i=0;i<StringLen(text);i++)if(StringGetCharacter(text,i)<32)return false;
      return true;
   }
   static bool Unsigned(const string text)
   {
      int n=StringLen(text);if(n<1 || n>20 || (n>1 && StringSubstr(text,0,1)=="0"))return false;
      for(int i=0;i<n;i++){ushort c=StringGetCharacter(text,i);if(c<48 || c>57)return false;}
      return (n<20 || StringCompare(text,"18446744073709551615")<=0);
   }
   static bool Integer(const string text)
   {
      if(!Text(text,20) || StringLen(text)==0)return false;
      return (IntegerToString(StringToInteger(text))==text);
   }
   static bool Number(const string text)
   {
      int n=StringLen(text),i=0,digits=0;
      if(n<1 || n>64)return false;
      if(StringSubstr(text,0,1)=="-" || StringSubstr(text,0,1)=="+")i++;
      bool point=false;
      for(;i<n;i++)
      {
         ushort c=StringGetCharacter(text,i);
         if(c==46 && !point){point=true;continue;}
         if(c<48 || c>57)return false;
         digits++;
      }
      return (digits>0 && MathIsValidNumber(StringToDouble(text)));
   }
   static bool Value(const string key,const string type,const string value)
   {
      if(!Text(key,96) || StringLen(key)==0 || StringFind(key,"=")>=0 || !Text(value,2048))return false;
      if(type!="S" && type!="I" && type!="D" && type!="B")return false;
      if(type=="I" && !Integer(value))return false;
      if(type=="D" && !Number(value))return false;
      if(type=="B" && value!="0" && value!="1")return false;
      if(key=="kill" || key=="safety.kill" || key=="safety.uncertain" || key=="risk.enrolled" || key=="risk.review_required")
         return type=="B";
      if(key=="risk.peak_equity" || key=="risk.day_equity" || key=="risk.day_floating" || key=="risk.daily_net")
         return type=="D";
      if(key=="safety.time" || key=="execution.daily_count" || key=="execution.last_submit" ||
         key=="risk.day" || key=="risk.baseline_time" || key=="risk.closed_today" ||
         key=="risk.last_entry_time" || key=="risk.loss_streak" || key=="risk.sl_today" || key=="risk.tp_today" || key=="risk.entry_orders")
         return type=="I" && StringToInteger(value)>=0;
      if(key=="execution.last_uid" || key=="execution.pending_uid" || StringFind(key,"execution.uid.")==0)
         return type=="S" && (value=="" || (Unsigned(value) && value!="0"));
      return true;
   }
};
#endif // QSMC_STATECODEC_MQH
