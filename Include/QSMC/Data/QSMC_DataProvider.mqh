//+------------------------------------------------------------------+
//|                                              QSMC_DataProvider.mqh |
//|  Thin, retrying wrapper over CopyRates / SymbolInfo.  This is the   |
//|  only place allowed to talk to the terminal's history API; every    |
//|  consumer receives plain data through MarketSnapshot.               |
//+------------------------------------------------------------------+
#ifndef QSMC_DATAPROVIDER_MQH
#define QSMC_DATAPROVIDER_MQH

#include "../Core/QSMC_Constants.mqh"
#include "../Core/QSMC_Types.mqh"

class CQSMCDataProvider
{
private:
   string m_symbol;
   bool   m_initialised;
   int    m_lastCopied;
   int    m_lastError;
   long   m_fetchCount;

public:
   CQSMCDataProvider()
   {
      m_symbol      = "";
      m_initialised = false;
      m_lastCopied  = 0;
      m_lastError   = 0;
      m_fetchCount  = 0;
   }

   bool Init(const string symbol)
   {
      if(StringLen(symbol) == 0) return false;
      if(SymbolInfoDouble(symbol, SYMBOL_POINT) <= 0.0) return false;
      if(SymbolInfoInteger(symbol, SYMBOL_SELECT) == 0 && !SymbolSelect(symbol, true))
         return false;

      m_symbol      = symbol;
      m_initialised = true;
      return true;
   }

   string Symbol()     const { return m_symbol; }
   bool   IsReady()    const { return m_initialised; }
   int    LastCopied() const { return m_lastCopied; }
   int    LastError()  const { return m_lastError; }
   long   FetchCount() const { return m_fetchCount; }

   //+---------------------------------------------------------------+
   //| Copy up to `count` bars, retrying transient history errors.     |
   //| Result array is forced to series order (index 0 = newest).      |
   //+---------------------------------------------------------------+
   bool GetRates(const ENUM_TIMEFRAMES tf, const int count,
                 MqlRates &rates[], const int attempts = 3)
   {
      m_lastCopied = 0;
      m_lastError  = 0;
      if(!m_initialised || count <= 0 || tf == PERIOD_CURRENT) return false;

      for(int attempt = 0; attempt < attempts; attempt++)
      {
         ResetLastError();
         int copied = CopyRates(m_symbol, tf, 0, count, rates);
         if(copied > 0)
         {
            ArraySetAsSeries(rates, true);
            m_lastCopied = copied;
            m_fetchCount++;
            return true;
         }

         m_lastError = GetLastError();
         if(m_lastError != ERR_HISTORY_WILL_UPDATED &&
            m_lastError != ERR_NO_HISTORY_DATA && m_lastError != ERR_HISTORY_TIMEOUT)
            break;

         Sleep(50 * (attempt + 1));
      }
      return false;
   }

   bool GetRatesRange(const ENUM_TIMEFRAMES tf, const datetime from,
                      const int count, MqlRates &rates[])
   {
      m_lastCopied = 0;
      if(!m_initialised || count <= 0 || from == 0) return false;

      ResetLastError();
      int copied = CopyRates(m_symbol, tf, from, count, rates);
      if(copied > 0)
      {
         ArraySetAsSeries(rates, true);
         m_lastCopied = copied;
         m_fetchCount++;
         return true;
      }
      m_lastError = GetLastError();
      return false;
   }

   bool GetTick(MqlTick &tick)
   {
      if(!m_initialised) return false;
      ResetLastError();
      if(!SymbolInfoTick(m_symbol, tick)) return false;
      return (tick.ask > 0.0 && tick.bid > 0.0);
   }

   //--- symbol metadata ---------------------------------------------
   double Point()      const { return SymbolInfoDouble(m_symbol, SYMBOL_POINT); }
   int    Digits()     const { return (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS); }
   double Bid()        const { return SymbolInfoDouble(m_symbol, SYMBOL_BID); }
   double Ask()        const { return SymbolInfoDouble(m_symbol, SYMBOL_ASK); }
   double TickValue()  const { return SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE); }
   double TickSize()   const { return SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE); }
   double VolumeMin()  const { return SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN); }
   double VolumeMax()  const { return SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX); }
   double VolumeStep() const { return SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP); }
   long   StopsLevel() const { return SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL); }
   long   FreezeLevel()const { return SymbolInfoInteger(m_symbol, SYMBOL_TRADE_FREEZE_LEVEL); }

   long SpreadPoints() const
   {
      double point = Point();
      if(point <= 0.0) return 0;
      double ask = Ask();
      double bid = Bid();
      if(ask > 0.0 && bid > 0.0 && ask >= bid)
         return (long)MathRound((ask - bid) / point);
      return (long)SymbolInfoInteger(m_symbol, SYMBOL_SPREAD);
   }

   // Number of bars the terminal currently reports for a timeframe.
   int AvailableBars(const ENUM_TIMEFRAMES tf) const
   {
      if(!m_initialised) return 0;
      return (int)SeriesInfoInteger(m_symbol, tf, SERIES_BARS_COUNT);
   }

   datetime LastBarTime(const ENUM_TIMEFRAMES tf) const
   {
      if(!m_initialised) return 0;
      return (datetime)SeriesInfoInteger(m_symbol, tf, SERIES_LASTBAR_DATE);
   }

   bool IsNewBar(const ENUM_TIMEFRAMES tf, datetime &lastSeen)
   {
      datetime barTime = LastBarTime(tf);
      if(barTime == 0 || barTime == lastSeen) return false;
      lastSeen = barTime;
      return true;
   }

   string Describe() const
   {
      return StringFormat("provider %s ready=%s copied=%d lastError=%d",
                          m_symbol, (m_initialised ? "yes" : "no"),
                          m_lastCopied, m_lastError);
   }
};

#endif // QSMC_DATAPROVIDER_MQH
