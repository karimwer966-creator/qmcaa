//+------------------------------------------------------------------+
//|                                            QSMC_HealthMonitor.mqh |
//|  Read-only environment probe: terminal/account/symbol permissions, |
//|  quote freshness and spread sanity.  Fails CLOSED: any missing     |
//|  answer is treated as "not permitted".                             |
//+------------------------------------------------------------------+
#ifndef QSMC_HEALTHMONITOR_MQH
#define QSMC_HEALTHMONITOR_MQH

#include "../Core/QSMC_Constants.mqh"
#include "../Core/QSMC_Types.mqh"

enum ENUM_QSMC_HEALTH
{
   QSMC_HEALTH_UNKNOWN  = 0,
   QSMC_HEALTH_HEALTHY  = 1,
   QSMC_HEALTH_DEGRADED = 2,
   QSMC_HEALTH_BLOCKED  = 3
};

class CQSMCHealthMonitor
{
private:
   string  m_symbol;
   int     m_maxSpreadPoints;
   int     m_staleSeconds;
   bool    m_initialised;

   ENUM_QSMC_HEALTH m_level;
   bool    m_connected;
   bool    m_terminalTradeAllowed;
   bool    m_mqlTradeAllowed;
   bool    m_accountTradeAllowed;
   bool    m_accountExpertAllowed;
   bool    m_symbolAvailable;
   bool    m_symbolTradeEnabled;
   bool    m_quotesFresh;
   bool    m_spreadOk;
   long    m_spreadPoints;
   int     m_quoteAgeSeconds;
   string  m_reason;
   datetime m_checked;

   void ResetFlags()
   {
      m_connected           = false;
      m_terminalTradeAllowed= false;
      m_mqlTradeAllowed     = false;
      m_accountTradeAllowed = false;
      m_accountExpertAllowed= false;
      m_symbolAvailable     = false;
      m_symbolTradeEnabled  = false;
      m_quotesFresh         = false;
      m_spreadOk            = false;
      m_spreadPoints        = 0;
      m_quoteAgeSeconds     = 0;
      m_reason              = "";
   }

public:
   CQSMCHealthMonitor()
   {
      m_symbol           = "";
      m_maxSpreadPoints  = 0;
      m_staleSeconds     = 60;
      m_initialised      = false;
      m_level            = QSMC_HEALTH_UNKNOWN;
      m_checked          = 0;
      ResetFlags();
   }

   bool Init(const string symbol, const int maxSpreadPoints, const int staleSeconds)
   {
      if(StringLen(symbol) == 0) return false;
      m_symbol          = symbol;
      m_maxSpreadPoints = (maxSpreadPoints > 0 ? maxSpreadPoints : 0);
      m_staleSeconds    = (staleSeconds > 0 ? staleSeconds : 60);
      m_initialised     = true;
      m_level           = QSMC_HEALTH_UNKNOWN;
      return true;
   }

   //+---------------------------------------------------------------+
   //| Probe the environment.  Never throws, never trades.            |
   //+---------------------------------------------------------------+
   ENUM_QSMC_HEALTH Update()
   {
      ResetFlags();
      if(!m_initialised)
      {
         m_level  = QSMC_HEALTH_BLOCKED;
         m_reason = "health monitor not initialised";
         return m_level;
      }

      m_checked = TimeCurrent();

      //--- terminal ---------------------------------------------------
      m_connected            = (TerminalInfoInteger(TERMINAL_CONNECTED) != 0);
      m_terminalTradeAllowed = (TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) != 0);
      m_mqlTradeAllowed      = (MQLInfoInteger(MQL_TRADE_ALLOWED) != 0);

