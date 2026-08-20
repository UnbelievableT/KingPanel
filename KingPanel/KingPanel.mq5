//+------------------------------------------------------------------+
//|                                                    KingPanel.mq5 |
//|                KING PANEL V1.1 - MT5 account terminal dashboard  |
//|                                                                  |
//|  Bloomberg-terminal style compact dashboard:                     |
//|  Overview / Analysis / Symbols / Magics / Trade / Risk / News    |
//|  Pure CCanvas rendering, DPI aware, draggable / collapsible,     |
//|  EN-CN bilingual, gold chart theme, news marks & alerts          |
//+------------------------------------------------------------------+
#property copyright "KING PANEL"
#property link      "https://t.me/topxea"
#property version   "1.20"
#property description "KING PANEL — Bloomberg-terminal style MT5 account dashboard"
#property description "Telegram @topxea"

#include "KP_Theme.mqh"
#include "KP_Canvas.mqh"
#include "KP_Data.mqh"
#include "KP_Trade.mqh"
#include "KP_News.mqh"
#include "KP_UI.mqh"

//--- inputs ----------------------------------------------------------
input group "════ Panel ════"
input int    InpX          = 10;      // Initial X (px, first load only)
input int    InpY          = 30;      // Initial Y (px, first load only)
input int    InpWidth      = 600;     // Panel width (px, 520-900; wider for cent accounts)
input double InpScale      = 1.0;     // Scale multiplier (on top of DPI auto-scale)
input bool   InpLangCN     = false;   // Chinese interface by default (false = English)
input bool   InpChartTheme = true;    // Apply gold chart theme (restored on removal)

input group "════ Fonts ════"
input string InpFontMono   = "Consolas";         // Numeric font (monospace)
input string InpFontCJK    = "Microsoft YaHei";  // CJK font

input group "════ Data ════"
input int    InpRebuildSec = 20;      // Full statistics rebuild interval (sec)

input group "════ News ════"
input bool   InpNewsAlert  = true;    // Popup alert before events
input int    InpNewsStars  = 3;       // Alert/marks importance threshold (1-3)
input int    InpNewsLead   = 15;      // Alert lead time (minutes)
input bool   InpNewsMarks  = true;    // Draw event lines on the chart
input string InpNewsCurs   = "USD,EUR,JPY";  // Default currencies (first load only)

input group "════ Order Ticket ════"
input long   InpPanelMagic = 0;       // Magic for panel orders (0 = manual)

input group "════ Risk Defaults (first load only) ════"
input double InpDefFloatSL = 500;     // Loss guard default (account currency)
input double InpDefFloatTP = 500;     // Profit guard default (account currency)
input int    InpDefCloseHH = 22;      // Timed close default hour (server, 0-23)
input int    InpDefCloseMM = 30;      // Timed close default minute (0-59)

input group "════ Brand ════"
input bool   InpShowBrand  = true;         // Show Telegram channel
input string InpChannel    = "@topxea";    // Telegram channel

//--- state -----------------------------------------------------------
bool     g_dirty        = true;
datetime g_next_rebuild = 0;

//+------------------------------------------------------------------+
int OnInit()
  {
   KP_InitScale(InpScale <= 0 ? 1.0 : InpScale);
   KP_InitStorage();
   KP_FontMono = InpFontMono;
   KP_FontCJK  = InpFontCJK;
   KP_BaseW    = (int)MathMax(520, MathMin(900, InpWidth));

   KP_BrandShow    = InpShowBrand;
   KP_BrandChannel = InpChannel;
   KPT_PanelMagic  = InpPanelMagic;

   // restore ui state
   KP_Lang     = (int)KP_StoreGet("ui_lang", InpLangCN ? 1 : 0);
   if(KP_Lang < 0 || KP_Lang > 1)
      KP_Lang = 0;
   g_panel_x   = (int)KP_StoreGet("ui_x", InpX);
   g_panel_y   = (int)KP_StoreGet("ui_y", InpY);
   g_tab       = (int)KP_StoreGet("ui_tab", 0);
   g_collapsed = (KP_StoreGet("ui_collapsed", 0) > 0.5);
   if(g_tab < 0 || g_tab > 7)
      g_tab = 0;
   g_ot_lots   = KP_StoreGet("ot_lots", 0);
   g_ot_sl     = (int)KP_StoreGet("ot_sl", 0);
   g_ot_tp     = (int)KP_StoreGet("ot_tp", 0);
   g_ot_dist   = (int)MathMax(10.0, KP_StoreGet("ot_dist", 200));
   KPT_RiskLoad(InpDefFloatSL, InpDefFloatTP, InpDefCloseHH, InpDefCloseMM);
   KPN_LoadSettings(InpNewsAlert, InpNewsStars, InpNewsLead, InpNewsMarks, InpNewsCurs);

   if(InpChartTheme)
      KP_ApplyChartTheme();

   if(!KPC_Create(g_panel_x, g_panel_y, KPU_PanelW(), KPU_PanelH()))
     {
      Print("[KING PANEL] canvas create failed");
      return INIT_FAILED;
     }

   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true);
   ChartSetInteger(0, CHART_EVENT_MOUSE_WHEEL, true);

   KPData_UpdateAccount();
   KPData_UpdateLive();
   KPData_Rebuild();
   g_next_rebuild = TimeCurrent() + InpRebuildSec;
   g_dirty = false;

   KPU_Render();
   EventSetTimer(1);
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   ChartSetInteger(0, CHART_MOUSE_SCROLL, true);
   KPN_ClearMarks();
   KP_RestoreChartTheme();
   KPC_Destroy();
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   // rendering is timer-driven; nothing per-tick
  }

