#property script_show_inputs
#include <QSMC/QSMC.mqh>
#include "../Tests/Harness/QSMC_Selftest.mqh"

void OnStart()
{
   SQSMCTestReport report;
   CQSMCSelftest::Run(report);
   Print("QSMC self-test: passed=",report.passed," failed=",report.failed);
   Print(report.details);
}
