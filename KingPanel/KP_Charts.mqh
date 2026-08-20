//+------------------------------------------------------------------+
//| KP_Charts.mqh - KING PANEL V1.3                                  |
//| Chart Center: six composed pages. Every plot is height-capped    |
//| and the freed space carries companion analytics — nothing is     |
//| ever stretched to the full window height.                        |
//+------------------------------------------------------------------+
#ifndef KP_CHARTS_MQH
#define KP_CHARTS_MQH

//--- shared drawing helpers -----------------------------------------
void KPCH_Box(const int x, const int y, const int w, const int h)
  {
   KPC_Fill(x, y, w, h, KP_BG_CELL);
   KPC_Frame(x, y, w, h, KP_SEP);
   for(int i=1; i<4; i++)
      KPC_HDot(x+1, x+w-2, y + h*i/4, KP_SEP);
  }

int KPCH_Title(const int x, const int y, const string t)
  {
   KPC_Fill(x, y + KP_S(2), KP_S(2), KP_S(9), KP_AMBER_DIM);
   KPC_Lbl(x + KP_S(6), y, t, KP_TXT_DIM, 6.2, 0, true);
   return y + KP_S(14);
  }

// five ticks on the right edge of a box, aligned to its quarters
void KPCH_YLab(const int bx, const int by, const int bh,
               const double mx, const double mn, const bool pct)
  {
   for(int q=0; q<5; q++)
     {
      double v = mx - (mx - mn) * q / 4.0;
      int off = (q == 0 ? KP_S(2) : q == 4 ? -KP_S(12) : -KP_S(5));
      uint c = (q % 2 == 0 ? KP_TXT_DIM : KP_TXT_FAINT);
      KPC_Num(bx + KP_S(4), by + bh*q/4 + off,
              (pct ? KP_Pct(v) : KP_Money(v, 0)), c, 6.0);
     }
  }

void KPCH_Empty(const int px, const int y, const int cw, const int H,
                const string msg)
  {
   KPC_Lbl(px + cw/2, y + H/2 - KP_S(7), msg, KP_TXT_FAINT, 8.0, 1);
  }

// underwater drawdown series from the trading curve; returns deepest idx
int KPCH_BuildUW(double &uw[])
  {
   ArrayResize(uw, g_curve_n);
   double peak = -DBL_MAX, peakbal = 0;
   int mi = 0;
   for(int i=0; i<g_curve_n; i++)
     {
      if(g_curve_trd[i] >= peak)
        {
         peak = g_curve_trd[i];
         peakbal = g_curve_bal[i];
        }
      uw[i] = (peakbal > 0 ? -(peak - g_curve_trd[i]) / peakbal * 100.0 : 0.0);
      if(uw[i] < uw[mi])
         mi = i;
     }
   return mi;
  }

//--- page 0: equity + underwater + rolling PF -----------------------
void KPCH_PageEquity(const int px, int y, const int cw, const int H)
  {
   if(g_curve_n < 2)
     {
      KPCH_Empty(px, y, cw, H, LL("NO DATA", "暂无数据"));
      return;
     }
   int lab_w = KP_S(58);
   int pw = cw - lab_w;
   int base = H - KP_S(68);
   int h1 = MathMin(KP_S(380), (int)(base * 0.55));
   int h2 = MathMin(KP_S(160), (int)(base * 0.22));
   int h3 = MathMin(KP_S(240), base - h1 - h2);

   y = KPCH_Title(px, y, LL("BALANCE CURVE", "资金曲线"));
   KPCH_Box(px, y, pw, h1);
   KPC_Spark(px + KP_S(4), y + KP_S(4), pw - KP_S(8), h1 - KP_S(8),
             g_curve_bal, g_curve_n, KP_AMBER, KP_CURVE_FILL);
   double mn = g_curve_bal[ArrayMinimum(g_curve_bal, 0, g_curve_n)];
   double mx = g_curve_bal[ArrayMaximum(g_curve_bal, 0, g_curve_n)];
   double last = g_curve_bal[g_curve_n-1];
   double pad = (mx - mn) * 0.07;
   KPCH_YLab(px + pw, y, h1, mx + pad, mn - pad, false);
   KPC_Num(px + pw - KP_S(6), y + KP_S(4), KP_Money(last, 0), KP_AMBER, 7.0, 2, true);
   y += h1 + KP_S(4);

   y = KPCH_Title(px, y, LL("UNDERWATER DRAWDOWN", "回撤水下曲线"));
   double uw[];
   int mi = KPCH_BuildUW(uw);
   KPCH_Box(px, y, pw, h2);
   KPC_Spark(px + KP_S(4), y + KP_S(4), pw - KP_S(8), h2 - KP_S(8),
             uw, g_curve_n, KP_RED, KP_FILL_RED, true);
   if(uw[mi] < -0.0000001)
     {
      int mpx = px + KP_S(4) + (int)MathRound((double)mi * (pw - KP_S(9)) / (g_curve_n-1));
      g_cv.FillCircle(mpx, y + h2 - KP_S(5), 3, KP_YELLOW);
      KPC_Num(MathMin(mpx + KP_S(6), px + pw - KP_S(40)), y + h2 - KP_S(17),
              KP_Pct(-uw[mi]), KP_YELLOW, 6.4, 0, true);
     }
   KPCH_YLab(px + pw, y, h2, 0.0, uw[mi], true);
   y += h2 + KP_S(4);

   double pf_now = 0;
   bool has_pf = false;
   if(h3 >= KP_S(50) && g_close_n >= 25)
     {
      y = KPCH_Title(px, y, LL("ROLLING 20-TRADE PROFIT FACTOR", "滚动20笔盈利因子"));
      int n = g_close_n - 19;
      double pf[];
      ArrayResize(pf, n);
      double gp = 0, gl = 0;
      for(int i=0; i<g_close_n; i++)
        {
         double v = g_pos[g_close_order[i]].net;
         if(v >= 0) gp += v; else gl -= v;
         if(i >= 20)
           {
            double o = g_pos[g_close_order[i-20]].net;
            if(o >= 0) gp -= o; else gl += o;   // note: gl accumulated positive
           }
         if(i >= 19)
            pf[i-19] = (gl > 0.0000001 ? MathMin(9.99, gp / gl) : 9.99);
        }
      pf_now = pf[n-1];
      has_pf = true;
      KPCH_Box(px, y, pw, h3);
      double pmn = pf[ArrayMinimum(pf, 0, n)];
      double pmx = pf[ArrayMaximum(pf, 0, n)];
      KPC_Spark(px + KP_S(4), y + KP_S(4), pw - KP_S(8), h3 - KP_S(8),
                pf, n, KP_CYAN, KP_FILL_CYAN);
      double ppad = (pmx - pmn) * 0.07;
      double smx = pmx + ppad, smn = pmn - ppad;
      if(smx > 1.0 && smn < 1.0 && smx > smn)
        {
         int ry = y + KP_S(4) + (int)((smx - 1.0) / (smx - smn) * (h3 - KP_S(9)));
         KPC_HDot(px + KP_S(4), px + pw - KP_S(5), ry, KP_AMBER_DIM);
        }
      KPCH_YLab(px + pw, y, h3, smx, smn, false);
      y += h3 + KP_S(4);
     }

   string s = StringFormat("%s %s   %s %s   %s %s",
              LL("HIGH", "最高"), KP_Money(mx, 0),
              LL("LOW", "最低"), KP_Money(mn, 0),
              LL("LAST", "当前"), KP_Money(last, 0));
   if(has_pf)
      s += StringFormat("   PF20 %.2f", pf_now);
   KPC_Lbl(px, y, s, KP_TXT_DIM, 6.6);
  }

