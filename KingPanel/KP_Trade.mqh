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

// slippage allowance: a flat 30 points rejects exactly the flattens the
// guards need on wide-spread symbols (indices, crypto, news spikes)
int KPT_Dev(const string sym)
  {
   long sp = SymbolInfoInteger(sym, SYMBOL_SPREAD);
   return (int)MathMax(30, MathMin(500, sp * 3));
  }

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
      // keep the position's own magic on the closing deal, otherwise the
      // panel would re-stamp other EAs' trades and corrupt per-magic stats
      g_trade.SetExpertMagicNumber(PositionGetInteger(POSITION_MAGIC));
      g_trade.SetDeviationInPoints(KPT_Dev(PositionGetString(POSITION_SYMBOL)));
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
   if(PositionSelectByTicket(ticket))
     {
      g_trade.SetExpertMagicNumber(PositionGetInteger(POSITION_MAGIC));
      g_trade.SetDeviationInPoints(KPT_Dev(PositionGetString(POSITION_SYMBOL)));
     }
   if(g_trade.PositionClose(ticket))
      return 1;
   PrintFormat("[KING PANEL] close #%I64u failed: %d %s",
               ticket, g_trade.ResultRetcode(), g_trade.ResultRetcodeDescription());
   return 0;
  }

// mine_only: automation side effects must never cancel another EA's
// working orders - only an explicit user click may do that
int KPT_DeletePendings(const bool mine_only=false)
  {
   int sent = 0;
   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      ulong tk = OrderGetTicket(i);
      if(tk == 0)
         continue;
      if(mine_only && OrderGetInteger(ORDER_MAGIC) != KPT_PanelMagic)
         continue;
      if(g_trade.OrderDelete(tk))
         sent++;
     }
   return sent;
  }

