// Pure-contract script: does not touch account state or send requests.
#property script_show_inputs
#property strict
#include "../Tests/Harness/QSMC_SafetySelftest.mqh"
void OnStart()
{
   SQSMCSafetyTestReport report;
   CQSMCSafetySelftest::Run(report);
   Print("QSMC SAFETY SELFTEST passed=",report.passed," failed=",report.failed);
   Print(report.details);
}
