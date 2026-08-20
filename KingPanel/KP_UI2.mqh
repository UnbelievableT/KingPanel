//+------------------------------------------------------------------+
//| KP_UI2.mqh - KING PANEL V1.1                                     |
//| Tabs: analysis / symbols / magic / trade / risk / news           |
//| Interaction: click, wheel scroll, drag                           |
//+------------------------------------------------------------------+
#ifndef KP_UI2_MQH
#define KP_UI2_MQH

//--- scroll slots (trade tab has two lists; news lives on tab 7) ----
int KPU_ScrollSlot(const int tab)
  {
   if(tab == 4 && g_pos_sub == 1)
      return 8;
   return tab;
  }

int KPU_MaxScroll(const int slot)
  {
   int n = 0;
   switch(slot)
     {
      case 1:
         if(g_period == 0) n = ArraySize(g_days);
         else if(g_period == 1) n = ArraySize(g_weeks);
         else if(g_period == 2) n = ArraySize(g_months);
         else n = ArraySize(g_years);
         break;
      case 2: n = ArraySize(g_syms);   break;
      case 3: n = ArraySize(g_magics); break;
      case 4: n = g_live_count;        break;
      case 7: n = KPN_FilteredCount(); break;
      case 8: n = g_ord_count;         break;
     }
   return MathMax(0, n - KPU_VisRows(slot));
  }

//--- scrollbar (right edge of a table area) -------------------------
// wide arrows, visible track, page-proportional thumb; clicking the
// track jumps straight to that position; wheel scrolls as well
void KPU_ScrollUI(const int x, const int y, const int h, const int slot)
  {
   int ms = KPU_MaxScroll(slot);
   if(ms <= 0)
      return;
   int vis = KPU_VisRows(slot);
   int bw = KP_S(16), bh = KP_S(16);
   uint cu = (g_scroll[slot] > 0  ? KP_AMBER : KP_TXT_FAINT);
   uint cd = (g_scroll[slot] < ms ? KP_AMBER : KP_TXT_FAINT);
   KPC_Fill(x, y, bw, bh, KP_BTN);
   KPC_Frame(x, y, bw, bh, KP_SEP);
   KPC_Text(x + bw/2, y + KP_S(3), "▲", cu, KP_FontCJK, 6.2, 1);
   KPC_AddHit(x, y, bw, bh, KPHIT_SCROLLUP, slot);
   KPC_Fill(x, y + h - bh, bw, bh, KP_BTN);
   KPC_Frame(x, y + h - bh, bw, bh, KP_SEP);
   KPC_Text(x + bw/2, y + h - bh + KP_S(3), "▼", cd, KP_FontCJK, 6.2, 1);
   KPC_AddHit(x, y + h - bh, bw, bh, KPHIT_SCROLLDN, slot);

   int ty1 = y + bh + KP_S(1), ty2 = y + h - bh - KP_S(1);
   int trk = ty2 - ty1;
   if(trk <= KP_S(20))
      return;
   KPC_Fill(x + bw/2 - KP_S(4), ty1, KP_S(8), trk, KP_BG_CELL);
   KPC_Frame(x + bw/2 - KP_S(4), ty1, KP_S(8), trk, KP_SEP);
   KPC_AddHit(x, ty1, bw, trk, KPHIT_SCROLLTRK, slot);
   // thumb sized by page share of the whole list
   int th = MathMax(KP_S(16), (int)((double)trk * vis / (vis + ms)));
   int tp = ty1 + (int)((double)(trk - th) * g_scroll[slot] / MathMax(1, ms));
   KPC_Fill(x + bw/2 - KP_S(3), tp + KP_S(1), KP_S(6), th - KP_S(2), KP_AMBER_DIM);
  }

//--- analysis tab ----------------------------------------------------
void KPU_DrawAnalysis(const int W, const int y0)
  {
   int px = KP_S(KPL_PAD);
   int cw = W - 2*px - KP_S(16);
   int y  = y0 + KP_S(4);

   // period selector
   int bw = KP_S(34), bh = KP_S(16);
   for(int i=0; i<4; i++)
     {
      string pn = (i == 0 ? LL("D", "日") : i == 1 ? LL("W", "周") :
                   i == 2 ? LL("M", "月") : LL("Y", "年"));
      KPU_Chip(px + i*(bw+KP_S(3)), y, bw, bh, pn, g_period == i, KPHIT_PERIOD, i, 6.8);
     }
   KPC_Lbl(px + cw, y + KP_S(3), LL("BY CLOSE TIME · INCL FEES", "按平仓时间归集 · 含手续费"),
           KP_TXT_FAINT, 6.0, 2);
   y += bh + KP_S(5);

   // columns
   int c_lbl = KP_S(68), c_ord = KP_S(38), c_lot = KP_S(44), c_win = KP_S(40);
   int c_gw  = KP_S(64), c_gl  = KP_S(64), c_dd = KP_S(60), c_ddp = KP_S(46);
   int c_net = cw - KP_S(16) - c_lbl - c_ord - c_lot - c_win - c_gw - c_gl - c_dd - c_ddp;
   int hx = px;

   KPC_Fill(px, y, cw, KP_S(KPL_THEAD), KP_BG_THEAD);
   int ty = y + KP_S(4);
   KPC_Lbl(hx + KP_S(3), ty, LL("DATE", "日期"), KP_TXT_DIM, 6.4);         hx += c_lbl;
   KPC_Lbl(hx + c_ord - KP_S(3), ty, LL("TRD", "订单"), KP_TXT_DIM, 6.4, 2);  hx += c_ord;
   KPC_Lbl(hx + c_lot - KP_S(3), ty, LL("LOTS", "手数"), KP_TXT_DIM, 6.4, 2);    hx += c_lot;
   KPC_Lbl(hx + c_win - KP_S(3), ty, LL("WIN%", "胜率"), KP_TXT_DIM, 6.4, 2);    hx += c_win;
   KPC_Lbl(hx + c_gw - KP_S(3), ty, LL("PROFIT", "总盈利"), KP_TXT_DIM, 6.4, 2); hx += c_gw;
   KPC_Lbl(hx + c_gl - KP_S(3), ty, LL("LOSS", "总亏损"), KP_TXT_DIM, 6.4, 2);   hx += c_gl;
   KPC_Lbl(hx + c_dd - KP_S(3), ty, LL("MAXDD", "最大回撤"), KP_TXT_DIM, 6.4, 2); hx += c_dd;
   KPC_Lbl(hx + c_ddp - KP_S(3), ty, "DD%", KP_TXT_DIM, 6.4, 2); hx += c_ddp;
   KPC_Lbl(hx + c_net - KP_S(3), ty, LL("NET", "净盈亏"), KP_TXT_DIM, 6.4, 2);
   y += KP_S(KPL_THEAD);

   int n = 0;
   if(g_period == 0) n = ArraySize(g_days);
   else if(g_period == 1) n = ArraySize(g_weeks);
   else if(g_period == 2) n = ArraySize(g_months);
   else n = ArraySize(g_years);

   int vis = KPU_VisRows(1), rh = KP_S(KPL_ROW);
   int table_y = y;
   g_scroll[1] = MathMax(0, MathMin(g_scroll[1], KPU_MaxScroll(1)));

   for(int r=0; r<vis; r++)
     {
      int yy = y + r*rh;
      KPC_Fill(px, yy, cw, rh, (r % 2 == 0 ? KP_BG_CELL : KP_BG_CELL2));
      int di = n - 1 - g_scroll[1] - r;   // newest first
      if(di < 0 || di >= n)
         continue;
      KPAggRow row;
      if(g_period == 0) row = g_days[di];
      else if(g_period == 1) row = g_weeks[di];
      else if(g_period == 2) row = g_months[di];
      else row = g_years[di];

      double wr = (row.trades > 0 ? 100.0*row.wins/row.trades : 0.0);
      int xx = px;
      int ry = yy + KP_S(3);
      bool cash_only = (row.trades == 0 && MathAbs(row.cashflow) > 0.0000001);
      KPC_Num(xx + KP_S(3), ry, row.label, (cash_only ? KP_TXT_FAINT : KP_TXT), 6.8); xx += c_lbl;
      KPC_Num(xx + c_ord - KP_S(3), ry, (row.trades>0 ? (string)row.trades : "-"), KP_TXT_DIM, 6.8, 2); xx += c_ord;
      KPC_Num(xx + c_lot - KP_S(3), ry, (row.trades>0 ? KP_Lots(row.lots) : "-"), KP_TXT_DIM, 6.8, 2);  xx += c_lot;
      KPC_Num(xx + c_win - KP_S(3), ry, (row.trades>0 ? KP_Pct(wr,0) : "-"),
              (wr >= 50 ? KP_GREEN : KP_TXT_DIM), 6.8, 2); xx += c_win;
      KPC_Num(xx + c_gw - KP_S(3), ry, (row.trades>0 ? KP_Money(row.gross_win,0) : "-"), KP_GREEN, 6.8, 2); xx += c_gw;
      KPC_Num(xx + c_gl - KP_S(3), ry, (row.trades>0 ? KP_Money(row.gross_loss,0) : "-"), KP_RED, 6.8, 2);  xx += c_gl;
      KPC_Num(xx + c_dd - KP_S(3), ry, (row.trades>0 && row.dd > 0.005 ? KP_Money(row.dd,0) : "-"),
              (row.dd > 0.005 ? KP_RED : KP_TXT_FAINT), 6.8, 2); xx += c_dd;
      KPC_Num(xx + c_ddp - KP_S(3), ry, (row.trades>0 && row.dd > 0.005 ? KP_Pct(row.dd_pct) : "-"),
              (row.dd_pct >= 10.0 ? KP_RED : row.dd > 0.005 ? KP_TXT_DIM : KP_TXT_FAINT), 6.8, 2); xx += c_ddp;
      KPC_Num(xx + c_net - KP_S(3), ry, KP_MoneySigned(row.profit,1), KP_PLColor(row.profit), 6.8, 2, true);
     }
   y += vis*rh;

   // summary row (whole history)
   KPC_Fill(px, y, cw, rh, KP_BG_THEAD);
   KPC_HLine(px, px+cw-1, y, KP_AMBER_DIM);
   double swr = g_tot.win_rate;
   int sx = px, sy2 = y + KP_S(3);
   KPC_Lbl(sx + KP_S(3), sy2, LL("TOTAL", "汇总"), KP_AMBER, 6.8, 0, true);  sx += c_lbl;
   KPC_Num(sx + c_ord - KP_S(3), sy2, (string)g_tot.closed_trades, KP_TXT, 6.8, 2); sx += c_ord;
   KPC_Num(sx + c_lot - KP_S(3), sy2, KP_Lots(g_tot.lots), KP_TXT, 6.8, 2); sx += c_lot;
   KPC_Num(sx + c_win - KP_S(3), sy2, KP_Pct(swr,0), (swr>=50 ? KP_GREEN : KP_TXT_DIM), 6.8, 2); sx += c_win;
   KPC_Num(sx + c_gw - KP_S(3), sy2, KP_Money(g_tot.gross_profit,0), KP_GREEN, 6.8, 2); sx += c_gw;
   KPC_Num(sx + c_gl - KP_S(3), sy2, KP_Money(g_tot.gross_loss,0), KP_RED, 6.8, 2); sx += c_gl;
   KPC_Num(sx + c_dd - KP_S(3), sy2, KP_Money(g_tot.max_dd,0), KP_RED, 6.8, 2); sx += c_dd;
   KPC_Num(sx + c_ddp - KP_S(3), sy2, KP_Pct(g_tot.max_dd_pct), KP_RED, 6.8, 2); sx += c_ddp;
   KPC_Num(sx + c_net - KP_S(3), sy2, KP_MoneySigned(g_tot.net,1), KP_PLColor(g_tot.net), 6.8, 2, true);

   KPU_ScrollUI(W - KP_S(18), table_y, vis*rh, 1);
  }

