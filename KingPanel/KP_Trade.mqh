//+------------------------------------------------------------------+
//| KP_Trade.mqh - KING PANEL V1.0                                   |
//| Close operations + risk-guard automation                         |
//+------------------------------------------------------------------+
#ifndef KP_TRADE_MQH
#define KP_TRADE_MQH

#include <Trade/Trade.mqh>
#include "KP_Theme.mqh"
#include "KP_Data.mqh"

CTrade g_trade;

//--- close modes -----------------------------------------------------
#define KP_CLOSE_ALL     0
#define KP_CLOSE_PROFIT  1
#define KP_CLOSE_LOSS    2
#define KP_CLOSE_BUY     3
#define KP_CLOSE_SELL    4

// close positions by filter; returns number of close orders sent
int KPT_CloseBy(const int mode)
  {
   int sent = 0;
   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      ulong tk = PositionGetTicket(i);
      if(tk == 0)
         continue;
      double pl   = PositionGetDouble(POSITION_PROFIT)
                  + PositionGetDouble(POSITION_SWAP);
      long   type = PositionGetInteger(POSITION_TYPE);
      bool doit = false;
      switch(mode)
        {
         case KP_CLOSE_ALL:    doit = true;                              break;
         case KP_CLOSE_PROFIT: doit = (pl > 0);                          break;
         case KP_CLOSE_LOSS:   doit = (pl < 0);                          break;
         case KP_CLOSE_BUY:    doit = (type == POSITION_TYPE_BUY);       break;
         case KP_CLOSE_SELL:   doit = (type == POSITION_TYPE_SELL);      break;
        }
      if(!doit)
         continue;
      g_trade.SetDeviationInPoints(30);
      if(g_trade.PositionClose(tk))
         sent++;
      else
         PrintFormat("[KING PANEL] close #%I64u failed: %d %s",
                     tk, g_trade.ResultRetcode(), g_trade.ResultRetcodeDescription());
     }
   return sent;
  }

int KPT_CloseTicket(const ulong ticket)
  {
   g_trade.SetDeviationInPoints(30);
   if(g_trade.PositionClose(ticket))
      return 1;
   PrintFormat("[KING PANEL] close #%I64u failed: %d %s",
               ticket, g_trade.ResultRetcode(), g_trade.ResultRetcodeDescription());
   return 0;
  }

int KPT_DeletePendings()
  {
   int sent = 0;
   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      ulong tk = OrderGetTicket(i);
      if(tk == 0)
         continue;
      if(g_trade.OrderDelete(tk))
         sent++;
     }
   return sent;
  }

//--- risk guard settings --------------------------------------------
struct KPRisk
  {
   bool              sl_on;      // floating loss guard
   double            sl_val;     // close all when floating PL <= -sl_val
   bool              tp_on;      // floating profit guard
   double            tp_val;     // close all when floating PL >= tp_val
   bool              floor_on;   // equity floor guard
   double            floor_val;  // close all when equity <= floor_val
   bool              time_on;    // daily timed close
   int               time_hh;
   int               time_mm;
  };

KPRisk   g_risk;
datetime g_risk_last_timeclose = 0;   // day marker
string   g_risk_lastmsg = "";
datetime g_risk_lastmsg_t = 0;

// defaults apply on first load only; afterwards panel-adjusted values persist
void KPT_RiskLoad(const double def_sl=500.0, const double def_tp=500.0,
                  const int def_hh=22, const int def_mm=30)
  {
   g_risk.sl_on     = (KP_StoreGet("risk_sl_on", 0) > 0.5);
   g_risk.sl_val    =  KP_StoreGet("risk_sl_val", MathAbs(def_sl));
   g_risk.tp_on     = (KP_StoreGet("risk_tp_on", 0) > 0.5);
   g_risk.tp_val    =  KP_StoreGet("risk_tp_val", MathAbs(def_tp));
   g_risk.floor_on  = (KP_StoreGet("risk_floor_on", 0) > 0.5);
   g_risk.floor_val =  KP_StoreGet("risk_floor_val", 0.0);
   g_risk.time_on   = (KP_StoreGet("risk_time_on", 0) > 0.5);
   g_risk.time_hh   = (int)KP_StoreGet("risk_time_hh", MathMax(0, MathMin(23, def_hh)));
   g_risk.time_mm   = (int)KP_StoreGet("risk_time_mm", MathMax(0, MathMin(59, def_mm)));
   g_risk_last_timeclose = (datetime)(long)KP_StoreGet("risk_time_last", 0);
  }

