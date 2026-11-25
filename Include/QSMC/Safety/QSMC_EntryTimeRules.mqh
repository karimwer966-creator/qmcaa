// Entry-only broker-server time rules. Never a position-management gate.
#ifndef QSMC_ENTRYTIMERULES_MQH
#define QSMC_ENTRYTIMERULES_MQH
class CQSMCEntryTimeRules
{
public:
   static bool Minute(const int value){return value>=0 && value<1440;}
   static int FromHourMinute(const int hour,const int minute)
   {
      if(hour<0 || hour>23 || minute<0 || minute>59)return -1;
      return hour*60+minute;
   }
   static bool Window(const int minute,const int start,const int end)
   {
      if(!Minute(minute) || !Minute(start) || !Minute(end) || start==end)return false;
      return (start<end?minute>=start && minute<end:minute>=start || minute<end);
   }
   static bool Schedule(const int weekday,const int minute,const int friday,
                        const bool sessions,const int asiaStart,const int asiaEnd,
                        const int londonStart,const int londonEnd,const int nyStart,
                        const int nyEnd,string &why)
   {
      why="";
      if(weekday<0 || weekday>6 || !Minute(minute) || !Minute(friday))
      {why="invalid broker-server clock/cutoff";return false;}
      if(weekday==0 || weekday==6){why="weekend: new entries blocked";return false;}
      if(weekday==5 && minute>=friday){why="Friday cutoff: new entries blocked";return false;}
      if(Window(minute,1425,75)){why="rollover 23:45-01:15: new entries blocked";return false;}
      if(sessions)
      {
         if(!Minute(asiaStart) || !Minute(asiaEnd) || asiaStart==asiaEnd ||
            !Minute(londonStart) || !Minute(londonEnd) || londonStart==londonEnd ||
            !Minute(nyStart) || !Minute(nyEnd) || nyStart==nyEnd)
         {why="invalid configured entry session";return false;}
         if(!Window(minute,asiaStart,asiaEnd) && !Window(minute,londonStart,londonEnd) &&
            !Window(minute,nyStart,nyEnd))
         {why="outside current configured entry sessions";return false;}
      }
      why="entry schedule permits; news and other gates still required";
      return true;
   }
};
#endif // QSMC_ENTRYTIMERULES_MQH