//--- page 1: daily bars + hold-time buckets -------------------------
void KPCH_PageDaily(const int px, int y, const int cw, const int H)
  {
   int nsrc = ArraySize(g_days);
   if(nsrc < 1 || g_close_n < 1)
     {
      KPCH_Empty(px, y, cw, H, LL("NO DATA", "暂无数据"));
      return;
     }
   int lab_w = KP_S(58);
   int pw = cw - lab_w;
   int take = MathMin(nsrc, 60);
   int bars_h = MathMin(KP_S(340), (int)((H - KP_S(180)) * 0.9));
   if(bars_h < KP_S(120)) bars_h = KP_S(120);

   y = KPCH_Title(px, y, StringFormat(LL("DAILY P&L (LAST %d)", "日盈亏 (近%d日)"), take));
   double vals[];
   ArrayResize(vals, take);
   double best = 0, worst = 0, tot = 0;
   for(int i=0; i<take; i++)
     {
      vals[i] = g_days[nsrc-take+i].profit;
      tot += vals[i];
      if(vals[i] > best)  best = vals[i];
      if(vals[i] < worst) worst = vals[i];
     }
   KPCH_Box(px, y, pw, bars_h);
   KPC_Bars(px + KP_S(4), y + KP_S(4), pw - KP_S(8), bars_h - KP_S(8),
            vals, take, KP_GREEN, KP_RED, KP_TXT_FAINT);
   KPCH_YLab(px + pw, y, bars_h, MathMax(0.0, best), MathMin(0.0, worst), false);
   KPC_Num(px + KP_S(2), y + bars_h + KP_S(2), g_days[nsrc-take].label, KP_TXT_FAINT, 6.0);
   KPC_Num(px + pw - KP_S(2), y + bars_h + KP_S(2), g_days[nsrc-1].label, KP_TXT_FAINT, 6.0, 2);
   y += bars_h + KP_S(16);

   //-- hold-time buckets
   y = KPCH_Title(px, y, LL("HOLD-TIME ANALYSIS", "持仓时长分析"));
   long th[6] = {300, 1800, 7200, 28800, 86400, 432000};
   string bl_en[7] = {"<5M", "5-30M", "30M-2H", "2-8H", "8-24H", "1-5D", ">5D"};
   string bl_cn[7] = {"<5分", "5-30分", "30分-2时", "2-8时", "8-24时", "1-5日", ">5日"};
   double bnet[7];
   int bcnt[7], bwin[7];
   ArrayInitialize(bnet, 0.0);
   ArrayInitialize(bcnt, 0);
   ArrayInitialize(bwin, 0);
   long w_hold = 0, l_hold = 0;
   int  w_n = 0, l_n = 0;
   for(int i=0; i<g_close_n; i++)
     {
      int gi = g_close_order[i];
      long hold = (long)(g_pos[gi].close_time - g_pos[gi].open_time);
      int b = 6;
      for(int k=0; k<6; k++)
         if(hold < th[k]) { b = k; break; }
      bnet[b] += g_pos[gi].net;
      bcnt[b]++;
      if(g_pos[gi].net >= 0) { bwin[b]++; w_hold += hold; w_n++; }
      else                   { l_hold += hold; l_n++; }
     }
   double amax = 0;
   for(int b=0; b<7; b++)
      if(MathAbs(bnet[b]) > amax) amax = MathAbs(bnet[b]);
   if(amax <= 0) amax = 1;

   int rh = KP_S(15);
   int c_l = KP_S(56), c_c = KP_S(52), c_w = KP_S(46), c_n = KP_S(90);
   int hx = px;
   KPC_Fill(px, y, cw, KP_S(14), KP_BG_THEAD);
   KPC_Lbl(hx + KP_S(3), y + KP_S(2), LL("HOLD", "时长"), KP_TXT_FAINT, 5.8);        hx += c_l;
   KPC_Lbl(hx + c_c - KP_S(3), y + KP_S(2), LL("TRD", "笔数"), KP_TXT_FAINT, 5.8, 2); hx += c_c;
   KPC_Lbl(hx + c_w - KP_S(3), y + KP_S(2), "WIN%", KP_TXT_FAINT, 5.8, 2);           hx += c_w;
   KPC_Lbl(hx + c_n - KP_S(3), y + KP_S(2), LL("NET", "净盈亏"), KP_TXT_FAINT, 5.8, 2);
   y += KP_S(15);
   for(int b=0; b<7; b++)
     {
      int yy = y + b*rh;
      KPC_Fill(px, yy, cw, rh, (b % 2 == 0 ? KP_BG_CELL : KP_BG_CELL2));
      int xx = px;
      KPC_Lbl(xx + KP_S(3), yy + KP_S(2), LL(bl_en[b], bl_cn[b]), KP_TXT_DIM, 6.2); xx += c_l;
      KPC_Num(xx + c_c - KP_S(3), yy + KP_S(2), (string)bcnt[b], KP_TXT_DIM, 6.2, 2); xx += c_c;
      KPC_Num(xx + c_w - KP_S(3), yy + KP_S(2),
              (bcnt[b] > 0 ? KP_Pct(100.0*bwin[b]/bcnt[b], 0) : "-"),
              KP_TXT_DIM, 6.2, 2); xx += c_w;
      KPC_Num(xx + c_n - KP_S(3), yy + KP_S(2),
              (bcnt[b] > 0 ? KP_MoneySigned(bnet[b], 0) : "-"),
              KP_PLColor(bnet[b]), 6.2, 2); xx += c_n;
      int bx = xx + KP_S(8);
      int bw = cw - (xx - px) - KP_S(14);
      int fw = (int)MathRound(bw * MathAbs(bnet[b]) / amax);
      KPC_Fill(bx, yy + KP_S(4), bw, KP_S(6), KP_SEP);
      if(fw > 0 && bcnt[b] > 0)
         KPC_Fill(bx, yy + KP_S(4), fw, KP_S(6), (bnet[b] >= 0 ? KP_GREEN : KP_RED));
     }
   y += 7*rh + KP_S(4);

   double aw = (w_n > 0 ? (double)w_hold / w_n : 0);
   double al = (l_n > 0 ? (double)l_hold / l_n : 0);
   string s = StringFormat("%d %s   %s %s   %s %s / %s",
              take, LL("DAYS SHOWN", "日展示"),
              LL("SUM", "合计"), KP_MoneySigned(tot, 0),
              LL("AVG HOLD W/L", "盈/亏平均持仓"),
              KP_Duration((long)aw), KP_Duration((long)al));
   if(al > 0 && aw > 0 && aw / al < 0.7)
      s += LL("  — cutting winners, riding losers", "  — 盈利拿不住、亏损扛太久");
   KPC_Lbl(px, y, s, KP_TXT_DIM, 6.4);
  }

