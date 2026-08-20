//+------------------------------------------------------------------+
//| KP_UI.mqh - KING PANEL V1.1                                      |
//| Layout core: header / tabs / footer / overview / chart modal     |
//+------------------------------------------------------------------+
#ifndef KP_UI_MQH
#define KP_UI_MQH

#include "KP_Theme.mqh"
#include "KP_Canvas.mqh"
#include "KP_Data.mqh"
#include "KP_Trade.mqh"
#include "KP_News.mqh"

//--- hit ids ---------------------------------------------------------
#define KPHIT_COLLAPSE   1
#define KPHIT_TAB        2
#define KPHIT_PERIOD     3
#define KPHIT_CURVESRC   4
#define KPHIT_CLOSEOP    5
#define KPHIT_CLOSETK    6
#define KPHIT_DELPEND    7
#define KPHIT_RISKTGL    8
#define KPHIT_RISKSTEP   9
#define KPHIT_NEWSFILT   10
#define KPHIT_NEWSREF    11
#define KPHIT_SCROLLUP   12
#define KPHIT_SCROLLDN   13
#define KPHIT_SORT       14
#define KPHIT_SCROLLTRK  15
#define KPHIT_LANG       20
#define KPHIT_EXPAND     21
#define KPHIT_CHARTSEL   22
#define KPHIT_POSSUB     23
#define KPHIT_DELTK      24
#define KPHIT_NEWSALERT  25
#define KPHIT_NEWSSTARS  26
#define KPHIT_NEWSLEAD   27
#define KPHIT_NEWSMARK   28
#define KPHIT_NEWSCUR    29
#define KPHIT_OT_SYM     30
#define KPHIT_OT_LOTS    31
#define KPHIT_OT_PRESET  32
#define KPHIT_OT_SL      33
#define KPHIT_OT_TP      34
#define KPHIT_OT_DIST    35
#define KPHIT_OT_BUY     36
#define KPHIT_OT_SELL    37
#define KPHIT_OT_PEND    38

//--- ui state --------------------------------------------------------
int    g_tab        = 0;      // 0..7
bool   g_collapsed  = false;
int    g_panel_x    = 10;
int    g_panel_y    = 30;
int    g_scroll[10] = {0,0,0,0,0,0,0,0,0,0};
int    g_period     = 0;      // 0 D 1 W 2 M 3 Y
int    g_curve_src  = 0;      // 0 balance history, 1 session equity
bool   g_sort_desc  = true;
int    g_modal      = 0;      // 0 none, 1 charts
int    g_chart_sel  = 0;      // 0 equity 1 daily 2 monthly 3 dd 4 mfe/mae
int    g_pos_sub    = 0;      // 0 positions, 1 pending orders

// order ticket state
string g_ot_symbol  = "";     // defaults to chart symbol on first draw
double g_ot_lots    = 0.0;    // 0 = init from symbol minimum
int    g_ot_sl      = 0;      // points, 0 = none
int    g_ot_tp      = 0;      // points, 0 = none
int    g_ot_dist    = 200;    // pending distance, points

bool   g_dragging   = false;
int    g_drag_dx    = 0;
int    g_drag_dy    = 0;

//--- layout constants (unscaled px) ---------------------------------
#define KPL_PAD    6
#define KPL_HDR    24
#define KPL_ACC    18
#define KPL_TABS   20
#define KPL_FOOT   17
#define KPL_ROW    16
#define KPL_THEAD  17

#define KP_NTABS 8

string KPU_TabName(const int i)
  {
   switch(i)
     {
      case 0: return LL("OVERVIEW", "总览");
      case 1: return LL("ANALYSIS", "分析");
      case 2: return LL("SYMBOLS",  "品种");
      case 3: return LL("MAGICS",   "策略");
      case 4: return LL("TRADE",    "持仓");
      case 5: return LL("ORDER",    "下单");
      case 6: return LL("RISK",     "风控");
      case 7: return LL("NEWS",     "日历");
     }
   return "";
  }

//--- dynamic height: panel fills the chart window -------------------
int g_content_h = 0;   // scaled px available for tab content (set in PanelH)

int KPU_PanelW() { return KP_S(KP_BaseW); }

int KPU_PanelH()
  {
   if(g_collapsed)
      return KP_S(KPL_HDR);
   int chart_h = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
   int frame = KP_S(KPL_HDR + KPL_ACC + KPL_TABS + KPL_FOOT);
   int h = chart_h - g_panel_y - KP_S(4);
   int min_h = frame + KP_S(380);   // tallest fixed layout + fractional-DPI rounding margin
   if(chart_h <= 0 || h < min_h)
      h = min_h;
   g_content_h = h - frame;
   return h;
  }

// visible rows for a scrollable list, from the space the tab's fixed
// chrome leaves over (overheads are the summed unscaled row heights)
int KPU_VisRows(const int slot)
  {
   int ovh = 66;   // overheads carry +6px fractional-DPI rounding margin
   switch(slot)
     {
      case 1:            ovh = 64;  break;   // analysis: selector+head+summary
      case 2: case 3:    ovh = 63;  break;   // agg: section+head+footer line
      case 4: case 8:    ovh = 96;  break;   // trade: summary+ops+subtabs+head
      case 7:            ovh = 109; break;   // news: 2 toolbars+currencies+head+countdown
     }
   if(g_content_h <= 0)
      return 12;
   int v = (g_content_h - KP_S(ovh)) / KP_S(KPL_ROW);
   return MathMax(5, MathMin(60, v));
  }

