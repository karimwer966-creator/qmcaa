// Fixed approved policy: inclusive +/-30 minutes, cache age strictly <15 minutes.
#ifndef QSMC_NEWSPOLICY_MQH
#define QSMC_NEWSPOLICY_MQH
class CQSMCNewsPolicy
{
public:
   static bool Keywords(const string text,string &canonical)
   {
      canonical="";
      int length=StringLen(text),position=0,count=0;
      if(length<1 || length>1024)return false;
      while(position<=length)
      {
         int end=StringFind(text,";",position);
         if(end<0)end=length;
         string token=StringSubstr(text,position,end-position);
         StringTrimLeft(token);StringTrimRight(token);StringToUpper(token);
         if(StringLen(token)==0 || ++count>64)return false;
         canonical+=token+";";
         if(end==length)break;
         position=end+1;
      }
      return true;
   }
   static bool Relevant(const string currency,const bool high,const string name,const string canonical)
   {
      if(currency!="USD")return false;
      if(high)return true;
      string upper=name;StringToUpper(upper);
      int position=0,length=StringLen(canonical);
      while(position<length)
      {
         int end=StringFind(canonical,";",position);
         if(end<=position)return false; // Init must validate/canonicalize first.
         if(StringFind(upper,StringSubstr(canonical,position,end-position))>=0)return true;
         position=end+1;
      }
      return false;
   }
   static bool Blackout(const long now,const long eventTime)
   {
      if(now<=0 || eventTime<=0)return true;
      return (eventTime>=now-1800 && eventTime<=now+1800);
   }
   static bool Covered(const long from,const long to,const long fetched,const long now)
   {
      return (now>1800 && fetched>0 && fetched<=now && now-fetched<900 &&
              from>0 && from<=now-1800 && to>=now+1800 && to>from);
   }
};
#endif // QSMC_NEWSPOLICY_MQH
