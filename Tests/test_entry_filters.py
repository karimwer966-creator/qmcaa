#!/usr/bin/env python3
"""Host shims execute actual pure entry-time/news policy headers, NOT MT5 APIs."""
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]


class EntryFilterTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which('g++'), 'host C++ compiler unavailable')
    def test_actual_policy_headers(self):
        source = r'''
#include <string>
#include <cctype>
#include <cassert>
#include <cmath>
using string=std::string;
int StringLen(const string &s){return (int)s.size();}
int StringFind(const string &s,const string &q,int from=0){
 auto p=s.find(q,(size_t)from);return p==string::npos?-1:(int)p;
}
string StringSubstr(const string &s,int from,int count){return s.substr((size_t)from,(size_t)count);}
void StringToUpper(string &s){for(char &c:s)c=(char)std::toupper((unsigned char)c);}
void StringTrimLeft(string &s){s.erase(0,s.find_first_not_of(" \t\r\n"));}
void StringTrimRight(string &s){auto p=s.find_last_not_of(" \t\r\n");s=(p==string::npos?"":s.substr(0,p+1));}
#include "Include/QSMC/Safety/QSMC_EntryTimeRules.mqh"
#include "Include/QSMC/Safety/QSMC_NewsPolicy.mqh"
int main(){
 string why;
 assert(CQSMCEntryTimeRules::FromHourMinute(8,90)==-1);
 assert(CQSMCEntryTimeRules::FromHourMinute(24,0)==-1);
 assert(CQSMCEntryTimeRules::FromHourMinute(23,59)==1439);
 assert(CQSMCEntryTimeRules::Window(1410,1380,60));
 assert(CQSMCEntryTimeRules::Window(30,1380,60));
 assert(!CQSMCEntryTimeRules::Window(60,1380,60));
 assert(!CQSMCEntryTimeRules::Window(10,0,0));
 assert(!CQSMCEntryTimeRules::Window(10,-1,60));
 auto permitted=[&](int day,int minute,bool sessions){
   return CQSMCEntryTimeRules::Schedule(day,minute,1200,sessions,120,480,540,720,900,1080,why);
 };
 assert(!permitted(1,74,false) && permitted(1,75,false));
 assert(permitted(1,1424,false) && !permitted(1,1425,false));
 assert(permitted(5,1199,false) && !permitted(5,1200,false));
 assert(!permitted(0,600,false) && !permitted(6,600,false));
 assert(permitted(1,540,true) && !permitted(1,720,true));
 assert(!permitted(1,800,true) && permitted(1,900,true));
 assert(CQSMCEntryTimeRules::Schedule(1,600,1200,true,540,720,570,660,900,1080,why));
 for(int day=0;day<7;day++)for(int m=0;m<1440;m++){
   bool expected=day>=1 && day<=5 && (day!=5 || m<1200) && m>=75 && m<1425;
   assert(permitted(day,m,false)==expected);
   bool session=(m>=120 && m<480)||(m>=540 && m<720)||(m>=900 && m<1080);
   assert(permitted(day,m,true)==(expected && session));
 }
 assert(!CQSMCEntryTimeRules::Schedule(1,600,1200,true,0,0,540,720,900,1080,why));
 const long now=100000;
 assert(CQSMCNewsPolicy::Blackout(now,now-1800));
 assert(CQSMCNewsPolicy::Blackout(now,now+1800));
 assert(!CQSMCNewsPolicy::Blackout(now,now-1801));
 assert(!CQSMCNewsPolicy::Blackout(now,now+1801));
 assert(CQSMCNewsPolicy::Blackout(now,0));
 assert(CQSMCNewsPolicy::Covered(now-1800,now+2700,now,now));
 assert(CQSMCNewsPolicy::Covered(now-1800,now+2700,now,now+899));
 assert(!CQSMCNewsPolicy::Covered(now-1800,now+2700,now,now+900));
 assert(!CQSMCNewsPolicy::Covered(now-1800,now+1799,now,now));
 assert(!CQSMCNewsPolicy::Covered(now-1799,now+2700,now,now));
 assert(!CQSMCNewsPolicy::Covered(now-1800,now+2700,now,now-1));
 string keywords;
 assert(CQSMCNewsPolicy::Keywords(" nfp ; CPI;FOMC;Fed ",keywords));
 assert(CQSMCNewsPolicy::Relevant("USD",false,"Nonfarm nFp release",keywords));
 assert(CQSMCNewsPolicy::Relevant("USD",false,"cpi report",keywords));
 assert(CQSMCNewsPolicy::Relevant("USD",false,"Fed Chair speaks",keywords));
 assert(CQSMCNewsPolicy::Relevant("USD",true,"Unrecognized high impact",keywords));
 assert(!CQSMCNewsPolicy::Relevant("EUR",true,"CPI",keywords));
 assert(!CQSMCNewsPolicy::Relevant("USD",false,"unrelated release",keywords));
 assert(!CQSMCNewsPolicy::Keywords("CPI;;NFP",keywords));
 assert(!CQSMCNewsPolicy::Keywords("CPI;",keywords));
 assert(!CQSMCNewsPolicy::Keywords("  ",keywords));
 assert(!CQSMCNewsPolicy::Keywords("",keywords));
}
'''
        with tempfile.TemporaryDirectory(prefix='qsmc-entry-') as tmp:
            cpp, binary = Path(tmp) / 'entry.cpp', Path(tmp) / 'entry'
            cpp.write_text(source)
            subprocess.run(['g++', '-std=c++17', '-Wall', '-Wextra', '-Werror',
                            '-I', str(ROOT), str(cpp), '-o', str(binary)], check=True)
            subprocess.run([str(binary)], check=True)

    def test_entry_only_integration_shape(self):
        safety = (ROOT/'Include/QSMC/Safety/QSMC_SafetyController.mqh').read_text()
        self.assertIn('return m_entries.Check(why);', safety)
        preflight = (ROOT/'Include/QSMC/Execution/QSMC_ExecutionPreflight.mqh').read_text()
        self.assertEqual(preflight.count('safety.CanSubmit(root,why)'), 2)
        broker = (ROOT/'Include/QSMC/Execution/QSMC_RealAdapter.mqh').read_text()
        self.assertIn('CQSMCExecutionPreflight::Validate', broker[broker.index('if(!OrderCheck'):broker.index('bool sent=OrderSend')])
        app = (ROOT/'Include/QSMC/App/QSMC_Orchestrator.mqh').read_text()
        self.assertIn('m_execution.MonitorRisk', app)
        self.assertNotIn('ProbeEntryFilters(', app)  # no news I/O gate in analysis/risk event flow
        news = (ROOT/'Include/QSMC/Safety/QSMC_NewsFilter.mqh').read_text()
        self.assertIn('m_tester?LoadCsv(now,why):LoadCalendar(now,why)', news)
        self.assertIn('m_valid=false;', news)
        self.assertIn('CalendarValueHistory(values,queryFrom,queryTo,NULL,"USD")', news)
        self.assertNotIn('WebRequest(', news)
        ea = (ROOT/'Experts/QSMC/QSMC.mq5').read_text()
        for label in ('AsiaStart','AsiaEnd','LondonStart','LondonEnd','NewYorkStart','NewYorkEnd'):
            self.assertIn(f'QSMC_ServerMinute(Inp{label}Hour,Inp{label}Minute)', ea)


if __name__ == '__main__':
    unittest.main()