//--- symbols / magic shared table -----------------------------------
void KPU_SortIdx(const KPAggRow &rows[], int &idx[])
  {
   int n = ArraySize(rows);
   ArrayResize(idx, n);
   for(int i=0; i<n; i++) idx[i] = i;
   for(int i=1; i<n; i++)
     {
      int k = idx[i];
      double v = rows[k].profit;
      int j = i - 1;
      while(j >= 0 && (g_sort_desc ? rows[idx[j]].profit < v
                                   : rows[idx[j]].profit > v))
        {
         idx[j+1] = idx[j];
         j--;
        }
      idx[j+1] = k;
     }
  }

void KPU_DrawAggTable(const int W, const int y0, const KPAggRow &rows[],
                      const string title, const int tab)
  {
   int px = KP_S(KPL_PAD);
   int cw = W - 2*px - KP_S(16);
   int y  = y0 + KP_S(4);

   y = KPU_Section(px, y, title);

   int c_lbl = KP_S(88), c_ord = KP_S(46), c_lot = KP_S(54), c_win = KP_S(48);
   int c_net = KP_S(96);
   int c_bar = cw - c_lbl - c_ord - c_lot - c_win - c_net;

   KPC_Fill(px, y, cw, KP_S(KPL_THEAD), KP_BG_THEAD);
   int ty = y + KP_S(4);
   int hx = px;
   KPC_Lbl(hx + KP_S(3), ty, (tab==2 ? LL("SYMBOL", "品种") : LL("MAGIC", "魔号")),
           KP_TXT_DIM, 6.4);  hx += c_lbl;
   KPC_Lbl(hx + c_ord - KP_S(3), ty, LL("TRADES", "订单"), KP_TXT_DIM, 6.4, 2); hx += c_ord;
   KPC_Lbl(hx + c_lot - KP_S(3), ty, LL("LOTS", "手数"), KP_TXT_DIM, 6.4, 2);   hx += c_lot;
   KPC_Lbl(hx + c_win - KP_S(3), ty, LL("WIN%", "胜率"), KP_TXT_DIM, 6.4, 2);   hx += c_win;
   KPC_Text(hx + c_net - KP_S(3), ty, (g_sort_desc ? "▼" : "▲"), KP_AMBER,
            KP_FontCJK, 6.0, 2);
   KPC_Lbl(hx + c_net - KP_S(14), ty, LL("NET", "净盈亏"), KP_AMBER, 6.4, 2);
   KPC_AddHit(hx, y, c_net + KP_S(6), KP_S(KPL_THEAD), KPHIT_SORT, tab);
   hx += c_net;
   KPC_Lbl(hx + KP_S(8), ty, LL("DISTRIBUTION", "利润分布"), KP_TXT_DIM, 6.4);
   y += KP_S(KPL_THEAD);

   int n = ArraySize(rows);
   int idx[];
   KPU_SortIdx(rows, idx);

   double amax = 0;
   for(int i=0; i<n; i++)
      if(MathAbs(rows[i].profit) > amax) amax = MathAbs(rows[i].profit);
   if(amax < 0.0000001) amax = 1;

   int vis = KPU_VisRows(tab), rh = KP_S(KPL_ROW);
   int table_y = y;
   g_scroll[tab] = MathMax(0, MathMin(g_scroll[tab], KPU_MaxScroll(tab)));

   for(int r=0; r<vis; r++)
     {
      int yy = y + r*rh;
      KPC_Fill(px, yy, cw, rh, (r % 2 == 0 ? KP_BG_CELL : KP_BG_CELL2));
      int di = g_scroll[tab] + r;
      if(di >= n)
         continue;
      KPAggRow row = rows[idx[di]];
      // localized label for the manual-magic bucket
      string lab = (tab == 3 && row.key_magic == 0 ? LL("MANUAL", "手动") : row.label);
      double wr = (row.trades > 0 ? 100.0*row.wins/row.trades : 0.0);
      int xx = px, ry = yy + KP_S(3);
      KPC_Num(xx + KP_S(3), ry, KPU_Trunc(lab, c_lbl-KP_S(8), KP_FontMono, 6.8), KP_TXT, 6.8); xx += c_lbl;
      KPC_Num(xx + c_ord - KP_S(3), ry, (string)row.trades, KP_TXT_DIM, 6.8, 2); xx += c_ord;
      KPC_Num(xx + c_lot - KP_S(3), ry, KP_Lots(row.lots), KP_TXT_DIM, 6.8, 2);  xx += c_lot;
      KPC_Num(xx + c_win - KP_S(3), ry, (row.trades>0 ? KP_Pct(wr,0) : "-"),
              (wr >= 50 ? KP_GREEN : KP_TXT_DIM), 6.8, 2); xx += c_win;
      KPC_Num(xx + c_net - KP_S(3), ry, KP_MoneySigned(row.profit,1), KP_PLColor(row.profit), 6.8, 2, true); xx += c_net;
      int bx = xx + KP_S(8);
      int bw = c_bar - KP_S(14);
      int fw = (int)MathRound(bw * MathAbs(row.profit) / amax);
      KPC_Fill(bx, yy + KP_S(5), bw, KP_S(6), KP_SEP);
      if(fw > 0)
         KPC_Fill(bx, yy + KP_S(5), fw, KP_S(6), (row.profit >= 0 ? KP_GREEN : KP_RED));
     }
   y += vis*rh;

   double rowsum = 0;
   for(int i=0; i<n; i++)
      rowsum += rows[i].profit;
   KPC_HLine(px, px+cw-1, y, KP_AMBER_DIM);
   KPC_Lbl(px + KP_S(3), y + KP_S(5), StringFormat(LL("%d ITEMS", "共 %d 项"), n),
           KP_TXT_FAINT, 6.4);
   KPC_Num(px + cw - KP_S(3), y + KP_S(5),
           LL("NET TOTAL ", "净盈亏合计 ") + KP_MoneySigned(rowsum, 1), KP_TXT_DIM, 6.6, 2);

   KPU_ScrollUI(W - KP_S(18), table_y, vis*rh, tab);
  }