void KPT_RiskSave()
  {
   KP_StoreSet("risk_sl_on",     g_risk.sl_on ? 1 : 0);
   KP_StoreSet("risk_sl_val",    g_risk.sl_val);
   KP_StoreSet("risk_tp_on",     g_risk.tp_on ? 1 : 0);
   KP_StoreSet("risk_tp_val",    g_risk.tp_val);
   KP_StoreSet("risk_floor_on",  g_risk.floor_on ? 1 : 0);
   KP_StoreSet("risk_floor_val", g_risk.floor_val);
   KP_StoreSet("risk_time_on",   g_risk.time_on ? 1 : 0);
   KP_StoreSet("risk_time_hh",   g_risk.time_hh);
   KP_StoreSet("risk_time_mm",   g_risk.time_mm);
   KP_StoreSet("risk_time_last", (double)(long)g_risk_last_timeclose);
  }

void KPT_RiskMsg(const string msg)
  {
   g_risk_lastmsg   = msg;
   g_risk_lastmsg_t = TimeCurrent();
   Print("[KING PANEL] ", msg);
  }

//--- order ticket ---------------------------------------------------
long KPT_PanelMagic = 0;

double KPT_NormLots(const string sym, const double lots)
  {
   double mn = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
   double mx = SymbolInfoDouble(sym, SYMBOL_VOLUME_MAX);
   double st = SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP);
   double v = lots;
   if(st > 0)
      v = MathRound(v / st) * st;
   if(mn > 0 && v < mn) v = mn;
   if(mx > 0 && v > mx) v = mx;
   return NormalizeDouble(v, 8);
  }

// dir: 0 buy, 1 sell; sl/tp in points (0 = none)
bool KPT_Market(const string sym, const int dir, const double lots,
                const int sl_pts, const int tp_pts)
  {
   MqlTick tk;
   if(!SymbolInfoTick(sym, tk))
     {
      KPT_RiskMsg(LL("No quotes for ", "无报价: ") + sym);
      return false;
     }
   double pt = SymbolInfoDouble(sym, SYMBOL_POINT);
   int    dg = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   double px = (dir == 0 ? tk.ask : tk.bid);
   double sl = 0, tp = 0;
   if(sl_pts > 0)
      sl = NormalizeDouble(dir == 0 ? px - sl_pts*pt : px + sl_pts*pt, dg);
   if(tp_pts > 0)
      tp = NormalizeDouble(dir == 0 ? px + tp_pts*pt : px - tp_pts*pt, dg);
   double v = KPT_NormLots(sym, lots);
   g_trade.SetExpertMagicNumber(KPT_PanelMagic);
   g_trade.SetDeviationInPoints(30);
   bool ok = (dir == 0 ? g_trade.Buy(v, sym, 0, sl, tp, "KING PANEL")
                       : g_trade.Sell(v, sym, 0, sl, tp, "KING PANEL"));
   if(ok)
      KPT_RiskMsg(StringFormat("%s %s %s @%s",
                  (dir == 0 ? "BUY" : "SELL"), KP_Lots(v), sym,
                  DoubleToString(px, dg)));
   else
      KPT_RiskMsg(StringFormat("%s FAIL %d %s",
                  (dir == 0 ? "BUY" : "SELL"),
                  g_trade.ResultRetcode(), g_trade.ResultRetcodeDescription()));
   return ok;
  }