// delete pending orders whose symbol is exposed to a currency
int KPT_DeletePendingsCur(const string cur)
  {
   int sent = 0;
   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      ulong tk = OrderGetTicket(i);
      if(tk == 0)
         continue;
      if(!KPN_SymTouches(OrderGetString(ORDER_SYMBOL), cur))
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

//--- prop mode: daily-loss guard with order lockout -----------------
struct KPProp
  {
   bool              on;
   double            daily;        // max daily loss, account currency
   datetime          lock_until;   // orders blocked while now < lock_until
  };

KPProp   g_prop;
datetime g_prop_warned_anchor = 0;   // 80%-budget warning dedupe per day

void KPT_PropLoad(const bool def_on, const double def_daily)
  {
   g_prop.on         = (KP_StoreGet("prop_on", def_on ? 1 : 0) > 0.5);
   g_prop.daily      = MathMax(50.0, KP_StoreGet("prop_daily", MathAbs(def_daily)));
   g_prop.lock_until = (datetime)(long)KP_StoreGet("prop_lock", 0);
   g_prop_warned_anchor = (datetime)(long)KP_StoreGet("prop_warned", 0);
  }

void KPT_PropSave()
  {
   KP_StoreSet("prop_on",     g_prop.on ? 1 : 0);
   KP_StoreSet("prop_daily",  g_prop.daily);
   KP_StoreSet("prop_lock",   (double)(long)g_prop.lock_until);
   KP_StoreSet("prop_warned", (double)(long)g_prop_warned_anchor);
  }

bool KPT_Locked()
  {
   return (TimeCurrent() < g_prop.lock_until);
  }

string KPT_LockLeft()
  {
   return KP_Duration((long)(g_prop.lock_until - TimeCurrent()));
  }

//--- prop-day equity anchor -----------------------------------------
// Prop firms measure the day as equity_now - equity_at_reset. Using
// realized+floating instead double-counts floating P&L that was already
// open when the day started. We snapshot equity at the rollover; when no
// valid snapshot exists (EA attached mid-day) we fall back to the
// realized+floating estimate, which is what balance-at-anchor implies.
double   g_prop_eq_val  = 0;
datetime g_prop_eq_time = 0;

void KPT_PropAnchorLoad()
  {
   g_prop_eq_time = (datetime)(long)KP_StoreGet("prop_eq_t", 0);
   g_prop_eq_val  = KP_StoreGet("prop_eq_v", 0);
  }

// call every timer tick, after the account snapshot is refreshed
void KPT_PropAnchorTick()
  {
   datetime a = KP_ResetAnchor(TimeCurrent());
   if(g_prop_eq_time == a)
      return;
   g_prop_eq_time = a;
   g_prop_eq_val  = g_acc.equity;
   KP_StoreSet("prop_eq_t", (double)(long)a);
   KP_StoreSet("prop_eq_v", g_prop_eq_val);
  }

double KPT_DayPL()
  {
   if(g_prop_eq_time == KP_ResetAnchor(TimeCurrent()) && g_prop_eq_val > 0)
      return g_acc.equity - g_prop_eq_val - g_tot.reset_cash;
   return g_tot.reset_pl + g_acc.floating_pl;   // no snapshot yet
  }

// remaining loss budget for the day (never negative)
double KPT_DayBudgetLeft()
  {
   return MathMax(0.0, g_prop.daily + MathMin(0.0, KPT_DayPL()));
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

// floor variant for risk sizing: rounds DOWN to the volume step so the
// realized risk can never exceed the intended risk; returns 0 when the
// budget doesn't even cover the minimum lot
double KPT_NormLotsFloor(const string sym, const double lots)
  {
   double mn = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
   double mx = SymbolInfoDouble(sym, SYMBOL_VOLUME_MAX);
   double st = SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP);
   double v = lots;
   if(st > 0)
      v = MathFloor(v / st + 0.0000001) * st;
   if(mx > 0 && v > mx) v = mx;
   if(mn > 0 && v < mn) return 0.0;
   return NormalizeDouble(v, 8);
  }

// money lost by 1.0 lot when price moves sl_pts points against it.
// Prefers OrderCalcProfit (exact, handles cross-currency conversion);
// falls back to tick-value arithmetic when it fails.
double KPT_MoneyPerLot(const string sym, const int dir, const int sl_pts)
  {
   if(sl_pts <= 0)
      return 0.0;
   double pt = SymbolInfoDouble(sym, SYMBOL_POINT);
   MqlTick tk;
   if(pt > 0 && SymbolInfoTick(sym, tk) && tk.bid > 0)
     {
      double open  = (dir == 0 ? tk.ask : tk.bid);
      double close = (dir == 0 ? open - sl_pts*pt : open + sl_pts*pt);
      double profit = 0;
      if(OrderCalcProfit(dir == 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,
                         sym, 1.0, open, close, profit) && profit < 0)
         return -profit;
     }
   double ts = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
   double tv = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE);
   if(ts > 0 && tv > 0 && pt > 0)
      return sl_pts * pt / ts * tv;
   return 0.0;
  }

// lots for a given money risk at sl_pts; realized_risk gets the actual
// money at risk after step-flooring (<= risk_money by construction)
double KPT_RiskLots(const string sym, const int dir, const double risk_money,
                    const int sl_pts, double &realized_risk)
  {
   realized_risk = 0.0;
   double per_lot = KPT_MoneyPerLot(sym, dir, sl_pts);
   if(per_lot <= 0.0 || risk_money <= 0.0)
      return 0.0;
   double want = risk_money / per_lot;
   double vmax = SymbolInfoDouble(sym, SYMBOL_VOLUME_MAX);
   if(vmax > 0 && want > vmax)
      return 0.0;    // clamping here would silently take LESS risk than asked
   double v = KPT_NormLotsFloor(sym, want);
   if(v > 0)
      realized_risk = v * per_lot;
   return v;
  }

// smallest SL/TP distance the broker will accept right now
int KPT_MinStop(const string sym)
  {
   return (int)(SymbolInfoInteger(sym, SYMBOL_TRADE_STOPS_LEVEL)
              + SymbolInfoInteger(sym, SYMBOL_SPREAD) + 2);
  }