//--- trade tab (positions + pending orders) -------------------------
void KPU_DrawPositions(const int W, const int y0)
  {
   int px = KP_S(KPL_PAD);
   int cw = W - 2*px - KP_S(16);
   int y  = y0 + KP_S(4);

   // summary strip
   int nb=0, ns=0; double lb=0, ls=0, plb=0, pls=0;
   for(int i=0; i<g_live_count; i++)
     {
      if(g_live[i].type == POSITION_TYPE_BUY) { nb++; lb += g_live[i].lots; plb += g_live[i].profit; }
      else                                    { ns++; ls += g_live[i].lots; pls += g_live[i].profit; }
     }
   int ty0 = y + KP_S(3);
   KPC_Lbl(px, ty0, LL("LONG", "多"), KP_GREEN, 6.6, 0, true);
   KPC_Num(px + KP_S(34), ty0, StringFormat("%d/%s %s", nb, KP_Lots(lb), KP_MoneySigned(plb,1)),
           KP_PLColor(plb), 6.8);
   KPC_Lbl(px + KP_S(172), ty0, LL("SHORT", "空"), KP_RED, 6.6, 0, true);
   KPC_Num(px + KP_S(212), ty0, StringFormat("%d/%s %s", ns, KP_Lots(ls), KP_MoneySigned(pls,1)),
           KP_PLColor(pls), 6.8);
   KPC_Lbl(px + cw - KP_S(150), ty0, LL("FLOAT", "浮动"), KP_TXT_DIM, 6.6);
   KPC_Num(px + cw, ty0, KP_MoneySigned(g_acc.floating_pl), KP_PLColor(g_acc.floating_pl), 7.2, 2, true);
   y += KP_S(22);

   // ops row
   string bn[6];
   bn[0] = LL("CLOSE ALL", "全平");
   bn[1] = LL("CLOSE BUY", "平多");
   bn[2] = LL("CLOSE SELL", "平空");
   bn[3] = LL("CLOSE WIN", "平盈利");
   bn[4] = LL("CLOSE LOSS", "平亏损");
   bn[5] = LL("DEL ORDERS", "撤挂单");
   int    bm[6] = {KP_CLOSE_ALL, KP_CLOSE_BUY, KP_CLOSE_SELL, KP_CLOSE_PROFIT, KP_CLOSE_LOSS, -1};
   int bw = (cw - KP_S(15)) / 6, bh = KP_S(18);
   for(int i=0; i<6; i++)
     {
      int bx = px + i*(bw + KP_S(3));
      int id  = (bm[i] < 0 ? KPHIT_DELPEND : KPHIT_CLOSEOP);
      long ar = (bm[i] < 0 ? 0 : bm[i]);
      KPC_Button(bx, y, bw, bh, bn[i], (i==0 ? KP_AMBER : KP_TXT), KP_BTN, id, ar, "", 6.2);
     }
   y += bh + KP_S(5);

   // sub tabs
   int sw = KP_S(96);
   KPU_Chip(px, y, sw, KP_S(16),
            StringFormat(LL("POSITIONS %d", "持仓 %d"), g_live_count),
            g_pos_sub == 0, KPHIT_POSSUB, 0, 6.4);
   KPU_Chip(px + sw + KP_S(4), y, sw, KP_S(16),
            StringFormat(LL("ORDERS %d", "挂单 %d"), g_ord_count),
            g_pos_sub == 1, KPHIT_POSSUB, 1, 6.4);
   y += KP_S(20);

   int vis = KPU_VisRows(KPU_ScrollSlot(4)), rh = KP_S(KPL_ROW);
   int slot = KPU_ScrollSlot(4);
   g_scroll[slot] = MathMax(0, MathMin(g_scroll[slot], KPU_MaxScroll(slot)));

   if(g_pos_sub == 0)
     {
      // positions table
      int c_sym = KP_S(76), c_dir = KP_S(28), c_lot = KP_S(50);
      int c_op  = KP_S(80), c_cp  = KP_S(80), c_pl = KP_S(88);
      int c_tm  = cw - c_sym - c_dir - c_lot - c_op - c_cp - c_pl - KP_S(22);
      KPC_Fill(px, y, cw, KP_S(KPL_THEAD), KP_BG_THEAD);
      int ty = y + KP_S(4), hx = px;
      KPC_Lbl(hx + KP_S(3), ty, LL("SYMBOL", "品种"), KP_TXT_DIM, 6.4);   hx += c_sym;
      KPC_Lbl(hx, ty, LL("B/S", "向"), KP_TXT_DIM, 6.4);                  hx += c_dir;
      KPC_Lbl(hx + c_lot - KP_S(3), ty, LL("LOTS", "手数"), KP_TXT_DIM, 6.4, 2);  hx += c_lot;
      KPC_Lbl(hx + c_op - KP_S(3), ty, LL("OPEN", "开仓价"), KP_TXT_DIM, 6.4, 2); hx += c_op;
      KPC_Lbl(hx + c_cp - KP_S(3), ty, LL("PRICE", "现价"), KP_TXT_DIM, 6.4, 2);  hx += c_cp;
      KPC_Lbl(hx + c_pl - KP_S(3), ty, LL("P&L", "盈亏"), KP_TXT_DIM, 6.4, 2);    hx += c_pl;
      KPC_Lbl(hx + c_tm - KP_S(3), ty, LL("AGE", "时长"), KP_TXT_DIM, 6.4, 2);
      y += KP_S(KPL_THEAD);
      int table_y = y;

      if(g_live_count == 0)
        {
         KPC_Fill(px, y, cw, vis*rh, KP_BG_CELL);
         int my = y + vis*rh/2 - KP_S(16);
         KPC_Lbl(px + cw/2, my, LL("NO OPEN POSITIONS", "当前无持仓"), KP_TXT_FAINT, 7.6, 1);
         if(KP_BrandShow)
            KPC_Text(px + cw/2, my + KP_S(20), "Telegram " + KP_BrandChannel,
                     KP_TXT_FAINT, KP_FontMono, 6.4, 1);
        }
      else
        {
         for(int r=0; r<vis; r++)
           {
            int yy = y + r*rh;
            KPC_Fill(px, yy, cw, rh, (r % 2 == 0 ? KP_BG_CELL : KP_BG_CELL2));
            int di = g_scroll[4] + r;
            if(di >= g_live_count)
               continue;
            int dg = (int)SymbolInfoInteger(g_live[di].symbol, SYMBOL_DIGITS);
            bool buy = (g_live[di].type == POSITION_TYPE_BUY);
            int xx = px, ry = yy + KP_S(3);
            KPC_Num(xx + KP_S(3), ry, KPU_Trunc(g_live[di].symbol, c_sym-KP_S(8), KP_FontMono, 6.8), KP_TXT, 6.8); xx += c_sym;
            KPC_Num(xx, ry, (buy ? "B" : "S"), (buy ? KP_GREEN : KP_RED), 6.8, 0, true); xx += c_dir;
            KPC_Num(xx + c_lot - KP_S(3), ry, KP_Lots(g_live[di].lots), KP_TXT_DIM, 6.8, 2); xx += c_lot;
            KPC_Num(xx + c_op - KP_S(3), ry, DoubleToString(g_live[di].price_open, dg), KP_TXT_DIM, 6.8, 2); xx += c_op;
            KPC_Num(xx + c_cp - KP_S(3), ry, DoubleToString(g_live[di].price_cur, dg), KP_TXT, 6.8, 2); xx += c_cp;
            KPC_Num(xx + c_pl - KP_S(3), ry, KP_MoneySigned(g_live[di].profit,1), KP_PLColor(g_live[di].profit), 6.8, 2, true); xx += c_pl;
            KPC_Num(xx + c_tm - KP_S(3), ry, KP_Duration((long)(TimeCurrent() - g_live[di].time)), KP_TXT_FAINT, 6.4, 2);
            int cx = px + cw - KP_S(16);
            KPC_Fill(cx, yy + KP_S(2), KP_S(13), rh - KP_S(4), KP_BTN);
            KPC_Num(cx + KP_S(6), yy + KP_S(3), "×", KP_RED, 6.8, 1, true);
            KPC_AddHit(cx, yy, KP_S(16), rh, KPHIT_CLOSETK, (long)g_live[di].ticket);
           }
        }
      y += vis*rh;
      KPU_ScrollUI(W - KP_S(18), table_y, vis*rh, 4);
     }
   else
     {
      // pending orders table
      int c_sym = KP_S(76), c_typ = KP_S(46), c_lot = KP_S(50);
      int c_pr  = KP_S(80), c_cp  = KP_S(80), c_ds = KP_S(56);
      int c_tm  = cw - c_sym - c_typ - c_lot - c_pr - c_cp - c_ds - KP_S(22);
      KPC_Fill(px, y, cw, KP_S(KPL_THEAD), KP_BG_THEAD);
      int ty = y + KP_S(4), hx = px;
      KPC_Lbl(hx + KP_S(3), ty, LL("SYMBOL", "品种"), KP_TXT_DIM, 6.4);   hx += c_sym;
      KPC_Lbl(hx, ty, LL("TYPE", "类型"), KP_TXT_DIM, 6.4);               hx += c_typ;
      KPC_Lbl(hx + c_lot - KP_S(3), ty, LL("LOTS", "手数"), KP_TXT_DIM, 6.4, 2);   hx += c_lot;
      KPC_Lbl(hx + c_pr - KP_S(3), ty, LL("PRICE", "挂单价"), KP_TXT_DIM, 6.4, 2); hx += c_pr;
      KPC_Lbl(hx + c_cp - KP_S(3), ty, LL("NOW", "现价"), KP_TXT_DIM, 6.4, 2);     hx += c_cp;
      KPC_Lbl(hx + c_ds - KP_S(3), ty, LL("DIST", "距离"), KP_TXT_DIM, 6.4, 2);    hx += c_ds;
      KPC_Lbl(hx + c_tm - KP_S(3), ty, LL("AGE", "时长"), KP_TXT_DIM, 6.4, 2);
      y += KP_S(KPL_THEAD);
      int table_y = y;

      if(g_ord_count == 0)
        {
         KPC_Fill(px, y, cw, vis*rh, KP_BG_CELL);
         KPC_Lbl(px + cw/2, y + vis*rh/2 - KP_S(7),
                 LL("NO PENDING ORDERS", "当前无挂单"), KP_TXT_FAINT, 7.6, 1);
        }
      else
        {
         for(int r=0; r<vis; r++)
           {
            int yy = y + r*rh;
            KPC_Fill(px, yy, cw, rh, (r % 2 == 0 ? KP_BG_CELL : KP_BG_CELL2));
            int di = g_scroll[8] + r;
            if(di >= g_ord_count)
               continue;
            int dg = (int)SymbolInfoInteger(g_ord[di].symbol, SYMBOL_DIGITS);
            double pt = SymbolInfoDouble(g_ord[di].symbol, SYMBOL_POINT);
            bool buy = KP_OrdIsBuy(g_ord[di].type);
            int dist = (pt > 0 ? (int)MathRound(MathAbs(g_ord[di].price - g_ord[di].price_cur) / pt) : 0);
            int xx = px, ry = yy + KP_S(3);
            KPC_Num(xx + KP_S(3), ry, KPU_Trunc(g_ord[di].symbol, c_sym-KP_S(8), KP_FontMono, 6.8), KP_TXT, 6.8); xx += c_sym;
            KPC_Num(xx, ry, KP_OrdTypeTag(g_ord[di].type), (buy ? KP_GREEN : KP_RED), 6.6); xx += c_typ;
            KPC_Num(xx + c_lot - KP_S(3), ry, KP_Lots(g_ord[di].lots), KP_TXT_DIM, 6.8, 2); xx += c_lot;
            KPC_Num(xx + c_pr - KP_S(3), ry, DoubleToString(g_ord[di].price, dg), KP_AMBER, 6.8, 2); xx += c_pr;
            KPC_Num(xx + c_cp - KP_S(3), ry, DoubleToString(g_ord[di].price_cur, dg), KP_TXT, 6.8, 2); xx += c_cp;
            KPC_Num(xx + c_ds - KP_S(3), ry, (string)dist, KP_TXT_DIM, 6.8, 2); xx += c_ds;
            KPC_Num(xx + c_tm - KP_S(3), ry, KP_Duration((long)(TimeCurrent() - g_ord[di].time)), KP_TXT_FAINT, 6.4, 2);
            int cx = px + cw - KP_S(16);
            KPC_Fill(cx, yy + KP_S(2), KP_S(13), rh - KP_S(4), KP_BTN);
            KPC_Num(cx + KP_S(6), yy + KP_S(3), "×", KP_RED, 6.8, 1, true);
            KPC_AddHit(cx, yy, KP_S(16), rh, KPHIT_DELTK, (long)g_ord[di].ticket);
           }
        }
      y += vis*rh;
      KPU_ScrollUI(W - KP_S(18), table_y, vis*rh, 8);
     }
  }

