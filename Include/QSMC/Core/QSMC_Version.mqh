#ifndef QSMC_VERSION_MQH
#define QSMC_VERSION_MQH

#define QSMC_NAME             "QSMC"
#define QSMC_VERSION_MAJOR    0
#define QSMC_VERSION_MINOR    1
#define QSMC_VERSION_PATCH    0
#define QSMC_VERSION_STRING   "0.1.0"

string QSMC_VersionFull()
{
   return StringFormat("%s v%s (build %s)", QSMC_NAME, QSMC_VERSION_STRING, __DATE__);
}

#endif