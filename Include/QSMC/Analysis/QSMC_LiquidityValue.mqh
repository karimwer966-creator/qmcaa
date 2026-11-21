//+------------------------------------------------------------------+
//|                                          QSMC_LiquidityValue.mqh |
//|  Liquidity map: equal highs/lows (resting liquidity), swing          |
//|  extremes and the range high/low.  Sweep detection is explicit:      |
//|  a wick beyond the level that closes back inside.                    |
//+------------------------------------------------------------------+
#ifndef QSMC_LIQUIDITYVALUE_MQH
#define QSMC_LIQUIDITYVALUE_MQH

#include "../Core/QSMC_Constants.mqh"
#include "../Core/QSMC_Types.mqh"
#include "../Data/QSMC_MarketSnapshot.mqh"
#include "QSMC_Structure.mqh"

enum ENUM_QSMC_LEVEL_TYPE
{
   QSMC_LEVEL_EQUAL_HIGH = 0,
   QSMC_LEVEL_EQUAL_LOW  = 1,
   QSMC_LEVEL_SWING_HIGH = 2,
   QSMC_LEVEL_SWING_LOW  = 3,
   QSMC_LEVEL_RANGE_HIGH = 4,
   QSMC_LEVEL_RANGE_LOW  = 5,
   QSMC_LEVEL_POC        = 6,
   QSMC_LEVEL_VAH        = 7,
   QSMC_LEVEL_VAL        = 8,
   QSMC_LEVEL_PROFILE_HIGH = 9,
   QSMC_LEVEL_PROFILE_LOW  = 10
};

struct SQSMCLevel
{
   double              price;
   ENUM_QSMC_LEVEL_TYPE type;
   int                 touches;
   bool                swept;
   datetime            lastTouch;
   double              strength;

   void Reset()
   {
      price     = 0.0;
      type      = QSMC_LEVEL_SWING_HIGH;
      touches   = 0;
      swept     = false;
      lastTouch = 0;
      strength  = 0.0;
   }

   bool IsUpper() const
   {
      return (type == QSMC_LEVEL_EQUAL_HIGH || type == QSMC_LEVEL_SWING_HIGH ||
              type == QSMC_LEVEL_RANGE_HIGH || type == QSMC_LEVEL_VAH ||
              type == QSMC_LEVEL_PROFILE_HIGH);
   }
   bool IsLower() const
   {
      return (type == QSMC_LEVEL_EQUAL_LOW || type == QSMC_LEVEL_SWING_LOW ||
              type == QSMC_LEVEL_RANGE_LOW || type == QSMC_LEVEL_VAL ||
              type == QSMC_LEVEL_PROFILE_LOW);
   }

   string Name() const
   {
      switch(type)
      {
         case QSMC_LEVEL_EQUAL_HIGH: return "equal high";
         case QSMC_LEVEL_EQUAL_LOW:  return "equal low";
         case QSMC_LEVEL_SWING_HIGH: return "swing high";
         case QSMC_LEVEL_SWING_LOW:  return "swing low";
         case QSMC_LEVEL_RANGE_HIGH: return "range high";
         case QSMC_LEVEL_RANGE_LOW:  return "range low";
         case QSMC_LEVEL_POC:        return "profile POC";
         case QSMC_LEVEL_VAH:        return "value area high";
         case QSMC_LEVEL_VAL:        return "value area low";
         case QSMC_LEVEL_PROFILE_HIGH:return "profile high";
         case QSMC_LEVEL_PROFILE_LOW: return "profile low";
      }
      return "level";
   }
};

class CQSMCLiquidityValue
{
private:
   SQSMCLevel m_levels[QSMC_MAX_LEVELS];
   int        m_count;
   int        m_lookback;

   int FindNear(const double price, const double tolerance) const
   {
      for(int i = 0; i < m_count; i++)
         if(MathAbs(m_levels[i].price - price) <= tolerance) return i;
      return QSMC_INVALID_INDEX;
   }

   void Add(const SQSMCLevel &level)
   {
      int existing = FindNear(level.price, level.price * 0.00005);
      if(existing != QSMC_INVALID_INDEX)
      {
         m_levels[existing].touches++;
         if(m_levels[existing].type != level.type &&
            (level.type == QSMC_LEVEL_EQUAL_HIGH || level.type == QSMC_LEVEL_EQUAL_LOW))
            m_levels[existing].type = level.type;
         m_levels[existing].strength = MathMin(1.0, m_levels[existing].strength + 0.2);
         return;
      }
      if(m_count >= QSMC_MAX_LEVELS) return;
      m_levels[m_count] = level;
      m_count++;
   }

public:
   CQSMCLiquidityValue() { Reset(); }

   void Reset()
   {
      m_count    = 0;
      m_lookback = 0;
      for(int i = 0; i < QSMC_MAX_LEVELS; i++) m_levels[i].Reset();
   }

   int Count() const { return m_count; }
   int Lookback() const { return m_lookback; }

   bool Get(const int index, SQSMCLevel &out) const
   {
      if(index < 0 || index >= m_count) return false;
      out = m_levels[index];
      return true;
   }