//--- order ticket tab ------------------------------------------------
void KPU_DrawOrder(const int W, const int y0)
  {
   int px = KP_S(KPL_PAD);
   int cw = W - 2*px;
   int y  = y0 + KP_S(4);

   if(g_ot_symbol == "" || !SymbolInfoInteger(g_ot_symbol, SYMBOL_SELECT))
      g_ot_symbol = _Symbol;
   double vmin  = SymbolInfoDouble(g_ot_symbol, SYMBOL_VOLUME_MIN);
   double vstep = SymbolInfoDouble(g_ot_symbol, SYMBOL_VOLUME_STEP);
   if(g_ot_lots <= 0)
      g_ot_lots = (vmin > 0 ? vmin : 0.01);

   y = KPU_Section(px, y, LL("ORDER TICKET", "下单面板"));

   //-- symbol row + quotes
   int dg = (int)SymbolInfoInteger(g_ot_symbol, SYMBOL_DIGITS);
   MqlTick tk;
   bool has_tk = SymbolInfoTick(g_ot_symbol, tk);
   KPC_Button(px, y, KP_S(18), KP_S(20), "<", KP_TXT_DIM, KP_BTN, KPHIT_OT_SYM, 0, "", 7.4, false);
   KPC_Fill(px + KP_S(21), y, KP_S(124), KP_S(20), KP_BG_INPUT);
   KPC_Frame(px + KP_S(21), y, KP_S(124), KP_S(20), KP_SEP);
   KPC_Num(px + KP_S(83), y + KP_S(4),
           KPU_Trunc(g_ot_symbol, KP_S(116), KP_FontMono, 8.0), KP_AMBER, 8.0, 1, true);
   KPC_Button(px + KP_S(148), y, KP_S(18), KP_S(20), ">", KP_TXT_DIM, KP_BTN, KPHIT_OT_SYM, 1, "", 7.4, false);

   long sprd = SymbolInfoInteger(g_ot_symbol, SYMBOL_SPREAD);
   KPC_Lbl(px + KP_S(184), y + KP_S(5), LL("BID", "卖价"), KP_TXT_FAINT, 6.2);
   KPC_Num(px + KP_S(212), y + KP_S(3), (has_tk ? DoubleToString(tk.bid, dg) : "--"),
           KP_RED, 8.0, 0, true);
   KPC_Lbl(px + cw - KP_S(170), y + KP_S(5), LL("ASK", "买价"), KP_TXT_FAINT, 6.2);
   KPC_Num(px + cw - KP_S(142), y + KP_S(3), (has_tk ? DoubleToString(tk.ask, dg) : "--"),
           KP_GREEN, 8.0, 0, true);
   KPC_Num(px + cw, y + KP_S(5), StringFormat("SPR %d", (int)sprd), KP_TXT_FAINT, 6.4, 2);
   y += KP_S(26);

   //-- lots row
   KPC_Lbl(px, y + KP_S(4), LL("LOTS", "手数"), KP_TXT_DIM, 6.6);
   KPC_Button(px + KP_S(50), y, KP_S(18), KP_S(18), "-", KP_TXT, KP_BTN, KPHIT_OT_LOTS, 0, "", 7.6, false);
   KPC_Fill(px + KP_S(70), y, KP_S(66), KP_S(18), KP_BG_INPUT);
   KPC_Frame(px + KP_S(70), y, KP_S(66), KP_S(18), KP_SEP);
   KPC_Num(px + KP_S(103), y + KP_S(3), DoubleToString(g_ot_lots, 2), KP_AMBER, 7.6, 1, true);
   KPC_Button(px + KP_S(138), y, KP_S(18), KP_S(18), "+", KP_TXT, KP_BTN, KPHIT_OT_LOTS, 1, "", 7.6, false);
   double presets[4] = {0.01, 0.10, 0.50, 1.00};
   for(int i=0; i<4; i++)
     {
      string pl = DoubleToString(presets[i], 2);
      bool on = (MathAbs(g_ot_lots - presets[i]) < 0.0000001);
      KPU_Chip(px + KP_S(170) + i*KP_S(48), y + KP_S(1), KP_S(44), KP_S(16), pl,
               on, KPHIT_OT_PRESET, i, 6.2);
     }
   KPC_Num(px + cw, y + KP_S(4),
           StringFormat("MIN %s STEP %s", DoubleToString(vmin, 2), DoubleToString(vstep, 2)),
           KP_TXT_FAINT, 6.0, 2);
   y += KP_S(24);

   //-- SL / TP row (points, 0 = off)
   KPC_Lbl(px, y + KP_S(4), LL("SL pt", "止损点"), KP_TXT_DIM, 6.6);
   KPC_Button(px + KP_S(50), y, KP_S(18), KP_S(18), "-", KP_TXT, KP_BTN, KPHIT_OT_SL, 0, "", 7.6, false);
   KPC_Fill(px + KP_S(70), y, KP_S(56), KP_S(18), KP_BG_INPUT);
   KPC_Frame(px + KP_S(70), y, KP_S(56), KP_S(18), KP_SEP);
   KPC_Num(px + KP_S(98), y + KP_S(3), (g_ot_sl > 0 ? (string)g_ot_sl : LL("OFF", "关")),
           (g_ot_sl > 0 ? KP_RED : KP_TXT_FAINT), 7.2, 1, true);
   KPC_Button(px + KP_S(128), y, KP_S(18), KP_S(18), "+", KP_TXT, KP_BTN, KPHIT_OT_SL, 1, "", 7.6, false);

   int tx = px + cw/2 + KP_S(10);
   KPC_Lbl(tx, y + KP_S(4), LL("TP pt", "止盈点"), KP_TXT_DIM, 6.6);
   KPC_Button(tx + KP_S(50), y, KP_S(18), KP_S(18), "-", KP_TXT, KP_BTN, KPHIT_OT_TP, 0, "", 7.6, false);
   KPC_Fill(tx + KP_S(70), y, KP_S(56), KP_S(18), KP_BG_INPUT);
   KPC_Frame(tx + KP_S(70), y, KP_S(56), KP_S(18), KP_SEP);
   KPC_Num(tx + KP_S(98), y + KP_S(3), (g_ot_tp > 0 ? (string)g_ot_tp : LL("OFF", "关")),
           (g_ot_tp > 0 ? KP_GREEN : KP_TXT_FAINT), 7.2, 1, true);
   KPC_Button(tx + KP_S(128), y, KP_S(18), KP_S(18), "+", KP_TXT, KP_BTN, KPHIT_OT_TP, 1, "", 7.6, false);
   y += KP_S(24);

   //-- market buttons
   int bw2 = cw/2 - KP_S(3);
   KPC_Fill(px, y, bw2, KP_S(34), KP_RED_DIM);
   KPC_Frame(px, y, bw2, KP_S(34), KP_RED);
   KPC_Lbl(px + bw2/2, y + KP_S(4), LL("SELL", "卖出 SELL"), KP_TXT, 7.4, 1, true);
   KPC_Num(px + bw2/2, y + KP_S(19), (has_tk ? DoubleToString(tk.bid, dg) : "--"),
           KP_RED, 7.4, 1, true);
   KPC_AddHit(px, y, bw2, KP_S(34), KPHIT_OT_SELL, 0);

   int bx2 = px + cw - bw2;
   KPC_Fill(bx2, y, bw2, KP_S(34), KP_GREEN_DIM);
   KPC_Frame(bx2, y, bw2, KP_S(34), KP_GREEN);
   KPC_Lbl(bx2 + bw2/2, y + KP_S(4), LL("BUY", "买入 BUY"), KP_TXT, 7.4, 1, true);
   KPC_Num(bx2 + bw2/2, y + KP_S(19), (has_tk ? DoubleToString(tk.ask, dg) : "--"),
           KP_GREEN, 7.4, 1, true);
   KPC_AddHit(bx2, y, bw2, KP_S(34), KPHIT_OT_BUY, 0);
   y += KP_S(40);

   //-- pending row
   KPC_Lbl(px, y + KP_S(4), LL("DIST pt", "距离点"), KP_TXT_DIM, 6.6);
   KPC_Button(px + KP_S(50), y, KP_S(18), KP_S(18), "-", KP_TXT, KP_BTN, KPHIT_OT_DIST, 0, "", 7.6, false);
   KPC_Fill(px + KP_S(70), y, KP_S(56), KP_S(18), KP_BG_INPUT);
   KPC_Frame(px + KP_S(70), y, KP_S(56), KP_S(18), KP_SEP);
   KPC_Num(px + KP_S(98), y + KP_S(3), (string)g_ot_dist, KP_AMBER, 7.2, 1, true);
   KPC_Button(px + KP_S(128), y, KP_S(18), KP_S(18), "+", KP_TXT, KP_BTN, KPHIT_OT_DIST, 1, "", 7.6, false);

   string pn[4] = {"B-LMT", "S-LMT", "B-STP", "S-STP"};
   int pbw = (cw - KP_S(170)) / 4 - KP_S(3);
   for(int i=0; i<4; i++)
     {
      int pbx = px + KP_S(170) + i*(pbw + KP_S(3));
      bool pbuy = (i == 0 || i == 2);
      KPC_Button(pbx, y, pbw, KP_S(18), pn[i],
                 (pbuy ? KP_GREEN : KP_RED), KP_BTN, KPHIT_OT_PEND, i, "", 6.4);
     }
   y += KP_S(24);

   //-- info line
   long stops = SymbolInfoInteger(g_ot_symbol, SYMBOL_TRADE_STOPS_LEVEL);
   KPC_Lbl(px, y + KP_S(2),
           StringFormat(LL("ONE-CLICK EXECUTION · Pending = market -/+ DIST · STOPS LEVEL %d pt · MAGIC %I64d",
                           "单击即下单 · 挂单价 = 现价 ∓ 距离点数 · 最小停止位 %d 点 · MAGIC %I64d"),
                        (int)stops, KPT_PanelMagic),
           KP_TXT_FAINT, 6.0);
  }