//--- page 2: monthly bars + R-multiple distribution -----------------
void KPCH_PageMonthly(const int px, int y, const int cw, const int H)
  {
   int y0p = y;
   int nsrc = ArraySize(g_months);
   if(nsrc < 1)
     {
      KPCH_Empty(px, y, cw, H, LL("NO DATA", "暂无数据"));
      return;
     }
   int lab_w = KP_S(58);
   int pw = cw - lab_w;
   int take = MathMin(nsrc, 36);
   int bars_h = MathMin(KP_S(320), (int)((H - KP_S(200)) * 0.9));
   if(bars_h < KP_S(120)) bars_h = KP_S(120);

   y = KPCH_Title(px, y, StringFormat(LL("MONTHLY P&L (LAST %d)", "月盈亏 (近%d月)"), take));
   double vals[];
   ArrayResize(vals, take);
   double best = 0, worst = 0, tot = 0;
   for(int i=0; i<take; i++)
     {
      vals[i] = g_months[nsrc-take+i].profit;
      tot += vals[i];
      if(vals[i] > best)  best = vals[i];
      if(vals[i] < worst) worst = vals[i];
     }
   KPCH_Box(px, y, pw, bars_h);
   KPC_Bars(px + KP_S(4), y + KP_S(4), pw - KP_S(8), bars_h - KP_S(8),
            vals, take, KP_GREEN, KP_RED, KP_TXT_FAINT);
   KPCH_YLab(px + pw, y, bars_h, MathMax(0.0, best), MathMin(0.0, worst), false);
   KPC_Num(px + KP_S(2), y + bars_h + KP_S(2), g_months[nsrc-take].label, KP_TXT_FAINT, 6.0);
   KPC_Num(px + pw - KP_S(2), y + bars_h + KP_S(2), g_months[nsrc-1].label, KP_TXT_FAINT, 6.0, 2);
   y += bars_h + KP_S(16);

   //-- R-multiple distribution (SL-based R; MAE proxy on small samples)
   y = KPCH_Title(px, y, LL("R-MULTIPLE DISTRIBUTION", "R倍数分布"));
   double edges[7] = {-2, -1, 0, 1, 2, 3, 5};
   int bins[8];
   ArrayInitialize(bins, 0);
   int n_sl = 0, n_proxy = 0;
   double r_sum = 0;
   bool use_proxy = (g_close_n <= 2000);
   for(int i=0; i<g_close_n; i++)
     {
      int gi = g_close_order[i];
      double r0 = 0;
      if(g_pos[gi].sl0 > 0 && g_pos[gi].lots > 0)
        {
         double entry = g_pos[gi].vwap_num / g_pos[gi].lots;
         double ts = SymbolInfoDouble(g_pos[gi].symbol, SYMBOL_TRADE_TICK_SIZE);
         double tv = SymbolInfoDouble(g_pos[gi].symbol, SYMBOL_TRADE_TICK_VALUE);
         if(ts > 0 && tv > 0)
            r0 = MathAbs(entry - g_pos[gi].sl0) / ts * tv * g_pos[gi].lots;
         if(r0 > 0) n_sl++;
        }
      if(r0 <= 0 && use_proxy)
        {
         for(int e=0; e<g_exc_n; e++)
            if(g_exc[e].pos_id == g_pos[gi].pos_id && g_exc[e].mae > 0)
              {
               r0 = g_exc[e].mae;
               n_proxy++;
               break;
              }
        }
      if(r0 <= 0)
         continue;
      double r = g_pos[gi].net / r0;
      r_sum += r;
      int b = 7;
      for(int e=0; e<7; e++)
         if(r < edges[e]) { b = e; break; }
      bins[b]++;
     }
   int n_r = n_sl + n_proxy;
   if(n_r < 5)
      KPC_Lbl(px, y + KP_S(6),
              LL("NEEDS SL-BASED TRADES (OR <=2000 TRADES FOR MAE PROXY)",
                 "需要带止损的交易 (或 ≤2000 笔时用 MAE 代理)"),
              KP_TXT_FAINT, 6.4);
   else
     {
      int hist_h = MathMin(KP_S(140), H - (y - y0p) - KP_S(40));
      if(hist_h < KP_S(70)) hist_h = KP_S(70);
      KPCH_Box(px, y, pw, hist_h);
      int bmax = 1;
      for(int b=0; b<8; b++)
         if(bins[b] > bmax) bmax = bins[b];
      string bn[8] = {"<-2R", "-2..-1", "-1..0", "0..1", "1..2", "2..3", "3..5", ">5R"};
      double bwd = (double)(pw - KP_S(16)) / 8.0;
      for(int b=0; b<8; b++)
        {
         int bx = px + KP_S(8) + (int)(b * bwd);
         int bw = (int)bwd - KP_S(4);
         int bh = (int)((double)(hist_h - KP_S(24)) * bins[b] / bmax);
         uint c = (b < 3 ? KP_RED : KP_GREEN);
         if(bins[b] > 0)
           {
            KPC_Fill(bx, y + hist_h - KP_S(4) - bh, bw, bh, c);
            KPC_Num(bx + bw/2, y + hist_h - KP_S(16) - bh, (string)bins[b],
                    KP_TXT_DIM, 5.8, 1);
           }
         KPC_Num(bx + bw/2, y + hist_h + KP_S(2), bn[b], KP_TXT_FAINT, 5.4, 1);
        }
      y += hist_h + KP_S(14);
      KPC_Lbl(px, y, StringFormat(
              LL("SUM %s   AVG R %.2f   SAMPLE %d (SL %d / MAE-PROXY %d)",
                 "合计 %s   平均R %.2f   样本 %d (止损 %d / MAE代理 %d)"),
              KP_MoneySigned(tot, 0), (n_r > 0 ? r_sum / n_r : 0.0),
              n_r, n_sl, n_proxy), KP_TXT_DIM, 6.4);
     }
  }

