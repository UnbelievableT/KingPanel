//+------------------------------------------------------------------+
//| KP_Export.mqh - KING PANEL V1.5                                  |
//| One-click report: positions/periods CSV + dark HTML statement    |
//| with inline-SVG equity curve + full-chart PNG screenshot.        |
//| Everything lands in MQL5\Files\KingPanel\ (sandbox, Market-safe).|
//+------------------------------------------------------------------+
#ifndef KP_EXPORT_MQH
#define KP_EXPORT_MQH

string KPX_Dir()
  {
   return StringFormat("KingPanel\\%I64d", g_acc.login);
  }

// closed positions journal
bool KPX_WritePositions(const string path)
  {
   int h = FileOpen(path, FILE_WRITE|FILE_TXT|FILE_ANSI, '\t', CP_UTF8);
   if(h == INVALID_HANDLE)
      return false;
   FileWriteString(h, "pos_id,symbol,magic,dir,lots,open_time,close_time,"
                      "entry_vwap,exit_vwap,sl_initial,net\n");
   for(int k=0; k<g_close_n; k++)
     {
      int i = g_close_order[k];
      double entry = (g_pos[i].lots > 0 ? g_pos[i].vwap_num / g_pos[i].lots : 0);
      double exitv = (g_pos[i].lots_out > 0 ? g_pos[i].exit_num / g_pos[i].lots_out : 0);
      FileWriteString(h, StringFormat("%I64d,%s,%I64d,%s,%.2f,%s,%s,%.5f,%.5f,%.5f,%.2f\n",
         g_pos[i].pos_id, g_pos[i].symbol, g_pos[i].magic,
         (g_pos[i].dir == 0 ? "buy" : "sell"), g_pos[i].lots,
         TimeToString(g_pos[i].open_time, TIME_DATE|TIME_MINUTES),
         TimeToString(g_pos[i].close_time, TIME_DATE|TIME_MINUTES),
         entry, exitv, g_pos[i].sl0, g_pos[i].net));
     }
   FileClose(h);
   return true;
  }

// daily period table
bool KPX_WritePeriods(const string path)
  {
   int h = FileOpen(path, FILE_WRITE|FILE_TXT|FILE_ANSI, '\t', CP_UTF8);
   if(h == INVALID_HANDLE)
      return false;
   FileWriteString(h, "date,trades,lots,wins,losses,gross_win,gross_loss,"
                      "max_dd,dd_pct,net,cashflow\n");
   int n = ArraySize(g_days);
   for(int i=0; i<n; i++)
      FileWriteString(h, StringFormat("%s,%d,%.2f,%d,%d,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f\n",
         g_days[i].label, g_days[i].trades, g_days[i].lots,
         g_days[i].wins, g_days[i].losses, g_days[i].gross_win,
         g_days[i].gross_loss, g_days[i].dd, g_days[i].dd_pct,
         g_days[i].profit, g_days[i].cashflow));
   FileClose(h);
   return true;
  }

