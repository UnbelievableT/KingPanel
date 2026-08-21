//+------------------------------------------------------------------+
//|                                                    KingPanel.mq5 |
//|                KING PANEL V1.5 - MT5 account terminal dashboard  |
//|                                                                  |
//|  Bloomberg-terminal style compact dashboard:                     |
//|  Overview / Analysis / Symbols / Magics / Trade / Risk / News    |
//|  Pure CCanvas rendering, DPI aware, draggable / collapsible,     |
//|  EN-CN bilingual, gold chart theme, news marks & alerts          |
//+------------------------------------------------------------------+
#property copyright "KING PANEL"
#property link      "https://t.me/topxea"
#property version   "1.50"
#property description "KING PANEL — Bloomberg-terminal style MT5 account dashboard"
#property description "Telegram @topxea"
#property description "v1.5: two audit rounds (99 fixes), MFE/MAE history backoff, self-explaining heatmap"

#include "KP_Theme.mqh"
#include "KP_Canvas.mqh"
#include "KP_Data.mqh"
#include "KP_News.mqh"
#include "KP_Trade.mqh"
#include "KP_UI.mqh"

//--- inputs ----------------------------------------------------------
input group "════ Panel ════"
input int    InpX          = 10;      // Initial X (px, first load only)
input int    InpY          = 30;      // Initial Y (px, first load only)
input int    InpWidth      = 600;     // Panel width (px, 520-900; wider for cent accounts)
input double InpScale      = 1.0;     // Scale multiplier (whole panel: layout AND text)
input double InpFontScale  = 0;       // Text size multiplier (0 = auto by screen DPI; try 1.2 if text looks small)
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

input group "════ Notifications ════"
input bool   InpPushOn     = true;    // Phone push via SendNotification (needs MetaQuotes ID)
input bool   InpPushRisk   = true;    // Push on risk-guard / lockout events
input bool   InpPushNews   = true;    // Push news alerts

input group "════ Automation ════"
input int    InpBEBuffer   = 20;      // Break-even buffer (points locked in)
input int    InpTrailPts   = 200;     // Trailing distance default (points, first load)

input group "════ Telegram (optional) ════"
input string InpTgToken    = "";      // Bot token (empty = off; whitelist api.telegram.org)
input string InpTgChat     = "";      // Chat id
input bool   InpTgDaily    = true;    // Daily digest after the prop-day reset

input group "════ Fleet / Aliases ════"
input bool   InpFleetOn    = true;    // Publish snapshot for multi-account view
input string InpMagicAliases = "";    // e.g. "12345=KING S1;678=Grid v2"

input group "════ Prop Mode (first load only) ════"
input bool   InpPropOn      = false;  // Daily-loss guard + order lockout armed by default
input double InpDefDailyLoss = 500;   // Daily loss limit default (account currency)
input int    InpPropResetHH  = 0;     // Daily reset hour (server time, 0-23)

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
string   g_owner_key    = "";
string   g_owner_hb     = "";
long     g_inst_id      = 0;
datetime g_ea_start     = 0;   // attach time: proof we saw a rollover

// A GlobalVariable is a double: 53 bits of mantissa. A raw ChartID is an
// 18-digit value (~1.3e17), so (double)id rounds to a multiple of ~16 and
// EVERY long-domain comparison against the stored value fails - even for a
// sole instance. The claim would flap once per tick and the guards would
// run at a fraction of their intended rate. Fold the id into 48 bits so
// the value written is the value read back, exactly.
long KP_InstanceId()
  {
   return (long)(ChartID() % 281474976710656);   // 2^48
  }