//--- page 3: drawdown + streaks + worst episodes --------------------
void KPCH_PageDD(const int px, int y, const int cw, const int H)
  {
   if(g_curve_n < 2)
     {
      KPCH_Empty(px, y, cw, H, LL("NO DATA", "暂无数据"));
      return;
     }
   int lab_w = KP_S(58);
   int pw = cw - lab_w;
   int uh = MathMin(KP_S(360), (int)((H - KP_S(150)) * 0.9));
   if(uh < KP_S(140)) uh = KP_S(140);

   y = KPCH_Title(px, y, LL("UNDERWATER DRAWDOWN", "回撤水下曲线"));
   double uw[];
   int mi = KPCH_BuildUW(uw);
   KPCH_Box(px, y, pw, uh);
   KPC_Spark(px + KP_S(4), y + KP_S(4), pw - KP_S(8), uh - KP_S(8),
             uw, g_curve_n, KP_RED, KP_FILL_RED, true);
   if(uw[mi] < -0.0000001)
     {
      int mpx = px + KP_S(4) + (int)MathRound((double)mi * (pw - KP_S(9)) / (g_curve_n-1));
      g_cv.FillCircle(mpx, y + uh - KP_S(5), 3, KP_YELLOW);
      KPC_Num(MathMin(mpx + KP_S(6), px + pw - KP_S(40)), y + uh - KP_S(17),
              KP_Pct(-uw[mi]), KP_YELLOW, 6.6, 0, true);
     }
   KPCH_YLab(px + pw, y, uh, 0.0, uw[mi], true);
   KPC_Num(px + KP_S(2), y + uh + KP_S(2), KP_DateOnly(g_curve_t[0]), KP_TXT_FAINT, 6.0);
   KPC_Num(px + pw - KP_S(2), y + uh + KP_S(2), KP_DateOnly(g_curve_t[g_curve_n-1]),
           KP_TXT_FAINT, 6.0, 2);
   y += uh + KP_S(16);

   //-- streaks (left) and worst episodes (right)
   int colw = cw/2 - KP_S(10);
   int ly = KPCH_Title(px, y, LL("STREAKS", "连胜连亏"));
   int cur = 0, maxw = 0, maxl = 0, run = 0;
   for(int i=0; i<g_close_n; i++)
     {
      bool win = (g_pos[g_close_order[i]].net >= 0);
      if(i == 0 || win == (run > 0))
         run = (win ? MathAbs(run)+1 : -(MathAbs(run)+1));
      else
         run = (win ? 1 : -1);
      if(run > maxw)  maxw = run;
      if(-run > maxl) maxl = -run;
     }
   cur = run;
   KPU_KV(px, ly, colw, LL("CURRENT", "当前"),
          (cur == 0 ? "-" : StringFormat("%d %s", MathAbs(cur),
           cur > 0 ? LL("WINS", "连胜") : LL("LOSSES", "连亏"))),
          (cur >= 0 ? KP_GREEN : KP_RED));
   KPU_KV(px, ly + KP_S(14), colw, LL("MAX WIN STREAK", "最长连胜"),
          (string)maxw, KP_GREEN);
   KPU_KV(px, ly + KP_S(28), colw, LL("MAX LOSS STREAK", "最长连亏"),
          (string)maxl, KP_RED);
   // last 10 results as dots
   int dn = MathMin(10, g_close_n);
   KPC_Lbl(px, ly + KP_S(44), LL("LAST 10", "近10笔"), KP_TXT_FAINT, 6.0);
   for(int i=0; i<dn; i++)
     {
      bool win = (g_pos[g_close_order[g_close_n-dn+i]].net >= 0);
      int dx = px + KP_S(52) + i*KP_S(12);
      if(win) g_cv.FillCircle(dx, ly + KP_S(48), 3, KP_GREEN);
      else    g_cv.Circle(dx, ly + KP_S(48), 3, KP_RED);
     }

   int rx = px + cw/2 + KP_S(10);
   int ry = KPCH_Title(rx, y, LL("WORST DRAWDOWNS", "最深回撤段"));
   // episodes on the trading curve
   double ep_d[3];
   datetime ep_s[3], ep_e[3];
   double ep_p[3];
   for(int k=0; k<3; k++) { ep_d[k] = 0; ep_s[k] = 0; ep_e[k] = 0; ep_p[k] = 0; }
   double peak = -DBL_MAX, peakbal = 0, depth = 0;
   datetime pk_t = 0, tr_t = 0;
   for(int i=0; i<=g_curve_n; i++)
     {
      bool flush = (i == g_curve_n);
      if(!flush && g_curve_trd[i] >= peak)
         flush = (depth > 0);
      if(flush && depth > 0)
        {
         for(int k=0; k<3; k++)
            if(depth > ep_d[k])
              {
               for(int m=2; m>k; m--)
                 { ep_d[m]=ep_d[m-1]; ep_s[m]=ep_s[m-1]; ep_e[m]=ep_e[m-1]; ep_p[m]=ep_p[m-1]; }
               ep_d[k] = depth; ep_s[k] = pk_t; ep_e[k] = tr_t;
               ep_p[k] = (peakbal > 0 ? depth/peakbal*100.0 : 0);
               break;
              }
         depth = 0;
        }
      if(i == g_curve_n)
         break;
      if(g_curve_trd[i] >= peak)
        {
         peak = g_curve_trd[i];
         peakbal = g_curve_bal[i];
         pk_t = g_curve_t[i];
        }
      else if(peak - g_curve_trd[i] > depth)
        {
         depth = peak - g_curve_trd[i];
         tr_t = g_curve_t[i];
        }
     }
   for(int k=0; k<3 && ep_d[k] > 0; k++)
     {
      KPC_Num(rx, ry + k*KP_S(14),
              StringFormat("%d. %s (%s)", k+1, KP_Money(ep_d[k], 0), KP_Pct(ep_p[k])),
              KP_RED, 6.4);
      KPC_Num(rx + colw, ry + k*KP_S(14),
              KP_DateOnly(ep_s[k]) + " - " + KP_DateOnly(ep_e[k]), KP_TXT_FAINT, 6.0, 2);
     }
   y += KP_S(80);
   KPC_Lbl(px, y, StringFormat("%s %s (%s)   %s %s",
           LL("MAX DD", "最大回撤"), KP_Money(g_tot.max_dd, 0), KP_Pct(g_tot.max_dd_pct),
           LL("NOW", "当前"), KP_Pct(-uw[g_curve_n-1])), KP_TXT_DIM, 6.6);
  }

