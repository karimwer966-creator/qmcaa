//+------------------------------------------------------------------+
//|                                                  QSMC_Scanners.mqh |
//|  Runs the analytical detectors once per decision bar and exposes a  |
//|  single immutable scan context.  SVP values are injected by the App  |
//|  layer (SetValueContext) so this module never depends on SVP.        |
//+------------------------------------------------------------------+
#ifndef QSMC_SCANNERS_MQH
#define QSMC_SCANNERS_MQH

#include "../Core/QSMC_Types.mqh"
#include "../Data/QSMC_MarketSnapshot.mqh"
#include "QSMC_Structure.mqh"
#include "QSMC_Bias.mqh"
#include "QSMC_Zones.mqh"
#include "QSMC_ZoneScorer.mqh"
#include "QSMC_LiquidityValue.mqh"
#include "QSMC_Reaction.mqh"
#include "QSMC_EarlyBreakDetector.mqh"
#include "QSMC_CandlePatterns.mqh"
#include "QSMC_Sessions.mqh"
#include "QSMC_FairValueGaps.mqh"
#include "QSMC_ICTSetup.mqh"
#include "QSMC_OrderFlowProxy.mqh"
#include "QSMC_ElliottGuide.mqh"
#include "QSMC_BreakOrderBlock.mqh"

struct SQSMCScanContext
{
   bool                valid;
   ENUM_QSMC_BIAS      bias;
   ENUM_QSMC_BIAS      htfBias;
   double              biasScore;
   double              biasConfidence;
   int                 swingCount;
   double              atr;
   double              price;

   int                 zoneCount;
   bool                hasZone;
   SQSMCZone           zone;           // candidate zone in bias direction
   double              zoneScore;
   double              zoneDistance;

   bool                reactionOk;
   ENUM_QSMC_DIRECTION reactionDir;
   double              reactionScore;
   ENUM_QSMC_PATTERN   pattern;
   string              reactionNote;

   bool                breakDetected;
   ENUM_QSMC_DIRECTION breakDir;
   double              breakLevel;
   double              breakDisplacement;

   bool                sweepDetected;
   bool                sweepUpper;      // true = liquidity above was swept
   double              sweepLevel;

   bool                svpReady;
   double              poc;
   double              vah;
   double              val;
   bool                aboveValue;
   bool                belowValue;

   string              sessionSummary;
   bool                inKillzone;
   bool                sweptSessionHigh;
   bool                sweptSessionLow;
   bool                flowReady;
   double              flowPressure;
   double              relativeTickVolume;
   bool                elliottReady;
   int                 elliottLastType;
   string              ictStage;
   string              ictSummary;
   bool                ictCandidate;
   ENUM_QSMC_DIRECTION ictDirection;
   double              ictConfluence;
   string              alternateStage;
   string              alternateSummary;
   bool                alternateCandidate;
   ENUM_QSMC_DIRECTION alternateDirection;
   double              alternateConfluence;
   double              alternateBreakLevel;
   double              alternateObTop;
   double              alternateObBottom;
   string              orderFlowSummary;
   string              elliottSummary;

   string              summary;

