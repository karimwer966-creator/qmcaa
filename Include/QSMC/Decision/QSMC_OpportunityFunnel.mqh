//+------------------------------------------------------------------+
//|                                      QSMC_OpportunityFunnel.mqh |
//| Primary Sweep->MSS->FVG and secondary BOS/CHoCH->OB-retouch models. |
//| HTF bias, active session and directional liquidity are hard filters.|
//| All component points are heuristics, never calibrated probabilities.|
//+------------------------------------------------------------------+
#ifndef QSMC_OPPORTUNITYFUNNEL_MQH
#define QSMC_OPPORTUNITYFUNNEL_MQH
#include "../Analysis/QSMC_Scanners.mqh"
#include "QSMC_SignalRegistry.mqh"

struct SQSMCOpportunityRecord
{
   string model;
   string status;
   string stage;
   ENUM_QSMC_DIRECTION direction;
   double scorePoints;
   string reason;
   void Reset()
   {model="";status="REJECTED";stage="UNAVAILABLE";direction=QSMC_DIR_NONE;scorePoints=0.0;reason="";}
};
struct SQSMCOpportunityAudit
{
   datetime barTime;
   double close;
   double atr;
   SQSMCOpportunityRecord primary;
   SQSMCOpportunityRecord alternate;
   void Reset()
   {barTime=0;close=0.0;atr=0.0;primary.Reset();alternate.Reset();}
};

class CQSMCOpportunityFunnel
{
private:
   static double ClampPoints(const double points)
   {return MathMax(0.0,MathMin(100.0,points));}

   static void EvaluateOne(const SQSMCScanContext &c,const string model,
                           const bool rawCandidate,const ENUM_QSMC_DIRECTION direction,
                           const string stage,const string rawReason,const double basePoints,
                           const double minScore,SQSMCOpportunityRecord &out,
                           CQSMCSignalRegistry &registry)
   {
      out.Reset();out.model=model;out.stage=stage;out.direction=direction;
      if(!c.valid){out.status="DATA_UNAVAILABLE";out.reason="analysis context invalid; no candidate emitted";return;}
      if(!rawCandidate || direction==QSMC_DIR_NONE)
      {
         bool waiting=(StringFind(stage,"WAIT_")==0 || stage=="UNAVAILABLE");
         out.status=(waiting?"WAITING":"REJECTED");
         out.reason=(waiting?"waiting: ":"rejected: ")+rawReason;
         return;
      }

      // Common hard filters apply to both the primary and alternate models.
      if(c.htfBias==QSMC_BIAS_NEUTRAL)
      {out.reason="rejected: HTF Bias is neutral; direction not permitted | "+rawReason;return;}
      bool biasAligned=((direction==QSMC_DIR_BUY && c.htfBias==QSMC_BIAS_BULLISH) ||
                        (direction==QSMC_DIR_SELL && c.htfBias==QSMC_BIAS_BEARISH));
      if(!biasAligned)
      {out.reason="rejected: direction conflicts with HTF Bias "+QSMC_BiasToString(c.htfBias)+" | "+rawReason;return;}
      if(!c.inKillzone)
      {out.reason="rejected: outside configured London/New York session | "+rawReason;return;}
      if(c.sweptSessionHigh && c.sweptSessionLow)
      {out.reason="rejected: both-side session liquidity raids are ambiguous | "+rawReason;return;}
      bool liquidityAligned=(direction==QSMC_DIR_BUY?c.sweptSessionLow:c.sweptSessionHigh);
      if(!liquidityAligned)
      {out.reason="rejected: no direction-aligned recent session-liquidity raid | "+rawReason;return;}

      double points=basePoints;
      string evidence="accepted: HTF Bias "+QSMC_BiasToString(c.htfBias)+
                      "; active session; direction-aligned liquidity raid";
      if(c.flowReady)
      {
         double signedPressure=(direction==QSMC_DIR_BUY?c.flowPressure:-c.flowPressure);
         if(signedPressure>=0.15)
         {
            points+=4.0;
            if(c.relativeTickVolume>=1.5)points+=2.0;
            evidence+="; tick-volume proxy aligned";
         }
         else if(signedPressure<=-0.15)
         {points-=4.0;evidence+="; tick-volume proxy counter-pressure";}
         else evidence+="; tick-volume proxy neutral";
      }
      else evidence+="; tick-volume proxy unavailable (omitted)";

      if(c.svpReady)
      {
         bool valueAligned=(direction==QSMC_DIR_BUY?c.aboveValue:c.belowValue);
         bool valueOpposed=(direction==QSMC_DIR_BUY?c.belowValue:c.aboveValue);
         if(valueAligned){points+=4.0;evidence+="; Volume Profile value context aligned";}
         else if(valueOpposed){points-=4.0;evidence+="; Volume Profile value context opposed";}
         else evidence+="; price within/near value (no adjustment)";
      }
      else evidence+="; Volume Profile unavailable (omitted)";

      if(c.elliottReady)
      {
         bool pivotAligned=(direction==QSMC_DIR_BUY?c.elliottLastType==QSMC_SWING_LOW:
                                                    c.elliottLastType==QSMC_SWING_HIGH);
         bool pivotOpposed=(direction==QSMC_DIR_BUY?c.elliottLastType==QSMC_SWING_HIGH:
                                                    c.elliottLastType==QSMC_SWING_LOW);
         if(pivotAligned){points+=3.0;evidence+="; heuristic Elliott pivot aligned (+3)";}
         else if(pivotOpposed){points-=3.0;evidence+="; heuristic Elliott pivot opposed (-3)";}
      }
      else evidence+="; Elliott guide unavailable (omitted)";

      out.scorePoints=ClampPoints(points);
      if(out.scorePoints/100.0<minScore)
      {
         out.reason=StringFormat("rejected: confluence %.1f/100 below configured threshold %.2f | %s",
                                 out.scorePoints,minScore,evidence);
         return;
      }
      out.status="ACCEPTED";
      out.reason=StringFormat("%s; confluence %.1f/100 (not a probability); %s",
                              rawReason,out.scorePoints,evidence);
      registry.Add(direction,out.scorePoints/100.0,model,out.reason);
   }

public:
   static int Build(const SQSMCScanContext &context,const datetime barTime,
                    const double minimumScore,CQSMCSignalRegistry &registry,
                    SQSMCOpportunityAudit &audit)
   {
      registry.Reset();audit.Reset();audit.barTime=barTime;
      audit.close=context.price;audit.atr=context.atr;
      audit.primary.model="Sweep-MSS-FVG";
      audit.alternate.model="BOS-CHoCH-OB-Retest";
      EvaluateOne(context,"Sweep-MSS-FVG",context.ictCandidate,context.ictDirection,
                  context.ictStage,context.ictSummary,context.ictConfluence,
                  minimumScore,audit.primary,registry);
      EvaluateOne(context,"BOS-CHoCH-OB-Retest",context.alternateCandidate,
                  context.alternateDirection,context.alternateStage,
                  context.alternateSummary,context.alternateConfluence,
                  minimumScore,audit.alternate,registry);
      return registry.Count();
   }
};
#endif // QSMC_OPPORTUNITYFUNNEL_MQH