//--- page 4: MFE/MAE scatter + efficiency ---------------------------
void KPCH_PageMFE(const int px, int y, const int cw, const int H)
  {
   if(g_exc_n < 1)
     {
      KPCH_Empty(px, y, cw, H,
                 LL("NO SAMPLE YET (M1 HISTORY LOADING)", "暂无样本 (M1 历史加载中)"));
      return;
     }
   y = KPCH_Title(px, y, LL("MFE x MAE PER TRADE", "单笔 MFE × MAE"));
   int side = MathMin(MathMin(cw - KP_S(150), H - KP_S(110)), KP_S(400));
   int sx0 = px, sy0 = y;
   int sx1 = sx0 + side - 1, sy1 = sy0 + side - 1;

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

   g_cv.FillTriangle(sx0, sy1, sx1, sy0, sx0, sy0, KP_TINT_GREEN);
   g_cv.FillTriangle(sx0, sy1, sx1, sy0, sx1, sy1, KP_TINT_RED);
   for(int q=1; q<4; q++)
     {
      KPC_HDot(sx0, sx1, sy0 + side*q/4, KP_SEP);
      KPC_VDot(sx0 + side*q/4, sy0, sy1, KP_SEP);
     }
   KPC_Frame(sx0, sy0, side, side, KP_SEP);
   g_cv.Line(sx0, sy1, sx1, sy0, KP_TXT_FAINT);
   g_cv.FontSet(KP_FontMono, KP_F(6.0), FW_NORMAL, 450);
   g_cv.TextOut(sx0 + side/2 + KP_S(6), sy0 + side/2 - KP_S(6),
                "MFE=MAE", KP_TXT_FAINT, TA_CENTER|TA_TOP);
   for(int i=0; i<g_exc_n; i++)
     {
      int dx2 = sx0 + (int)(g_exc[i].mae / m * (side-1));
      int dy2 = sy1 - (int)(g_exc[i].mfe / m * (side-1));
      if(g_exc[i].net >= 0)
         g_cv.FillCircle(dx2, dy2, 2, KP_GREEN);
      else
         g_cv.Circle(dx2, dy2, 2, KP_RED);
     }
   KPC_Lbl(sx0 + KP_S(4), sy0 + KP_S(2), "MFE", KP_TXT_DIM, 6.2);
   for(int q=0; q<5; q+=2)
      KPC_Num(sx1 + KP_S(6), sy0 + side*q/4 - (q==0 ? 0 : KP_S(q==4 ? 12 : 6)),
              KP_Money(m - m*q/4.0, 0), KP_TXT_FAINT, 6.0);
   KPC_Num(sx0, sy1 + KP_S(4), "0", KP_TXT_FAINT, 6.2);
   KPC_Lbl(sx0 + side/2, sy1 + KP_S(4),
           LL("MAE (ADVERSE)", "MAE 最大不利波动"), KP_TXT_FAINT, 6.2, 1);
   KPC_Num(sx1, sy1 + KP_S(4), KP_Money(m, 0), KP_TXT_FAINT, 6.2, 2);

   //-- legend + key stats right of the square
   double avg_f = sf / g_exc_n, avg_a = sa / g_exc_n;
   double eratio  = (avg_a > 0.0000001 ? avg_f / avg_a : 0.0);
   double capture = (sf > 0.0000001 ? sn / sf * 100.0 : 0.0);
   int lx0 = sx1 + KP_S(48);
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
   KPU_KV(lx0, ly0, KP_S(84), LL("AVG MFE", "均MFE"), KP_Money(avg_f, 0), KP_GREEN);
   ly0 += KP_S(14);
   KPU_KV(lx0, ly0, KP_S(84), LL("AVG MAE", "均MAE"), KP_Money(avg_a, 0), KP_RED);
   ly0 += KP_S(14);
   KPU_KV(lx0, ly0, KP_S(84), LL("CAPTURE", "兑现率"), KP_Pct(capture, 0),
          (capture > 0 ? KP_AMBER : KP_TXT_DIM));
   ly0 += KP_S(14);
   KPU_KV(lx0, ly0, KP_S(84), LL("WIN/N", "盈/总"),
          StringFormat("%d/%d", nwin, g_exc_n), KP_TXT);

   //-- entry / exit efficiency (how much of the trade range was used)
   double e_ent = 0, e_ext = 0, e_tot = 0;
   int e_n = 0;
   for(int i=0; i<g_exc_n; i++)
     {
      double rng = g_exc[i].hi - g_exc[i].lo;
      if(rng <= 0)
         continue;
      double en, ex, tt;
      if(g_exc[i].dir == 0)
        {
         en = (g_exc[i].hi - g_exc[i].entry) / rng;
         ex = (g_exc[i].exitv - g_exc[i].lo) / rng;
         tt = (g_exc[i].exitv - g_exc[i].entry) / rng;
        }
      else
        {
         en = (g_exc[i].entry - g_exc[i].lo) / rng;
         ex = (g_exc[i].hi - g_exc[i].exitv) / rng;
         tt = (g_exc[i].entry - g_exc[i].exitv) / rng;
        }
      e_ent += en; e_ext += ex; e_tot += tt;
      e_n++;
     }
   int ey = sy1 + KP_S(20);
   if(e_n > 0)
     {
      ey = KPCH_Title(px, ey, LL("RANGE EFFICIENCY", "波段利用效率"));
      string el[3];
      el[0] = LL("ENTRY", "入场");
      el[1] = LL("EXIT", "出场");
      el[2] = LL("TOTAL", "整体");
      double ev[3];
      ev[0] = e_ent / e_n * 100.0;
      ev[1] = e_ext / e_n * 100.0;
      ev[2] = e_tot / e_n * 100.0;
      for(int k=0; k<3; k++)
        {
         int yy = ey + k*KP_S(15);
         KPC_Lbl(px, yy, el[k], KP_TXT_DIM, 6.2);
         KPC_HBar(px + KP_S(50), yy + KP_S(2), KP_S(160), KP_S(7),
                  MathMax(0.0, MathMin(1.0, ev[k]/100.0)),
                  (k == 2 ? KP_AMBER : KP_CYAN), KP_SEP);
         KPC_Num(px + KP_S(220), yy, KP_Pct(ev[k], 0), KP_TXT, 6.4);
        }
      KPC_Lbl(px + KP_S(250), ey + KP_S(2),
              KPU_Trunc(LL("100% = perfect entry & exit at the extremes",
                           "100% = 在极值入场并在反向极值出场"),
                        cw - KP_S(256), KPU_LblFont(), 5.8), KP_TXT_FAINT, 5.8);
      ey += 3*KP_S(15) + KP_S(4);
     }
   int scope = MathMin(200, g_tot.closed_trades);
   KPC_Lbl(px, ey, StringFormat("%s %d/%d   %s",
           LL("SAMPLE", "样本"), g_exc_n, scope,
           LL("ABOVE DIAGONAL = MORE FAVORABLE THAN ADVERSE",
              "对角线上方 = 顺风大于逆风, 点越靠左上越健康")), KP_TXT_DIM, 6.4);
  }