   void Reset()
   {
      valid              = false;
      bias               = QSMC_BIAS_NEUTRAL;
      htfBias            = QSMC_BIAS_NEUTRAL;
      biasScore          = 0.0;
      biasConfidence     = 0.0;
      swingCount         = 0;
      atr                = 0.0;
      price              = 0.0;

      zoneCount          = 0;
      hasZone            = false;
      zone.Reset();
      zoneScore          = 0.0;
      zoneDistance       = 0.0;

      reactionOk         = false;
      reactionDir        = QSMC_DIR_NONE;
      reactionScore      = 0.0;
      pattern            = QSMC_PATTERN_NONE;
      reactionNote       = "";

      breakDetected      = false;
      breakDir           = QSMC_DIR_NONE;
      breakLevel         = 0.0;
      breakDisplacement  = 0.0;

      sweepDetected      = false;
      sweepUpper         = false;
      sweepLevel         = 0.0;

      svpReady           = false;
      poc                = 0.0;
      vah                = 0.0;
      val                = 0.0;
      aboveValue         = false;
      belowValue         = false;

      sessionSummary     = "sessions unavailable";
      inKillzone         = false;
      sweptSessionHigh   = false;
      sweptSessionLow    = false;
      flowReady          = false;
      flowPressure       = 0.0;
      relativeTickVolume = 0.0;
      elliottReady       = false;
      elliottLastType    = QSMC_SWING_NONE;
      ictStage           = "UNAVAILABLE";
      ictSummary         = "ICT setup unavailable";
      ictCandidate       = false;
      ictDirection       = QSMC_DIR_NONE;
      ictConfluence      = 0.0;
      alternateStage     = "UNAVAILABLE";
      alternateSummary   = "BOS/CHoCH-OB model unavailable";
      alternateCandidate = false;
      alternateDirection = QSMC_DIR_NONE;
      alternateConfluence= 0.0;
      alternateBreakLevel= 0.0;
      alternateObTop     = 0.0;
      alternateObBottom  = 0.0;
      orderFlowSummary   = "tick-volume proxy unavailable";
      elliottSummary     = "swing guide unavailable";

      summary            = "";
   }
};

class CQSMCScanners
{
private:
   CQSMCStructure       m_structure;
   CQSMCZones           m_zones;
   CQSMCLiquidityValue  m_liquidity;
   SQSMCBiasResult      m_bias;
   SQSMCScanContext     m_context;
   int                  m_scanCount;
   bool                 m_sessionsEnabled;
   int                  m_asiaStart,m_asiaEnd,m_londonStart,m_londonEnd,m_nyStart,m_nyEnd;
   double               m_minFvgAtr;
   CQSMCSessions        m_sessions;
   CQSMCFairValueGaps   m_fvgs;
   SQSMCSessionContext  m_sessionContext;
   SQSMCICTSetup        m_ict;
   SQSMCBreakOrderBlock m_alternate;
   SQSMCOrderFlowProxyResult m_orderFlow;
   SQSMCElliottGuideResult m_elliott;
   bool                 m_svpReady;
   double               m_poc;
   double               m_vah;
   double               m_val;

public:
   CQSMCScanners()
   {
      m_scanCount = 0;
      m_sessionsEnabled=true;
      m_asiaStart=120;m_asiaEnd=480;m_londonStart=540;m_londonEnd=720;
      m_nyStart=900;m_nyEnd=1080;m_minFvgAtr=0.15;
      m_sessionContext.Reset();m_ict.Reset();m_alternate.Reset();m_orderFlow.Reset();m_elliott.Reset();
      m_svpReady  = false;
      m_poc       = 0.0;
      m_vah       = 0.0;
      m_val       = 0.0;
      m_context.Reset();
   }

   void Reset()
   {
      m_structure.Reset();
      m_zones.Reset();
      m_liquidity.Reset();
      m_bias.Reset();
      m_sessionContext.Reset();m_ict.Reset();m_alternate.Reset();m_orderFlow.Reset();m_elliott.Reset();
      m_fvgs.Reset();
      m_context.Reset();
   }

   int                        Scans()     const { return m_scanCount; }
   int                        ZoneCount() const { return m_zones.Count(); }
   int StructureCount() const { return m_structure.Count(); }
   bool GetStructurePoint(const int index,SQSMCStructurePoint &out) const
   {return m_structure.Get(index,out);}
   bool GetZone(const int index,SQSMCZone &out) const { return m_zones.Get(index,out); }
   int FvgCount() const { return m_fvgs.Count(); }
   bool GetFvg(const int index,SQSMCFairValueGap &out) const { return m_fvgs.Get(index,out); }
   void GetSessionContext(SQSMCSessionContext &out) const { out=m_sessionContext; }
   void GetICTSetup(SQSMCICTSetup &out) const { out=m_ict; }
   void GetAlternateSetup(SQSMCBreakOrderBlock &out) const { out=m_alternate; }
   void GetOrderFlowProxy(SQSMCOrderFlowProxyResult &out) const { out=m_orderFlow; }
   void GetElliottGuide(SQSMCElliottGuideResult &out) const { out=m_elliott; }

