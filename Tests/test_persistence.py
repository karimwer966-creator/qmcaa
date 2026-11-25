#!/usr/bin/env python3
"""Actual scalar/scope headers under C++ shims; no MT5 disk/locking certification."""
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]


class PersistenceTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which('g++'), 'host C++ compiler unavailable')
    def test_actual_scope_and_codec(self):
        source = r'''
#include <string>
#include <cmath>
#include <cassert>
using string=std::string;
using ushort=unsigned short;
int StringLen(const string &s){return (int)s.size();}
ushort StringGetCharacter(const string &s,int i){return (ushort)(unsigned char)s.at((size_t)i);}
int StringFind(const string &s,const string &q){auto p=s.find(q);return p==string::npos?-1:(int)p;}
int StringCompare(const string &a,const string &b){return a.compare(b);}
string StringSubstr(const string &s,int from,int count=-1){return s.substr((size_t)from,count<0?string::npos:(size_t)count);}
string IntegerToString(long v){return std::to_string(v);}
long StringToInteger(const string &s){try{return std::stol(s);}catch(...){return 0;}}
double StringToDouble(const string &s){try{return std::stod(s);}catch(...){return 0;}}
bool MathIsValidNumber(double x){return std::isfinite(x);}
string StringFormat(const char *,unsigned long v){return std::to_string(v);}
#include "Include/QSMC/Core/QSMC_OwnerScope.mqh"
#include "Include/QSMC/Infrastructure/QSMC_StateCodec.mqh"
int main(){
 string a=CQSMCOwnerScope::Raw(123,"Broker-A","XAUUSD.a",53000001);
 assert(!a.empty() && a==CQSMCOwnerScope::Raw(123,"Broker-A","XAUUSD.a",53000001));
 assert(a!=CQSMCOwnerScope::Raw(124,"Broker-A","XAUUSD.a",53000001));
 assert(a!=CQSMCOwnerScope::Raw(123,"Broker-B","XAUUSD.a",53000001));
 assert(a!=CQSMCOwnerScope::Raw(123,"Broker-A","XAUUSD.b",53000001));
 assert(a!=CQSMCOwnerScope::Raw(123,"Broker-A","XAUUSD.a",53000002));
 assert(CQSMCOwnerScope::Raw(0,"Broker-A","XAUUSD",1).empty());
 assert(CQSMCOwnerScope::Raw(1,"Broker\nA","XAUUSD",1).empty());
 assert(CQSMCOwnerScope::Raw(1,"Broker-A","XAUUSD",0).empty());
 assert(CQSMCStateCodec::Unsigned("18446744073709551615"));
 assert(!CQSMCStateCodec::Unsigned("18446744073709551616"));
 assert(!CQSMCStateCodec::Unsigned("01"));
 assert(!CQSMCStateCodec::Integer("9223372036854775808"));
 assert(CQSMCStateCodec::Integer("-9223372036854775808"));
 assert(!CQSMCStateCodec::Integer("1x"));
 assert(CQSMCStateCodec::Number("-0.000125"));
 assert(!CQSMCStateCodec::Number("NaN"));
 assert(!CQSMCStateCodec::Number("inf"));
 assert(!CQSMCStateCodec::Number("10garbage"));
 assert(CQSMCStateCodec::Value("safety.kill","B","1"));
 assert(!CQSMCStateCodec::Value("safety.kill","S","1"));
 assert(!CQSMCStateCodec::Value("safety.kill","B","true"));
 assert(!CQSMCStateCodec::Value("risk.day","I","-1"));
 assert(!CQSMCStateCodec::Value("risk.peak_equity","S","10000"));
 assert(CQSMCStateCodec::Value("execution.pending_uid","S","18446744073709551615"));
 assert(!CQSMCStateCodec::Value("execution.pending_uid","S","0"));
 assert(!CQSMCStateCodec::Value("execution.pending_uid","S","broken"));
 assert(!CQSMCStateCodec::Value("bad=key","S","v"));
 assert(!CQSMCStateCodec::Value("test.key","S","line\nbreak"));
}
'''
        with tempfile.TemporaryDirectory(prefix='qsmc-state-') as tmp:
            cpp, binary = Path(tmp) / 'state.cpp', Path(tmp) / 'state'
            cpp.write_text(source)
            subprocess.run(['g++', '-std=c++17', '-Wall', '-Wextra', '-Werror',
                            '-I', str(ROOT), str(cpp), '-o', str(binary)], check=True)
            subprocess.run([str(binary)], check=True)

    def test_storage_and_recovery_source_boundaries(self):
        store = (ROOT/'Include/QSMC/Infrastructure/QSMC_StateStore.mqh').read_text()
        self.assertNotIn('FileDelete(', store)
        self.assertIn('FILE_COMMON|FILE_REWRITE', store)
        self.assertIn('if(FileIsExist(m_file+".tmp",FILE_COMMON))return Fail', store)
        self.assertIn('scope!="scope="+m_scope', store)
        self.assertIn('keys[j]==key', store)
        self.assertIn('2*StringLen(text)', store)
        lock = store[store.index('m_lock=FileOpen'):store.index('m_ready=true;')]
        self.assertNotIn('FILE_SHARE', lock)
        identity = (ROOT/'Include/QSMC/Core/QSMC_InstanceIdentity.mqh').read_text()
        self.assertIn('m_magic=explicitMagic;', identity)
        self.assertNotIn('h %', identity)
        recovery = (ROOT/'Include/QSMC/Execution/QSMC_RiskRecovery.mqh').read_text()
        self.assertNotIn('Remove(', recovery)
        self.assertNotIn('OrderSend(', recovery)
        risk = (ROOT/'Include/QSMC/Execution/QSMC_RiskManager.mqh').read_text()
        self.assertIn('"__ACCOUNT_RISK__",1', risk)
        self.assertIn('CQSMCRiskMath::Peak(false', risk)
        self.assertIn('store.GetInt("risk.day",0)!=(long)day', risk)
        enrollment = (ROOT/'Scripts/QSMC_EnrollRisk.mq5').read_text()
        self.assertNotIn('SetKillSwitch(', enrollment)
        self.assertNotIn('Remove(', enrollment)
        self.assertIn('HistoryDealsTotal()!=0', enrollment)


if __name__ == '__main__':
    unittest.main()