//--- misc helpers ----------------------------------------------------
string KPU_Trunc(const string txt, const int maxw, const string font, const double pt)
  {
   if(KPC_TextW(txt, font, pt) <= maxw)
      return txt;
   string s = txt;
   while(StringLen(s) > 1)
     {
      s = StringSubstr(s, 0, StringLen(s) - 1);
      if(KPC_TextW(s + "…", font, pt) <= maxw)
         return s + "…";
     }
   return s;
  }

string KPU_LblFont() { return (KP_Lang == 0 ? KP_FontMono : KP_FontCJK); }

// section header: amber tick + title
int KPU_Section(const int x, int y, const string title)
  {
   KPC_Fill(x, y + KP_S(2), KP_S(3), KP_S(10), KP_AMBER);
   KPC_Lbl(x + KP_S(8), y, title, KP_AMBER, 7.0, 0, true);
   return y + KP_S(16);
  }

// key-value row
void KPU_KV(const int x, const int y, const int w, const string k,
            const string v, const uint vclr)
  {
   KPC_Lbl(x, y, k, KP_TXT_DIM, 6.6);
   KPC_Num(x + w, y, v, vclr, 6.8, 2);
  }

// selector chip (active = amber block, inactive = dim text)
void KPU_Chip(const int x, const int y, const int w, const int h,
              const string txt, const bool active,
              const int hit_id, const long arg=0, const double pt=6.6)
  {
   if(active)
     {
      KPC_Fill(x, y, w, h, KP_AMBER);
      KPC_Lbl(x + w/2, y + (h - KP_S(12))/2, txt, KP_BG, pt, 1, true);
     }
   else
     {
      KPC_Fill(x, y, w, h, KP_BTN);
      KPC_Frame(x, y, w, h, KP_SEP);
      KPC_Lbl(x + w/2, y + (h - KP_S(12))/2, txt, KP_TXT_DIM, pt, 1);
     }
   KPC_AddHit(x, y, w, h, hit_id, arg);
  }

//--- header ----------------------------------------------------------
void KPU_DrawHeader(const int W)
  {
   int h = KP_S(KPL_HDR);
   KPC_Fill(0, 0, W, h, KP_BG_HEAD);
   KPC_HLine(0, W-1, h-1, KP_BORDER);

   // logo block
   int lx = KP_S(8);
   KPC_Fill(lx, KP_S(5), KP_S(14), KP_S(14), KP_AMBER);
   KPC_Text(lx + KP_S(7), KP_S(6), "K", KP_BG, KP_FontMono, 8.6, 1, true);
   KPC_Text(lx + KP_S(20), KP_S(4), "KING PANEL", KP_TXT, KP_FontMono, 8.6, 0, true);
   int tw = KPC_TextW("KING PANEL", KP_FontMono, 8.6, true);
   KPC_Text(lx + KP_S(26) + tw, KP_S(7), "V1.2", KP_AMBER, KP_FontMono, 6.6, 0, true);

   // collapse button
   int bx = W - KP_S(24), bw = KP_S(17);
   KPC_Fill(bx, KP_S(4), bw, KP_S(16), KP_BTN);
   KPC_Frame(bx, KP_S(4), bw, KP_S(16), KP_SEP);
   KPC_Num(bx + bw/2, KP_S(6), (g_collapsed ? "+" : "-"), KP_AMBER, 8.6, 1, true);
   KPC_AddHit(bx, 0, KP_S(24), h, KPHIT_COLLAPSE);

   // algo status dot
   uint ac = (g_acc.algo_ok ? KP_GREEN : KP_RED);
   KPC_Fill(W - KP_S(37), KP_S(9), KP_S(6), KP_S(6), ac);

   // language toggle
   int gx = W - KP_S(70), gw = KP_S(26);
   KPC_Fill(gx, KP_S(4), gw, KP_S(16), KP_BTN);
   KPC_Frame(gx, KP_S(4), gw, KP_S(16), KP_SEP);
   KPC_Text(gx + gw/2, KP_S(7), (KP_Lang == 0 ? "EN" : "中"),
            KP_TXT_DIM, (KP_Lang == 0 ? KP_FontMono : KP_FontCJK), 6.6, 1);
   KPC_AddHit(gx, 0, gw, h, KPHIT_LANG);

   // brand: telegram channel, understated
   if(KP_BrandShow)
      KPC_Text(W - KP_S(76), KP_S(7), KP_BrandChannel, KP_TXT_FAINT,
               KP_FontMono, 6.4, 2);
  }

//--- account strip ---------------------------------------------------
void KPU_DrawAccStrip(const int W, const int y0)
  {
   int h = KP_S(KPL_ACC);
   KPC_Fill(0, y0, W, h, KP_BG_TAB);
   KPC_HLine(0, W-1, y0 + h - 1, KP_SEP);
   int x = KP_S(8);
   int ty = y0 + KP_S(3);

   string acc = StringFormat("%I64d", g_acc.login);
   KPC_Num(x, ty, acc, KP_AMBER, 7.0, 0, true);
   x += KPC_TextW(acc, KP_FontMono, 7.0, true) + KP_S(10);

   string srv = KPU_Trunc(g_acc.server, KP_S(150), KP_FontMono, 7.0);
   KPC_Num(x, ty, srv, KP_TXT_DIM, 7.0);
   x += KPC_TextW(srv, KP_FontMono, 7.0) + KP_S(10);

   string lev = StringFormat("1:%d", (int)g_acc.leverage);
   KPC_Num(x, ty, lev, KP_TXT_DIM, 7.0);
   x += KPC_TextW(lev, KP_FontMono, 7.0) + KP_S(10);

   KPC_Num(x, ty, g_acc.currency, KP_TXT_DIM, 7.0);

   string ps = StringFormat(LL("POS %d · ORD %d", "持仓 %d · 挂单 %d"),
                            g_acc.positions, g_acc.pendings);
   KPC_Lbl(W - KP_S(8), ty, ps,
           (g_acc.positions > 0 ? KP_CYAN : KP_TXT_FAINT), 6.6, 2);
  }

