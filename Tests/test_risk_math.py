#!/usr/bin/env python3
"""Execute the ACTUAL pure RiskMath header with C++ math shims.
This does not compile MQL, test broker APIs, or certify persistence.
"""
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(shutil.which('g++'), 'host C++ compiler unavailable')
class RiskMathTests(unittest.TestCase):
    def test_actual_header_arithmetic(self):
        source = r'''
#include <algorithm>
#include <cassert>
#include <cmath>
#include <limits>
#include <random>
inline bool MathIsValidNumber(double v){return std::isfinite(v);}
inline double MathFloor(double v){return std::floor(v);}
inline double MathMin(double a,double b){return std::min(a,b);}
inline double MathMax(double a,double b){return std::max(a,b);}
#include "Include/QSMC/Execution/QSMC_RiskMath.mqh"
int main(){
 double b=0,l=0,peak=0,dd=0;
 assert(CQSMCRiskMath::Peak(true,0,10000,peak,dd) && peak==10000 && dd==0);
 assert(CQSMCRiskMath::Peak(false,peak,11000,peak,dd) && peak==11000);
 // Use distinct prior/output variables as the production caller does.
 double prior=11000;
 assert(CQSMCRiskMath::Peak(false,prior,9000,peak,dd) && peak==11000 && std::abs(dd-18.1818181818)<1e-8);
 assert(!CQSMCRiskMath::Peak(false,0,9000,peak,dd));
 assert(CQSMCRiskMath::Budget(10000,0.5,b) && b==50);
 assert(!CQSMCRiskMath::Budget(10000,2.01,b));
 assert(!CQSMCRiskMath::Budget(std::numeric_limits<double>::quiet_NaN(),0.5,b));
 assert(!CQSMCRiskMath::Budget(10000,std::numeric_limits<double>::infinity(),b));
 assert(CQSMCRiskMath::FloorLots(50,100,0.25,10,0.25,10,l) && l==0.5);
 assert(!CQSMCRiskMath::FloorLots(24,100,0.25,10,0.25,10,l) && l==0);
 assert(CQSMCRiskMath::FloorLots(1000,100,0.25,1.1,0.25,0.9,l) && l==0.75);
 assert(!CQSMCRiskMath::FloorLots(50,0,0.01,100,0.01,10,l));
 assert(!CQSMCRiskMath::FloorLots(50,100,0.01,100,0,10,l));
 assert(!CQSMCRiskMath::FloorLots(50,100,0.01,100,0.01,-1,l));
 assert(!CQSMCRiskMath::FloorLots(50,100,0.01,100,0.01,std::numeric_limits<double>::infinity(),l));
 assert(CQSMCRiskMath::Margin(10000,1200,200,50));
 assert(!CQSMCRiskMath::Margin(10000,1199,200,50));
 assert(CQSMCRiskMath::Margin(10000,2200,200,2000));
 assert(!CQSMCRiskMath::Margin(10000,2199,200,2000));
 assert(!CQSMCRiskMath::Margin(10000,2000,-1,50));
 assert(CQSMCRiskMath::Margin(10000,1000,0,50));
 assert(!CQSMCRiskMath::Margin(10000,std::numeric_limits<double>::quiet_NaN(),0,50));
 std::mt19937 gen(42);
 std::uniform_real_distribution<double> money(0.01,100000), risk(0.01,10000), caps(0.001,100);
 const double steps[]={1,0.25,0.1,0.01,0.001,0.00001};
 for(int i=0;i<20000;i++){
   double budget=money(gen),loss=risk(gen),cap=caps(gen),step=steps[i%6];
   bool ok=CQSMCRiskMath::FloorLots(budget,loss,step,100,step,cap,l);
   if(ok){
     assert(l>=step && l<=100 && l<=cap && l*loss<=budget);
     assert(std::abs(l/step-std::round(l/step))<1e-6);
   }else assert(l==0);
 }
}
'''
        with tempfile.TemporaryDirectory(prefix='qsmc-risk-') as tmp:
            cpp = Path(tmp) / 'risk.cpp'
            binary = Path(tmp) / 'risk'
            cpp.write_text(source)
            subprocess.run(['g++', '-std=c++17', '-Wall', '-Wextra', '-Werror',
                            '-I', str(ROOT), str(cpp), '-o', str(binary)], check=True)
            subprocess.run([str(binary)], check=True)


if __name__ == '__main__':
    unittest.main()