//--- page 5: session heatmap ----------------------------------------
void KPCH_PageHeat(const int px, int y, const int cw, const int H)
  {
   double cell_net[7][24];
   int    cell_cnt[7][24];
   ArrayInitialize(cell_net, 0.0);
   ArrayInitialize(cell_cnt, 0);
   int  total_n = 0;
   bool weekend = false;
   for(int i=0; i<g_pos_count; i++)
     {
      if(!g_pos[i].closed)
         continue;
      MqlDateTime ct;
      TimeToStruct(g_pos[i].close_time, ct);
      int r2 = (ct.day_of_week == 0 ? 6 : ct.day_of_week - 1);
      cell_net[r2][ct.hour] += g_pos[i].net;
      cell_cnt[r2][ct.hour]++;
      if(r2 >= 5)
         weekend = true;
      total_n++;
     }
   if(total_n < 1)
     {
      KPCH_Empty(px, y, cw, H, LL("NO DATA", "暂无数据"));
      return;
     }
   int nrows = (weekend ? 7 : 5);
   double amax = 0;
   int b_r = -1, b_h = 0, w_r = -1, w_h = 0;
   double b_v = 0, w_v = 0;
   for(int r2=0; r2<nrows; r2++)
      for(int h2=0; h2<24; h2++)
        {
         if(cell_cnt[r2][h2] == 0)
            continue;
         double v = cell_net[r2][h2];
         if(MathAbs(v) > amax) amax = MathAbs(v);
         if(b_r < 0 || v > b_v) { b_v = v; b_r = r2; b_h = h2; }
         if(w_r < 0 || v < w_v) { w_v = v; w_r = r2; w_h = h2; }
        }
   if(amax <= 0) amax = 1;

   y = KPCH_Title(px, y, LL("SESSION HEATMAP (SERVER TIME)", "时段热力图 (服务器时间)"));
   int lx0 = px + KP_S(30);
   int gw2 = cw - KP_S(30) - KP_S(58);
   double cwid = (double)gw2 / 24.0;
   int gy0 = y + KP_S(12);
   int avail = H - KP_S(90);
   int ch2 = MathMax(KP_S(16), MathMin(KP_S(34), avail / nrows));
   int grid_h = ch2 * nrows;

   for(int h2=0; h2<24; h2+=3)
      KPC_Num(lx0 + (int)(h2*cwid), y, StringFormat("%02d", h2), KP_TXT_FAINT, 5.8);

   string dle[7] = {"MON","TUE","WED","THU","FRI","SAT","SUN"};
   string dlc[7] = {"周一","周二","周三","周四","周五","周六","周日"};
   for(int r2=0; r2<nrows; r2++)
     {
      int ry2 = gy0 + r2*ch2;
      KPC_Lbl(px, ry2 + (ch2 - KP_S(10))/2, LL(dle[r2], dlc[r2]), KP_TXT_DIM, 5.8);
      double rowsum = 0;
      for(int h2=0; h2<24; h2++)
        {
         int cx0 = lx0 + (int)(h2*cwid);
         int cx1 = lx0 + (int)((h2+1)*cwid);
         double v = cell_net[r2][h2];
         rowsum += v;
         double frac = MathMin(1.0, MathAbs(v) / amax);
         uint cc = (cell_cnt[r2][h2] > 0 ?
                    KP_Mix(KP_BG_CELL2, (v >= 0 ? KP_GREEN : KP_RED),
                           0.15 + 0.65 * frac) : KP_BG_CELL2);
         KPC_Fill(cx0, ry2, cx1 - cx0 - 1, ch2 - 1, cc);
         if(cell_cnt[r2][h2] > 0 && cx1 - cx0 >= KP_S(14) && ch2 >= KP_S(15))
            KPC_Num(cx0 + (cx1 - cx0)/2, ry2 + (ch2 - KP_S(9))/2,
                    (string)cell_cnt[r2][h2],
                    (frac > 0.5 ? KP_BG : KP_TXT_DIM), 5.4, 1);
        }
      KPC_Num(px + cw - KP_S(2), ry2 + (ch2 - KP_S(10))/2,
              KP_MoneySigned(rowsum, 0), KP_PLColor(rowsum), 6.0, 2);
     }

   int off_h = (int)MathRound((double)(long)(TimeTradeServer() - TimeGMT()) / 3600.0);
   int  s0[4] = {21, 0, 7, 12};
   int  s1[4] = {6, 9, 16, 21};
   string sn2[4] = {"SYD","TYO","LON","NYC"};
   uint sc2[4];
   sc2[0] = 0xFF6E7686;
   sc2[1] = 0xFFD6A832;
   sc2[2] = KP_AMBER;
   sc2[3] = KP_CYAN;
   int sy2 = gy0 + grid_h + KP_S(4);
   for(int s3=0; s3<4; s3++)
     {
      int yb = sy2 + s3*KP_S(4);
      for(int h2=0; h2<24; h2++)
        {
         int gmt_h = ((h2 - off_h) % 24 + 24) % 24;
         bool op = (s0[s3] <= s1[s3] ? (gmt_h >= s0[s3] && gmt_h < s1[s3])
                                     : (gmt_h >= s0[s3] || gmt_h < s1[s3]));
         if(op)
            KPC_Fill(lx0 + (int)(h2*cwid), yb,
                     (int)MathCeil(cwid) - 1, KP_S(3), sc2[s3]);
        }
      KPC_Num(px + cw - KP_S(2), yb - KP_S(3), sn2[s3], sc2[s3], 5.0, 2);
     }

   int by0 = sy2 + KP_S(20);
   int bh2 = y + H - KP_S(30) - by0;
   if(bh2 >= KP_S(48))
     {
      double hourly[24];
      for(int h2=0; h2<24; h2++)
        {
         hourly[h2] = 0;
         for(int r2=0; r2<nrows; r2++)
            hourly[h2] += cell_net[r2][h2];
        }
      KPC_Lbl(lx0, by0, LL("HOURLY NET", "小时净盈亏"), KP_TXT_FAINT, 6.0);
      KPC_Bars(lx0, by0 + KP_S(13), gw2, bh2 - KP_S(15),
               hourly, 24, KP_GREEN, KP_RED, KP_TXT_FAINT);
     }

   string bd = (b_r >= 0 ? LL(dle[b_r], dlc[b_r]) : "-");
   string wd = (w_r >= 0 ? LL(dle[w_r], dlc[w_r]) : "-");
   KPC_Lbl(px, y + H - KP_S(26), StringFormat(
           LL("BEST %s %02d:00 %s   WORST %s %02d:00 %s   %d TRADES · BY CLOSE",
              "最佳 %s %02d:00 %s   最差 %s %02d:00 %s   %d 笔 · 按平仓归集"),
           bd, b_h, KP_MoneySigned(b_v, 0),
           wd, w_h, KP_MoneySigned(w_v, 0), total_n), KP_TXT_DIM, 6.4);
  }

