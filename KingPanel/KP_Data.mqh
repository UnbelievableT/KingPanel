//+------------------------------------------------------------------+
//| KP_Data.mqh - KING PANEL V1.0                                    |
//| Statistics engine: history scan, aggregation, curves             |
//+------------------------------------------------------------------+
#ifndef KP_DATA_MQH
#define KP_DATA_MQH

#include <Generic/HashMap.mqh>
#include "KP_Theme.mqh"

//--- live account snapshot ------------------------------------------
struct KPAccount
  {
   long              login;
   string            server;
   string            company;
   string            currency;
   long              leverage;
   double            balance;
   double            equity;
   double            margin;
   double            margin_free;
   double            margin_level;   // %
   double            floating_pl;
   int               positions;
   int               pendings;
   bool              algo_ok;        // terminal+EA algotrading enabled
  };

//--- reconstructed (closed or open) position ------------------------
struct KPPosRec
  {
   long              pos_id;
   string            symbol;
   long              magic;
   int               dir;        // 0 buy, 1 sell, -1 unknown
   datetime          open_time;
   datetime          close_time;
   double            lots;       // opened volume total
   double            vwap_num;   // sum(entry price * lots) for avg entry
   double            sl0;        // SL attached to the first entry deal (0 = none)
   double            exit_num;   // sum(exit price * lots) for exit vwap
   double            lots_out;   // closed volume total
   double            net;        // profit+swap+commission of all its deals
   bool              closed;
  };

//--- aggregation row (period / symbol / magic) ----------------------
struct KPAggRow
  {
   string            label;      // display key
   datetime          key_time;   // bucket start (periods)
   long              key_magic;  // magic (magic table)
   int               trades;     // OUT deal count
   int               wins;
   int               losses;
   double            lots;
   double            profit;     // net (profit+comm+swap)
   double            gross_win;
   double            gross_loss; // negative sum
   double            cashflow;   // deposits/withdrawals inside bucket (periods only)
   double            peak;       // intra-bucket running peak of trading equity
   double            peak_bal;   // actual balance at that peak (pct denominator)
   double            dd;         // intra-bucket max drawdown (value)
   double            dd_pct;     // dd vs balance at the peak, %
  };

//--- live open position row -----------------------------------------
struct KPLivePos
  {
   ulong             ticket;
   long              pos_id;     // POSITION_IDENTIFIER
   string            symbol;
   long              magic;
   int               type;       // POSITION_TYPE_BUY/SELL
   double            lots;
   double            price_open;
   double            price_cur;
   double            sl;
   double            tp;
   double            profit;     // incl swap
   double            swap;
   datetime          time;
  };

//--- live pending order row -----------------------------------------
struct KPLiveOrd
  {
   ulong             ticket;
   string            symbol;
   long              magic;
   int               type;       // ORDER_TYPE_*
   double            lots;
   double            price;      // entry price
   double            price_cur;
   double            sl;
   double            tp;
   datetime          time;       // setup time
  };

// short tag for pending order types
string KP_OrdTypeTag(const int t)
  {
   switch(t)
     {
      case ORDER_TYPE_BUY_LIMIT:       return "B-LMT";
      case ORDER_TYPE_SELL_LIMIT:      return "S-LMT";
      case ORDER_TYPE_BUY_STOP:        return "B-STP";
      case ORDER_TYPE_SELL_STOP:       return "S-STP";
      case ORDER_TYPE_BUY_STOP_LIMIT:  return "B-SLM";
      case ORDER_TYPE_SELL_STOP_LIMIT: return "S-SLM";
     }
   return "?";
  }

bool KP_OrdIsBuy(const int t)
  {
   return (t == ORDER_TYPE_BUY_LIMIT || t == ORDER_TYPE_BUY_STOP ||
           t == ORDER_TYPE_BUY_STOP_LIMIT);
  }

//--- totals ----------------------------------------------------------
struct KPTotals
  {
   double            net;             // trading net (profit+comm+swap), no cashflow
   double            gross_profit;
   double            gross_loss;      // negative
   double            commission;
   double            swap;
   int               closed_trades;   // closed positions
   int               wins;
   int               losses;
   double            lots;
   double            largest_win;
   double            largest_loss;
   double            profit_factor;
   double            win_rate;        // %
   double            expectancy;      // net / closed
   double            avg_win;
   double            avg_loss;        // negative
   long              avg_hold_sec;
   long              max_hold_sec;
   double            max_dd;          // trading-curve peak-to-trough, value
   double            max_dd_pct;      // vs actual balance at peak
   double            recovery;        // net / max_dd
   double            growth_pct;      // net / deposits
   int               dep_count;
   double            dep_sum;
   int               wd_count;
   double            wd_sum;          // negative
   double            initial_deposit;
   datetime          first_trade;
   int               ea_trades;       // OUT deals, magic!=0
   int               manual_trades;
   double            ea_profit;
   double            manual_profit;
   double            today_pl;
   double            week_pl;
   double            month_pl;
   double            reset_pl;        // realized net since the prop-day reset anchor
   double            reset_cash;      // deposits/withdrawals since that anchor
  };