   //+---------------------------------------------------------------+
   //| Build the liquidity map.                                        |
   //+---------------------------------------------------------------+
   bool Detect(const CQSMCMarketSnapshot &snap,
               const CQSMCStructure &structure,
               const int slot,
               const int lookback,
               const double tolerancePrice)
   {
      Reset();
      if(lookback < 20 || tolerancePrice <= 0.0) return false;

      m_lookback = lookback;
      const int newest = snap.NewestIndex();

      //--- equal highs / lows from clustered swings -------------------
      SQSMCStructurePoint a, b;
      for(int i = 0; i < structure.Count(); i++)
      {
         if(!structure.Get(i, a)) continue;
         if(a.shift > lookback) continue;

         bool paired = false;
         for(int j = i + 1; j < structure.Count(); j++)
         {
            if(!structure.Get(j, b)) continue;
            if(b.type != a.type) continue;
            if(MathAbs(a.price - b.price) > tolerancePrice) continue;

            SQSMCLevel level;
            level.Reset();
            level.price   = (a.price + b.price) * 0.5;
            level.type    = (a.type == QSMC_SWING_HIGH ? QSMC_LEVEL_EQUAL_HIGH
                                                       : QSMC_LEVEL_EQUAL_LOW);
            level.touches = 2;
            level.lastTouch = MathMax(a.time, b.time);
            level.strength  = 0.6;
            Add(level);
            paired = true;
            break;
         }

         //--- record the swing itself as a reference level ------------
         SQSMCLevel swing;
         swing.Reset();
         swing.price     = a.price;
         swing.type      = (a.type == QSMC_SWING_HIGH ? QSMC_LEVEL_SWING_HIGH
                                                      : QSMC_LEVEL_SWING_LOW);
         swing.touches   = 1;
         swing.lastTouch = a.time;
         swing.strength  = paired ? 0.3 : 0.25;
         Add(swing);
      }

      //--- range extremes over the lookback ---------------------------
      int window = MathMin(lookback, snap.BarCount(slot) - newest);
      if(window > 5)
      {
         SQSMCLevel hi;
         hi.Reset();
         hi.price     = snap.HighestHigh(slot, newest, window);
         hi.type      = QSMC_LEVEL_RANGE_HIGH;
         hi.touches   = 1;
         hi.strength  = 0.5;
         hi.lastTouch = snap.BarTime(slot, newest);
         Add(hi);

         SQSMCLevel lo;
         lo.Reset();
         lo.price     = snap.LowestLow(slot, newest, window);
         lo.type      = QSMC_LEVEL_RANGE_LOW;
         lo.touches   = 1;
         lo.strength  = 0.5;
         lo.lastTouch = snap.BarTime(slot, newest);
         Add(lo);
      }

      //--- sweep marking ----------------------------------------------
      MarkSweeps(snap, slot, 5);
      return (m_count > 0);
   }

   void MarkSweeps(const CQSMCMarketSnapshot &snap, const int slot, const int bars)
   {
      const int newest = snap.NewestIndex();
      for(int i = 0; i < m_count; i++)
      {
         m_levels[i].swept = false;
         if(!m_levels[i].IsUpper() && !m_levels[i].IsLower()) continue;
         for(int k = newest; k < newest + bars; k++)
         {
            if(k >= snap.BarCount(slot)) break;
            if(m_levels[i].IsUpper())
            {
               if(snap.High(slot, k) > m_levels[i].price + QSMC_EPSILON &&
                  snap.Close(slot, k) < m_levels[i].price)
               {
                  m_levels[i].swept = true;
                  break;
               }
            }
            else
            {
               if(snap.Low(slot, k) < m_levels[i].price - QSMC_EPSILON &&
                  snap.Close(slot, k) > m_levels[i].price)
               {
                  m_levels[i].swept = true;
                  break;
               }
            }
         }
      }
   }

   //--- queries ------------------------------------------------------
   bool NearUpper(const double price, const double tolerance, SQSMCLevel &out) const
   {
      bool found = false;
      double best = 0.0;
      for(int i = 0; i < m_count; i++)
      {
         if(!m_levels[i].IsUpper()) continue;
         double dist = MathAbs(m_levels[i].price - price);
         if(dist > tolerance) continue;
         if(!found || dist < best) { found = true; best = dist; out = m_levels[i]; }
      }
      return found;
   }

   bool NearLower(const double price, const double tolerance, SQSMCLevel &out) const
   {
      bool found = false;
      double best = 0.0;
      for(int i = 0; i < m_count; i++)
      {
         if(!m_levels[i].IsLower()) continue;
         double dist = MathAbs(m_levels[i].price - price);
         if(dist > tolerance) continue;
         if(!found || dist < best) { found = true; best = dist; out = m_levels[i]; }
      }
      return found;
   }

   // Most recent sweep in the last `bars` bars, if any.
   bool RecentSweep(const bool upper, SQSMCLevel &out) const
   {
      for(int i = 0; i < m_count; i++)
      {
         if(m_levels[i].swept && m_levels[i].IsUpper() == upper)
         {
            out = m_levels[i];
            return true;
         }
      }
      return false;
   }

   int SweptCount() const
   {
      int n = 0;
      for(int i = 0; i < m_count; i++) if(m_levels[i].swept) n++;
      return n;
   }

   string Describe() const
   {
      return StringFormat("levels=%d swept=%d", m_count, SweptCount());
   }
};

#endif // QSMC_LIQUIDITYVALUE_MQH
