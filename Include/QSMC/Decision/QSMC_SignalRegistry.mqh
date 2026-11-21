//+------------------------------------------------------------------+
//|                                          QSMC_SignalRegistry.mqh |
//|  Fixed-capacity candidate and rejection registry for deterministic  |
//|  decision audits.                                                   |
//+------------------------------------------------------------------+
#ifndef QSMC_SIGNALREGISTRY_MQH
#define QSMC_SIGNALREGISTRY_MQH
#include "../Core/QSMC_Constants.mqh"
#include "../Core/QSMC_Types.mqh"

struct SQSMCCandidate
{
   ENUM_QSMC_DIRECTION direction;
   double score;
   string source;
   string evidence;
};

class CQSMCSignalRegistry
{
private:
   SQSMCCandidate m_items[QSMC_MAX_SIGNALS];
   int m_count;
public:
   CQSMCSignalRegistry() { Reset(); }
   void Reset()
   {
      m_count=0;
      for(int i=0;i<QSMC_MAX_SIGNALS;i++)
      {
         m_items[i].direction=QSMC_DIR_NONE;
         m_items[i].score=0.0;
         m_items[i].source="";
         m_items[i].evidence="";
      }
   }
   int Count() const { return m_count; }
   bool Add(const ENUM_QSMC_DIRECTION direction,const double score,
            const string source,const string evidence)
   {
      if(direction==QSMC_DIR_NONE || score<0.0 || score>1.0 || m_count>=QSMC_MAX_SIGNALS) return false;
      m_items[m_count].direction=direction;
      m_items[m_count].score=score;
      m_items[m_count].source=source;
      m_items[m_count].evidence=evidence;
      m_count++;
      return true;
   }
   bool Get(const int index,SQSMCCandidate &out) const
   {
      if(index<0 || index>=m_count) return false;
      out=m_items[index];
      return true;
   }
};
#endif // QSMC_SIGNALREGISTRY_MQH