// SL/TP closer than the broker's stop distance is rejected outright: the
// risk-% lot size was computed FROM sl_pts, so silently widening it would
// break the risk contract the user set.
bool KPT_StopsOK(const string sym, const int sl_pts, const int tp_pts)
  {
   int ms = KPT_MinStop(sym);
   if(sl_pts > 0 && sl_pts < ms)
     {
      KPT_RiskMsg(StringFormat(LL("SL %d pt too close (min %d incl. spread)",
                                  "止损 %d 点过近 (含点差最小 %d)"), sl_pts, ms));
      return false;
     }
   if(tp_pts > 0 && tp_pts < ms)
     {
      KPT_RiskMsg(StringFormat(LL("TP %d pt too close (min %d incl. spread)",
                                  "止盈 %d 点过近 (含点差最小 %d)"), tp_pts, ms));
      return false;
     }
   return true;
  }

// free-margin check before sending
bool KPT_MarginOK(const string sym, const int dir, const double v, const double px)
  {
   double need = 0;
   if(!OrderCalcMargin(dir == 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,
                       sym, v, px, need))
      return true;                       // cannot tell: let the server decide
   if(need <= AccountInfoDouble(ACCOUNT_MARGIN_FREE))
      return true;
   KPT_RiskMsg(StringFormat(LL("Not enough free margin: needs %s, free %s",
                               "可用保证金不足: 需要 %s, 可用 %s"),
               KP_Money(need, 0), KP_Money(AccountInfoDouble(ACCOUNT_MARGIN_FREE), 0)));
   return false;
  }

// dir: 0 buy, 1 sell; sl/tp in points (0 = none)
bool KPT_Market(const string sym, const int dir, const double lots,
                const int sl_pts, const int tp_pts)
  {
   if(KPT_Locked())
     {
      KPT_RiskMsg(LL("LOCKED ", "已锁定 ") + KPT_LockLeft());
      return false;
     }
   if(g_ng_block_on)
     {
      if(!g_news_ok)
        {
         // armed but blind: refusing is the only safe reading of "block
         // me around news" when the calendar cannot be consulted
         KPT_RiskMsg(LL("NEWS BLOCK: calendar unavailable (guard is armed)",
                        "新闻拦截: 日历不可用 (护盾已武装)"));
         return false;
        }
      string ev_name = "", ev_cur = "";
      long ev_in = 0;
      if(KPN_ActiveEvent(sym, ev_name, ev_cur, ev_in))
        {
         KPT_RiskMsg(StringFormat(LL("NEWS BLOCK: %s %s (%s)",
                                     "新闻拦截: %s %s (%s)"),
                     ev_cur, ev_name,
                     ev_in >= 0 ? LL("in ", "还有 ") + KP_Duration(ev_in)
                                : LL("just released", "刚公布")));
         return false;
        }
     }
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
   if(!KPT_StopsOK(sym, sl_pts, tp_pts) || !KPT_MarginOK(sym, dir, v, px))
      return false;
   g_trade.SetExpertMagicNumber(KPT_PanelMagic);
   g_trade.SetDeviationInPoints(KPT_Dev(sym));
   bool ok = (dir == 0 ? g_trade.Buy(v, sym, 0, sl, tp, "KING PANEL")
                       : g_trade.Sell(v, sym, 0, sl, tp, "KING PANEL"));
   if(ok)
      KPT_RiskMsg(StringFormat(LL("%s %s %s @%s", "%s %s %s @%s"),
                  (dir == 0 ? LL("BUY", "买入") : LL("SELL", "卖出")),
                  KP_Lots(v, KP_LotDigits(sym)), sym, DoubleToString(px, dg)));
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
   if(KPT_Locked())
     {
      KPT_RiskMsg(LL("LOCKED ", "已锁定 ") + KPT_LockLeft());
      return false;
     }
   if(g_ng_block_on)
     {
      if(!g_news_ok)
        {
         // armed but blind: refusing is the only safe reading of "block
         // me around news" when the calendar cannot be consulted
         KPT_RiskMsg(LL("NEWS BLOCK: calendar unavailable (guard is armed)",
                        "新闻拦截: 日历不可用 (护盾已武装)"));
         return false;
        }
      string ev_name = "", ev_cur = "";
      long ev_in = 0;
      if(KPN_ActiveEvent(sym, ev_name, ev_cur, ev_in))
        {
         KPT_RiskMsg(StringFormat(LL("NEWS BLOCK: %s %s (%s)",
                                     "新闻拦截: %s %s (%s)"),
                     ev_cur, ev_name,
                     ev_in >= 0 ? LL("in ", "还有 ") + KP_Duration(ev_in)
                                : LL("just released", "刚公布")));
         return false;
        }
     }
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
   if(!KPT_StopsOK(sym, sl_pts, tp_pts) || !KPT_MarginOK(sym, is_buy ? 0 : 1, v, px))
      return false;
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
      KPT_RiskMsg(StringFormat("%s %s %s @%s", tag,
                  KP_Lots(v, KP_LotDigits(sym)), sym, DoubleToString(px, dg)));
   else
      KPT_RiskMsg(StringFormat("%s FAIL %d %s", tag,
                  g_trade.ResultRetcode(), g_trade.ResultRetcodeDescription()));
   return ok;
  }

