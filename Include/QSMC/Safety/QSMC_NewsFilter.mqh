// USD high-impact/keyword blackout. No web requests, order APIs or state writes.
#ifndef QSMC_NEWSFILTER_MQH
#define QSMC_NEWSFILTER_MQH
#include "QSMC_NewsPolicy.mqh"
#define QSMC_NEWS_MAX_EVENTS 2048

class CQSMCNewsFilter
{
private:
   bool m_ready;
   bool m_tester;
   bool m_valid;
   string m_keywords;
   string m_csv;
   datetime m_from;
   datetime m_to;
   datetime m_fetched;
   datetime m_attempt;
   datetime m_times[QSMC_NEWS_MAX_EVENTS];
   string m_names[QSMC_NEWS_MAX_EVENTS];
   int m_count;
   string m_status;

   bool Relevant(const string currency,const bool high,const string name) const
   {
      return CQSMCNewsPolicy::Relevant(currency,high,name,m_keywords);
   }
   bool Add(const datetime time,const string name)
   {
      if(time<=0 || StringLen(name)==0 || StringLen(name)>512 || m_count>=QSMC_NEWS_MAX_EVENTS)return false;
      m_times[m_count]=time;m_names[m_count]=name;m_count++;
      return true;
   }
   bool Timestamp(const string text,datetime &time) const
   {
      time=StringToTime(text);
      return (time>0 && TimeToString(time,TIME_DATE|TIME_SECONDS)==text);
   }
   bool ReadRow(const int handle,string &row[]) const
   {
      ArrayResize(row,5);
      for(int i=0;i<5;i++)
      {
         if(FileIsEnding(handle) || (i>0 && FileIsLineEnding(handle)))return false;
         row[i]=FileReadString(handle);
         if(StringLen(row[i])>512)return false;
      }
      return (FileIsLineEnding(handle) || FileIsEnding(handle));
   }
   bool LoadCsv(const datetime now,string &why)
   {
      if(StringLen(m_csv)==0){why="tester news CSV missing: filtering unavailable, entries BLOCKED";return false;}
      int h=FileOpen(m_csv,FILE_READ|FILE_CSV|FILE_ANSI,';');
      if(h==INVALID_HANDLE){why="tester news CSV cannot be opened; entries BLOCKED";return false;}
      bool ok=(FileSize(h)>0 && FileSize(h)<=1048576);
      string row[];
      if(ok)ok=ReadRow(h,row);
      if(ok)ok=(row[0]=="COVERAGE" && row[3]=="SERVER" && row[4]=="1" &&
                Timestamp(row[1],m_from) && Timestamp(row[2],m_to) && m_to>m_from);
      int rows=0;datetime previous=0;
      while(ok && !FileIsEnding(h))
      {
         if(++rows>4096 || !ReadRow(h,row)){ok=false;break;}
         datetime time=0;
         bool known=(row[3]=="HIGH" || row[3]=="MODERATE" || row[3]=="LOW" || row[3]=="NONE");
         string currency=row[2];StringToUpper(currency);
         if(row[0]!="EVENT" || !Timestamp(row[1],time) || time<m_from || time>m_to ||
            time<previous || !known || StringLen(currency)!=3 || currency!=row[2] || StringLen(row[4])==0)
         {ok=false;break;}
         previous=time;
         if(Relevant(currency,row[3]=="HIGH",row[4]) && !Add(time,row[4]))ok=false;
      }
      FileClose(h);
      if(!ok){why="tester news CSV malformed/oversized/unsorted; entries BLOCKED";return false;}
      m_fetched=now;
      if(!CQSMCNewsPolicy::Covered((long)m_from,(long)m_to,(long)m_fetched,(long)now))
      {why="tester news CSV does not cover full +/-30-minute window; entries BLOCKED";return false;}
      return true;
   }
   bool LoadCalendar(const datetime now,string &why)
   {
      m_from=now-1800;m_to=now+2700; // +30-minute future window plus 15-minute cache life.
      // Query whole intersecting server days so tentative/all-day events are
      // not silently missed merely because their placeholder time is midnight.
      MqlDateTime startDay,endDay;
      if(!TimeToStruct(m_from,startDay) || !TimeToStruct(m_to,endDay))
      {why="calendar query clock conversion failed";return false;}
      startDay.hour=0;startDay.min=0;startDay.sec=0;
      endDay.hour=0;endDay.min=0;endDay.sec=0;
      datetime queryFrom=StructToTime(startDay),queryTo=StructToTime(endDay)+86399;
      MqlCalendarValue values[];
      ResetLastError();
      int count=CalendarValueHistory(values,queryFrom,queryTo,NULL,"USD");
      int error=GetLastError();
      if(count<0 || error!=0 || count>QSMC_NEWS_MAX_EVENTS || count!=ArraySize(values))
      {why="USD calendar unavailable/incomplete error="+IntegerToString(error)+"; entries BLOCKED";return false;}
      for(int i=0;i<count;i++)
      {
         MqlCalendarEvent event;
         if(!CalendarEventById(values[i].event_id,event))
         {why="calendar event metadata unavailable; entries BLOCKED";return false;}
         if(StringLen(event.name)==0 || StringLen(event.name)>512)
         {why="calendar event name missing/oversized; entries BLOCKED";return false;}
         if(!Relevant("USD",event.importance==CALENDAR_IMPORTANCE_HIGH,event.name))continue;
         if(event.time_mode!=CALENDAR_TIMEMODE_DATETIME || values[i].time<=0 ||
            !Add(values[i].time,event.name))
         {why="relevant calendar event has uncertain time or cache capacity exceeded; entries BLOCKED";return false;}
      }
      m_fetched=now;return true;
   }
public:
   CQSMCNewsFilter(){m_ready=false;m_tester=false;m_valid=false;m_from=0;m_to=0;m_fetched=0;m_attempt=0;m_count=0;m_status="news not initialized";}
   bool Init(const string keywords,const string csv)
   {
      m_ready=false;m_valid=false;m_count=0;m_from=0;m_to=0;m_fetched=0;m_attempt=0;
      m_tester=(MQLInfoInteger(MQL_TESTER)!=0);m_csv=csv;
      if(StringLen(keywords)==0 || StringLen(keywords)>1024 || StringLen(csv)>512 ||
         StringFind(csv,"..")>=0 || StringFind(csv,":")>=0)return false;
      if(!CQSMCNewsPolicy::Keywords(keywords,m_keywords))return false;
      m_ready=true;
      m_status=(m_tester?"tester news requires server-time CSV; missing/invalid coverage BLOCKS entries":
                          "USD calendar required; unavailable/stale coverage BLOCKS entries");
      Print("QSMC NEWS: ",m_status,"; +/-30 minutes, refresh <15 minutes; not yet queried");
      return true;
   }
   void Invalidate(){m_valid=false;m_attempt=0;}
   bool Check(const datetime now,string &why)
   {
      why="";
      if(!m_ready || now<=1800){why="news filter/server clock unavailable; entries BLOCKED";return false;}
      if(!m_valid || !CQSMCNewsPolicy::Covered((long)m_from,(long)m_to,(long)m_fetched,(long)now))
      {
         m_valid=false;
         // Retry failures no more than once per minute, without serving stale data.
         if(m_attempt>0 && now>=m_attempt && now-m_attempt<60)
         {
            why="news source unavailable/stale; refresh retry cooldown active, entries BLOCKED";
            m_status=why;return false;
         }
         m_attempt=now;m_count=0;
         bool ok=(m_tester?LoadCsv(now,why):LoadCalendar(now,why));
         if(!ok){m_status=why;return false;}
         m_valid=true;
      }
      // Calendar/file calls may have blocked: certify the clock AFTER I/O too.
      datetime observed=TimeTradeServer();
      if(observed<now || !CQSMCNewsPolicy::Covered((long)m_from,(long)m_to,(long)m_fetched,(long)observed))
      {
         Invalidate();why="news coverage stale after source read/clock change; entries BLOCKED";
         m_status=why;return false;
      }
      for(int i=0;i<m_count;i++)
      {
         if(CQSMCNewsPolicy::Blackout((long)observed,(long)m_times[i]))
         {
            why="USD news blackout: "+m_names[i]+" at server "+TimeToString(m_times[i],TIME_DATE|TIME_SECONDS);
            m_status=why;return false;
         }
      }
      why="USD news window clear within cached source coverage (not a guarantee against unscheduled news)";
      m_status=why;return true;
   }
   string Status() const{return m_status;}
};
#endif // QSMC_NEWSFILTER_MQH