//--- module state ----------------------------------------------------
KPAccount  g_acc;
KPTotals   g_tot;

KPPosRec   g_pos[];        // reconstructed positions
int        g_pos_count = 0;

KPAggRow   g_days[];       // chronological
KPAggRow   g_weeks[];
KPAggRow   g_months[];
KPAggRow   g_years[];
KPAggRow   g_syms[];
KPAggRow   g_magics[];

KPLivePos  g_live[];
int        g_live_count = 0;

KPLiveOrd  g_ord[];
int        g_ord_count = 0;

// closed positions in close-time order (indices into g_pos)
int        g_close_order[];
int        g_close_n = 0;

// balance curve (per OUT/balance deal): actual balance + trading-only
datetime   g_curve_t[];
double     g_curve_bal[];   // actual account balance
double     g_curve_trd[];   // cumulative trading pl only
int        g_curve_n = 0;

// intraday equity samples (timer-fed ring, chronological flat array)
double     g_eq_smp[];
int        g_eq_n   = 0;
int        g_eq_max = 1800;   // 1s sampling => 30min window

datetime   g_last_rebuild = 0;

//--- helpers ---------------------------------------------------------
datetime KP_DayStart(const datetime t)
  {
   return (datetime)(t - (t % 86400));
  }

// prop-day reset hour (server time), set from EA input
int KP_ResetHour = 0;

// most recent daily reset anchor at KP_ResetHour:00 server time
datetime KP_ResetAnchor(const datetime now)
  {
   datetime a = KP_DayStart(now) + KP_ResetHour * 3600;
   if(now < a)
      a -= 86400;
   return a;
  }

datetime KP_WeekStart(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   int dow = (dt.day_of_week == 0 ? 7 : dt.day_of_week); // Mon=1..Sun=7
   return KP_DayStart(t) - (dow - 1) * 86400;
  }

datetime KP_MonthStart(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   dt.day = 1; dt.hour = 0; dt.min = 0; dt.sec = 0;
   return StructToTime(dt);
  }

datetime KP_YearStart(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   dt.mon = 1; dt.day = 1; dt.hour = 0; dt.min = 0; dt.sec = 0;
   return StructToTime(dt);
  }

void KP_AggInit(KPAggRow &r)
  {
   r.label = ""; r.key_time = 0; r.key_magic = 0;
   r.trades = 0; r.wins = 0; r.losses = 0;
   r.lots = 0; r.profit = 0; r.gross_win = 0; r.gross_loss = 0;
   r.cashflow = 0;
   r.peak = -DBL_MAX; r.peak_bal = 0; r.dd = 0; r.dd_pct = 0;
  }

// intra-bucket drawdown tracking on the running trading-equity value;
// bal_now = actual account balance at the same moment (pct denominator)
void KP_RowDD(KPAggRow &r, const double trd_now, const double bal_now)
  {
   if(trd_now > r.peak)
     {
      r.peak = trd_now;
      r.peak_bal = bal_now;
     }
   double d = r.peak - trd_now;
   if(d > r.dd)
     {
      r.dd = d;
      r.dd_pct = (r.peak_bal > 0.0000001 ? d / r.peak_bal * 100.0 : 0.0);
     }
  }

// feed pre-deal and post-deal equity so the first losing deal of a
// bucket still registers against the pre-deal watermark
void KP_RowDD2(KPAggRow &r, const double trd_now, const double net,
               const double bal_now)
  {
   KP_RowDD(r, trd_now - net, bal_now - net);
   KP_RowDD(r, trd_now, bal_now);
  }

// drawdown of the bucket whose start time equals key (0 if none)
double KPData_DDForKey(const KPAggRow &rows[], const datetime key)
  {
   for(int i=ArraySize(rows)-1; i>=0; i--)
      if(rows[i].key_time == key)
         return rows[i].dd;
   return 0.0;
  }

// append-or-last bucket for chronological period aggregation
int KP_PeriodBucket(KPAggRow &rows[], const datetime key, const string label)
  {
   int n = ArraySize(rows);
   if(n > 0 && rows[n-1].key_time == key)
      return n - 1;
   // history deals can be slightly out of order - search back a few
   for(int i=n-1; i>=0 && i>=n-4; i--)
      if(rows[i].key_time == key)
         return i;
   ArrayResize(rows, n+1, 64);
   KP_AggInit(rows[n]);
   rows[n].key_time = key;
   rows[n].label    = label;
   return n;
  }

