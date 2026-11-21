//+------------------------------------------------------------------+
//|                                                 QSMC_MarketData.mqh |
//|  Builds and owns the current MarketSnapshot.  The only module that  |
//|  decides *when* data is refreshed; consumers only read snapshots.   |
//+------------------------------------------------------------------+
#ifndef QSMC_MARKETDATA_MQH
#define QSMC_MARKETDATA_MQH

#include "../Core/QSMC_Constants.mqh"
#include "../Core/QSMC_Types.mqh"
#include "QSMC_DataProvider.mqh"
#include "QSMC_MarketSnapshot.mqh"
#include "QSMC_DataValidator.mqh"
#include "QSMC_TimeframeManager.mqh"

class CQSMCMarketData
{
private:
   CQSMCDataProvider*   m_provider;
   CQSMCMarketSnapshot  m_snapshot;
   string               m_symbol;
   ENUM_TIMEFRAMES      m_execTf;
   ENUM_TIMEFRAMES      m_htf;
   ENUM_TIMEFRAMES      m_ltf;
   int                  m_bars;
   bool                 m_closedOnly;
   bool                 m_initialised;
   datetime             m_lastBar[QSMC_SNAP_SLOTS];
   long                 m_refreshCount;

public:
   CQSMCMarketData()
   {
      m_provider     = NULL;
      m_symbol       = "";
      m_execTf       = PERIOD_CURRENT;
      m_htf          = PERIOD_CURRENT;
      m_ltf          = PERIOD_CURRENT;
      m_bars         = 0;
      m_closedOnly   = true;
      m_initialised  = false;
      m_refreshCount = 0;
      for(int i = 0; i < QSMC_SNAP_SLOTS; i++) m_lastBar[i] = 0;
   }

   bool Init(CQSMCDataProvider *provider,
             const string symbol,
             const ENUM_TIMEFRAMES execTf,
             const ENUM_TIMEFRAMES htf,
             const ENUM_TIMEFRAMES ltf,
             const int bars,
             const bool closedOnly)
   {
      string err;
      if(provider == NULL) return false;
      if(!CQSMCTimeframeManager::ValidateOrdering(htf, execTf, ltf, err)) return false;
      if(bars < 100) return false;

      m_provider    = provider;
      m_symbol      = symbol;
      m_execTf      = execTf;
      m_htf         = htf;
      m_ltf         = ltf;
      m_bars        = bars;
      m_closedOnly  = closedOnly;
      m_initialised = true;

      m_snapshot.SetSymbol(symbol);
      m_snapshot.SetTimeframes(execTf, htf, ltf);
      m_snapshot.SetClosedOnly(closedOnly);
      return true;
   }

   bool IsReady() const { return m_initialised; }
   long Refreshes() const { return m_refreshCount; }
   string Symbol() const { return m_symbol; }
   ENUM_TIMEFRAMES ExecTf() const { return m_execTf; }