//--- per-position automation: break-even / trailing / partial -------
int  KPT_TrailPts = 200;    // panel-wide trailing distance, points
int  KPT_BEBuf    = 20;     // break-even lock-in buffer, points

bool KPT_TrailOn(const ulong ticket)
  {
   return (KP_StoreGet("tr_" + (string)ticket, 0) > 0.5);
  }

void KPT_TrailSet(const ulong ticket, const bool on)
  {
   if(on)
      KP_StoreSet("tr_" + (string)ticket, 1);
   else
      GlobalVariableDel(KP_GVPrefix + "tr_" + (string)ticket);
  }

// move SL to entry +/- buffer (locks a small profit); broker-safe
bool KPT_BE(const ulong ticket, const int buf_pts)
  {
   if(!PositionSelectByTicket(ticket))
      return false;
   string sym  = PositionGetString(POSITION_SYMBOL);
   long   type = PositionGetInteger(POSITION_TYPE);
   double entry = PositionGetDouble(POSITION_PRICE_OPEN);
   double tp    = PositionGetDouble(POSITION_TP);
   double sl    = PositionGetDouble(POSITION_SL);
   double pt    = SymbolInfoDouble(sym, SYMBOL_POINT);
   int    dg    = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   long   stops = SymbolInfoInteger(sym, SYMBOL_TRADE_STOPS_LEVEL);
   MqlTick tk;
   if(pt <= 0 || !SymbolInfoTick(sym, tk))
      return false;
   bool buy = (type == POSITION_TYPE_BUY);
   double ns = NormalizeDouble(buy ? entry + buf_pts*pt : entry - buf_pts*pt, dg);
   // must clear the broker stop distance from the current price
   if(buy  && ns > tk.bid - (stops+1)*pt)
     {
      KPT_RiskMsg(LL("BE: not enough profit yet", "保本: 盈利尚不足以保本"));
      return false;
     }
   if(!buy && ns < tk.ask + (stops+1)*pt)
     {
      KPT_RiskMsg(LL("BE: not enough profit yet", "保本: 盈利尚不足以保本"));
      return false;
     }
   // never loosen an already-better SL
   if(sl > 0 && ((buy && sl >= ns) || (!buy && sl <= ns)))
      return true;
   if(g_trade.PositionModify(ticket, ns, tp))
     {
      KPT_RiskMsg(StringFormat(LL("BE #%I64u @%s", "保本 #%I64u @%s"),
                  ticket, DoubleToString(ns, dg)));
      return true;
     }
   KPT_RiskMsg(StringFormat(LL("BE FAIL %d", "保本失败 %d"), g_trade.ResultRetcode()));
   return false;
  }