int KP_NameBucket(KPAggRow &rows[], const string label)
  {
   int n = ArraySize(rows);
   for(int i=0; i<n; i++)
      if(rows[i].label == label)
         return i;
   ArrayResize(rows, n+1, 16);
   KP_AggInit(rows[n]);
   rows[n].label = label;
   return n;
  }

// period bucket helpers (week label year comes from the WEEK START so a
// deal on Jan 1 belonging to last year's final week is not mislabeled)
int KP_DayBucket(const datetime dtime)
  {
   return KP_PeriodBucket(g_days, KP_DayStart(dtime), KP_DateOnly(dtime));
  }

int KP_WeekBucket(const datetime dtime)
  {
   datetime ws = KP_WeekStart(dtime);
   MqlDateTime wsdt;
   TimeToStruct(ws, wsdt);
   int wk = (int)((ws - KP_YearStart(ws)) / (7*86400)) + 1;
   return KP_PeriodBucket(g_weeks, ws, StringFormat("%04d W%02d", wsdt.year, wk));
  }

int KP_MonthBucket(const datetime dtime)
  {
   MqlDateTime dt;
   TimeToStruct(dtime, dt);
   return KP_PeriodBucket(g_months, KP_MonthStart(dtime),
                          StringFormat("%04d.%02d", dt.year, dt.mon));
  }

int KP_YearBucket(const datetime dtime)
  {
   MqlDateTime dt;
   TimeToStruct(dtime, dt);
   return KP_PeriodBucket(g_years, KP_YearStart(dtime),
                          StringFormat("%04d", dt.year));
  }

//--- magic aliases: "12345=KING S1;678=Grid v2" from EA input --------
long   g_alias_magic[];
string g_alias_name[];
int    g_alias_n = 0;

void KP_AliasLoad(const string csv)
  {
   ArrayFree(g_alias_magic);
   ArrayFree(g_alias_name);
   g_alias_n = 0;
   string pairs[];
   int n = StringSplit(csv, ';', pairs);
   for(int i=0; i<n; i++)
     {
      int eq = StringFind(pairs[i], "=");
      if(eq <= 0)
         continue;
      string k = StringSubstr(pairs[i], 0, eq);
      string v = StringSubstr(pairs[i], eq+1);
      StringTrimLeft(k); StringTrimRight(k);
      StringTrimLeft(v); StringTrimRight(v);
      long m = StringToInteger(k);
      if(m == 0 || StringLen(v) == 0)
         continue;
      int a = g_alias_n;
      ArrayResize(g_alias_magic, a+1);
      ArrayResize(g_alias_name, a+1);
      g_alias_magic[a] = m;
      g_alias_name[a]  = v;
      g_alias_n++;
     }
  }

string KP_MagicName(const long magic)
  {
   for(int i=0; i<g_alias_n; i++)
      if(g_alias_magic[i] == magic)
         return g_alias_name[i];
   return (magic == 0 ? "" : (string)magic);
  }

int KP_MagicBucket(KPAggRow &rows[], const long magic)
  {
   int n = ArraySize(rows);
   for(int i=0; i<n; i++)
      if(rows[i].key_magic == magic)
         return i;
   ArrayResize(rows, n+1, 16);
   KP_AggInit(rows[n]);
   rows[n].key_magic = magic;
   rows[n].label = KP_MagicName(magic);   // "" for 0: localized at display
   return n;
  }

void KP_AddDealToRow(KPAggRow &r, const double net, const double lots)
  {
   r.trades++;
   r.lots += lots;
   r.profit += net;
   if(net >= 0) { r.wins++;  r.gross_win  += net; }
   else         { r.losses++; r.gross_loss += net; }
  }

//--- account snapshot ------------------------------------------------
void KPData_UpdateAccount()
  {
   g_acc.login        = AccountInfoInteger(ACCOUNT_LOGIN);
   g_acc.server       = AccountInfoString(ACCOUNT_SERVER);
   g_acc.company      = AccountInfoString(ACCOUNT_COMPANY);
   g_acc.currency     = AccountInfoString(ACCOUNT_CURRENCY);
   g_acc.leverage     = AccountInfoInteger(ACCOUNT_LEVERAGE);
   g_acc.balance      = AccountInfoDouble(ACCOUNT_BALANCE);
   g_acc.equity       = AccountInfoDouble(ACCOUNT_EQUITY);
   g_acc.margin       = AccountInfoDouble(ACCOUNT_MARGIN);
   g_acc.margin_free  = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   g_acc.margin_level = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
   // equity = balance + credit + floating, so a bonus/credit account
   // would otherwise report a permanent phantom floating profit and bias
   // every floating guard (loss, profit, prop day budget)
   g_acc.floating_pl  = g_acc.equity - g_acc.balance
                      - AccountInfoDouble(ACCOUNT_CREDIT);
   g_acc.positions    = PositionsTotal();
   g_acc.pendings     = OrdersTotal();
   g_acc.algo_ok      = (bool)TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)
                        && (bool)MQLInfoInteger(MQL_TRADE_ALLOWED);
  }

