// Tester wrapper for pure contracts. Not a strategy or broker execution test.
#property strict
#property version "1.000"
#include "../../Tests/Harness/QSMC_SafetySelftest.mqh"
int g_safetyFailures=-1;
int OnInit()
{
   if(MQLInfoInteger(MQL_TESTER)==0)
   {Print("Use Strategy Tester, or Scripts/QSMC_SafetySelftest for chart diagnostics");return INIT_PARAMETERS_INCORRECT;}
   SQSMCSafetyTestReport report;
   CQSMCSafetySelftest::Run(report);
   g_safetyFailures=report.failed;
   Print("QSMC SAFETY SELFTEST passed=",report.passed," failed=",report.failed);
   Print(report.details);
   return report.failed==0?INIT_SUCCEEDED:INIT_FAILED;
}
void OnTick(){} // No signal, order, timer or persistence path.
double OnTester(){return g_safetyFailures==0?1.0:0.0;}
