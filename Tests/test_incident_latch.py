#!/usr/bin/env python3
"""Actual IncidentSafety header with a fake store/clock, not MQL/disk tests."""
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(shutil.which('g++'), 'host C++ compiler unavailable')
class IncidentLatchTests(unittest.TestCase):
    def test_actual_header_with_failure_injection(self):
        source = r'''
#include <string>
#include <map>
#include <cassert>
using string=std::string;
using datetime=long;
#define QSMC_TYPES_MQH
#define QSMC_STATESTORE_MQH
#define TIME_DATE 1
#define TIME_SECONDS 2
long TimeCurrent(){return 1234;}
string TimeToString(long,int){return "test-time";}
int StringLen(const string &s){return (int)s.size();}
template<class... T> void Print(T...){ }
class CQSMCStateStore {
public:
 std::map<string,string> data;
 bool ready=true,fail=false,kill=false;
 bool IsReady(){return ready;}
 bool Exists(const string &k){return data.count(k)!=0;}
 string GetString(const string &k,const string &d=""){return Exists(k)?data[k]:d;}
 bool GetBool(const string &k,bool d=false){return Exists(k)?data[k]=="1":d;}
 long GetInt(const string &k,long d=0){return Exists(k)?std::stol(data[k]):d;}
 bool SetString(const string &k,const string &v){if(fail)return false;data[k]=v;return true;}
 bool SetBool(const string &k,bool v){return SetString(k,v?"1":"0");}
 bool SetInt(const string &k,long v){return SetString(k,std::to_string(v));}
 bool SetKillSwitch(bool v,const string &reason=""){
   (void)reason;
   if(fail){kill=true;return false;}kill=v;return true;
 }
 bool KillSwitchActive(){return kill;}
 string KillSwitchReason(){return "fake brake";}
};
#include "Include/QSMC/Safety/QSMC_IncidentSafety.mqh"
int main(){
 CQSMCStateStore store;
 CQSMCIncidentSafety latch,restored;
 assert(latch.Restore(store) && !latch.IsLatched());
 assert(latch.Latch(store,"fault",true));
 assert(!restored.Restore(store) && restored.IsLatched() && restored.RecoveryUncertain());
 assert(!restored.Acknowledge(store,false) && restored.IsLatched());
 store.data["execution.pending_uid"]="123";
 assert(!restored.Acknowledge(store,true) && restored.IsLatched());
 store.data.erase("execution.pending_uid");
 store.fail=true;
 assert(!restored.Acknowledge(store,true) && restored.IsLatched() && store.kill);
 assert(!restored.Latch(store,"another fault",false) && restored.RecoveryUncertain());
 store.fail=false;
 assert(restored.Acknowledge(store,true) && !restored.IsLatched() && !store.kill);
 assert(restored.Restore(store));
 store.data["safety.kill"]="1";
 assert(!restored.Restore(store) && restored.IsLatched());
 store.data["safety.kill"]="broken";
 assert(!restored.Restore(store) && restored.RecoveryUncertain());
 store.ready=false;
 assert(!restored.Restore(store) && restored.IsLatched());
 assert(!restored.Acknowledge(store,true));
}
'''
        with tempfile.TemporaryDirectory(prefix='qsmc-latch-') as tmp:
            cpp, binary = Path(tmp) / 'latch.cpp', Path(tmp) / 'latch'
            cpp.write_text(source)
            subprocess.run(['g++', '-std=c++17', '-Wall', '-Wextra', '-Werror',
                            '-I', str(ROOT), str(cpp), '-o', str(binary)], check=True)
            subprocess.run([str(binary)], check=True)


if __name__ == '__main__':
    unittest.main()