//--- live positions --------------------------------------------------
void KPData_UpdateLive()
  {
   int total = PositionsTotal();
   ArrayResize(g_live, total);
   g_live_count = 0;
   for(int i=0; i<total; i++)
     {
      ulong tk = PositionGetTicket(i);
      if(tk == 0)
         continue;
      KPLivePos p;
      p.ticket     = tk;
      p.pos_id     = PositionGetInteger(POSITION_IDENTIFIER);
      p.symbol     = PositionGetString(POSITION_SYMBOL);
      p.magic      = PositionGetInteger(POSITION_MAGIC);
      p.type       = (int)PositionGetInteger(POSITION_TYPE);
      p.lots       = PositionGetDouble(POSITION_VOLUME);
      p.price_open = PositionGetDouble(POSITION_PRICE_OPEN);
      p.price_cur  = PositionGetDouble(POSITION_PRICE_CURRENT);
      p.sl         = PositionGetDouble(POSITION_SL);
      p.tp         = PositionGetDouble(POSITION_TP);
      p.swap       = PositionGetDouble(POSITION_SWAP);
      p.profit     = PositionGetDouble(POSITION_PROFIT) + p.swap;
      p.time       = (datetime)PositionGetInteger(POSITION_TIME);
      g_live[g_live_count++] = p;
     }
   // stable order: rows must never reshuffle under the cursor between
   // renders, or a per-row close button hits a different ticket
   for(int a=1; a<g_live_count; a++)
     {
      KPLivePos key = g_live[a];
      int b = a - 1;
      while(b >= 0 && g_live[b].ticket > key.ticket)
        {
         g_live[b+1] = g_live[b];
         b--;
        }
      g_live[b+1] = key;
     }

   // pending orders
   int ords = OrdersTotal();
   ArrayResize(g_ord, ords);
   g_ord_count = 0;
   for(int i=0; i<ords; i++)
     {
      ulong tk = OrderGetTicket(i);
      if(tk == 0)
         continue;
      KPLiveOrd o;
      o.ticket    = tk;
      o.symbol    = OrderGetString(ORDER_SYMBOL);
      o.magic     = OrderGetInteger(ORDER_MAGIC);
      o.type      = (int)OrderGetInteger(ORDER_TYPE);
      o.lots      = OrderGetDouble(ORDER_VOLUME_CURRENT);
      o.price     = OrderGetDouble(ORDER_PRICE_OPEN);
      o.price_cur = OrderGetDouble(ORDER_PRICE_CURRENT);
      o.sl        = OrderGetDouble(ORDER_SL);
      o.tp        = OrderGetDouble(ORDER_TP);
      o.time      = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
      g_ord[g_ord_count++] = o;
     }
  }

//--- equity ring buffer ---------------------------------------------
void KPData_SampleEquity()
  {
   if(ArraySize(g_eq_smp) != g_eq_max)
     {
      ArrayResize(g_eq_smp, g_eq_max);
      g_eq_n = 0;
     }
   if(g_eq_n < g_eq_max)
      g_eq_smp[g_eq_n++] = g_acc.equity;
   else
     {
      for(int i=0; i<g_eq_max-1; i++)
         g_eq_smp[i] = g_eq_smp[i+1];
      g_eq_smp[g_eq_max-1] = g_acc.equity;
     }
  }

//--- full history rebuild -------------------------------------------
string g_hist_fp = "";