// close half (or given fraction) of a position, volume-step aware
bool KPT_Half(const ulong ticket)
  {
   if(!PositionSelectByTicket(ticket))
      return false;
   string sym = PositionGetString(POSITION_SYMBOL);
   double vol = PositionGetDouble(POSITION_VOLUME);
   double part = KPT_NormLotsFloor(sym, vol / 2.0);
   if(part <= 0 || part >= vol)
     {
      KPT_RiskMsg(LL("HALF: volume below broker minimum", "减半: 剩余量低于最小手数"));
      return false;
     }
   g_trade.SetDeviationInPoints(30);
   if(g_trade.PositionClosePartial(ticket, part))
     {
      KPT_RiskMsg(StringFormat(LL("HALF #%I64u closed %s", "减半 #%I64u 平 %s"),
                  ticket, KP_Lots(part)));
      return true;
     }
   KPT_RiskMsg(StringFormat(LL("HALF FAIL %d", "减半失败 %d"), g_trade.ResultRetcode()));
   return false;
  }

//--- trailing failure backoff (ring, in-memory) ---------------------
ulong    g_tf_ticket[16];
datetime g_tf_until[16];
int      g_tf_n = 0;

bool KPT_TrailBlocked(const ulong ticket)
  {
   for(int i=0; i<g_tf_n; i++)
      if(g_tf_ticket[i] == ticket)
         return (TimeCurrent() < g_tf_until[i]);
   return false;
  }

void KPT_TrailFail(const ulong ticket)
  {
   for(int i=0; i<g_tf_n; i++)
      if(g_tf_ticket[i] == ticket)
        {
         g_tf_until[i] = TimeCurrent() + 30;
         return;
        }
   int slot = (g_tf_n < 16 ? g_tf_n++ : 0);
   g_tf_ticket[slot] = ticket;
   g_tf_until[slot]  = TimeCurrent() + 30;
  }

// maintain armed trailing stops; called every timer tick.
// Trails only on the profitable side of the entry (never installs a
// losing SL the trader didn't ask for) and only ever tightens.
void KPT_TrailTick()
  {
   for(int i=0; i<g_live_count; i++)
     {
      if(!KPT_TrailOn(g_live[i].ticket))
         continue;
      string sym = g_live[i].symbol;
      double pt = SymbolInfoDouble(sym, SYMBOL_POINT);
      int    dg = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
      long   stops = SymbolInfoInteger(sym, SYMBOL_TRADE_STOPS_LEVEL);
      MqlTick tk;
      if(pt <= 0 || !SymbolInfoTick(sym, tk))
         continue;
      bool buy = (g_live[i].type == POSITION_TYPE_BUY);
      // a distance below the broker stop level would silently never fire
      int eff = (int)MathMax(KPT_TrailPts, stops + 5);
      double cand = NormalizeDouble(buy ? tk.bid - eff*pt
                                        : tk.ask + eff*pt, dg);
      if(buy  && cand < g_live[i].price_open) continue;
      if(!buy && cand > g_live[i].price_open) continue;
      double sl = g_live[i].sl;
      if(sl > 0 && ((buy && cand <= sl + pt) || (!buy && cand >= sl - pt)))
         continue;   // no improvement
      if(buy  && cand > tk.bid - (stops+1)*pt) continue;
      if(!buy && cand < tk.ask + (stops+1)*pt) continue;
      if(KPT_TrailBlocked(g_live[i].ticket))
         continue;
      g_trade.SetExpertMagicNumber(g_live[i].magic);
      if(!g_trade.PositionModify(g_live[i].ticket, cand, g_live[i].tp))
        {
         // a rejected modify repeated every second floods the journal and
         // the server; back the ticket off for 30 s and report it once
         KPT_TrailFail(g_live[i].ticket);
         KPT_RiskMsg(StringFormat(LL("Trail #%I64u failed %d", "追踪 #%I64u 失败 %d"),
                     g_live[i].ticket, g_trade.ResultRetcode()));
        }
     }
  }