//--- risk tab --------------------------------------------------------
void KPU_RiskRow(const int px, const int cw, int y, const string title,
                 const string desc, const bool on, const string val,
                 const int which)
  {
   int rh = KP_S(44);
   KPC_Fill(px, y, cw, rh, KP_BG_CELL);
   KPC_Frame(px, y, cw, rh, KP_SEP);
   KPC_Fill(px, y, KP_S(3), rh, (on ? KP_AMBER : KP_SEP));
   KPC_Lbl(px + KP_S(10), y + KP_S(5), title, KP_TXT, 7.2, 0, true);
   KPC_Lbl(px + KP_S(10), y + KP_S(24), desc, KP_TXT_FAINT, 6.0);

   int vx = px + cw - KP_S(196);
   KPC_Button(vx, y + KP_S(11), KP_S(18), KP_S(20), "-", KP_TXT, KP_BTN,
              KPHIT_RISKSTEP, which*10 + 0, "", 8.0, false);
   KPC_Fill(vx + KP_S(20), y + KP_S(11), KP_S(96), KP_S(20), KP_BG_INPUT);
   KPC_Frame(vx + KP_S(20), y + KP_S(11), KP_S(96), KP_S(20), KP_SEP);
   KPC_Num(vx + KP_S(68), y + KP_S(15), val, (on ? KP_AMBER : KP_TXT_DIM), 7.4, 1, true);
   KPC_Button(vx + KP_S(118), y + KP_S(11), KP_S(18), KP_S(20), "+", KP_TXT, KP_BTN,
              KPHIT_RISKSTEP, which*10 + 1, "", 8.0, false);

   int tx = px + cw - KP_S(48);
   KPC_Button(tx, y + KP_S(11), KP_S(40), KP_S(20), (on ? "ON" : "OFF"),
              (on ? KP_BG : KP_TXT_DIM), (on ? KP_GREEN : KP_BTN),
              KPHIT_RISKTGL, which, "", 7.0, false);
  }