void KPData_Rebuild()
  {
   // fast path: with no new deals and no period-boundary crossing the
   // whole aggregation is provably identical - skip the O(deals) scan.
   // (10k+ deal scalper accounts stalled the timer every 20s otherwise)
   if(HistorySelect(0, TimeCurrent() + 86400))
     {
      int   deals0 = HistoryDealsTotal();
      ulong last0  = (deals0 > 0 ? HistoryDealGetTicket(deals0-1) : 0);
      // the /600 term bounds staleness from server-side deal mutations
      // (dividend/profit corrections) to at most 10 minutes
      string fp = StringFormat("%d|%I64u|%I64d|%I64d|%I64d|%I64d",
                  deals0, last0,
                  (long)KP_DayStart(TimeCurrent()),
                  (long)KP_WeekStart(TimeCurrent()),
                  (long)KP_ResetAnchor(TimeCurrent()),
                  (long)(TimeCurrent() / 600));
      if(fp == g_hist_fp)
        {
         g_last_rebuild = TimeCurrent();
         KPData_ComputeExcursions();   // keep filling the MFE/MAE cache
         return;
        }
      g_hist_fp = fp;
     }
   // a failed select must leave the previous statistics AND the previous
   // rebuild stamp intact - zeroing them would tell the prop guard the
   // day is flat and relax the daily-loss limit
   if(!HistorySelect(0, TimeCurrent() + 86400))
      return;
   g_last_rebuild = TimeCurrent();

   // reset
   ZeroMemory(g_tot);
   ArrayFree(g_pos);      g_pos_count = 0;
   ArrayFree(g_days);     ArrayFree(g_weeks);
   ArrayFree(g_months);   ArrayFree(g_years);
   ArrayFree(g_syms);     ArrayFree(g_magics);
   ArrayFree(g_curve_t);  ArrayFree(g_curve_bal);
   ArrayFree(g_curve_trd);
   g_curve_n = 0;

   int deals = HistoryDealsTotal();
   CHashMap<long,int> posmap;

   datetime today_t = KP_DayStart(TimeCurrent());
   datetime week_t  = KP_WeekStart(TimeCurrent());
   datetime month_t = KP_MonthStart(TimeCurrent());
   datetime reset_t = KP_ResetAnchor(TimeCurrent());

   double bal = 0.0;   // running actual balance
   double trd = 0.0;   // running trading-only pl
   // seeded on the first evaluation like KP_RowDD does per bucket;
   // leaving peak_bal at 0 made the first drawdown report 0.0%
   double peak_trd = -DBL_MAX, peak_bal = 0.0;

   for(int i=0; i<deals; i++)
     {
      ulong tk = HistoryDealGetTicket(i);
      if(tk == 0)
         continue;

      long     dtype  = HistoryDealGetInteger(tk, DEAL_TYPE);
      datetime dtime  = (datetime)HistoryDealGetInteger(tk, DEAL_TIME);
      double   profit = HistoryDealGetDouble(tk, DEAL_PROFIT);
      double   comm   = HistoryDealGetDouble(tk, DEAL_COMMISSION);
      double   swap   = HistoryDealGetDouble(tk, DEAL_SWAP);
      double   fee    = HistoryDealGetDouble(tk, DEAL_FEE);
      double   net    = profit + comm + swap + fee;

      // ---- cash flow (deposit / withdrawal / credit etc.) ----
      if(dtype == DEAL_TYPE_BALANCE || dtype == DEAL_TYPE_CREDIT ||
         dtype == DEAL_TYPE_BONUS   || dtype == DEAL_TYPE_CHARGE ||
         dtype == DEAL_TYPE_CORRECTION)
        {
         if(dtype == DEAL_TYPE_BALANCE)
           {
            if(profit >= 0) { g_tot.dep_count++; g_tot.dep_sum += profit; }
            else            { g_tot.wd_count++;  g_tot.wd_sum  += profit; }
            if(g_tot.initial_deposit == 0.0 && profit > 0)
               g_tot.initial_deposit = profit;
           }
         bal += net;
         // period cashflow attribution
         int di = KP_PeriodBucket(g_days, KP_DayStart(dtime), KP_DateOnly(dtime));
         g_days[di].cashflow += net;
         if(dtime >= reset_t)
            g_tot.reset_cash += net;   // denominator of the prop day move
         // curve point
         int n = g_curve_n;
         ArrayResize(g_curve_t,   n+1, 256);
         ArrayResize(g_curve_bal, n+1, 256);
         ArrayResize(g_curve_trd, n+1, 256);
         g_curve_t[n] = dtime; g_curve_bal[n] = bal; g_curve_trd[n] = trd;
         g_curve_n++;
         // NOTE: peak_bal is intentionally NOT updated on cash flow —
         // a deposit landing mid-drawdown must not dilute the DD%
         continue;
        }

      if(dtype != DEAL_TYPE_BUY && dtype != DEAL_TYPE_SELL)
         continue;

      long   entry  = HistoryDealGetInteger(tk, DEAL_ENTRY);
      long   pos_id = HistoryDealGetInteger(tk, DEAL_POSITION_ID);
      long   magic  = HistoryDealGetInteger(tk, DEAL_MAGIC);
      string symbol = HistoryDealGetString(tk, DEAL_SYMBOL);
      double lots   = HistoryDealGetDouble(tk, DEAL_VOLUME);

      // ---- position reconstruction ----
      int pidx = -1;
      if(!posmap.TryGetValue(pos_id, pidx))
        {
         pidx = g_pos_count;
         ArrayResize(g_pos, pidx+1, 256);
         g_pos[pidx].pos_id     = pos_id;
         g_pos[pidx].symbol     = symbol;
         g_pos[pidx].magic      = magic;
         g_pos[pidx].dir        = -1;
         g_pos[pidx].open_time  = dtime;
         g_pos[pidx].close_time = 0;
         g_pos[pidx].lots       = 0;
         g_pos[pidx].vwap_num   = 0;
         g_pos[pidx].sl0        = 0;
         g_pos[pidx].exit_num   = 0;
         g_pos[pidx].lots_out   = 0;
         g_pos[pidx].net        = 0;
         g_pos[pidx].closed     = false;
         posmap.Add(pos_id, pidx);
         g_pos_count++;
        }
      g_pos[pidx].net += net;
      // INOUT is a reversal: it closes the existing exposure and opens
      // the remainder the other way. Counting its full volume as BOTH an
      // entry and an exit inflated lots, lots_out and both VWAPs.
      if(entry == DEAL_ENTRY_IN)
        {
         if(g_pos[pidx].dir == -1)
            g_pos[pidx].dir = (dtype == DEAL_TYPE_BUY ? 0 : 1);
         g_pos[pidx].lots += lots;
         g_pos[pidx].vwap_num += HistoryDealGetDouble(tk, DEAL_PRICE) * lots;
         if(g_pos[pidx].sl0 == 0)
            g_pos[pidx].sl0 = HistoryDealGetDouble(tk, DEAL_SL);
         if(g_pos[pidx].open_time == 0 || dtime < g_pos[pidx].open_time)
            g_pos[pidx].open_time = dtime;
        }
      if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY)
        {
         if(dtime > g_pos[pidx].close_time)
            g_pos[pidx].close_time = dtime;
         g_pos[pidx].exit_num += HistoryDealGetDouble(tk, DEAL_PRICE) * lots;
         g_pos[pidx].lots_out += lots;
        }
      else if(entry == DEAL_ENTRY_INOUT)
        {
         // split the reversal: the part that offsets open volume is an
         // exit, whatever is left opens the new side
         double still_open = g_pos[pidx].lots - g_pos[pidx].lots_out;
         double closing    = MathMin(MathMax(0.0, still_open), lots);
         double opening    = lots - closing;
         double dprice     = HistoryDealGetDouble(tk, DEAL_PRICE);
         if(closing > 0)
           {
            g_pos[pidx].exit_num += dprice * closing;
            g_pos[pidx].lots_out += closing;
            if(dtime > g_pos[pidx].close_time)
               g_pos[pidx].close_time = dtime;
           }
         if(opening > 0)
           {
            g_pos[pidx].lots     += opening;
            g_pos[pidx].vwap_num += dprice * opening;
            g_pos[pidx].dir = (dtype == DEAL_TYPE_BUY ? 0 : 1);
           }
        }

      // ---- commissions of IN deals go to totals/buckets too ----
      bool is_out = (entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY ||
                     entry == DEAL_ENTRY_INOUT);

      g_tot.commission += comm + fee;
      g_tot.swap       += swap;

      bal += net;
      trd += net;

      if(!is_out)
        {
         if(MathAbs(net) > 0.0000001)
           {
            // entry commission: attribute to ALL buckets so every
            // aggregation level reconciles with the account totals
            g_days[KP_DayBucket(dtime)].profit     += net;
            g_weeks[KP_WeekBucket(dtime)].profit   += net;
            g_months[KP_MonthBucket(dtime)].profit += net;
            g_years[KP_YearBucket(dtime)].profit   += net;
            int si = KP_NameBucket(g_syms, symbol);
            g_syms[si].profit += net;
            int mi = KP_MagicBucket(g_magics, magic);
            g_magics[mi].profit += net;
            if(dtime >= today_t) g_tot.today_pl += net;
            if(dtime >= week_t)  g_tot.week_pl  += net;
            if(dtime >= month_t) g_tot.month_pl += net;
            if(dtime >= reset_t) g_tot.reset_pl += net;
           }
         continue;
        }

      // ---- OUT deal: full stats attribution ----
      int di = KP_DayBucket(dtime);
      KP_AddDealToRow(g_days[di], net, lots);
      KP_RowDD2(g_days[di], trd, net, bal);

      int wi = KP_WeekBucket(dtime);
      KP_AddDealToRow(g_weeks[wi], net, lots);
      KP_RowDD2(g_weeks[wi], trd, net, bal);

      int mi2 = KP_MonthBucket(dtime);
      KP_AddDealToRow(g_months[mi2], net, lots);
      KP_RowDD2(g_months[mi2], trd, net, bal);

      int yi = KP_YearBucket(dtime);
      KP_AddDealToRow(g_years[yi], net, lots);
      KP_RowDD2(g_years[yi], trd, net, bal);

      int si = KP_NameBucket(g_syms, symbol);
      KP_AddDealToRow(g_syms[si], net, lots);

      int mgi = KP_MagicBucket(g_magics, g_pos[pidx].magic);
      KP_AddDealToRow(g_magics[mgi], net, lots);

      // EA vs manual (per OUT deal)
      // attribute by the magic that OPENED the position: a closing deal
      // carries whoever closed it (the panel, another EA, the user)
      long omagic = g_pos[pidx].magic;
      if(omagic != 0) { g_tot.ea_trades++;     g_tot.ea_profit += net; }
      else            { g_tot.manual_trades++; g_tot.manual_profit += net; }

      // quick period nets
      if(dtime >= today_t) g_tot.today_pl += net;
      if(dtime >= week_t)  g_tot.week_pl  += net;
      if(dtime >= month_t) g_tot.month_pl += net;
      if(dtime >= reset_t) g_tot.reset_pl += net;

      g_tot.lots += lots;
      if(g_tot.first_trade == 0)
         g_tot.first_trade = dtime;

      // curve point on every OUT deal
      int n = g_curve_n;
      ArrayResize(g_curve_t,   n+1, 256);
      ArrayResize(g_curve_bal, n+1, 256);
      ArrayResize(g_curve_trd, n+1, 256);
      g_curve_t[n] = dtime; g_curve_bal[n] = bal; g_curve_trd[n] = trd;
      g_curve_n++;

      // drawdown on trading-only curve, pct vs actual balance at peak
      // feed the pre-deal watermark first so the very first losing deal
      // is measured against the balance it started from (mirrors
      // KP_RowDD2); otherwise the opening drawdown reported 0.0%
      for(int f=0; f<2; f++)
        {
         double t_v = (f == 0 ? trd - net : trd);
         double b_v = (f == 0 ? bal - net : bal);
         if(t_v >= peak_trd)
           {
            peak_trd = t_v;
            peak_bal = b_v;
           }
         else
           {
            double dd = peak_trd - t_v;
            if(dd > g_tot.max_dd)
              {
               g_tot.max_dd = dd;
               g_tot.max_dd_pct = (peak_bal > 0 ? dd / peak_bal * 100.0 : 0.0);
              }
           }
        }
     }

   // ---- totals from closed positions ----
   long hold_sum = 0;
   int  hold_cnt = 0;
   for(int i=0; i<g_pos_count; i++)
     {
      // closed = has a close deal and its id is absent from live positions
      bool open = (g_pos[i].close_time == 0);
      if(!open)
         for(int j=0; j<g_live_count; j++)
            if(g_live[j].pos_id == g_pos[i].pos_id)
              { open = true; break; }
      g_pos[i].closed = !open;
      if(!g_pos[i].closed)
         continue;

      double net = g_pos[i].net;
      g_tot.closed_trades++;
      g_tot.net += net;
      if(net >= 0)
        {
         g_tot.wins++;
         g_tot.gross_profit += net;
         if(net > g_tot.largest_win) g_tot.largest_win = net;
        }
      else
        {
         g_tot.losses++;
         g_tot.gross_loss += net;
         if(net < g_tot.largest_loss) g_tot.largest_loss = net;
        }
      long hold = (long)(g_pos[i].close_time - g_pos[i].open_time);
      if(hold >= 0)
        {
         hold_sum += hold;
         hold_cnt++;
         if(hold > g_tot.max_hold_sec) g_tot.max_hold_sec = hold;
        }
     }

   g_tot.profit_factor = (g_tot.gross_loss < -0.0000001 ?
                          g_tot.gross_profit / (-g_tot.gross_loss) : 0.0);
   g_tot.win_rate   = (g_tot.closed_trades > 0 ?
                       100.0 * g_tot.wins / g_tot.closed_trades : 0.0);
   g_tot.expectancy = (g_tot.closed_trades > 0 ?
                       g_tot.net / g_tot.closed_trades : 0.0);
   g_tot.avg_win    = (g_tot.wins   > 0 ? g_tot.gross_profit / g_tot.wins   : 0.0);
   g_tot.avg_loss   = (g_tot.losses > 0 ? g_tot.gross_loss   / g_tot.losses : 0.0);
   g_tot.avg_hold_sec = (hold_cnt > 0 ? hold_sum / hold_cnt : 0);
   g_tot.recovery   = (g_tot.max_dd > 0.0000001 ? g_tot.net / g_tot.max_dd : 0.0);
   g_tot.growth_pct = (g_tot.dep_sum > 0.0000001 ?
                       g_tot.net / g_tot.dep_sum * 100.0 : 0.0);

   // closed positions sorted by close time: pack (time<<20 | index) and
   // let ArraySort do the work; index fits 20 bits (guarded below)
   g_close_n = 0;
   ArrayResize(g_close_order, g_tot.closed_trades);
   if(g_pos_count < (1 << 20))
     {
      long keys[];
      ArrayResize(keys, g_tot.closed_trades);
      int kn = 0;
      for(int i=0; i<g_pos_count; i++)
         if(g_pos[i].closed)
            keys[kn++] = (((long)g_pos[i].close_time) << 20) | (long)i;
      if(kn > 0)
        {
         ArraySort(keys);
         for(int i=0; i<kn; i++)
            g_close_order[i] = (int)(keys[i] & 0xFFFFF);
         g_close_n = kn;
        }
     }

   KPData_ComputeExcursions();
  }