// ptype: 0 BuyLimit, 1 SellLimit, 2 BuyStop, 3 SellStop; dist in points
bool KPT_Pending(const string sym, const int ptype, const double lots,
                 const int dist_pts, const int sl_pts, const int tp_pts)
  {
   MqlTick tk;
   if(!SymbolInfoTick(sym, tk))
     {
      KPT_RiskMsg(LL("No quotes for ", "无报价: ") + sym);
      return false;
     }
   double pt = SymbolInfoDouble(sym, SYMBOL_POINT);
   int    dg = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   long   stops = SymbolInfoInteger(sym, SYMBOL_TRADE_STOPS_LEVEL);
   long   sprd  = SymbolInfoInteger(sym, SYMBOL_SPREAD);
   int    dist  = (int)MathMax(dist_pts, stops + sprd + 3);   // broker-safe
   bool   is_buy = (ptype == 0 || ptype == 2);
   double px = 0;
   switch(ptype)
     {
      case 0: px = tk.ask - dist*pt; break;   // buy limit
      case 1: px = tk.bid + dist*pt; break;   // sell limit
      case 2: px = tk.ask + dist*pt; break;   // buy stop
      case 3: px = tk.bid - dist*pt; break;   // sell stop
     }
   px = NormalizeDouble(px, dg);
   double sl = 0, tp = 0;
   if(sl_pts > 0)
      sl = NormalizeDouble(is_buy ? px - sl_pts*pt : px + sl_pts*pt, dg);
   if(tp_pts > 0)
      tp = NormalizeDouble(is_buy ? px + tp_pts*pt : px - tp_pts*pt, dg);
   double v = KPT_NormLots(sym, lots);
   g_trade.SetExpertMagicNumber(KPT_PanelMagic);
   bool ok = false;
   switch(ptype)
     {
      case 0: ok = g_trade.BuyLimit (v, px, sym, sl, tp, ORDER_TIME_GTC, 0, "KING PANEL"); break;
      case 1: ok = g_trade.SellLimit(v, px, sym, sl, tp, ORDER_TIME_GTC, 0, "KING PANEL"); break;
      case 2: ok = g_trade.BuyStop  (v, px, sym, sl, tp, ORDER_TIME_GTC, 0, "KING PANEL"); break;
      case 3: ok = g_trade.SellStop (v, px, sym, sl, tp, ORDER_TIME_GTC, 0, "KING PANEL"); break;
     }
   string tag = KP_OrdTypeTag(ptype == 0 ? ORDER_TYPE_BUY_LIMIT :
                              ptype == 1 ? ORDER_TYPE_SELL_LIMIT :
                              ptype == 2 ? ORDER_TYPE_BUY_STOP : ORDER_TYPE_SELL_STOP);
   if(ok)
      KPT_RiskMsg(StringFormat("%s %s %s @%s", tag, KP_Lots(v), sym,
                  DoubleToString(px, dg)));
   else
      KPT_RiskMsg(StringFormat("%s FAIL %d %s", tag,
                  g_trade.ResultRetcode(), g_trade.ResultRetcodeDescription()));
   return ok;
  }

// call every timer tick; true if any action fired
bool KPT_RiskCheck()
  {
   bool fired = false;
   double fpl = g_acc.floating_pl;

   if(g_risk.sl_on && g_acc.positions > 0 && fpl <= -MathAbs(g_risk.sl_val))
     {
      int n = KPT_CloseBy(KP_CLOSE_ALL);
      g_risk.sl_on = false;   // one-shot
      KPT_RiskSave();
      KPT_RiskMsg(StringFormat(LL("Loss guard %.2f <= -%.2f, closed %d",
                                  "浮亏触发 %.2f ≤ -%.2f, 全平 %d 单"),
                  fpl, MathAbs(g_risk.sl_val), n));
      fired = true;
     }

   if(g_risk.tp_on && g_acc.positions > 0 && fpl >= MathAbs(g_risk.tp_val))
     {
      int n = KPT_CloseBy(KP_CLOSE_ALL);
      g_risk.tp_on = false;   // one-shot
      KPT_RiskSave();
      KPT_RiskMsg(StringFormat(LL("Profit guard %.2f >= %.2f, closed %d",
                                  "浮盈触发 %.2f ≥ %.2f, 全平 %d 单"),
                  fpl, MathAbs(g_risk.tp_val), n));
      fired = true;
     }

   if(g_risk.floor_on && g_risk.floor_val > 0 &&
      g_acc.equity <= g_risk.floor_val && g_acc.positions > 0)
     {
      int n = KPT_CloseBy(KP_CLOSE_ALL);
      g_risk.floor_on = false;   // one-shot
      KPT_RiskSave();
      KPT_RiskMsg(StringFormat(LL("Equity floor %.2f <= %.2f, closed %d",
                                  "净值保护 %.2f ≤ %.2f, 全平 %d 单"),
                  g_acc.equity, g_risk.floor_val, n));
      fired = true;
     }

   if(g_risk.time_on)
     {
      datetime now  = TimeCurrent();
      datetime day  = KP_DayStart(now);
      datetime mark = day + g_risk.time_hh * 3600 + g_risk.time_mm * 60;
      if(now >= mark && g_risk_last_timeclose < day)
        {
         g_risk_last_timeclose = day;
         KPT_RiskSave();
         if(g_acc.positions > 0)
           {
            int n = KPT_CloseBy(KP_CLOSE_ALL);
            KPT_RiskMsg(StringFormat(LL("Timed close %02d:%02d, closed %d",
                                        "定时平仓 %02d:%02d, 全平 %d 单"),
                        g_risk.time_hh, g_risk.time_mm, n));
            fired = true;
           }
        }
     }
   return fired;
  }

#endif // KP_TRADE_MQH