//--- tab bar ---------------------------------------------------------
void KPU_DrawTabs(const int W, const int y0)
  {
   int h = KP_S(KPL_TABS);
   KPC_Fill(0, y0, W, h, KP_BG_TAB);
   KPC_HLine(0, W-1, y0 + h - 1, KP_SEP);

   int tw = W / KP_NTABS;
   for(int i=0; i<KP_NTABS; i++)
     {
      int x = i * tw;
      int ww = (i == KP_NTABS-1 ? W - (KP_NTABS-1)*tw : tw);
      bool act = (i == g_tab && g_modal == 0);
      if(act)
        {
         KPC_Fill(x + KP_S(2), y0 + KP_S(2), ww - KP_S(4), h - KP_S(5), KP_AMBER);
         KPC_Lbl(x + ww/2, y0 + KP_S(4), KPU_TabName(i), KP_BG,
                 (KP_Lang == 0 ? 6.4 : 7.2), 1, true);
        }
      else
         KPC_Lbl(x + ww/2, y0 + KP_S(4), KPU_TabName(i), KP_TXT_DIM,
                 (KP_Lang == 0 ? 6.4 : 7.2), 1);
      KPC_AddHit(x, y0, ww, h, KPHIT_TAB, i);
     }
  }

//--- footer ----------------------------------------------------------
void KPU_DrawFooter(const int W, const int y0)
  {
   int h = KP_S(KPL_FOOT);
   KPC_Fill(0, y0, W, h, KP_BG_HEAD);
   KPC_HLine(0, W-1, y0, KP_BORDER);
   int ty = y0 + KP_S(3);

   // sessions (approx GMT, DST ignored)
   MqlDateTime g;
   TimeToStruct(TimeGMT(), g);
   int hh = g.hour;
   string names[4] = {"SYD","TYO","LON","NYC"};
   bool   open_[4];
   open_[0] = (hh >= 21 || hh < 6);
   open_[1] = (hh < 9);
   open_[2] = (hh >= 7 && hh < 16);
   open_[3] = (hh >= 12 && hh < 21);
   int x = KP_S(8);
   for(int i=0; i<4; i++)
     {
      uint c = (open_[i] ? KP_GREEN : KP_TXT_FAINT);
      KPC_Fill(x, ty + KP_S(3), KP_S(5), KP_S(5), c);
      KPC_Num(x + KP_S(8), ty, names[i], (open_[i] ? KP_TXT_DIM : KP_TXT_FAINT), 6.4);
      x += KP_S(38);
     }

   if(g_risk_lastmsg != "" && TimeCurrent() - g_risk_lastmsg_t < 120)
     {
      string m = KPU_Trunc(g_risk_lastmsg, W - x - KP_S(96), KPU_LblFont(), 6.4);
      KPC_Lbl(x + KP_S(4), ty, m, KP_YELLOW, 6.4);
     }
   else
     {
      long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      string info = StringFormat("%s  %s %d", _Symbol, LL("SPR", "点差"), (int)spread);
      KPC_Lbl(x + KP_S(4), ty, info, KP_TXT_FAINT, 6.4);
     }

   MqlDateTime st;
   TimeToStruct(TimeTradeServer(), st);
   string clk = StringFormat("SRV %02d:%02d:%02d", st.hour, st.min, st.sec);
   KPC_Num(W - KP_S(8), ty, clk, KP_AMBER, 6.6, 2);
  }