//--- charts modal dispatcher ----------------------------------------
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
   string cn[6];
   cn[0] = LL("EQUITY", "资金曲线");
   cn[1] = LL("DAILY", "日盈亏");
   cn[2] = LL("MONTHLY", "月盈亏");
   cn[3] = LL("DRAWDOWN", "回撤");
   cn[4] = "MFE/MAE";
   cn[5] = LL("HEATMAP", "时段热力");
   int sw = KP_S(76);
   for(int i=0; i<6; i++)
      KPU_Chip(px + i*(sw + KP_S(4)), y, sw, KP_S(16), cn[i],
               g_chart_sel == i, KPHIT_CHARTSEL, i, 6.0);
   y += KP_S(24);

   int H = g_content_h - (y - y0) - KP_S(4);
   switch(g_chart_sel)
     {
      case 0: KPCH_PageEquity(px, y, cw, H);  break;
      case 1: KPCH_PageDaily(px, y, cw, H);   break;
      case 2: KPCH_PageMonthly(px, y, cw, H); break;
      case 3: KPCH_PageDD(px, y, cw, H);      break;
      case 4: KPCH_PageMFE(px, y, cw, H);     break;
      case 5: KPCH_PageHeat(px, y, cw, H);    break;
     }
  }

#endif // KP_CHARTS_MQH