//--- news auto-flat: close exposed positions before filtered events -
void KPT_NewsGuardTick()
  {
   if(!g_ng_flat_on || !g_news_ok || g_live_count == 0)
      return;
   datetime now = TimeCurrent();
   for(int i=0; i<g_news_count; i++)
     {
      if(g_news[i].importance < g_ng_stars)
         continue;
      if(!KPN_CurOK(g_news[i].cur))
         continue;
      long dt = (long)(g_news[i].time - now);
      if(dt <= 0 || dt > (long)g_ng_before*60)
         continue;
      // one-shot per event
      if(KP_StoreGet("ngf_" + (string)g_news[i].vid, 0) > 0.5)
         continue;
      int n = 0, m = 0;
      for(int p=g_live_count-1; p>=0; p--)
         if(KPN_SymTouches(g_live[p].symbol, g_news[i].cur))
           {
            m++;
            n += KPT_CloseTicket(g_live[p].ticket);
           }
      // a pending left armed would fill straight into the event
      int np = KPT_DeletePendingsCur(g_news[i].cur);
      if(n > 0 || np > 0)
        {
         // one-shot only once every touching position is gone;
         // partial failures retry on the next tick inside the window
         if(n == m)
            KP_StoreSet("ngf_" + (string)g_news[i].vid, 1);
         string msg;
         if(KP_Lang == 0)
            msg = StringFormat("NEWS FLAT: closed %d, cancelled %d before %s %s (in %s)",
                  n, np, g_news[i].cur, g_news[i].name, KP_Duration(dt));
         else
            msg = StringFormat("新闻避险: %s %s 前平 %d 单, 撤 %d 挂单 (还有 %s)",
                  g_news[i].cur, g_news[i].name, n, np, KP_Duration(dt));
         KPT_RiskMsg(msg);
         if(KP_PushRisk) KP_Push(msg);
        }
     }
  }