void KPU_DrawRisk(const int W, const int y0)
  {
   int px = KP_S(KPL_PAD);
   int cw = W - 2*px;
   int y  = y0 + KP_S(4);

   y = KPU_Section(px, y, LL("RISK GUARD · ONE-SHOT", "风险控制 · 一次性触发"));

   KPC_Fill(px, y, cw, KP_S(20), KP_BG_THEAD);
   int ry0 = y + KP_S(4);
   KPC_Lbl(px + KP_S(6), ry0, LL("FLOAT", "浮动盈亏"), KP_TXT_DIM, 6.4);
   KPC_Num(px + KP_S(126), ry0, KP_MoneySigned(g_acc.floating_pl),
           KP_PLColor(g_acc.floating_pl), 7.0, 2, true);
   KPC_Lbl(px + KP_S(156), ry0, LL("EQUITY", "净值"), KP_TXT_DIM, 6.4);
   KPC_Num(px + KP_S(266), ry0, KP_Money(g_acc.equity), KP_TXT, 7.0, 2, true);
   KPC_Lbl(px + KP_S(296), ry0, LL("POS", "持仓"), KP_TXT_DIM, 6.4);
   KPC_Num(px + cw - KP_S(8), ry0, (string)g_acc.positions,
           (g_acc.positions > 0 ? KP_CYAN : KP_TXT_FAINT), 7.0, 2, true);
   y += KP_S(25);

   int gap = KP_S(5);
   KPU_RiskRow(px, cw, y, LL("LOSS GUARD", "浮亏全平"),
               StringFormat(LL("Close all when float P&L <= -%s %s",
                               "浮动亏损 ≤ -%s %s 时市价全平"),
               KP_Money(MathAbs(g_risk.sl_val),0), g_acc.currency),
               g_risk.sl_on, "-" + KP_Money(MathAbs(g_risk.sl_val),0), 0);
   y += KP_S(44) + gap;
   KPU_RiskRow(px, cw, y, LL("PROFIT GUARD", "浮盈全平"),
               StringFormat(LL("Close all when float P&L >= %s %s",
                               "浮动盈利 ≥ %s %s 时市价全平"),
               KP_Money(MathAbs(g_risk.tp_val),0), g_acc.currency),
               g_risk.tp_on, "+" + KP_Money(MathAbs(g_risk.tp_val),0), 1);
   y += KP_S(44) + gap;
   KPU_RiskRow(px, cw, y, LL("EQUITY FLOOR", "净值保护"),
               LL("Close all when equity <= floor", "账户净值 ≤ 保护线时市价全平"),
               g_risk.floor_on, KP_Money(g_risk.floor_val,0), 2);
   y += KP_S(44) + gap;
   KPU_RiskRow(px, cw, y, LL("TIMED CLOSE", "定时平仓"),
               LL("Close all daily at server time (-/+ = 15 min)",
                  "每天到达服务器时间时市价全平 (-/+ 步进15分钟)"),
               g_risk.time_on,
               StringFormat("%02d:%02d", g_risk.time_hh, g_risk.time_mm), 3);
   y += KP_S(44) + gap;

   KPC_Lbl(px, y + KP_S(2),
           LL("Guards disarm automatically after firing; re-enable manually.",
              "以上开关均为一次性: 触发执行后自动关闭, 需手动重新开启"),
           KP_TXT_FAINT, 6.0);
  }

