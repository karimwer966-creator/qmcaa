//+------------------------------------------------------------------+
//|                                         QSMC_UnifiedDecision.mqh |
//|  Auditable final decision envelope.  Decision code does not trade.  |
//+------------------------------------------------------------------+
#ifndef QSMC_UNIFIEDDECISION_MQH
#define QSMC_UNIFIEDDECISION_MQH
#include "../Core/QSMC_Constants.mqh"
#include "../Core/QSMC_Types.mqh"

struct SQSMCRejection
{
   ENUM_QSMC_RESULT code;
   string           reason;
   string           source;
};

struct SQSMCUnifiedDecision
{
   bool                valid;
   ENUM_QSMC_DIRECTION direction;
   double              confidence;
   datetime            barTime;
   ulong               uid;
   string              explanation;
   int                 rejectionCount;
   SQSMCRejection      rejections[QSMC_MAX_REJECTIONS];

   void Reset()
   {
      valid = false;
      direction = QSMC_DIR_NONE;
      confidence = 0.0;
      barTime = 0;
      uid = 0;
      explanation = "";
      rejectionCount = 0;
      for(int i=0; i<QSMC_MAX_REJECTIONS; i++)
      {
         rejections[i].code = QSMC_OK;
         rejections[i].reason = "";
         rejections[i].source = "";
      }
   }

   void Reject(const ENUM_QSMC_RESULT code, const string source, const string reason)
   {
      if(rejectionCount >= QSMC_MAX_REJECTIONS) return;
      rejections[rejectionCount].code = code;
      rejections[rejectionCount].source = source;
      rejections[rejectionCount].reason = reason;
      rejectionCount++;
   }
};

#endif // QSMC_UNIFIEDDECISION_MQH