   //+---------------------------------------------------------------+
   //| Refresh the snapshot.  All-or-nothing: on any failure the       |
   //| previous snapshot is invalidated so stale data is never used.   |
   //+---------------------------------------------------------------+
   bool Refresh(SQSMCResult &res)
   {
      res.Clear();
      if(!m_initialised || m_provider == NULL)
      {
         res.Set(QSMC_ERR_NOT_INITIALIZED, "market data not initialised");
         return false;
      }

      MqlTick tick;
      if(!m_provider.GetTick(tick))
      {
         m_snapshot.Reset();
         res.Set(QSMC_ERR_DATA_NOT_READY, "no tick available");
         return false;
      }

      MqlRates execRates[];
      MqlRates htfRates[];
      MqlRates ltfRates[];

      if(!m_provider.GetRates(m_execTf, m_bars, execRates))
      {
         m_snapshot.Reset();
         res.Set(QSMC_ERR_DATA_NOT_READY,
                 "exec bars unavailable (" + QSMC_TfToString(m_execTf) +
                 ", err " + IntegerToString(m_provider.LastError()) + ")");
         return false;
      }
      if(!m_provider.GetRates(m_htf, m_bars, htfRates))
      {
         m_snapshot.Reset();
         res.Set(QSMC_ERR_DATA_NOT_READY,
                 "htf bars unavailable (" + QSMC_TfToString(m_htf) + ")");
         return false;
      }
      if(!m_provider.GetRates(m_ltf, m_bars, ltfRates))
      {
         m_snapshot.Reset();
         res.Set(QSMC_ERR_DATA_NOT_READY,
                 "ltf bars unavailable (" + QSMC_TfToString(m_ltf) + ")");
         return false;
      }

      m_snapshot.SetSymbol(m_symbol);
      m_snapshot.SetTimeframes(m_execTf, m_htf, m_ltf);
      m_snapshot.SetClosedOnly(m_closedOnly);
      m_snapshot.SetQuote(tick.bid, tick.ask, m_provider.Point(),
                          m_provider.SpreadPoints());
      m_snapshot.SetContract(m_provider.Digits(),
                             m_provider.TickValue(),
                             m_provider.TickSize(),
                             m_provider.VolumeMin(),
                             m_provider.VolumeMax(),
                             m_provider.VolumeStep(),
                             m_provider.StopsLevel(),
                             m_provider.FreezeLevel());

      if(!m_snapshot.AttachBars(QSMC_SNAP_EXEC,
                                execRates, ArraySize(execRates)) ||
         !m_snapshot.AttachBars(QSMC_SNAP_HTF,
                                htfRates, ArraySize(htfRates)) ||
         !m_snapshot.AttachBars(QSMC_SNAP_LTF,
                                ltfRates, ArraySize(ltfRates)))
      {
         m_snapshot.Reset();
         res.Set(QSMC_ERR_DATA_INVALID, "snapshot attach failed");
         return false;
      }

      m_snapshot.SetCaptured(TimeCurrent());

      string err;
      if(!CQSMCDataValidator::ValidateSnapshot(m_snapshot, err))
      {
         m_snapshot.Reset();
         res.Set(QSMC_ERR_DATA_INVALID, err);
         return false;
      }

      m_refreshCount++;
      res.Set(QSMC_OK, "snapshot refreshed");
      return true;
   }

   const CQSMCMarketSnapshot* Snapshot() const { return &m_snapshot; }

   // Copy the current snapshot into caller-owned storage. The copy avoids
   // exposing a mutable pointer across layer boundaries and lets consumers
   // use ordinary object references.
   bool CopySnapshot(CQSMCMarketSnapshot &out) const
   {
      if(!m_snapshot.IsUsable()) return false;
      out.Reset();
      out.SetSymbol(m_snapshot.Symbol());
      out.SetTimeframes(m_snapshot.Tf(QSMC_SNAP_EXEC),m_snapshot.Tf(QSMC_SNAP_HTF),
                        m_snapshot.Tf(QSMC_SNAP_LTF));
      out.SetClosedOnly(m_snapshot.ClosedOnly());
      out.SetQuote(m_snapshot.Bid(),m_snapshot.Ask(),m_snapshot.Point(),m_snapshot.SpreadPoints());
      out.SetContract(m_snapshot.Digits(),m_snapshot.TickValue(),m_snapshot.TickSize(),
                      m_snapshot.VolumeMin(),m_snapshot.VolumeMax(),m_snapshot.VolumeStep(),
                      m_snapshot.StopsLevel(),m_snapshot.FreezeLevel());
      for(int slot=0;slot<QSMC_SNAP_SLOTS;slot++)
      {
         int count=m_snapshot.BarCount(slot);
         MqlRates rates[];
         if(count<=0 || ArrayResize(rates,count)!=count)return false;
         for(int i=0;i<count;i++)
            if(!m_snapshot.Bar(slot,i,rates[i]))return false;
         if(!out.AttachBars(slot,rates,count))return false;
      }
      out.SetCaptured(m_snapshot.Captured());
      return true;
   }

   bool HasData() const { return (m_snapshot.IsUsable()); }

   //--- new-bar detection per slot -----------------------------------
   bool IsNewBar(const ENUM_TIMEFRAMES tf)
   {
      int slot = -1;
      if(tf == m_execTf) slot = QSMC_SNAP_EXEC;
      else if(tf == m_htf) slot = QSMC_SNAP_HTF;
      else if(tf == m_ltf) slot = QSMC_SNAP_LTF;
      if(slot < 0) return false;

      datetime barTime = (datetime)SeriesInfoInteger(m_symbol, tf, SERIES_LASTBAR_DATE);
      if(barTime == 0 || barTime == m_lastBar[slot]) return false;
      m_lastBar[slot] = barTime;
      return true;
   }

   bool IsExecNewBar() { return IsNewBar(m_execTf); }

   string Describe() const
   {
      return m_snapshot.Describe() + " refreshes=" + IntegerToString(m_refreshCount);
   }
};

#endif // QSMC_MARKETDATA_MQH