//--- MFE / MAE excursion engine -------------------------------------
// Replays M1 bars per closed position (newest KP_EXC_SCOPE positions),
// converts price excursions to account money via tick value.
// Incremental: <= KP_EXC_BATCH new positions per rebuild, cached by id.
#define KP_EXC_SCOPE 200
#define KP_EXC_BATCH 40

struct KPExc
  {
   long              pos_id;
   double            mfe;        // max favorable excursion, money
   double            mae;        // max adverse excursion, money
   double            net;        // realized net of the position
   int               dir;        // 0 buy 1 sell
   double            entry;      // entry vwap
   double            exitv;      // exit vwap
   double            hi;         // window high
   double            lo;         // window low
  };

KPExc g_exc[];
int   g_exc_n = 0;

bool KPExc_Have(const long pid)
  {
   for(int i=0; i<g_exc_n; i++)
      if(g_exc[i].pos_id == pid)
         return true;
   return false;
  }

void KPData_ComputeExcursions()
  {
   int  considered = 0, added = 0;
   long bars_budget = 200000;
   MqlRates rates[];

   for(int i=g_pos_count-1; i>=0; i--)
     {
      if(considered >= KP_EXC_SCOPE || added >= KP_EXC_BATCH || bars_budget <= 0)
         break;
      if(!g_pos[i].closed)
         continue;
      considered++;
      if(KPExc_Have(g_pos[i].pos_id))
         continue;
      if(g_pos[i].lots <= 0 || g_pos[i].dir < 0 ||
         g_pos[i].close_time <= g_pos[i].open_time - 60)
         continue;

      double ts = SymbolInfoDouble(g_pos[i].symbol, SYMBOL_TRADE_TICK_SIZE);
      double tv = SymbolInfoDouble(g_pos[i].symbol, SYMBOL_TRADE_TICK_VALUE);
      if(ts <= 0 || tv <= 0)
         continue;   // symbol gone from market watch

      double entry = g_pos[i].vwap_num / g_pos[i].lots;
      ResetLastError();
      int got = CopyRates(g_pos[i].symbol, PERIOD_M1,
                          g_pos[i].open_time, g_pos[i].close_time, rates);
      if(got <= 0)
        {
         // history that never arrives (delisted symbol, broker cut-off)
         // would otherwise be re-requested on every rebuild forever
         if(KP_StoreGet("nx_" + (string)g_pos[i].pos_id, 0) > 2.5)
            continue;
         KP_StoreSet("nx_" + (string)g_pos[i].pos_id,
                     KP_StoreGet("nx_" + (string)g_pos[i].pos_id, 0) + 1);
         continue;
        }
      bars_budget -= got;

      double hi = rates[0].high, lo = rates[0].low;
      for(int b=1; b<got; b++)
        {
         if(rates[b].high > hi) hi = rates[b].high;
         if(rates[b].low  < lo) lo = rates[b].low;
        }
      double fe_p = (g_pos[i].dir == 0 ? hi - entry : entry - lo);
      double ae_p = (g_pos[i].dir == 0 ? entry - lo : hi - entry);
      if(fe_p < 0) fe_p = 0;
      if(ae_p < 0) ae_p = 0;

      // the cache must not outgrow the window it reports on, otherwise
      // the MFE/MAE page aggregates every trade seen since attach while
      // still labelling the sample "n / 200"
      if(g_exc_n >= KP_EXC_SCOPE)
        {
         for(int s=0; s<g_exc_n-1; s++)
            g_exc[s] = g_exc[s+1];
         g_exc_n--;
        }
      int n = g_exc_n;
      ArrayResize(g_exc, n+1, 64);
      g_exc[n].pos_id = g_pos[i].pos_id;
      g_exc[n].mfe    = fe_p / ts * tv * g_pos[i].lots;
      g_exc[n].mae    = ae_p / ts * tv * g_pos[i].lots;
      g_exc[n].net    = g_pos[i].net;
      g_exc[n].dir    = g_pos[i].dir;
      g_exc[n].entry  = entry;
      g_exc[n].exitv  = (g_pos[i].lots_out > 0 ?
                         g_pos[i].exit_num / g_pos[i].lots_out : entry);
      g_exc[n].hi     = hi;
      g_exc[n].lo     = lo;
      g_exc_n++;
      added++;
     }
  }

#endif // KP_DATA_MQH