//--- overview tab ----------------------------------------------------
void KPU_DrawOverview(const int W, const int y0)
  {
   int px = KP_S(KPL_PAD);
   int cw = W - 2*px;
   int y  = y0 + KP_S(5);

   //-- KPI tiles
   int tn = 4;
   int gap = KP_S(4);
   int tw = (cw - gap*(tn-1)) / tn;
   int th = KP_S(38);
   for(int i=0; i<tn; i++)
     {
      int x = px + i*(tw+gap);
      KPC_Fill(x, y, tw, th, KP_BG_TILE);
      KPC_Frame(x, y, tw, th, KP_SEP);
      KPC_Fill(x, y, tw, KP_S(1), (i==2 ? KP_PLColor(g_acc.floating_pl) : KP_AMBER_DIM));
      string lab; string v; uint c = KP_TXT;
      switch(i)
        {
         case 0: lab = LL("EQUITY", "净值");
                 v = KP_MoneyAuto(g_acc.equity);  break;
         case 1: lab = LL("BALANCE", "余额");
                 v = KP_MoneyAuto(g_acc.balance); break;
         case 2: lab = LL("FLOAT P&L", "浮动盈亏");
                 v = (g_acc.floating_pl > 0.0000001 ? "+" : "") + KP_MoneyAuto(g_acc.floating_pl);
                 c = KP_PLColor(g_acc.floating_pl); break;
         case 3: lab = LL("MARGIN LVL", "保证金率");
                 v = (g_acc.margin > 0.0000001 ? KP_Money(g_acc.margin_level, 0)+"%" : "--");
                 c = (g_acc.margin > 0.0000001 && g_acc.margin_level < 200 ? KP_RED : KP_TXT);
                 break;
        }
      KPC_Lbl(x + KP_S(5), y + KP_S(4), lab, KP_TXT_FAINT, 5.8);
      KPC_Num(x + tw - KP_S(5), y + KP_S(17), v, c, 9.6, 2, true);
     }
   y += th + KP_S(7);

   //-- curve section
   int sy = y;
   y = KPU_Section(px, y, (g_curve_src == 0 ?
                           LL("EQUITY CURVE · HISTORY", "资金曲线 · 历史") :
                           LL("EQUITY CURVE · LIVE 30M", "资金曲线 · 实时30分钟")));
   int bw = KP_S(32), bh = KP_S(14);
   int bx = px + cw - bw*3 - KP_S(6);
   KPU_Chip(bx, sy, bw, bh, LL("HIST", "历史"), g_curve_src == 0, KPHIT_CURVESRC, 0, 6.2);
   KPU_Chip(bx + bw + KP_S(3), sy, bw, bh, LL("LIVE", "实时"), g_curve_src == 1, KPHIT_CURVESRC, 1, 6.2);
   KPU_Chip(bx + (bw + KP_S(3))*2, sy, bw, bh, LL("FULL", "大图"), false, KPHIT_EXPAND, 0, 6.2);

   // curve absorbs whatever height the window grants beyond the fixed rows
   int chh = MathMax(KP_S(88), MathMin(KP_S(460), g_content_h - KP_S(284)));
   KPC_Fill(px, y, cw, chh, KP_BG_CELL);
   KPC_Frame(px, y, cw, chh, KP_SEP);
   for(int i=1; i<4; i++)
      KPC_HDot(px+1, px+cw-2, y + chh*i/4, KP_SEP);

   int lab_w = KP_S(64);
   double mn = 0, mx = 0, last = 0;
   bool has = false;
   if(g_curve_src == 0 && g_curve_n >= 2)
     {
      KPC_Spark(px + KP_S(3), y + KP_S(3), cw - lab_w - KP_S(6), chh - KP_S(6),
                g_curve_bal, g_curve_n, KP_AMBER, KP_CURVE_FILL);
      mn = g_curve_bal[ArrayMinimum(g_curve_bal, 0, g_curve_n)];
      mx = g_curve_bal[ArrayMaximum(g_curve_bal, 0, g_curve_n)];
      last = g_curve_bal[g_curve_n-1];
      has = true;
     }
   if(g_curve_src == 1 && g_eq_n >= 2)
     {
      KPC_Spark(px + KP_S(3), y + KP_S(3), cw - lab_w - KP_S(6), chh - KP_S(6),
                g_eq_smp, g_eq_n, KP_CYAN, KP_FILL_CYAN, false, g_eq_max);
      mn = g_eq_smp[ArrayMinimum(g_eq_smp, 0, g_eq_n)];
      mx = g_eq_smp[ArrayMaximum(g_eq_smp, 0, g_eq_n)];
      last = g_eq_smp[g_eq_n-1];
      has = true;
     }
   if(has)
     {
      int lx = px + cw - lab_w + KP_S(4);
      KPC_Num(lx, y + KP_S(4),         KP_Money(mx, 0), KP_TXT_DIM, 6.2);
      KPC_Num(lx, y + chh - KP_S(14),  KP_Money(mn, 0), KP_TXT_DIM, 6.2);
      KPC_Num(lx, y + chh/2 - KP_S(6), KP_Money(last, 0), KP_AMBER, 6.6, 0, true);
     }
   else
      KPC_Lbl(px + cw/2, y + chh/2 - KP_S(7), LL("NO DATA", "暂无数据"),
              KP_TXT_FAINT, 7.4, 1);
   y += chh + KP_S(7);

   //-- stats grid (two columns)
   y = KPU_Section(px, y, LL("STATISTICS", "统计指标"));
   int colw = (cw - KP_S(16)) / 2;
   int rh = KP_S(15);
   int x1 = px, x2 = px + colw + KP_S(16);
   int gy = y;

   KPU_KV(x1, gy+rh*0, colw, LL("NET PROFIT", "净利润"),
          KP_MoneySigned(g_tot.net), KP_PLColor(g_tot.net));
   KPU_KV(x1, gy+rh*1, colw, LL("GROSS PROFIT", "总盈利"),
          KP_Money(g_tot.gross_profit), KP_GREEN);
   KPU_KV(x1, gy+rh*2, colw, LL("GROSS LOSS", "总亏损"),
          KP_Money(g_tot.gross_loss), KP_RED);
   KPU_KV(x1, gy+rh*3, colw, LL("PROFIT FACTOR", "盈利因子"),
          (g_tot.profit_factor>0 ? DoubleToString(g_tot.profit_factor,2) : "--"),
          (g_tot.profit_factor >= 1.0 ? KP_GREEN : KP_RED));
   KPU_KV(x1, gy+rh*4, colw, LL("EXPECTANCY", "期望值"),
          KP_MoneySigned(g_tot.expectancy), KP_PLColor(g_tot.expectancy));
   KPU_KV(x1, gy+rh*5, colw, LL("MAX DRAWDOWN", "最大回撤"),
          KP_Money(g_tot.max_dd) + "  " + KP_Pct(g_tot.max_dd_pct), KP_RED);
   KPU_KV(x1, gy+rh*6, colw, LL("RECOVERY", "恢复系数"),
          (g_tot.max_dd>0 ? DoubleToString(g_tot.recovery,2) : "--"), KP_TXT);
   KPU_KV(x1, gy+rh*7, colw, LL("GROWTH", "账户增长"),
          KP_PctSigned(g_tot.growth_pct), KP_PLColor(g_tot.growth_pct));
   KPU_KV(x1, gy+rh*8, colw, LL("DEPOSIT/WD", "入金/出金"),
          StringFormat("%d/%d  ", g_tot.dep_count, g_tot.wd_count) +
          KP_Money(g_tot.dep_sum,0) + "/" + KP_Money(g_tot.wd_sum,0), KP_TXT);

   KPU_KV(x2, gy+rh*0, colw, LL("CLOSED TRADES", "平仓交易"),
          StringFormat("%d (%dW/%dL)", g_tot.closed_trades, g_tot.wins, g_tot.losses), KP_TXT);
   KPU_KV(x2, gy+rh*1, colw, LL("AVG WIN", "平均盈利"),
          KP_Money(g_tot.avg_win), KP_GREEN);
   KPU_KV(x2, gy+rh*2, colw, LL("AVG LOSS", "平均亏损"),
          KP_Money(g_tot.avg_loss), KP_RED);
   KPU_KV(x2, gy+rh*3, colw, LL("BEST TRADE", "最大单笔盈"),
          KP_Money(g_tot.largest_win), KP_GREEN);
   KPU_KV(x2, gy+rh*4, colw, LL("WORST TRADE", "最大单笔亏"),
          KP_Money(g_tot.largest_loss), KP_RED);
   KPU_KV(x2, gy+rh*5, colw, LL("AVG HOLD", "平均持仓"),
          KP_Duration(g_tot.avg_hold_sec), KP_TXT);
   KPU_KV(x2, gy+rh*6, colw, LL("VOLUME", "总手数"),
          KP_Lots(g_tot.lots), KP_TXT);
   double dd_today = KPData_DDForKey(g_days,   KP_DayStart(TimeCurrent()));
   double dd_month = KPData_DDForKey(g_months, KP_MonthStart(TimeCurrent()));
   KPU_KV(x2, gy+rh*7, colw, LL("TODAY MAXDD", "今日最大回撤"),
          (dd_today > 0.005 ? KP_Money(dd_today) : "--"),
          (dd_today > 0.005 ? KP_RED : KP_TXT_DIM));
   KPU_KV(x2, gy+rh*8, colw, LL("MONTH MAXDD", "本月最大回撤"),
          (dd_month > 0.005 ? KP_Money(dd_month) : "--"),
          (dd_month > 0.005 ? KP_RED : KP_TXT_DIM));

   KPC_VLine(px + colw + KP_S(8), gy + KP_S(1), gy + rh*9 - KP_S(3), KP_SEP);
   y = gy + rh*9 + KP_S(6);

   //-- bottom widgets: win ring | EA split | period mini
   int wh = KP_S(46);
   KPC_HLine(px, px+cw-1, y - KP_S(2), KP_SEP);
   int seg = cw / 3;

   int rr = KP_S(17);
   int rcx = px + rr + KP_S(4), rcy = y + wh/2;
   KPC_Ring(rcx, rcy, rr, rr - KP_S(5), g_tot.win_rate/100.0, KP_GREEN, KP_SEP);
   KPC_Num(rcx, rcy - KP_S(6), DoubleToString(g_tot.win_rate,0)+"%", KP_TXT, 6.8, 1, true);
   KPC_Lbl(rcx + rr + KP_S(8), y + KP_S(8), LL("WIN RATE", "胜率"), KP_TXT_DIM, 6.6);
   KPC_Num(rcx + rr + KP_S(8), y + KP_S(22),
           StringFormat("%d/%d", g_tot.wins, g_tot.closed_trades), KP_TXT_FAINT, 6.4);

   int ex = px + seg + KP_S(6);
   int ew = seg - KP_S(16);
   int etot = g_tot.ea_trades + g_tot.manual_trades;
   double eshare = (etot > 0 ? (double)g_tot.ea_trades/etot : 0.0);
   KPC_Lbl(ex, y + KP_S(4), LL("ALGO", "EA算法"), KP_CYAN, 6.4);
   KPC_Lbl(ex + ew, y + KP_S(4), LL("MANUAL", "手动"), KP_TXT_DIM, 6.4, 2);
   KPC_SplitBar(ex, y + KP_S(17), ew, KP_S(7), eshare, KP_CYAN, KP_AMBER_DIM);
   KPC_Num(ex, y + KP_S(28), StringFormat("%d (%.1f%%) %s", g_tot.ea_trades,
           eshare*100.0, KP_MoneySigned(g_tot.ea_profit,0)), KP_TXT_FAINT, 6.2);
   KPC_Num(ex + ew, y + KP_S(28), StringFormat("%d %s", g_tot.manual_trades,
           KP_MoneySigned(g_tot.manual_profit,0)), KP_TXT_FAINT, 6.2, 2);

   int mx2 = px + seg*2 + KP_S(10);
   int mw = seg - KP_S(16);
   KPU_KV(mx2, y + KP_S(2),  mw, LL("TODAY", "今日"),
          KP_MoneySigned(g_tot.today_pl), KP_PLColor(g_tot.today_pl));
   KPU_KV(mx2, y + KP_S(16), mw, LL("WEEK", "本周"),
          KP_MoneySigned(g_tot.week_pl),  KP_PLColor(g_tot.week_pl));
   KPU_KV(mx2, y + KP_S(30), mw, LL("MONTH", "本月"),
          KP_MoneySigned(g_tot.month_pl), KP_PLColor(g_tot.month_pl));

   KPC_VLine(px + seg - KP_S(2), y + KP_S(4), y + wh - KP_S(4), KP_SEP);
   KPC_VLine(px + seg*2 + KP_S(2), y + KP_S(4), y + wh - KP_S(4), KP_SEP);
  }

