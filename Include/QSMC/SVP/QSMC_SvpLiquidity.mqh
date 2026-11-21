//+------------------------------------------------------------------+
//|                                             QSMC_SvpLiquidity.mqh |
//|  Exposes POC / VAH / VAL / profile extremes as liquidity levels so   |
//|  the decision layer can reason about them uniformly with swing       |
//|  levels.  These are *reference* levels, not resting orders.          |
//+------------------------------------------------------------------+
#ifndef QSMC_SVPLIQUIDITY_MQH
#define QSMC_SVPLIQUIDITY_MQH

#include "../Core/QSMC_Constants.mqh"
#include "../Core/QSMC_Types.mqh"
#include "../Analysis/QSMC_LiquidityValue.mqh"
#include "QSMC_SvpCore.mqh"

class CQSMCSvpLiquidity
{
private:
   SQSMCLevel m_levels[QSMC_MAX_LEVELS];
   int        m_count;

   void Add(const double price, const ENUM_QSMC_LEVEL_TYPE type,
            const double strength)
   {
      if(price <= 0.0 || m_count >= QSMC_MAX_LEVELS) return;
      m_levels[m_count].Reset();
      m_levels[m_count].price     = price;
      m_levels[m_count].type      = type;
      m_levels[m_count].touches   = 1;
      m_levels[m_count].strength  = (strength < 0.0 ? 0.0 : (strength > 1.0 ? 1.0 : strength));
      m_levels[m_count].lastTouch = 0;
      m_levels[m_count].swept     = false;
      m_count++;
   }

public:
   CQSMCSvpLiquidity() { Reset(); }

   void Reset()
   {
      m_count = 0;
      for(int i = 0; i < QSMC_MAX_LEVELS; i++) m_levels[i].Reset();
   }

   int Count() const { return m_count; }

   bool Get(const int index, SQSMCLevel &out) const
   {
      if(index < 0 || index >= m_count) return false;
      out = m_levels[index];
      return true;
   }

   bool Build(const CQSMCSvpCore &core, const double price)
   {
      Reset();
      if(!core.IsReady()) return false;

      // POC is the highest-conviction reference inside the profile.
      double pocStrength = 0.8;
      SQSMCProfileBin bin;
      for(int b = 0; b < core.BinCount(); b++)
      {
         if(!core.GetBin(b, bin)) continue;
         if(bin.mid >= core.Poc() - core.BinSize() * 0.5 &&
            bin.mid <= core.Poc() + core.BinSize() * 0.5)
         {
            pocStrength = MathMin(1.0, 0.5 + bin.pct / 20.0);
            break;
         }
      }

      Add(core.Poc(), QSMC_LEVEL_POC, pocStrength);
      Add(core.Vah(), QSMC_LEVEL_VAH, 0.6);
      Add(core.Val(), QSMC_LEVEL_VAL, 0.6);
      Add(core.ProfileHigh(), QSMC_LEVEL_PROFILE_HIGH, 0.4);
      Add(core.ProfileLow(),  QSMC_LEVEL_PROFILE_LOW, 0.4);
      return (m_count > 0);
   }

   bool NearestAbove(const double price, SQSMCLevel &out, double &distance) const
   {
      bool found = false;
      distance = 0.0;
      for(int i = 0; i < m_count; i++)
      {
         if(m_levels[i].price <= price) continue;
         double dist = m_levels[i].price - price;
         if(!found || dist < distance) { found = true; distance = dist; out = m_levels[i]; }
      }
      return found;
   }

   bool NearestBelow(const double price, SQSMCLevel &out, double &distance) const
   {
      bool found = false;
      distance = 0.0;
      for(int i = 0; i < m_count; i++)
      {
         if(m_levels[i].price >= price) continue;
         double dist = price - m_levels[i].price;
         if(!found || dist < distance) { found = true; distance = dist; out = m_levels[i]; }
      }
      return found;
   }

   string Describe() const
   {
      return StringFormat("svp levels=%d", m_count);
   }
};

#endif // QSMC_SVPLIQUIDITY_MQH