//+------------------------------------------------------------------+
void OnTimer()
  {
   KPData_UpdateAccount();
   KPData_UpdateLive();
   KPData_SampleEquity();

   // risk guards
   if(KPT_RiskCheck())
      g_dirty = true;

   // periodic / event-driven full rebuild
   if(g_dirty || TimeCurrent() >= g_next_rebuild)
     {
      KPData_Rebuild();
      g_next_rebuild = TimeCurrent() + MathMax(5, InpRebuildSec);
      g_dirty = false;
     }

   // calendar: keep fresh when alerts/marks are on or tab is visible
   if(g_news_alert_on || g_news_marks_on || (g_tab == 7 && !g_collapsed))
      KPN_Refresh(false);
   KPN_CheckAlerts();

   // re-anchor staggered chart labels as price range drifts
   static datetime last_marks = 0;
   if(g_news_marks_on && TimeCurrent() - last_marks >= 60)
     {
      last_marks = TimeCurrent();
      KPN_UpdateMarks();
     }

   KPU_Render();
  }

//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD ||
      trans.type == TRADE_TRANSACTION_HISTORY_ADD)
      g_dirty = true;
  }

//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam,
                  const double &dparam, const string &sparam)
  {
   if(id == CHARTEVENT_OBJECT_CLICK && sparam == KP_OBJ)
     {
      int lx = (int)lparam - g_panel_x;
      int ly = (int)dparam - g_panel_y;
      if(KPU_OnClick(lx, ly))
        {
         KPData_UpdateAccount();
         KPData_UpdateLive();
         KPU_Render();
        }
      return;
     }

   if(id == CHARTEVENT_MOUSE_MOVE)
     {
      uint flags = (uint)StringToInteger(sparam);
      if(KPU_OnMouse((int)lparam, (int)dparam, flags))
         ChartRedraw();
      return;
     }

   if(id == CHARTEVENT_MOUSE_WHEEL)
     {
      int x     = (int)(short)lparam;
      int y     = (int)(short)(lparam >> 16);
      int delta = (int)dparam;
      if(KPU_OnWheel(x, y, delta))
         KPU_Render();
      return;
     }

   if(id == CHARTEVENT_CHART_CHANGE)
     {
      // CHART_CHANGE floods during scroll/zoom: everything below must be
      // either throttled or conditional on real geometry changes
      int cw = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
      int ch = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
      int nx = MathMax(0, MathMin(g_panel_x, cw - KP_S(60)));
      int ny = MathMax(0, MathMin(g_panel_y, ch - KP_S(24)));
      bool moved = (nx != g_panel_x || ny != g_panel_y);
      if(moved)
        {
         g_panel_x = nx;
         g_panel_y = ny;
         KPC_Move(nx, ny);
        }

      // reposition news labels (price-anchor moves only; no churn)
      static uint last_marks_ms = 0;
      uint nowms = GetTickCount();
      if(g_news_marks_on && nowms - last_marks_ms >= 300)
        {
         last_marks_ms = nowms;
         KPN_UpdateMarks();
        }

      // re-render only when the panel's own geometry actually changed
      if(!g_collapsed)
        {
         int newH = KPU_PanelH();
         if(moved || newH != g_cv_h)
            KPU_Render();
        }
      else if(moved)
         ChartRedraw();
     }
  }
//+------------------------------------------------------------------+