//--- charts modal ----------------------------------------------------
void KPU_DrawModal(const int W, const int y0)
  {
   int px = KP_S(KPL_PAD);
   int cw = W - 2*px;
   int y  = y0 + KP_S(4);

   // title + close
   KPC_Fill(px, y + KP_S(2), KP_S(3), KP_S(10), KP_AMBER);
   KPC_Lbl(px + KP_S(8), y, LL("CHART CENTER", "图表中心"), KP_AMBER, 7.4, 0, true);
   int cx = px + cw - KP_S(17);
   KPC_Fill(cx, y, KP_S(17), KP_S(15), KP_BTN);
   KPC_Frame(cx, y, KP_S(17), KP_S(15), KP_SEP);
   KPC_Num(cx + KP_S(8), y + KP_S(1), "×", KP_RED, 8.0, 1, true);
   KPC_AddHit(cx, y, KP_S(17), KP_S(15), KPHIT_EXPAND);
   y += KP_S(20);

   // selector
   string cn[5];
   cn[0] = LL("EQUITY", "资金曲线");
   cn[1] = LL("DAILY", "日盈亏");
   cn[2] = LL("MONTHLY", "月盈亏");
   cn[3] = LL("DRAWDOWN", "回撤");
   cn[4] = "MFE/MAE";
   int sw = KP_S(80);
   for(int i=0; i<5; i++)
      KPU_Chip(px + i*(sw + KP_S(4)), y, sw, KP_S(16), cn[i],
               g_chart_sel == i, KPHIT_CHARTSEL, i, 6.2);
   y += KP_S(22);

   // plot area (stretches with the window)
   int lab_w = KP_S(58);
   int pw = cw - lab_w;
   int ph = MathMax(KP_S(180), g_content_h - KP_S(80));
   KPC_Fill(px, y, cw, ph, KP_BG_CELL);
   KPC_Frame(px, y, cw, ph, KP_SEP);
   for(int i=1; i<4; i++)
      KPC_HDot(px+1, px+pw-2, y + ph*i/4, KP_SEP);

   int ix = px + KP_S(4), iy = y + KP_S(4);
   int iw = pw - KP_S(8), ih = ph - KP_S(8);
   string xl0 = "", xl1 = "", xl2 = "";     // x labels
   string sum = "";
   double mn = 0, mx = 0;
   bool has = false;
   bool own_axes = false;

   if(g_chart_sel == 0 && g_curve_n >= 2)
     {
      KPC_Spark(ix, iy, iw, ih, g_curve_bal, g_curve_n, KP_AMBER, KP_CURVE_FILL);
      mn = g_curve_bal[ArrayMinimum(g_curve_bal, 0, g_curve_n)];
      mx = g_curve_bal[ArrayMaximum(g_curve_bal, 0, g_curve_n)];
      xl0 = KP_DateOnly(g_curve_t[0]);
      xl1 = KP_DateOnly(g_curve_t[g_curve_n/2]);
      xl2 = KP_DateOnly(g_curve_t[g_curve_n-1]);
      sum = StringFormat("%s %s   %s %s   %s %s",
            LL("HIGH", "最高"), KP_Money(mx, 0),
            LL("LOW", "最低"), KP_Money(mn, 0),
            LL("LAST", "当前"), KP_Money(g_curve_bal[g_curve_n-1], 0));
      // labels must match the padded scale Spark actually plots with
        {
         double pad = (mx - mn) * 0.07;
         mx += pad;
         mn -= pad;
        }
      has = true;
     }
   else if(g_chart_sel == 1 || g_chart_sel == 2)
     {
      int nsrc = (g_chart_sel == 1 ? ArraySize(g_days) : ArraySize(g_months));
      int take = MathMin(nsrc, (g_chart_sel == 1 ? 60 : 36));
      if(take >= 1)
        {
         double vals[];
         ArrayResize(vals, take);
         double best = 0, worst = 0, tot = 0;
         for(int i=0; i<take; i++)
           {
            double v = (g_chart_sel == 1 ? g_days[nsrc-take+i].profit
                                         : g_months[nsrc-take+i].profit);
            vals[i] = v;
            tot += v;
            if(v > best)  best = v;
            if(v < worst) worst = v;
           }
         KPC_Bars(ix, iy, iw, ih, vals, take, KP_GREEN, KP_RED, KP_TXT_FAINT);
         // labels must match KPC_Bars' scale, which always includes zero
         mn = MathMin(0.0, worst);
         mx = MathMax(0.0, best);
         xl0 = (g_chart_sel == 1 ? g_days[nsrc-take].label : g_months[nsrc-take].label);
         xl2 = (g_chart_sel == 1 ? g_days[nsrc-1].label : g_months[nsrc-1].label);
         sum = StringFormat("%d %s   %s %s   %s %s   %s %s",
               take, LL(g_chart_sel == 1 ? "DAYS" : "MONTHS",
                        g_chart_sel == 1 ? "天" : "个月"),
               LL("BEST", "最佳"), KP_MoneySigned(best, 0),
               LL("WORST", "最差"), KP_MoneySigned(worst, 0),
               LL("SUM", "合计"), KP_MoneySigned(tot, 0));
         has = true;
        }
     }
   else if(g_chart_sel == 3 && g_curve_n >= 2)
     {
      double uw[];
      ArrayResize(uw, g_curve_n);
      double peak = -DBL_MAX, peakbal = 0;
      for(int i=0; i<g_curve_n; i++)
        {
         if(g_curve_trd[i] >= peak)
           {
            peak = g_curve_trd[i];
            peakbal = g_curve_bal[i];
           }
         uw[i] = (peakbal > 0 ? -(peak - g_curve_trd[i]) / peakbal * 100.0 : 0.0);
        }
      KPC_Spark(ix, iy, iw, ih, uw, g_curve_n, KP_RED, KP_FILL_RED, true);
      int mi = ArrayMinimum(uw, 0, g_curve_n);
      mn = uw[mi];
      mx = 0;
      // deepest-point marker + tag
      if(mn < -0.0000001)
        {
         int mpx = ix + (int)MathRound((double)mi * (iw-1) / (g_curve_n-1));
         int mpy = iy + ih - 1;
         g_cv.FillCircle(mpx, mpy - KP_S(2), 3, KP_YELLOW);
         KPC_Num(MathMin(mpx + KP_S(6), ix + iw - KP_S(40)), mpy - KP_S(14),
                 KP_Pct(-mn), KP_YELLOW, 6.6, 0, true);
        }
      xl0 = KP_DateOnly(g_curve_t[0]);
      xl1 = KP_DateOnly(g_curve_t[g_curve_n/2]);
      xl2 = KP_DateOnly(g_curve_t[g_curve_n-1]);
      sum = StringFormat("%s %s (%s)   %s %s",
            LL("MAX DD", "最大回撤"), KP_Money(g_tot.max_dd, 0),
            KP_Pct(g_tot.max_dd_pct),
            LL("NOW", "当前"), KP_Pct(-uw[g_curve_n-1]));
      has = true;
     }
   else if(g_chart_sel == 4 && g_exc_n > 0)
     {
      // MFE x MAE scatter, symmetric money scale so the MFE=MAE diagonal
      // is the true square diagonal and quadrants read at a glance
      double m = 0, sf = 0, sa = 0, sn = 0;
      int nwin = 0;
      for(int i=0; i<g_exc_n; i++)
        {
         if(g_exc[i].mae > m) m = g_exc[i].mae;
         if(g_exc[i].mfe > m) m = g_exc[i].mfe;
         sf += g_exc[i].mfe;
         sa += g_exc[i].mae;
         sn += g_exc[i].net;
         if(g_exc[i].net >= 0) nwin++;
        }
      if(m <= 0) m = 1;
      m *= 1.06;

      int side = MathMin(iw - KP_S(120), ih);   // leave room for legend
      if(side < KP_S(120)) side = MathMin(iw, ih);
      int sx0 = ix, sy0 = iy + (ih - side)/2;
      int sx1 = sx0 + side - 1, sy1 = sy0 + side - 1;

      // quadrant tints: above diagonal = favorable zone
      g_cv.FillTriangle(sx0, sy1, sx1, sy0, sx0, sy0, KP_TINT_GREEN);
      g_cv.FillTriangle(sx0, sy1, sx1, sy0, sx1, sy1, KP_TINT_RED);
      // grid
      for(int q=1; q<4; q++)
        {
         KPC_HDot(sx0, sx1, sy0 + side*q/4, KP_SEP);
         KPC_VDot(sx0 + side*q/4, sy0, sy1, KP_SEP);
        }
      KPC_Frame(sx0, sy0, side, side, KP_SEP);
      // diagonal MFE = MAE with 45-degree label
      g_cv.Line(sx0, sy1, sx1, sy0, KP_TXT_FAINT);
      g_cv.FontSet(KP_FontMono, KP_F(6.0), FW_NORMAL, 450);
      g_cv.TextOut(sx0 + side/2 + KP_S(6), sy0 + side/2 - KP_S(6),
                   "MFE=MAE", KP_TXT_FAINT, TA_CENTER|TA_TOP);
      // dots: filled = win, ring = loss
      for(int i=0; i<g_exc_n; i++)
        {
         int dx2 = sx0 + (int)(g_exc[i].mae / m * (side-1));
         int dy2 = sy1 - (int)(g_exc[i].mfe / m * (side-1));
         if(g_exc[i].net >= 0)
            g_cv.FillCircle(dx2, dy2, 2, KP_GREEN);
         else
            g_cv.Circle(dx2, dy2, 2, KP_RED);
        }
      // own axes: labels aligned to the square, not the full plot box
      KPC_Lbl(sx0 + KP_S(4), sy0 + KP_S(2), "MFE", KP_TXT_DIM, 6.2);
      for(int q=0; q<5; q+=2)
         KPC_Num(sx1 + KP_S(6), sy0 + side*q/4 - (q==0 ? 0 : KP_S(q==4 ? 12 : 6)),
                 KP_Money(m - m*q/4.0, 0), KP_TXT_FAINT, 6.0);
      // legend + key stats on the right
      double avg_f = sf / g_exc_n, avg_a = sa / g_exc_n;
      double eratio  = (avg_a > 0.0000001 ? avg_f / avg_a : 0.0);
      double capture = (sf > 0.0000001 ? sn / sf * 100.0 : 0.0);
      int lx0 = sx1 + KP_S(52);
      int ly0 = sy0 + KP_S(6);
      g_cv.FillCircle(lx0 + KP_S(3), ly0 + KP_S(5), 2, KP_GREEN);
      KPC_Lbl(lx0 + KP_S(10), ly0, LL("WIN", "盈利单"), KP_TXT_DIM, 6.4);
      ly0 += KP_S(14);
      g_cv.Circle(lx0 + KP_S(3), ly0 + KP_S(5), 2, KP_RED);
      KPC_Lbl(lx0 + KP_S(10), ly0, LL("LOSS", "亏损单"), KP_TXT_DIM, 6.4);
      ly0 += KP_S(20);
      KPC_Lbl(lx0, ly0, "E-RATIO", KP_TXT_FAINT, 6.2);
      ly0 += KP_S(12);
      KPC_Num(lx0, ly0, DoubleToString(eratio, 2),
              (eratio >= 1.0 ? KP_GREEN : KP_RED), 11.0, 0, true);
      ly0 += KP_S(26);
      KPU_KV(lx0, ly0, KP_S(96), LL("AVG MFE", "均MFE"), KP_Money(avg_f, 0), KP_GREEN);
      ly0 += KP_S(14);
      KPU_KV(lx0, ly0, KP_S(96), LL("AVG MAE", "均MAE"), KP_Money(avg_a, 0), KP_RED);
      ly0 += KP_S(14);
      KPU_KV(lx0, ly0, KP_S(96), LL("CAPTURE", "兑现率"), KP_Pct(capture, 0),
             (capture > 0 ? KP_AMBER : KP_TXT_DIM));
      ly0 += KP_S(14);
      KPU_KV(lx0, ly0, KP_S(96), LL("WIN/N", "盈/总"),
             StringFormat("%d/%d", nwin, g_exc_n), KP_TXT);
      // x labels aligned to the square edges
      KPC_Num(sx0, y + ph + KP_S(4), "0", KP_TXT_FAINT, 6.2);
      KPC_Lbl(sx0 + side/2, y + ph + KP_S(4),
              LL("MAE (ADVERSE EXCURSION)", "MAE 最大不利波动"), KP_TXT_FAINT, 6.2, 1);
      KPC_Num(sx1, y + ph + KP_S(4), KP_Money(m, 0), KP_TXT_FAINT, 6.2, 2);
      int scope = MathMin(200, g_tot.closed_trades);
      sum = StringFormat("%s %d/%d   %s",
            LL("SAMPLE", "样本"), g_exc_n, scope,
            LL("ABOVE DIAGONAL = MORE FAVORABLE THAN ADVERSE",
               "对角线上方 = 顺风幅度大于逆风幅度, 点越靠左上越健康"));
      own_axes = true;
      has = true;
     }

   if(has && !own_axes)
     {
      // y labels: five ticks aligned to the quarter gridlines
      int lx = px + pw + KP_S(4);
      bool pct = (g_chart_sel == 3);
      for(int q=0; q<5; q++)
        {
         double v = mx - (mx - mn) * q / 4.0;
         int off = (q == 0 ? KP_S(2) : q == 4 ? -KP_S(13) : -KP_S(6));
         uint c = (q % 2 == 0 ? KP_TXT_DIM : KP_TXT_FAINT);
         KPC_Num(lx, y + ph*q/4 + off, (pct ? KP_Pct(v) : KP_Money(v, 0)), c, 6.2);
        }
     }
   if(!has)
      KPC_Lbl(px + cw/2, y + ph/2 - KP_S(7),
              (g_chart_sel == 4 ?
               LL("NO SAMPLE YET (M1 HISTORY LOADING)", "暂无样本 (M1 历史加载中)") :
               LL("NO DATA", "暂无数据")),
              KP_TXT_FAINT, 8.0, 1);
   y += ph + KP_S(4);

   // x labels + summary
   if(has)
     {
      if(!own_axes)
        {
         KPC_Num(px, y, xl0, KP_TXT_FAINT, 6.2);
         if(xl1 != "")
            KPC_Lbl(px + pw/2, y, xl1, KP_TXT_FAINT, 6.2, 1);
         KPC_Num(px + pw, y, xl2, KP_TXT_FAINT, 6.2, 2);
        }
      y += KP_S(14);
      KPC_Lbl(px, y, sum, KP_TXT_DIM, 6.6);
     }
  }

