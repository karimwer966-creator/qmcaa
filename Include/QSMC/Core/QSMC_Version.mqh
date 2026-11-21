//+------------------------------------------------------------------+
//|                                                  QSMC_Version.mqh |
//|                         Single source of truth for build identity |
//+------------------------------------------------------------------+
#ifndef QSMC_VERSION_MQH
#define QSMC_VERSION_MQH

#define QSMC_NAME             "QSMC"
#define QSMC_VERSION_MAJOR    1
#define QSMC_VERSION_MINOR    0
#define QSMC_VERSION_PATCH    0
#define QSMC_VERSION_STRING   "1.0.0"

// Compile-time build stamp: uses the platform's __DATE__ macro.
string QSMC_Version()
{
   return QSMC_VERSION_STRING;
}

string QSMC_VersionFull()
{
   return StringFormat("%s v%s (compiled %s)", QSMC_NAME, QSMC_VERSION_STRING, __DATE__);
}

// Machine readable version for journals / state files.
string QSMC_VersionTag()
{
   return StringFormat("v%d.%d.%d",
                       QSMC_VERSION_MAJOR, QSMC_VERSION_MINOR, QSMC_VERSION_PATCH);
}

#endif // QSMC_VERSION_MQH