   void ConfigureICT(const SQSMCConfig &cfg)
   {
      m_sessionsEnabled=cfg.sessions_enabled;
      m_asiaStart=cfg.asia_start_minute;m_asiaEnd=cfg.asia_end_minute;
      m_londonStart=cfg.london_start_minute;m_londonEnd=cfg.london_end_minute;
      m_nyStart=cfg.new_york_start_minute;m_nyEnd=cfg.new_york_end_minute;
      m_minFvgAtr=cfg.min_fvg_atr;
   }

   // Return ranked, unmitigated zones on the current HTF bias side. Rank
   // zero is best; keeps the chart focused on relevant nearby POIs.
   bool GetRankedZone(const int rank,SQSMCZone &out) const
   {
      if(rank<0)return false;
      for(int i=0;i<m_zones.Count();i++)
      {
         SQSMCZone candidate;
         if(!m_zones.Get(i,candidate) || candidate.mitigated || candidate.score<0.30)continue;
         if(m_context.bias==QSMC_BIAS_BULLISH && !candidate.IsDemandLike())continue;
         if(m_context.bias==QSMC_BIAS_BEARISH && !candidate.IsSupplyLike())continue;
         if(m_context.atr>0.0 && MathAbs(candidate.Mid()-m_context.price)>m_context.atr*5.0)continue;
         int before=0;
         for(int j=0;j<m_zones.Count();j++)
         {
            if(j==i)continue;
            SQSMCZone other;
            if(!m_zones.Get(j,other)||other.mitigated||other.score<0.30)continue;
            if(m_context.bias==QSMC_BIAS_BULLISH && !other.IsDemandLike())continue;
            if(m_context.bias==QSMC_BIAS_BEARISH && !other.IsSupplyLike())continue;
            if(m_context.atr>0.0 && MathAbs(other.Mid()-m_context.price)>m_context.atr*5.0)continue;
            if(other.score>candidate.score || (other.score==candidate.score && j<i))before++;
         }
         if(before==rank){out=candidate;return true;}
      }
      return false;
   }

   //+---------------------------------------------------------------+
   //| Value-area context injected by the caller (SVP stays optional). |
   //+---------------------------------------------------------------+
   void SetValueContext(const bool ready, const double poc,
                        const double vah, const double val)
   {
      m_svpReady = ready;
      m_poc      = poc;
      m_vah      = vah;
      m_val      = val;
      m_context.svpReady=ready;
      m_context.poc=poc;
      m_context.vah=vah;
      m_context.val=val;
      m_context.aboveValue=(ready && poc>0.0 && m_context.price>vah);
      m_context.belowValue=(ready && poc>0.0 && m_context.price<val);
   }