#include "KP_UI2.mqh"

//--- main render -----------------------------------------------------
void KPU_Render()
  {
   int W = KPU_PanelW();
   int H = KPU_PanelH();
   KPC_EnsureSize(W, H);
   KPC_ClearHits();

   g_cv.Erase(KP_BG);
   KPU_DrawHeader(W);

   if(!g_collapsed)
     {
      int y = KP_S(KPL_HDR);
      KPU_DrawAccStrip(W, y);
      y += KP_S(KPL_ACC);
      KPU_DrawTabs(W, y);
      y += KP_S(KPL_TABS);

      if(g_modal == 1)
         KPU_DrawModal(W, y);
      else
        {
         switch(g_tab)
           {
            case 0: KPU_DrawOverview(W, y);  break;
            case 1: KPU_DrawAnalysis(W, y);  break;
            case 2: KPU_DrawAggTable(W, y, g_syms,
                       LL("SYMBOL STATISTICS", "品种统计"), 2);  break;
            case 3: KPU_DrawAggTable(W, y, g_magics,
                       LL("MAGIC STATISTICS", "策略统计"), 3);   break;
            case 4: KPU_DrawPositions(W, y); break;
            case 5: KPU_DrawOrder(W, y);     break;
            case 6: KPU_DrawRisk(W, y);      break;
            case 7: KPU_DrawNews(W, y);      break;
           }
        }
      KPU_DrawFooter(W, H - KP_S(KPL_FOOT));
     }

   KPC_Frame(0, 0, W, H, KP_BORDER);
   KPC_Update();
  }

#endif // KP_UI_MQH