// Atomic claim: GlobalVariableSetOnCondition is a compare-and-set, so two
// instances starting inside the same second cannot both win. The owner
// re-verifies every tick and demotes itself if it was taken over.
bool KP_TryClaimOwner()
  {
   bool have = GlobalVariableCheck(g_owner_key);
   double cur = (have ? GlobalVariableGet(g_owner_key) : 0);
   datetime hb = (GlobalVariableCheck(g_owner_hb)
                  ? (datetime)(long)GlobalVariableGet(g_owner_hb) : 0);
   if(have && (long)cur == g_inst_id)
      return true;                                  // already ours
   if(have && TimeLocal() - hb <= 15)
      return false;                                 // a live owner holds it
   if(have)
     {
      if(!GlobalVariableSetOnCondition(g_owner_key, (double)g_inst_id, cur))
         return false;                              // lost the race
     }
   else
     {
      GlobalVariableTemp(g_owner_key);
      GlobalVariableSet(g_owner_key, (double)g_inst_id);
      if((long)GlobalVariableGet(g_owner_key) != g_inst_id)
         return false;
     }
   GlobalVariableTemp(g_owner_hb);
   GlobalVariableSet(g_owner_hb, (double)(long)TimeLocal());
   return true;
  }

//+------------------------------------------------------------------+
int OnInit()
  {
   KP_InitScale(InpScale <= 0 ? 1.0 : InpScale);
   KP_InitFonts(InpFontScale);
   KP_InitStorage();
   KP_FontMono = InpFontMono;
   KP_FontCJK  = InpFontCJK;
   KP_BaseW    = (int)MathMax(520, MathMin(900, InpWidth));

   KP_BrandShow    = InpShowBrand;
   KP_BrandChannel = InpChannel;
   KPT_PanelMagic  = InpPanelMagic;
   KP_PushOn       = InpPushOn;
   KP_PushRisk     = InpPushRisk;
   KP_PushNews     = InpPushNews;
   KP_ResetHour    = (int)MathMax(0, MathMin(23, InpPropResetHH));

   // restore ui state
   KP_Lang     = (int)KP_StoreGet("ui_lang", InpLangCN ? 1 : 0);
   if(KP_Lang < 0 || KP_Lang > 1)
      KP_Lang = 0;
   g_panel_x   = (int)KP_StoreGet("ui_x", InpX);
   g_panel_y   = (int)KP_StoreGet("ui_y", InpY);
   g_tab       = (int)KP_StoreGet("ui_tab", 0);
   g_collapsed = (KP_StoreGet("ui_collapsed", 0) > 0.5);
   g_modal     = (KP_StoreGet("ui_modal", 0) > 0.5 ? 1 : 0);
   g_chart_sel = (int)KP_StoreGet("ui_chart", 0);
   if(g_chart_sel < 0 || g_chart_sel > 5)
      g_chart_sel = 0;
   if(g_tab < 0 || g_tab > 7)
      g_tab = 0;
   g_ot_lots   = 0;   // restored per-symbol on the first ORDER draw
   g_ot_sl     = (int)KP_StoreGet("ot_sl", 0);
   g_ot_tp     = (int)KP_StoreGet("ot_tp", 0);
   g_ot_dist   = (int)MathMax(10.0, KP_StoreGet("ot_dist", 200));
   KPT_RiskLoad(InpDefFloatSL, InpDefFloatTP, InpDefCloseHH, InpDefCloseMM);
   KPT_PropLoad(InpPropOn, InpDefDailyLoss);
   KPT_PropAnchorLoad();
   // only ONE instance per login may run the guards/automation, or two
   // panels would both fire the same close and both write the same GVs
   // TimeLocal (machine clock), never TimeCurrent: two panels on symbols
   // with different quote flow do not share a broker clock, and the stale
   // check would promote a second owner.
   g_owner_key = StringFormat("KP5_OWNER_%I64d", AccountInfoInteger(ACCOUNT_LOGIN));
   g_owner_hb  = g_owner_key + "_HB";
   g_inst_id   = KP_InstanceId();
   g_ea_start  = TimeCurrent();
   g_is_owner  = KP_TryClaimOwner();
   KPT_BEBuf    = (int)MathMax(0, MathMin(1000, InpBEBuffer));
   KPT_TrailPts = (int)MathMax(20.0, MathMin(5000.0, KP_StoreGet("at_trail", InpTrailPts)));
   KP_AliasLoad(InpMagicAliases);
   KPTG_Load(InpTgToken, InpTgChat, InpTgDaily);
   g_fleet_on = InpFleetOn;
   g_ot_mode = (int)KP_StoreGet("ot_mode", 0);
   if(g_ot_mode < 0 || g_ot_mode > 1)
      g_ot_mode = 0;
   g_ot_risk = MathMax(0.25, MathMin(10.0, KP_StoreGet("ot_risk", 1.0)));
   KPN_LoadSettings(InpNewsAlert, InpNewsStars, InpNewsLead, InpNewsMarks, InpNewsCurs);

   if(InpChartTheme)
      KP_ApplyChartTheme();

   if(!KPC_Create(g_panel_x, g_panel_y, KPU_PanelW(), KPU_PanelH()))
     {
      Print("[KING PANEL] canvas create failed");
      return INIT_FAILED;
     }

   g_chart_scroll_saved = (bool)ChartGetInteger(0, CHART_MOUSE_SCROLL);
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true);
   ChartSetInteger(0, CHART_EVENT_MOUSE_WHEEL, true);

   KPData_UpdateAccount();
   KPData_UpdateLive();
   KPData_Rebuild();
   g_next_rebuild = TimeCurrent() + InpRebuildSec;
   g_dirty = false;

   KPU_Render();
   // in a non-visual backtest a 1 s timer means a full canvas repaint per
   // simulated second, which dominates the run and can fail validation
   EventSetTimer((bool)MQLInfoInteger(MQL_TESTER) &&
                 !(bool)MQLInfoInteger(MQL_VISUAL_MODE) ? 60 : 1);
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   ChartSetInteger(0, CHART_MOUSE_SCROLL, g_chart_scroll_saved);
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, false);
   ChartSetInteger(0, CHART_EVENT_MOUSE_WHEEL, false);
   if(g_is_owner)
     {
      KPF_Cleanup();
      // only delete a claim we still hold
      if(GlobalVariableCheck(g_owner_key) &&
         (long)GlobalVariableGet(g_owner_key) == g_inst_id)
        {
         GlobalVariableDel(g_owner_key);
         GlobalVariableDel(g_owner_hb);
        }
     }
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

   // prop day rollover: stats must cover the new reset window before
   // the daily-loss guard may judge it
   if(g_prop.on && g_last_rebuild < KP_ResetAnchor(TimeCurrent()))
      g_dirty = true;

   // rebuild BEFORE the guards run: a trade that just closed must be in
   // the statistics the daily-loss guard is about to judge
   if(g_dirty || TimeCurrent() >= g_next_rebuild)
     {
      KPData_Rebuild();
      g_next_rebuild = TimeCurrent() + MathMax(5, InpRebuildSec);
      g_dirty = false;
     }

   KPT_PropAnchorTick();

   // ownership: the owner must verify it still holds the claim (another
   // instance may have taken over), everyone else retries the claim
   if(g_is_owner)
     {
      if(GlobalVariableCheck(g_owner_key) &&
         (long)GlobalVariableGet(g_owner_key) == g_inst_id)
         GlobalVariableSet(g_owner_hb, (double)(long)TimeLocal());
      else
         g_is_owner = false;          // demoted
     }
   else
     {
      g_is_owner = KP_TryClaimOwner();
      if(!g_is_owner)
         KPT_PropReload();            // follow the owner's lock state
     }

   // risk guards (owner only)
   if(g_is_owner && KPT_RiskCheck())
      g_dirty = true;

   // calendar: keep fresh when alerts/marks/guards are on or tab visible
   if(g_news_alert_on || g_news_marks_on || g_ng_block_on || g_ng_flat_on ||
      (g_tab == 7 && !g_collapsed))
      KPN_Refresh(false);
   KPN_CheckAlerts();

   // per-position automation + news auto-flat + delivery channels:
   // side-effecting subsystems run on the owner instance only
   if(g_is_owner)
     {
      KPT_TrailTick();
      KPT_NewsGuardTick();
      KPTG_Drain();
      KPTG_DigestTick();
      KPF_Write();
     }

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