   //+---------------------------------------------------------------+
   //| Run every detector for the current snapshot.                    |
   //+---------------------------------------------------------------+
   bool Scan(const CQSMCMarketSnapshot &snap,
             const int lookback,
             const int left,
             const int right,
             const double tolerancePrice,
             string &why)
   {
      why = "";
      m_context.Reset();
      m_sessionContext.Reset();m_ict.Reset();m_alternate.Reset();m_orderFlow.Reset();m_elliott.Reset();
      m_fvgs.Reset();

      const int slot   = QSMC_SNAP_EXEC;
      const int newest = snap.NewestIndex();

      double atr = snap.Atr(slot, 14, newest);
      if(atr <= 0.0)
      {
         why = "scan: ATR unavailable";
         return false;
      }

      double price = snap.Close(slot, newest);
      if(price <= 0.0)
      {
         why = "scan: no closed price";
         return false;
      }

      m_context.atr   = atr;
      m_context.price = price;
      m_context.svpReady = m_svpReady;
      m_context.poc      = m_poc;
      m_context.vah      = m_vah;
      m_context.val      = m_val;

      //--- structure --------------------------------------------------
      if(!m_structure.Detect(snap, slot, lookback, left, right))
      {
         why = "scan: no confirmed swing points";
         return false;
      }
      m_context.swingCount = m_structure.Count();

      //--- bias -------------------------------------------------------
      if(!CQSMCBias::Compute(snap, m_structure, m_bias))
      {
         why = m_bias.reason;
         return false;
      }
      m_context.bias           = m_bias.bias;
      if(m_bias.htfClose>m_bias.htfEma+QSMC_EPSILON)m_context.htfBias=QSMC_BIAS_BULLISH;
      else if(m_bias.htfClose<m_bias.htfEma-QSMC_EPSILON)m_context.htfBias=QSMC_BIAS_BEARISH;
      else m_context.htfBias=QSMC_BIAS_NEUTRAL;
      m_context.biasScore      = m_bias.score;
      m_context.biasConfidence = m_bias.confidence;

      //--- ICT sessions, FVGs, selected setup path and auxiliary guides.
      m_sessions.Evaluate(snap,slot,m_sessionsEnabled,m_asiaStart,m_asiaEnd,
                          m_londonStart,m_londonEnd,m_nyStart,m_nyEnd,m_sessionContext);
      m_fvgs.Build(snap,slot,lookback,m_minFvgAtr);
      CQSMCICTSetupModel::Evaluate(snap,slot,m_structure,m_sessionContext,m_fvgs,
                                   right,1.0,m_ict);
      CQSMCOrderFlowProxy::Calculate(snap,slot,20,m_orderFlow);
      CQSMCElliottGuide::Build(m_structure,m_elliott);
      m_context.sessionSummary=m_sessionContext.diagnostic;
      m_context.inKillzone=m_sessionContext.inLondonOrNewYork;
      m_context.sweptSessionHigh=m_sessionContext.sweptHigh;
      m_context.sweptSessionLow=m_sessionContext.sweptLow;
      m_context.flowReady=m_orderFlow.ready;
      m_context.flowPressure=m_orderFlow.pressure;
      m_context.relativeTickVolume=m_orderFlow.relativeVolume;
      m_context.elliottReady=m_elliott.ready;
      if(m_elliott.ready && m_elliott.count>0)
         m_context.elliottLastType=m_elliott.points[m_elliott.count-1].type;
      m_context.ictStage=CQSMCICTSetupModel::StageName(m_ict.stage);
      m_context.ictSummary=m_ict.explanation;
      m_context.ictCandidate=m_ict.candidate;
      m_context.ictDirection=m_ict.direction;
      m_context.ictConfluence=m_ict.confluenceScore;
      m_context.orderFlowSummary=(m_orderFlow.ready?
                                 StringFormat("%s RVOL %.2f pressure %.2f (proxy)",
                                              m_orderFlow.label,m_orderFlow.relativeVolume,
                                              m_orderFlow.pressure):m_orderFlow.diagnostic);
      m_context.elliottSummary=m_elliott.note;

      //--- zones ------------------------------------------------------
      m_zones.Build(snap, m_structure, slot, lookback, tolerancePrice, atr);
      CQSMCBreakOrderBlockModel::Evaluate(snap,slot,m_structure,m_zones,right,
                                          lookback,0.60,m_alternate);
      m_context.alternateStage=m_alternate.stage;
      m_context.alternateSummary=m_alternate.explanation;
      m_context.alternateCandidate=m_alternate.candidate;
      m_context.alternateDirection=m_alternate.direction;
      m_context.alternateBreakLevel=m_alternate.breakLevel;
      m_context.alternateObTop=m_alternate.orderBlock.top;
      m_context.alternateObBottom=m_alternate.orderBlock.bottom;
      m_context.alternateConfluence=(m_alternate.candidate?
                                     MathMin(80.0,55.0+10.0*m_alternate.displacementAtr):0.0);
      m_context.zoneCount = m_zones.Count();

      for(int z = 0; z < m_zones.Count(); z++)
      {
         SQSMCZone zone;
         if(!m_zones.Get(z, zone)) continue;
         double score = CQSMCZoneScorer::Score(zone, snap, m_context.bias, price, atr);
         m_zones.ApplyScore(z, score);   // cached copy refresh
      }

      //--- candidate zone on the bias side ----------------------------
      SQSMCZone candidate;
      double distance = 0.0;
      bool haveZone = false;

      if(m_context.bias == QSMC_BIAS_BULLISH)
         haveZone = m_zones.NearestDemand(price, candidate, distance);
      else if(m_context.bias == QSMC_BIAS_BEARISH)
         haveZone = m_zones.NearestSupply(price, candidate, distance);

      if(haveZone)
      {
         m_context.hasZone      = true;
         m_context.zone         = candidate;
         m_context.zoneDistance = distance;
         m_context.zoneScore    = CQSMCZoneScorer::Score(candidate, snap,
                                                         m_context.bias, price, atr);

         //--- reaction at the candidate zone --------------------------
         SQSMCReactionResult reaction;
         if(CQSMCReaction::Evaluate(snap, slot, candidate, reaction))
         {
            m_context.reactionOk    = true;
            m_context.reactionDir   = reaction.direction;
            m_context.reactionScore = reaction.score;
            m_context.pattern       = reaction.pattern;
            m_context.reactionNote  = reaction.reason;
         }
         else
         {
            m_context.reactionNote = reaction.reason;
         }
      }

      //--- break of structure -----------------------------------------
      SQSMCBreakResult brk;
      if(CQSMCBreakDetector::Detect(snap, m_structure, slot, atr, 1.0, brk))
      {
         m_context.breakDetected     = true;
         m_context.breakDir          = brk.direction;
         m_context.breakLevel        = brk.level;
         m_context.breakDisplacement = brk.displacement;
      }

      //--- liquidity ---------------------------------------------------
      m_liquidity.Detect(snap, m_structure, slot, lookback, tolerancePrice);
      SQSMCLevel swept;
      if(m_liquidity.RecentSweep(true, swept))
      {
         m_context.sweepDetected = true;
         m_context.sweepUpper    = true;
         m_context.sweepLevel    = swept.price;
      }
      else if(m_liquidity.RecentSweep(false, swept))
      {
         m_context.sweepDetected = true;
         m_context.sweepUpper    = false;
         m_context.sweepLevel    = swept.price;
      }

      //--- value context is preserved across scans ---------------------
      m_context.aboveValue = (m_svpReady && m_poc > 0.0 && price > m_vah);
      m_context.belowValue = (m_svpReady && m_poc > 0.0 && price < m_val);

      m_context.valid = true;
      m_context.summary = StringFormat("bias=%s htf=%s score=%.2f swings=%d zones=%d atr=%.5f ict=%s alt=%s%s",
                                       QSMC_BiasToString(m_context.bias),
                                       QSMC_BiasToString(m_context.htfBias),
                                       m_context.biasScore,
                                       m_context.swingCount,
                                       m_context.zoneCount,
                                       m_context.atr,m_context.ictStage,m_context.alternateStage,
                                       (m_context.reactionOk ? " reaction="+
                                        QSMC_DirectionToString(m_context.reactionDir) : ""));
      m_scanCount++;
      return true;
   }

   void ContextCopy(SQSMCScanContext &out) const { out = m_context; }

   string Describe() const
   {
      return StringFormat("scans=%d %s | %s | %s",
                          m_scanCount,
                          m_structure.Describe(),
                          m_zones.Describe(),
                          m_liquidity.Describe());
   }
};

#endif // QSMC_SCANNERS_MQH
