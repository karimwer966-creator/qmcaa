//+------------------------------------------------------------------+
//|                                                  QSMC_Arbiter.mqh |
//|  Stable winner selection: highest score; exact opposing tie rejects |
//|  the opportunity rather than arbitrary long/short priority.          |
//+------------------------------------------------------------------+
#ifndef QSMC_ARBITER_MQH
#define QSMC_ARBITER_MQH
#include "QSMC_SignalRegistry.mqh"
#include "QSMC_UnifiedDecision.mqh"

class CQSMCArbiter
{
public:
   static bool Resolve(const CQSMCSignalRegistry &registry,
                       const double minimumConfidence,
                       const datetime barTime,
                       SQSMCUnifiedDecision &out)
   {
      out.Reset();
      out.barTime=barTime;
      int buys=0,sells=0;
      double buyScore=-1.0,sellScore=-1.0;
      string buyEvidence="",sellEvidence="";
      SQSMCCandidate c;
      for(int i=0;i<registry.Count();i++)
      {
         if(!registry.Get(i,c)) continue;
         if(c.direction==QSMC_DIR_BUY)
         {
            buys++;
            if(c.score>buyScore) { buyScore=c.score; buyEvidence=c.source+": "+c.evidence; }
         }
         else if(c.direction==QSMC_DIR_SELL)
         {
            sells++;
            if(c.score>sellScore) { sellScore=c.score; sellEvidence=c.source+": "+c.evidence; }
         }
      }

      if(buys==0 && sells==0)
      {
         out.Reject(QSMC_ERR_NO_DECISION,"arbiter","no qualified analytical candidate");
         out.explanation="NO TRADE: no candidate";
         return false;
      }
      if(buys>0 && sells>0 && MathAbs(buyScore-sellScore)<1e-9)
      {
         out.Reject(QSMC_ERR_NO_DECISION,"arbiter","equal-score directional conflict");
         out.explanation="NO TRADE: conflicting candidates tied";
         return false;
      }

      if(buyScore>sellScore)
      {
         out.direction=QSMC_DIR_BUY;
         out.confidence=buyScore;
         out.explanation=buyEvidence;
         if(sells>0)
            out.Reject(QSMC_ERR_NO_DECISION,"arbiter",
                       StringFormat("SELL candidate score %.3f lost to BUY %.3f",sellScore,buyScore));
      }
      else
      {
         out.direction=QSMC_DIR_SELL;
         out.confidence=sellScore;
         out.explanation=sellEvidence;
         if(buys>0)
            out.Reject(QSMC_ERR_NO_DECISION,"arbiter",
                       StringFormat("BUY candidate score %.3f lost to SELL %.3f",buyScore,sellScore));
      }

      if(out.confidence<minimumConfidence)
      {
         out.Reject(QSMC_ERR_NO_DECISION,"confidence",
                    StringFormat("winner %.2f below minimum %.2f",out.confidence,minimumConfidence));
         out.direction=QSMC_DIR_NONE;
         out.explanation="NO TRADE: confidence threshold not met";
         return false;
      }

      // The deterministic UID is an audit/deduplication token, not a hash
      // security primitive. Inputs are stable decision-bar identity fields.
      ulong h=(ulong)barTime;
      h=(h*1099511628211)+(ulong)out.direction;
      h=(h*1099511628211)+(ulong)MathRound(out.confidence*1000000.0);
      out.uid=h;
      out.valid=true;
      return true;
   }
};
#endif // QSMC_ARBITER_MQH