//--- news tab --------------------------------------------------------
void KPU_DrawNews(const int W, const int y0)
  {
   int px = KP_S(KPL_PAD);
   int cw = W - 2*px - KP_S(16);
   int y  = y0 + KP_S(4);

   // row 1: filter / refresh / status
   string fn = (g_news_filter == 3 ? LL("HIGH", "仅高") :
                g_news_filter == 2 ? LL("MID+", "中高") : LL("ALL", "全部"));
   KPU_Chip(px, y, KP_S(46), KP_S(16), fn, true, KPHIT_NEWSFILT, 0, 6.2);
   KPC_Button(px + KP_S(50), y, KP_S(50), KP_S(16), LL("REFRESH", "刷新"),
              KP_TXT_DIM, KP_BTN, KPHIT_NEWSREF, 0, "", 6.2);
   string st = (g_news_ok ?
                StringFormat(LL("%d EVENTS · UPD %s · SERVER TIME",
                                "共 %d 条 · 更新 %s · 服务器时间"),
                             KPN_FilteredCount(), KP_TimeShort(g_news_last)) :
                LL("CALENDAR UNAVAILABLE (enable News in terminal)",
                   "日历不可用: 请在终端选项中启用新闻"));
   // event names come from the terminal's calendar in the TERMINAL UI
   // language; flag the mismatch so it doesn't read as a panel bug
   if(g_news_ok && KP_Lang == 0 &&
      TerminalInfoString(TERMINAL_LANGUAGE) != "English")
      st = LL("NAMES FOLLOW TERMINAL LANG · ", "") + st;
   KPC_Lbl(px + cw, y + KP_S(3), st, (g_news_ok ? KP_TXT_FAINT : KP_YELLOW), 6.0, 2);
   y += KP_S(20);

   // row 2: alert settings
   KPU_Chip(px, y, KP_S(64), KP_S(16),
            LL(g_news_alert_on ? "ALERT ON" : "ALERT OFF",
               g_news_alert_on ? "提醒 开" : "提醒 关"),
            g_news_alert_on, KPHIT_NEWSALERT, 0, 6.2);
   int ax = px + KP_S(70);
   KPC_Button(ax, y, KP_S(14), KP_S(16), "-", KP_TXT, KP_BTN, KPHIT_NEWSSTARS, 0, "", 6.8, false);
   string stars = (g_news_stars == 3 ? "★★★" : g_news_stars == 2 ? "★★" : "★");
   KPC_Text(ax + KP_S(36), y + KP_S(3), stars, KP_YELLOW, KP_FontCJK, 6.4, 1);
   KPC_Button(ax + KP_S(56), y, KP_S(14), KP_S(16), "+", KP_TXT, KP_BTN, KPHIT_NEWSSTARS, 1, "", 6.8, false);
   int lx = ax + KP_S(78);
   KPC_Button(lx, y, KP_S(14), KP_S(16), "-", KP_TXT, KP_BTN, KPHIT_NEWSLEAD, 0, "", 6.8, false);
   KPC_Num(lx + KP_S(16) + KP_S(20), y + KP_S(3),
           StringFormat("%dM", g_news_lead_min), KP_TXT, 6.4, 1);
   KPC_Button(lx + KP_S(56), y, KP_S(14), KP_S(16), "+", KP_TXT, KP_BTN, KPHIT_NEWSLEAD, 1, "", 6.8, false);
   KPU_Chip(px + cw - KP_S(64), y, KP_S(64), KP_S(16),
            LL(g_news_marks_on ? "MARKS ON" : "MARKS OFF",
               g_news_marks_on ? "标线 开" : "标线 关"),
            g_news_marks_on, KPHIT_NEWSMARK, 0, 6.2);
   y += KP_S(20);

   // row 3: currency filter chips
     {
      int ccw = (cw - KP_S(27)) / KPN_NCUR;
      for(int i=0; i<KPN_NCUR; i++)
        {
         bool on = ((g_news_curmask >> i) & 1) == 1;
         KPU_Chip(px + i*(ccw + KP_S(3)), y, ccw, KP_S(14),
                  KPN_CurName[i], on, KPHIT_NEWSCUR, i, 5.8);
        }
     }
   y += KP_S(18);

   // table head
   int c_tm = KP_S(64), c_cur = KP_S(36), c_imp = KP_S(14);
   int c_pv = KP_S(56), c_fc = KP_S(56), c_ac = KP_S(56);
   int c_nm = cw - c_tm - c_cur - c_imp - c_pv - c_fc - c_ac;
   KPC_Fill(px, y, cw, KP_S(KPL_THEAD), KP_BG_THEAD);
   int ty = y + KP_S(4), hx = px;
   KPC_Lbl(hx + KP_S(3), ty, LL("TIME", "时间"), KP_TXT_DIM, 6.4);   hx += c_tm;
   KPC_Lbl(hx, ty, LL("CCY", "货币"), KP_TXT_DIM, 6.4);              hx += c_cur + c_imp;
   KPC_Lbl(hx, ty, LL("EVENT", "事件"), KP_TXT_DIM, 6.4);            hx += c_nm;
   KPC_Lbl(hx + c_pv - KP_S(3), ty, LL("PREV", "前值"), KP_TXT_DIM, 6.4, 2);  hx += c_pv;
   KPC_Lbl(hx + c_fc - KP_S(3), ty, LL("FCST", "预测"), KP_TXT_DIM, 6.4, 2);  hx += c_fc;
   KPC_Lbl(hx + c_ac - KP_S(3), ty, LL("ACT", "公布"), KP_TXT_DIM, 6.4, 2);
   y += KP_S(KPL_THEAD);

   // filtered indices
   int fidx[];
   int fcnt = 0;
   ArrayResize(fidx, g_news_count);
   for(int i=0; i<g_news_count; i++)
      if(KPN_RowVisible(i))
         fidx[fcnt++] = i;

   datetime now = TimeCurrent();
   int next_i = -1;
   for(int i=0; i<fcnt; i++)
      if(g_news[fidx[i]].time >= now) { next_i = i; break; }

   int vis = KPU_VisRows(7), rh = KP_S(KPL_ROW);
   int table_y = y;
   g_scroll[7] = MathMax(0, MathMin(g_scroll[7], KPU_MaxScroll(7)));

   for(int r=0; r<vis; r++)
     {
      int yy = y + r*rh;
      KPC_Fill(px, yy, cw, rh, (r % 2 == 0 ? KP_BG_CELL : KP_BG_CELL2));
      int di = g_scroll[7] + r;
      if(di >= fcnt)
         continue;
      KPNewsRow nr = g_news[fidx[di]];
      bool past = (nr.time < now);
      bool is_next = (di == next_i);
      if(is_next)
         KPC_Fill(px, yy, cw, rh, KP_ROW_HL);
      // readable base colors: bright for upcoming, dim (not faint) for past
      uint main_c = (past ? KP_TXT_DIM : KP_TXT);
      uint iclr = (nr.importance == 3 ? KP_RED : nr.importance == 2 ? KP_YELLOW : KP_TXT_DIM);
      int xx = px, ry = yy + KP_S(3);
      KPC_Num(xx + KP_S(3), ry, KP_TimeShort(nr.time),
              (is_next ? KP_AMBER : main_c), 6.6, 0, is_next); xx += c_tm;
      KPC_Num(xx, ry, nr.cur, iclr, 6.6, 0, true); xx += c_cur;
      KPC_Fill(xx + KP_S(1), yy + KP_S(5), KP_S(6), KP_S(6), iclr); xx += c_imp;
      KPC_Lbl(xx + KP_S(4), ry, KPU_Trunc(nr.name, c_nm - KP_S(10), KPU_LblFont(), 6.6),
              main_c, 6.6); xx += c_nm;
      KPC_Num(xx + c_pv - KP_S(3), ry, nr.v_prev, KP_TXT_DIM, 6.4, 2); xx += c_pv;
      KPC_Num(xx + c_fc - KP_S(3), ry, nr.v_fcst, KP_CYAN, 6.4, 2);    xx += c_fc;
      KPC_Num(xx + c_ac - KP_S(3), ry, nr.v_act,
              (nr.v_act == "--" ? KP_TXT_FAINT : KP_AMBER), 6.4, 2, true);
     }
   y += vis*rh;

   if(next_i >= 0)
     {
      long dt = (long)(g_news[fidx[next_i]].time - now);
      string nm = KPU_Trunc(g_news[fidx[next_i]].name, KP_S(220), KPU_LblFont(), 6.4);
      KPC_Lbl(px, y + KP_S(5), StringFormat(LL("NEXT  %s %s  in %s",
              "下一事件  %s %s  %s 后"),
              g_news[fidx[next_i]].cur, nm, KP_Duration(dt)), KP_AMBER, 6.4, 0, true);
     }
   KPU_ScrollUI(W - KP_S(18), table_y, vis*rh, 7);
  }