// call every timer tick; true if any action fired
bool KPT_RiskCheck()
  {
   bool fired = false;
   double fpl = g_acc.floating_pl;

   if(g_risk.sl_on && g_acc.positions > 0 && fpl <= -MathAbs(g_risk.sl_val))
     {
      int n = KPT_CloseBy(KP_CLOSE_ALL);
      // disarm ONLY once the book is actually flat - a rejected close
      // (requote / no quotes / autotrading off) must leave the guard
      // armed so the next tick retries instead of silently giving up
      if(PositionsTotal() == 0)
        {
         g_risk.sl_on = false;
         KPT_RiskSave();
        }
      string m1 = StringFormat(LL("Loss guard %.2f <= -%.2f, closed %d",
                                  "浮亏触发 %.2f ≤ -%.2f, 全平 %d 单"),
                  fpl, MathAbs(g_risk.sl_val), n);
      KPT_RiskMsg(m1);
      if(KP_PushRisk) KP_Push(m1);
      fired = true;
     }

   if(g_risk.tp_on && g_acc.positions > 0 && fpl >= MathAbs(g_risk.tp_val))
     {
      int n = KPT_CloseBy(KP_CLOSE_ALL);
      if(PositionsTotal() == 0)
        {
         g_risk.tp_on = false;
         KPT_RiskSave();
        }
      string m2 = StringFormat(LL("Profit guard %.2f >= %.2f, closed %d",
                                  "浮盈触发 %.2f ≥ %.2f, 全平 %d 单"),
                  fpl, MathAbs(g_risk.tp_val), n);
      KPT_RiskMsg(m2);
      if(KP_PushRisk) KP_Push(m2);
      fired = true;
     }

   if(g_risk.floor_on && g_risk.floor_val > 0 &&
      g_acc.equity <= g_risk.floor_val && g_acc.positions > 0)
     {
      int n = KPT_CloseBy(KP_CLOSE_ALL);
      if(PositionsTotal() == 0)
        {
         g_risk.floor_on = false;
         KPT_RiskSave();
        }
      string m3 = StringFormat(LL("Equity floor %.2f <= %.2f, closed %d",
                                  "净值保护 %.2f ≤ %.2f, 全平 %d 单"),
                  g_acc.equity, g_risk.floor_val, n);
      KPT_RiskMsg(m3);
      if(KP_PushRisk) KP_Push(m3);
      fired = true;
     }

   // prop daily-loss guard: realized-since-reset + floating.
   // Only evaluate when the stats rebuild already covers the CURRENT
   // reset window — otherwise the first ticks of a new prop day would
   // judge it by yesterday's realized loss and re-fire spuriously.
   bool prop_fresh = (g_last_rebuild >= KP_ResetAnchor(TimeCurrent()));
   if(g_prop.on && !KPT_Locked() && prop_fresh)
     {
      double dpl = KPT_DayPL();
      double lim = MathAbs(g_prop.daily);
      if(dpl <= -lim)
        {
         int n = KPT_CloseBy(KP_CLOSE_ALL);
         int np = KPT_DeletePendings();   // a filling pending would trade unguarded
         g_prop.lock_until = KP_ResetAnchor(TimeCurrent()) + 86400;
         KPT_PropSave();
         string mp = StringFormat(LL("DAILY LOSS %.2f <= -%.2f: closed %d, deleted %d, LOCKED for %s",
                                     "当日亏损 %.2f ≤ -%.2f: 全平 %d 单, 撤挂单 %d, 锁定 %s"),
                     dpl, lim, n, np, KPT_LockLeft());
         KPT_RiskMsg(mp);
         if(KP_PushRisk) KP_Push(mp);
         fired = true;
        }
      else if(dpl <= -0.8 * lim)
        {
         datetime a = KP_ResetAnchor(TimeCurrent());
         if(g_prop_warned_anchor != a)
           {
            g_prop_warned_anchor = a;
            KPT_PropSave();
            string mw = StringFormat(LL("80%% of daily loss budget used (%.2f / -%.2f)",
                                        "当日亏损额度已用80%% (%.2f / -%.2f)"),
                        dpl, lim);
            KPT_RiskMsg(mw);
            if(KP_PushRisk) KP_Push(mw);
           }
        }
     }
   // while locked with the day still beyond the limit, keep retrying
   // closes that failed at breach time (off-quotes etc.); 30s backoff
   // so a weekend breach doesn't flood the journal every second
   static datetime prop_retry_t = 0;
   if(g_prop.on && KPT_Locked() && prop_fresh && g_acc.positions > 0 &&
      KPT_DayPL() <= -MathAbs(g_prop.daily) &&
      TimeCurrent() - prop_retry_t >= 30)
     {
      prop_retry_t = TimeCurrent();
      if(KPT_CloseBy(KP_CLOSE_ALL) > 0)
         fired = true;
     }

   if(g_risk.time_on)
     {
      datetime now  = TimeCurrent();
      datetime day  = KP_DayStart(now);
      datetime mark = day + g_risk.time_hh * 3600 + g_risk.time_mm * 60;
      if(now >= mark && g_risk_last_timeclose < day)
        {
         if(g_acc.positions > 0)
           {
            int n = KPT_CloseBy(KP_CLOSE_ALL);
            string m4 = StringFormat(LL("Timed close %02d:%02d, closed %d",
                                        "定时平仓 %02d:%02d, 全平 %d 单"),
                        g_risk.time_hh, g_risk.time_mm, n);
            KPT_RiskMsg(m4);
            if(KP_PushRisk) KP_Push(m4);
            fired = true;
           }
         // the day counts as handled only when nothing is left open,
         // otherwise the next tick retries the flatten
         if(PositionsTotal() == 0)
           {
            g_risk_last_timeclose = day;
            KPT_RiskSave();
           }
        }
     }
   return fired;
  }

#endif // KP_TRADE_MQH