// self-contained dark statement with an inline-SVG equity curve
bool KPX_WriteHTML(const string path)
  {
   int h = FileOpen(path, FILE_WRITE|FILE_TXT|FILE_ANSI, '\t', CP_UTF8);
   if(h == INVALID_HANDLE)
      return false;

   // downsampled equity polyline
   string pts = "";
   int n = MathMin(g_curve_n, 300);
   if(g_curve_n >= 2)
     {
      double mn = g_curve_bal[ArrayMinimum(g_curve_bal, 0, g_curve_n)];
      double mx = g_curve_bal[ArrayMaximum(g_curve_bal, 0, g_curve_n)];
      double rng = (mx - mn < 0.0000001 ? 1.0 : mx - mn);
      for(int i=0; i<n; i++)
        {
         int di = (int)MathRound((double)i * (g_curve_n-1) / MathMax(1, n-1));
         double x = 20.0 + 760.0 * i / MathMax(1, n-1);
         double yv = 180.0 - 160.0 * (g_curve_bal[di] - mn) / rng;
         pts += StringFormat("%.1f,%.1f ", x, yv);
        }
     }

   FileWriteString(h, "<!DOCTYPE html><html><head><meta charset='utf-8'>"
      "<title>KING PANEL Statement</title><style>"
      "body{background:#0a0d12;color:#e8eaed;font-family:Consolas,monospace;"
      "margin:24px}h1{color:#ffa028;font-size:20px}h2{color:#ffa028;"
      "font-size:14px;border-left:3px solid #ffa028;padding-left:8px}"
      "table{border-collapse:collapse;font-size:12px;margin:8px 0}"
      "td,th{padding:3px 12px;border-bottom:1px solid #1a212c;text-align:right}"
      "th{color:#8b93a1}td:first-child,th:first-child{text-align:left}"
      ".g{color:#22c87e}.r{color:#ff4a57}.d{color:#8b93a1}"
      "svg{background:#0c1017;border:1px solid #232b38}"
      ".foot{color:#57606e;font-size:11px;margin-top:24px}</style></head><body>");

   FileWriteString(h, StringFormat("<h1>KING PANEL — %I64d</h1>"
      "<p class='d'>%s · %s · 1:%d · %s</p>",
      g_acc.login, g_acc.server, g_acc.currency, (int)g_acc.leverage,
      TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES)));

   FileWriteString(h, "<h2>Equity curve</h2>"
      "<svg width='800' height='200' viewBox='0 0 800 200'>"
      "<polyline fill='none' stroke='#ffa028' stroke-width='1.5' points='"
      + pts + "'/></svg>");

   FileWriteString(h, StringFormat("<h2>Summary</h2><table>"
      "<tr><th>Net profit</th><td class='%s'>%.2f</td>"
      "<th>Profit factor</th><td>%.2f</td></tr>"
      "<tr><th>Gross profit</th><td class='g'>%.2f</td>"
      "<th>Gross loss</th><td class='r'>%.2f</td></tr>"
      "<tr><th>Closed trades</th><td>%d (%dW/%dL)</td>"
      "<th>Win rate</th><td>%.1f%%</td></tr>"
      "<tr><th>Max drawdown</th><td class='r'>%.2f (%.1f%%)</td>"
      "<th>Recovery</th><td>%.2f</td></tr>"
      "<tr><th>Expectancy</th><td>%.2f</td>"
      "<th>Volume</th><td>%.2f</td></tr></table>",
      (g_tot.net >= 0 ? "g" : "r"), g_tot.net, g_tot.profit_factor,
      g_tot.gross_profit, g_tot.gross_loss,
      g_tot.closed_trades, g_tot.wins, g_tot.losses, g_tot.win_rate,
      g_tot.max_dd, g_tot.max_dd_pct, g_tot.recovery,
      g_tot.expectancy, g_tot.lots));

   FileWriteString(h, "<h2>Monthly</h2><table><tr><th>Month</th><th>Trades</th>"
      "<th>Win%</th><th>Max DD</th><th>Net</th></tr>");
   int mn2 = ArraySize(g_months);
   for(int i=MathMax(0, mn2-24); i<mn2; i++)
     {
      double wr = (g_months[i].trades > 0 ?
                   100.0*g_months[i].wins/g_months[i].trades : 0);
      FileWriteString(h, StringFormat(
         "<tr><td>%s</td><td>%d</td><td>%.0f%%</td><td class='r'>%.2f</td>"
         "<td class='%s'>%.2f</td></tr>",
         g_months[i].label, g_months[i].trades, wr, g_months[i].dd,
         (g_months[i].profit >= 0 ? "g" : "r"), g_months[i].profit));
     }
   FileWriteString(h, "</table>");

   FileWriteString(h,
      "<p class='foot'>Positions reconstructed by DEAL_POSITION_ID; net "
      "includes commission, swap and fees; drawdown measured on the "
      "trading-only curve (cash flow excluded). Generated by KING PANEL "
      "— t.me/topxea</p></body></html>");
   FileClose(h);
   return true;
  }

// one click: CSVs + HTML + full-chart screenshot
void KPX_Export()
  {
   string dir = KPX_Dir();
   string stamp = TimeToString(TimeCurrent(), TIME_DATE);
   StringReplace(stamp, ".", "");
   bool ok = true;
   ok = KPX_WritePositions(dir + "\\positions_" + stamp + ".csv") && ok;
   ok = KPX_WritePeriods(dir + "\\daily_" + stamp + ".csv") && ok;
   ok = KPX_WriteHTML(dir + "\\report_" + stamp + ".html") && ok;

   int cw = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int ch = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
   if(cw > 0 && ch > 0)
      ChartScreenShot(0, dir + "\\panel_" + stamp + ".png", cw, ch);

   KPT_RiskMsg(ok ? LL("EXPORTED -> MQL5\\Files\\", "已导出 -> MQL5\\Files\\") + dir
                  : LL("EXPORT FAILED (see journal)", "导出失败 (见日志)"));
  }

#endif // KP_EXPORT_MQH