//--- click dispatch --------------------------------------------------
bool KPU_OnClick(const int lx, const int ly)
  {
   int hi = KPC_HitTest(lx, ly);
   if(hi < 0)
      return false;
   int  id  = g_hits[hi].id;
   long arg = g_hits[hi].arg;

   switch(id)
     {
      case KPHIT_COLLAPSE:
         g_collapsed = !g_collapsed;
         KP_StoreSet("ui_collapsed", g_collapsed ? 1 : 0);
         return true;

      case KPHIT_TAB:
         g_tab = (int)arg;
         g_modal = 0;
         if(g_tab == 7) KPN_Refresh(false);
         KP_StoreSet("ui_tab", g_tab);
         return true;

      case KPHIT_LANG:
         KP_Lang = (KP_Lang == 0 ? 1 : 0);
         KP_StoreSet("ui_lang", KP_Lang);
         return true;

      case KPHIT_EXPAND:
         g_modal = (g_modal == 1 ? 0 : 1);
         return true;

      case KPHIT_CHARTSEL:
         g_chart_sel = (int)arg;
         return true;

      case KPHIT_POSSUB:
         g_pos_sub = (int)arg;
         return true;

      case KPHIT_PERIOD:
         g_period = (int)arg;
         g_scroll[1] = 0;
         return true;

      case KPHIT_CURVESRC:
         g_curve_src = (int)arg;
         return true;

      case KPHIT_SORT:
         g_sort_desc = !g_sort_desc;
         return true;

      case KPHIT_SCROLLUP:
         g_scroll[(int)arg] = MathMax(0, g_scroll[(int)arg] - 3);
         return true;

      case KPHIT_SCROLLDN:
         g_scroll[(int)arg] = MathMin(KPU_MaxScroll((int)arg), g_scroll[(int)arg] + 3);
         return true;

      case KPHIT_SCROLLTRK:
        {
         int slot = (int)arg;
         int ms = KPU_MaxScroll(slot);
         if(ms > 0 && g_hits[hi].h > 0)
            g_scroll[slot] = (int)MathRound((double)ms * (ly - g_hits[hi].y) / g_hits[hi].h);
         g_scroll[slot] = MathMax(0, MathMin(ms, g_scroll[slot]));
         return true;
        }

      case KPHIT_CLOSEOP:
      case KPHIT_DELPEND:
      case KPHIT_CLOSETK:
      case KPHIT_DELTK:
         // one-click: waiting for a confirm just slips the price
         if(id == KPHIT_CLOSEOP)      KPT_CloseBy((int)arg);
         else if(id == KPHIT_DELPEND) KPT_DeletePendings();
         else if(id == KPHIT_CLOSETK) KPT_CloseTicket((ulong)arg);
         else                         g_trade.OrderDelete((ulong)arg);
         KPData_UpdateAccount();
         KPData_UpdateLive();
         KPData_Rebuild();
         return true;

      case KPHIT_RISKTGL:
        {
         int which = (int)arg;
         if(which == 0) g_risk.sl_on = !g_risk.sl_on;
         if(which == 1) g_risk.tp_on = !g_risk.tp_on;
         if(which == 2)
           {
            g_risk.floor_on = !g_risk.floor_on;
            if(g_risk.floor_on && g_risk.floor_val <= 0)
               g_risk.floor_val = MathFloor(g_acc.equity * 0.9 / 10) * 10;
           }
         if(which == 3)
           {
            g_risk.time_on = !g_risk.time_on;
            // arming after today's mark must not fire instantly:
            // consume today so the guard starts tomorrow
            if(g_risk.time_on)
              {
               datetime day = KP_DayStart(TimeCurrent());
               if(TimeCurrent() >= day + g_risk.time_hh*3600 + g_risk.time_mm*60)
                  g_risk_last_timeclose = day;
              }
           }
         KPT_RiskSave();
         return true;
        }

      case KPHIT_RISKSTEP:
        {
         int which = (int)arg / 10;
         int dir   = ((int)arg % 10 == 1 ? 1 : -1);
         if(which == 0) g_risk.sl_val    = MathMax(50.0, g_risk.sl_val    + dir*50.0);
         if(which == 1) g_risk.tp_val    = MathMax(50.0, g_risk.tp_val    + dir*50.0);
         if(which == 2) g_risk.floor_val = MathMax(0.0,  g_risk.floor_val + dir*100.0);
         if(which == 3)
           {
            int tm = g_risk.time_hh * 60 + g_risk.time_mm + dir * 15;
            if(tm < 0)     tm += 1440;
            if(tm >= 1440) tm -= 1440;
            g_risk.time_hh = tm / 60;
            g_risk.time_mm = tm % 60;
            // stepping the mark into the past while armed must not fire
            if(g_risk.time_on)
              {
               datetime day = KP_DayStart(TimeCurrent());
               if(TimeCurrent() >= day + g_risk.time_hh*3600 + g_risk.time_mm*60)
                  g_risk_last_timeclose = day;
              }
           }
         KPT_RiskSave();
         return true;
        }

      case KPHIT_NEWSFILT:
         g_news_filter = (g_news_filter == 2 ? 3 : g_news_filter == 3 ? 1 : 2);
         g_scroll[7] = 0;
         KPN_SaveSettings();
         return true;

      case KPHIT_NEWSREF:
         KPN_Refresh(true);
         return true;

      case KPHIT_NEWSALERT:
         g_news_alert_on = !g_news_alert_on;
         KPN_SaveSettings();
         return true;

      case KPHIT_NEWSSTARS:
         g_news_stars += ((int)arg == 1 ? 1 : -1);
         if(g_news_stars < 1) g_news_stars = 1;
         if(g_news_stars > 3) g_news_stars = 3;
         KPN_SaveSettings();
         KPN_UpdateMarks();
         return true;

      case KPHIT_NEWSLEAD:
         g_news_lead_min += ((int)arg == 1 ? 5 : -5);
         if(g_news_lead_min < 5)   g_news_lead_min = 5;
         if(g_news_lead_min > 120) g_news_lead_min = 120;
         KPN_SaveSettings();
         return true;

      case KPHIT_NEWSMARK:
         g_news_marks_on = !g_news_marks_on;
         KPN_SaveSettings();
         KPN_UpdateMarks();
         return true;

      case KPHIT_NEWSCUR:
        {
         int nm = g_news_curmask ^ (1 << (int)arg);
         if(nm != 0)               // never allow an empty selection
            g_news_curmask = nm;
         g_scroll[7] = 0;
         KPN_SaveSettings();
         KPN_UpdateMarks();
         return true;
        }

      case KPHIT_OT_SYM:
        {
         int total = SymbolsTotal(true);
         if(total <= 0)
            return true;
         int idx = 0;
         for(int i=0; i<total; i++)
            if(SymbolName(i, true) == g_ot_symbol) { idx = i; break; }
         idx += ((int)arg == 1 ? 1 : -1);
         if(idx < 0)      idx = total - 1;
         if(idx >= total) idx = 0;
         g_ot_symbol = SymbolName(idx, true);
         g_ot_lots = 0;            // re-init to new symbol minimum
         return true;
        }

      case KPHIT_OT_LOTS:
        {
         double st = SymbolInfoDouble(g_ot_symbol, SYMBOL_VOLUME_STEP);
         if(st <= 0) st = 0.01;
         g_ot_lots = KPT_NormLots(g_ot_symbol,
                     g_ot_lots + ((int)arg == 1 ? st : -st));
         KP_StoreSet("ot_lots", g_ot_lots);
         return true;
        }

      case KPHIT_OT_PRESET:
        {
         double presets[4] = {0.01, 0.10, 0.50, 1.00};
         g_ot_lots = KPT_NormLots(g_ot_symbol, presets[(int)arg]);
         KP_StoreSet("ot_lots", g_ot_lots);
         return true;
        }

      case KPHIT_OT_SL:
         g_ot_sl = MathMax(0, g_ot_sl + ((int)arg == 1 ? 50 : -50));
         KP_StoreSet("ot_sl", g_ot_sl);
         return true;

      case KPHIT_OT_TP:
         g_ot_tp = MathMax(0, g_ot_tp + ((int)arg == 1 ? 50 : -50));
         KP_StoreSet("ot_tp", g_ot_tp);
         return true;

      case KPHIT_OT_DIST:
         g_ot_dist = MathMax(10, g_ot_dist + ((int)arg == 1 ? 50 : -50));
         KP_StoreSet("ot_dist", g_ot_dist);
         return true;

      case KPHIT_OT_BUY:
      case KPHIT_OT_SELL:
      case KPHIT_OT_PEND:
         // one-click execution: a confirm step only costs slippage
         if(id == KPHIT_OT_BUY)
            KPT_Market(g_ot_symbol, 0, g_ot_lots, g_ot_sl, g_ot_tp);
         else if(id == KPHIT_OT_SELL)
            KPT_Market(g_ot_symbol, 1, g_ot_lots, g_ot_sl, g_ot_tp);
         else
            KPT_Pending(g_ot_symbol, (int)arg, g_ot_lots, g_ot_dist,
                        g_ot_sl, g_ot_tp);
         KPData_UpdateAccount();
         KPData_UpdateLive();
         return true;
     }
   return false;
  }

//--- wheel scroll ----------------------------------------------------
bool KPU_OnWheel(const int cx, const int cy, const int delta)
  {
   int lx = cx - g_panel_x;
   int ly = cy - g_panel_y;
   if(lx < 0 || ly < 0 || lx >= KPU_PanelW() || ly >= KPU_PanelH() || g_collapsed)
      return false;
   if(g_modal == 1)
      return false;
   int tab = g_tab;
   if(tab != 1 && tab != 2 && tab != 3 && tab != 4 && tab != 7)
      return false;
   int slot = KPU_ScrollSlot(tab);
   int step = (delta > 0 ? -3 : 3);
   g_scroll[slot] = MathMax(0, MathMin(KPU_MaxScroll(slot), g_scroll[slot] + step));
   return true;
  }

//--- drag ------------------------------------------------------------
bool KPU_OnMouse(const int cx, const int cy, const uint flags)
  {
   bool left = ((flags & 1) != 0);
   if(!g_dragging)
     {
      if(!left)
         return false;
      int lx = cx - g_panel_x;
      int ly = cy - g_panel_y;
      if(lx >= 0 && ly >= 0 && lx < KPU_PanelW() - KP_S(84) && ly < KP_S(KPL_HDR))
        {
         g_dragging = true;
         g_drag_dx = lx;
         g_drag_dy = ly;
         ChartSetInteger(0, CHART_MOUSE_SCROLL, false);
        }
      return false;
     }
   if(!left)
     {
      g_dragging = false;
      ChartSetInteger(0, CHART_MOUSE_SCROLL, true);
      KP_StoreSet("ui_x", g_panel_x);
      KP_StoreSet("ui_y", g_panel_y);
      KPU_Render();   // height depends on panel y: resize on release
      return false;
     }
   int nx = cx - g_drag_dx;
   int ny = cy - g_drag_dy;
   int cw = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int ch = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
   nx = MathMax(0, MathMin(nx, cw - KP_S(60)));
   ny = MathMax(0, MathMin(ny, ch - KP_S(24)));
   if(nx == g_panel_x && ny == g_panel_y)
      return false;
   g_panel_x = nx;
   g_panel_y = ny;
   KPC_Move(nx, ny);
   return true;
  }

#endif // KP_UI2_MQH