      //--- account ----------------------------------------------------
      m_accountTradeAllowed  = (AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) != 0);
      m_accountExpertAllowed = (AccountInfoInteger(ACCOUNT_TRADE_EXPERT) != 0);

      //--- symbol -----------------------------------------------------
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      m_symbolAvailable    = (point > 0.0 && SymbolInfoInteger(m_symbol, SYMBOL_SELECT) != 0);
      m_symbolTradeEnabled = ((ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(m_symbol, SYMBOL_TRADE_MODE)
                              != SYMBOL_TRADE_MODE_DISABLED);

      //--- quotes -----------------------------------------------------
      datetime quoteTime = (datetime)SymbolInfoInteger(m_symbol, SYMBOL_TIME);
      if(quoteTime > 0)
         m_quoteAgeSeconds = (int)(m_checked - quoteTime);
      else
         m_quoteAgeSeconds = 999999;

      m_quotesFresh = (quoteTime > 0 && m_quoteAgeSeconds <= m_staleSeconds);

      if(point > 0.0)
      {
         double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
         double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
         if(ask > 0.0 && bid > 0.0 && ask >= bid)
            m_spreadPoints = (long)MathRound((ask - bid) / point);
         else
            m_spreadPoints = (long)SymbolInfoInteger(m_symbol, SYMBOL_SPREAD);
      }

      m_spreadOk = (m_maxSpreadPoints <= 0 || m_spreadPoints <= m_maxSpreadPoints);

      //--- classification --------------------------------------------
      if(!m_connected)
      {
         m_level  = QSMC_HEALTH_BLOCKED;
         m_reason = "terminal disconnected";
         return m_level;
      }
      if(!m_symbolAvailable || !m_symbolTradeEnabled)
      {
         m_level  = QSMC_HEALTH_BLOCKED;
         m_reason = "symbol unavailable or trading disabled";
         return m_level;
      }
      if(!m_quotesFresh)
      {
         m_level  = QSMC_HEALTH_BLOCKED;
         m_reason = "quotes stale (" + IntegerToString(m_quoteAgeSeconds) + "s)";
         return m_level;
      }
      if(!m_spreadOk)
      {
         m_level  = QSMC_HEALTH_DEGRADED;
         m_reason = "spread " + IntegerToString((int)m_spreadPoints) + " > limit";
         return m_level;
      }
      if(!m_terminalTradeAllowed || !m_mqlTradeAllowed ||
         !m_accountTradeAllowed || !m_accountExpertAllowed)
      {
         m_level  = QSMC_HEALTH_DEGRADED;
         m_reason = "trading permissions withheld (terminal/account/algo)";
         return m_level;
      }

      m_level  = QSMC_HEALTH_HEALTHY;
      m_reason = "ok";
      return m_level;
   }

   //--- accessors ----------------------------------------------------
   ENUM_QSMC_HEALTH Level()          const { return m_level; }
   bool   Connected()                const { return m_connected; }
   bool   TerminalTradeAllowed()     const { return m_terminalTradeAllowed; }
   bool   MqlTradeAllowed()          const { return m_mqlTradeAllowed; }
   bool   AccountTradeAllowed()      const { return m_accountTradeAllowed; }
   bool   AccountExpertAllowed()     const { return m_accountExpertAllowed; }
   bool   SymbolAvailable()          const { return m_symbolAvailable; }
   bool   SymbolTradeEnabled()       const { return m_symbolTradeEnabled; }
   bool   QuotesFresh()              const { return m_quotesFresh; }
   bool   SpreadOk()                 const { return m_spreadOk; }
   long   SpreadPoints()             const { return m_spreadPoints; }
   int    QuoteAgeSeconds()          const { return m_quoteAgeSeconds; }
   string Reason()                   const { return m_reason; }
   datetime Checked()                const { return m_checked; }
   string Symbol()                   const { return m_symbol; }

   bool CanSubmitOrders() const
   {
      if(m_level != QSMC_HEALTH_HEALTHY) return false;
      return (m_connected && m_terminalTradeAllowed && m_mqlTradeAllowed &&
              m_accountTradeAllowed && m_accountExpertAllowed &&
              m_symbolAvailable && m_symbolTradeEnabled && m_quotesFresh);
   }

   string Describe() const
   {
      return StringFormat("health=%s spread=%dpt age=%ds reason=%s",
                          EnumToString(m_level), (int)m_spreadPoints,
                          m_quoteAgeSeconds, m_reason);
   }
};

#endif // QSMC_HEALTHMONITOR_MQH
