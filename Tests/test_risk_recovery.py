#!/usr/bin/env python3
"""Actual RiskRecovery header with a fake broker, not MT5 history certification."""
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(shutil.which('g++'), 'host C++ compiler unavailable')
class RiskRecoveryTests(unittest.TestCase):
    def test_actual_replay_with_mock_history(self):
        source = r'''
#include <string>
#include <vector>
#include <cmath>
#include <cassert>
using string=std::string;
using datetime=long;
#define QSMC_STATESTORE_MQH
#define QSMC_MAX_JOURNAL 256
const int DEAL_TIME=1,DEAL_TYPE=2,DEAL_MAGIC=3,DEAL_ENTRY=4,DEAL_POSITION_ID=5,DEAL_REASON=6;
const int DEAL_VOLUME=7,DEAL_PROFIT=8,DEAL_SWAP=9,DEAL_FEE=10,DEAL_COMMISSION=11,DEAL_SYMBOL=12;
const int DEAL_TYPE_BUY=20,DEAL_TYPE_SELL=21,DEAL_ENTRY_IN=30,DEAL_ENTRY_OUT=31,DEAL_ENTRY_OUT_BY=32;
const int DEAL_REASON_SL=40,DEAL_REASON_TP=41;
const int POSITION_MAGIC=50,POSITION_SYMBOL=51,POSITION_IDENTIFIER=52,POSITION_VOLUME=53;
struct Deal{long time,entry,position;double lots,profit;long reason=0,type=DEAL_TYPE_BUY,magic=7;string symbol="XAUUSD";};
struct Position{long identifier;double lots;};
std::vector<Deal> deals;
std::vector<Position> positions;
bool available=true;
int selected=-1;
long TimeCurrent(){return 1000;}
bool HistorySelect(long,long){return available;}
int HistoryDealsTotal(){return (int)deals.size();}
unsigned long HistoryDealGetTicket(int i){return (unsigned long)i+1;}
bool HistoryDealGetInteger(unsigned long t,int key,long &out){
 const auto &d=deals.at(t-1);
 switch(key){case DEAL_TIME:out=d.time;break;case DEAL_TYPE:out=d.type;break;case DEAL_MAGIC:out=d.magic;break;
 case DEAL_ENTRY:out=d.entry;break;case DEAL_POSITION_ID:out=d.position;break;case DEAL_REASON:out=d.reason;break;default:return false;}return true;
}
bool HistoryDealGetString(unsigned long t,int,string &out){out=deals.at(t-1).symbol;return true;}
bool HistoryDealGetDouble(unsigned long t,int key,double &out){
 const auto &d=deals.at(t-1);out=key==DEAL_VOLUME?d.lots:(key==DEAL_PROFIT?d.profit:0.0);return true;
}
int PositionsTotal(){return (int)positions.size();}
unsigned long PositionGetTicket(int i){selected=i;return (unsigned long)i+1;}
bool PositionGetInteger(int key,long &out){out=key==POSITION_MAGIC?7:positions.at((size_t)selected).identifier;return true;}
bool PositionGetString(int,string &out){out="XAUUSD";return true;}
bool PositionGetDouble(int,double &out){out=positions.at((size_t)selected).lots;return true;}
bool MathIsValidNumber(double v){return std::isfinite(v);}
double MathAbs(double v){return std::abs(v);}
#include "Include/QSMC/Execution/QSMC_RiskRecovery.mqh"
int main(){
 SQSMCRecoveredRisk r;string why;
 auto run=[&](){return CQSMCRiskRecovery::Replay("XAUUSD",7,50,200,r,why);};
 deals={{100,DEAL_ENTRY_IN,1,1,0},{210,DEAL_ENTRY_OUT,1,0.5,-5,DEAL_REASON_SL},
        {220,DEAL_ENTRY_OUT,1,0.5,-7,DEAL_REASON_SL}};
 assert(run() && r.closedToday==1 && r.lossStreak==1 && r.slToday==1 && r.realizedToday==-12);
 assert(run() && r.closedToday==1 && r.lossStreak==1); // idempotent replay
 deals.push_back({230,DEAL_ENTRY_IN,2,1,0});deals.push_back({240,DEAL_ENTRY_OUT,2,1,20,DEAL_REASON_TP});
 assert(run() && r.closedToday==2 && r.lossStreak==0 && r.tpToday==1 && r.realizedToday==8 && r.lastEntry==230);
 deals={{100,DEAL_ENTRY_IN,1,1,0},{210,DEAL_ENTRY_OUT,1,0.5,-5,DEAL_REASON_SL}};positions={{1,0.5}};
 assert(run() && r.closedToday==0 && r.lossStreak==0 && r.realizedToday==-5);
 positions[0].lots=0.6;assert(!run());positions.clear();
 deals={{210,DEAL_ENTRY_OUT,1,1,-5,DEAL_REASON_SL}};assert(!run()); // omitted entry
 deals={{100,DEAL_ENTRY_IN,1,1,0},{210,99,1,1,-5}};assert(!run()); // reversal/unknown
 deals={{100,DEAL_ENTRY_IN,1,1,0},{210,DEAL_ENTRY_OUT,1,2,-5}};assert(!run());
 deals={{100,DEAL_ENTRY_IN,1,1,0},{210,DEAL_ENTRY_OUT,1,1,-5}};deals[0].magic=8;assert(!run());
 deals={{100,DEAL_ENTRY_IN,1,1,0},{90,DEAL_ENTRY_OUT,1,1,-5}};assert(!run());
 deals={{100,DEAL_ENTRY_IN,1,1,0}};deals[0].type=999;deals[0].magic=0;assert(!run()); // account cash flow
 available=false;deals.clear();assert(!run());available=true;
 for(int i=0;i<257;i++){deals.push_back({100+2*i,DEAL_ENTRY_IN,i+1,1,0});deals.push_back({101+2*i,DEAL_ENTRY_OUT,i+1,1,1});}
 assert(!run()); // bounded, never silently drop lifecycles
}
'''
        with tempfile.TemporaryDirectory(prefix='qsmc-recovery-') as tmp:
            cpp, binary = Path(tmp)/'recovery.cpp', Path(tmp)/'recovery'
            cpp.write_text(source)
            subprocess.run(['g++', '-std=c++17', '-Wall', '-Wextra', '-Werror',
                            '-I', str(ROOT), str(cpp), '-o', str(binary)], check=True)
            subprocess.run([str(binary)], check=True)


if __name__ == '__main__':
    unittest.main()
