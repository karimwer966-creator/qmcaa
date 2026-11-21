//+------------------------------------------------------------------+
//|                                            QSMC_ElliottGuide.mqh |
//| Heuristic pivot labels plus a small optional confluence hint. It    |
//| does not validate Elliott rules, degree or alternate counts; the    |
//| hint is never a standalone setup or direction signal.               |
//+------------------------------------------------------------------+
#ifndef QSMC_ELLIOTTGUIDE_MQH
#define QSMC_ELLIOTTGUIDE_MQH
#include "QSMC_Structure.mqh"

#define QSMC_ELLIOTT_LABELS 8
struct SQSMCElliottPoint
{
   datetime time;
   double price;
   int type;
   int shift;
   string label;
};
struct SQSMCElliottGuideResult
{
   bool ready;
   int count;
   string note;
   SQSMCElliottPoint points[QSMC_ELLIOTT_LABELS];
   void Reset()
   {
      ready=false;count=0;note="";
      for(int i=0;i<QSMC_ELLIOTT_LABELS;i++)
      {points[i].time=0;points[i].price=0.0;points[i].type=QSMC_SWING_NONE;
       points[i].shift=0;points[i].label="";}
   }
};

class CQSMCElliottGuide
{
private:
   static string LabelAt(const int index)
   {
      switch(index)
      {
         case 0:return "1";case 1:return "2";case 2:return "3";case 3:return "4";
         case 4:return "5";case 5:return "A";case 6:return "B";case 7:return "C";
      }
      return "?";
   }
public:
   static bool Build(const CQSMCStructure &structure,SQSMCElliottGuideResult &out)
   {
      out.Reset();
      SQSMCStructurePoint picked[QSMC_ELLIOTT_LABELS];
      int count=0;
      for(int i=0;i<structure.Count();i++)
      {
         SQSMCStructurePoint p;
         if(!structure.Get(i,p))continue;
         if(count==0){picked[count++]=p;continue;}
         if(p.type==picked[count-1].type)
         {
            // When consecutive same-type fractals occur, retain the more
            // extreme pivot as one consolidated swing in this guide only.
            bool replace=(p.type==QSMC_SWING_HIGH?p.price>picked[count-1].price:
                                                    p.price<picked[count-1].price);
            if(replace)picked[count-1]=p;
            continue;
         }
         if(count<QSMC_ELLIOTT_LABELS)picked[count++]=p;
         else break;
      }
      if(count<5)
      {out.note="Elliott guide: need at least five alternating pivots";return false;}

      out.count=count;
      for(int i=0;i<count;i++)
      {
         int source=count-1-i; // publish oldest-to-newest
         out.points[i].time=picked[source].time;
         out.points[i].price=picked[source].price;
         out.points[i].type=picked[source].type;
         out.points[i].shift=picked[source].shift;
         out.points[i].label=LabelAt(i);
      }
      out.ready=true;
      out.note="heuristic pivot labels; Elliott rules/degree/alternates unvalidated";
      return true;
   }

   // Very small latest-pivot confluence hint only. It is not a wave count
   // validation and cannot create a candidate without the strategy setup.
   static int AlignmentHint(const SQSMCElliottGuideResult &guide,
                            const ENUM_QSMC_DIRECTION direction)
   {
      if(!guide.ready || guide.count<2)return 0;
      int last=guide.points[guide.count-1].type;
      if(direction==QSMC_DIR_BUY)
         return(last==QSMC_SWING_LOW?1:(last==QSMC_SWING_HIGH?-1:0));
      if(direction==QSMC_DIR_SELL)
         return(last==QSMC_SWING_HIGH?1:(last==QSMC_SWING_LOW?-1:0));
      return 0;
   }
};
#endif // QSMC_ELLIOTTGUIDE_MQH
