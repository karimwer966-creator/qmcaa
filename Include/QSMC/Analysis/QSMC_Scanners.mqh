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

struct SQSMCScanContext
{
   bool                valid;
   ENUM_QSMC_BIAS      bias;
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

   string              summary;

   void Reset()
   {
      valid              = false;
      bias               = QSMC_BIAS_NEUTRAL;
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
   bool                 m_svpReady;
   double               m_poc;
   double               m_vah;
   double               m_val;

public:
   CQSMCScanners()
   {
      m_scanCount = 0;
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
      m_context.Reset();
   }

   int                        Scans()     const { return m_scanCount; }
   int                        ZoneCount() const { return m_zones.Count(); }
   bool GetZone(const int index,SQSMCZone &out) const { return m_zones.Get(index,out); }

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
      m_context.biasScore      = m_bias.score;
      m_context.biasConfidence = m_bias.confidence;

      //--- zones ------------------------------------------------------
      m_zones.Build(snap, m_structure, slot, lookback, tolerancePrice, atr);
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
      m_context.summary = StringFormat("bias=%s(%.2f) swings=%d zones=%d atr=%.5f%s",
                                       QSMC_BiasToString(m_context.bias),
                                       m_context.biasScore,
                                       m_context.swingCount,
                                       m_context.zoneCount,
                                       m_context.atr,
                                       (m_context.reactionOk ? " reaction=" +
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
