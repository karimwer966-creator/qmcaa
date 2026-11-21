//+------------------------------------------------------------------+
//|                                     QSMC_OpportunityAudit.mqh |
//| Append-only per-bar opportunity decisions for reproducible review. |
//| Written under MQL5/Files/QSMC; audit I/O never changes decisions.  |
//+------------------------------------------------------------------+
#ifndef QSMC_OPPORTUNITYAUDIT_MQH
#define QSMC_OPPORTUNITYAUDIT_MQH
#include "../Core/QSMC_Constants.mqh"
#include "../Core/QSMC_Types.mqh"

class CQSMCOpportunityAuditLog
{
private:
   string m_file;
   string m_error;
   bool m_ready;

public:
   CQSMCOpportunityAuditLog(){m_file="";m_error="";m_ready=false;}

   bool Init(const ulong magic)
   {
      FolderCreate("QSMC");
      m_file=QSMC_FILE_FOLDER+"opportunities_"+IntegerToString((long)magic)+".csv";
      m_error="";
      int h=FileOpen(m_file,FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE,';');
      if(h==INVALID_HANDLE)
      {m_ready=false;m_error="audit file open failed: "+IntegerToString(GetLastError());return false;}
      if(FileSize(h)==0)
      {
         FileWrite(h,"time","symbol","timeframe","model","status","stage","direction",
                   "score_points","close","atr","htf_bias","session","swept_high","swept_low",
                   "tick_volume_rvol","tick_volume_pressure","profile_poc","profile_vah","profile_val",
                   "elliott_hint","reason");
         FileFlush(h);
      }
      FileClose(h);m_ready=true;return true;
   }

   bool Append(const datetime barTime,const string symbol,const ENUM_TIMEFRAMES timeframe,
               const string model,const string status,const string stage,
               const ENUM_QSMC_DIRECTION direction,const double scorePoints,
               const double close,const double atr,const ENUM_QSMC_BIAS htfBias,
               const string session,const bool sweptHigh,const bool sweptLow,
               const double relativeVolume,const double flowPressure,
               const double poc,const double vah,const double val,
               const int elliottHint,const string reason)
   {
      if(!m_ready)return false;
      int h=FileOpen(m_file,FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE,';');
      if(h==INVALID_HANDLE)
      {m_error="audit append open failed: "+IntegerToString(GetLastError());return false;}
      FileSeek(h,0,SEEK_END);
      FileWrite(h,TimeToString(barTime,TIME_DATE|TIME_MINUTES),symbol,(int)timeframe,
                model,status,stage,QSMC_DirectionToString(direction),
                DoubleToString(scorePoints,2),DoubleToString(close,8),DoubleToString(atr,8),
                QSMC_BiasToString(htfBias),session,(sweptHigh?1:0),(sweptLow?1:0),
                DoubleToString(relativeVolume,4),DoubleToString(flowPressure,4),
                DoubleToString(poc,8),DoubleToString(vah,8),DoubleToString(val,8),
                elliottHint,reason);
      FileFlush(h);FileClose(h);return true;
   }

   bool Ready() const{return m_ready;}
   string FileName() const{return m_file;}
   string LastError() const{return m_error;}
};
#endif // QSMC_OPPORTUNITYAUDIT_MQH
