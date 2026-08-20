//+------------------------------------------------------------------+
//| KP_Theme.mqh - KING PANEL V1.0                                   |
//| Bloomberg-terminal dark theme: colors, DPI scale, formatting     |
//+------------------------------------------------------------------+
#ifndef KP_THEME_MQH
#define KP_THEME_MQH

//--- ARGB palette (0xAARRGGBB), terminal-black + amber accent
#define KP_BG          0xFF0A0D12   // panel background
#define KP_BG_HEAD     0xFF11151D   // header / title bar
#define KP_BG_TAB      0xFF0D1118   // tab bar strip
#define KP_BG_CELL     0xFF0C1017   // table row (even)
#define KP_BG_CELL2    0xFF0F131B   // table row (odd)
#define KP_BG_THEAD    0xFF141A24   // table header row
#define KP_BG_TILE     0xFF0E1219   // KPI tile background
#define KP_BG_INPUT    0xFF161C27   // edit/input background
#define KP_BORDER      0xFF232B38   // outer border
#define KP_SEP         0xFF1A212C   // separators / grid lines
#define KP_AMBER       0xFFFFA028   // Bloomberg amber accent
#define KP_AMBER_DIM   0xFF8A5A1A   // dimmed amber
#define KP_TXT         0xFFE8EAED   // primary text
#define KP_TXT_DIM     0xFF8B93A1   // labels / secondary
#define KP_TXT_FAINT   0xFF57606E   // faint hints
#define KP_GREEN       0xFF22C87E   // positive
#define KP_GREEN_DIM   0xFF125C3D
#define KP_RED         0xFFFF4A57   // negative
#define KP_RED_DIM     0xFF6E2027
#define KP_CYAN        0xFF35B6FF   // info / links
#define KP_YELLOW      0xFFFFD24A   // warnings / moderate
#define KP_TAB_ACT     0xFFB3261E   // active tab red (terminal style)
#define KP_BTN         0xFF1B2330   // button face

// area fills: PRE-BLENDED OPAQUE colors. CCanvas primitives write the
// raw ARGB value into the bitmap (no blending), so any alpha < 0xFF
// would make the panel itself see-through onto the chart.
#define KP_CURVE_FILL  0xFF3D2D1A   // amber 20% over cell bg
#define KP_FILL_CYAN   0xFF143145   // cyan 20% over cell bg
#define KP_FILL_RED    0xFF3D1A1E   // red 20% over cell bg
#define KP_ROW_HL      0xFF302619   // amber 15% row highlight
#define KP_TINT_GREEN  0xFF102420   // green 8% quadrant tint
#define KP_TINT_RED    0xFF241518   // red 8% quadrant tint

//--- fonts (overridable from EA inputs)
string KP_FontMono = "Consolas";          // numerics
string KP_FontCJK  = "Microsoft YaHei";   // CJK labels

//--- brand: Telegram channel only (kept understated) ----------------
bool   KP_BrandShow    = true;
string KP_BrandChannel = "@topxea";

//--- language: 0 = English (default), 1 = Chinese -------------------
int KP_Lang = 0;

string LL(const string en, const string cn)
  {
   return (KP_Lang == 0 ? en : cn);
  }

//--- base panel width (px, unscaled; set from EA input) -------------
int KP_BaseW = 560;

//--- DPI scale ------------------------------------------------------
double KP_Scale = 1.0;

void KP_InitScale(const double user_mult)
  {
   double dpi = (double)TerminalInfoInteger(TERMINAL_SCREEN_DPI);
   if(dpi <= 0.0)
      dpi = 96.0;
   KP_Scale = (dpi / 96.0) * (user_mult <= 0.0 ? 1.0 : user_mult);
  }

// layout px scaled to screen
int KP_S(const int px) { return (int)MathRound(px * KP_Scale); }

// font size in tenths of points (negative => device independent)
int KP_F(const double pt) { return -(int)MathRound(pt * 10.0); }

//--- value color helper ---------------------------------------------
uint KP_PLColor(const double v)
  {
   if(v > 0.0000001)  return KP_GREEN;
   if(v < -0.0000001) return KP_RED;
   return KP_TXT_DIM;
  }

//--- number formatting ----------------------------------------------
// 12 345 678.90 style with thin thousands separator (comma)
string KP_Money(const double v, const int digits=2)
  {
   string s   = DoubleToString(MathAbs(v), digits);
   int    dot = StringFind(s, ".");
   string ip  = (dot < 0 ? s : StringSubstr(s, 0, dot));
   string fp  = (dot < 0 ? "" : StringSubstr(s, dot));
   string res = "";
   int    len = StringLen(ip);
   for(int i=0; i<len; i++)
     {
      if(i > 0 && (len - i) % 3 == 0)
         res += ",";
      res += StringSubstr(ip, i, 1);
     }
   return (v < 0 ? "-" : "") + res + fp;
  }

// cents-account friendly: drops decimals once the number gets long
string KP_MoneyAuto(const double v)
  {
   return KP_Money(v, MathAbs(v) >= 100000.0 ? 0 : 2);
  }

// signed with explicit plus
string KP_MoneySigned(const double v, const int digits=2)
  {
   if(v > 0.0000001)
      return "+" + KP_Money(v, digits);
   return KP_Money(v, digits);
  }

string KP_Pct(const double v, const int digits=1)
  {
   return DoubleToString(v, digits) + "%";
  }

string KP_PctSigned(const double v, const int digits=1)
  {
   return (v > 0.0000001 ? "+" : "") + DoubleToString(v, digits) + "%";
  }

// compact volume: 0.01 / 12.35 / 1.2K lots
string KP_Lots(const double v)
  {
   if(MathAbs(v) >= 1000.0)
      return DoubleToString(v/1000.0, 1) + "K";
   return DoubleToString(v, 2);
  }

// seconds -> "3d 04:12" | "04:12:33"
string KP_Duration(const long sec)
  {
   long s = (sec < 0 ? 0 : sec);
   long d = s / 86400;  s %= 86400;
   long h = s / 3600;   s %= 3600;
   long m = s / 60;     s %= 60;
   if(d > 0)
      return StringFormat("%dd %02d:%02d", (int)d, (int)h, (int)m);
   return StringFormat("%02d:%02d:%02d", (int)h, (int)m, (int)s);
  }

// datetime -> "MM.DD HH:MM"
string KP_TimeShort(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return StringFormat("%02d.%02d %02d:%02d", dt.mon, dt.day, dt.hour, dt.min);
  }

// datetime -> "YYYY.MM.DD"
string KP_DateOnly(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return StringFormat("%04d.%02d.%02d", dt.year, dt.mon, dt.day);
  }

//--- persistent storage keys (terminal global variables) ------------
string KP_GVPrefix = "KP5_";

void KP_InitStorage()
  {
   KP_GVPrefix = StringFormat("KP5_%I64d_", AccountInfoInteger(ACCOUNT_LOGIN));
  }

void KP_StoreSet(const string key, const double v)
  {
   GlobalVariableSet(KP_GVPrefix + key, v);
  }

double KP_StoreGet(const string key, const double def)
  {
   string k = KP_GVPrefix + key;
   if(GlobalVariableCheck(k))
      return GlobalVariableGet(k);
   return def;
  }

//--- gold chart theme (saved & restored on deinit) ------------------
#define KP_NCHPROPS 22
long kp_ch_props[KP_NCHPROPS] =
  {
   CHART_COLOR_BACKGROUND, CHART_COLOR_FOREGROUND, CHART_COLOR_GRID,
   CHART_COLOR_VOLUME, CHART_COLOR_CHART_UP, CHART_COLOR_CHART_DOWN,
   CHART_COLOR_CHART_LINE, CHART_COLOR_CANDLE_BULL, CHART_COLOR_CANDLE_BEAR,
   CHART_COLOR_BID, CHART_COLOR_ASK, CHART_COLOR_LAST, CHART_COLOR_STOP_LEVEL,
   CHART_SHOW_GRID, CHART_SHOW_VOLUMES, CHART_SHOW_PERIOD_SEP,
   CHART_SHOW_ASK_LINE, CHART_SHOW_BID_LINE, CHART_SHOW_OHLC,
   CHART_SHOW_ONE_CLICK, CHART_MODE, CHART_SHOW_TRADE_LEVELS
  };
long kp_ch_saved[KP_NCHPROPS];
bool kp_ch_applied = false;

void KP_ApplyChartTheme()
  {
   for(int i=0; i<KP_NCHPROPS; i++)
      kp_ch_saved[i] = ChartGetInteger(0, (ENUM_CHART_PROPERTY_INTEGER)kp_ch_props[i]);
   kp_ch_applied = true;

   ChartSetInteger(0, CHART_COLOR_BACKGROUND,  (long)C'7,9,13');     // near-black
   ChartSetInteger(0, CHART_COLOR_FOREGROUND,  (long)C'126,134,148');// axis text
   ChartSetInteger(0, CHART_COLOR_GRID,        (long)C'20,26,36');
   ChartSetInteger(0, CHART_COLOR_VOLUME,      (long)C'34,42,54');
   ChartSetInteger(0, CHART_COLOR_CHART_UP,    (long)C'242,187,60'); // gold
   ChartSetInteger(0, CHART_COLOR_CHART_DOWN,  (long)C'96,104,118'); // slate
   ChartSetInteger(0, CHART_COLOR_CHART_LINE,  (long)C'242,187,60');
   ChartSetInteger(0, CHART_COLOR_CANDLE_BULL, (long)C'242,187,60');
   ChartSetInteger(0, CHART_COLOR_CANDLE_BEAR, (long)C'44,50,62');
   ChartSetInteger(0, CHART_COLOR_BID,         (long)C'166,120,44');
   ChartSetInteger(0, CHART_COLOR_ASK,         (long)C'70,78,92');
   ChartSetInteger(0, CHART_COLOR_LAST,        (long)C'110,118,132');
   ChartSetInteger(0, CHART_COLOR_STOP_LEVEL,  (long)C'255,164,40');
   ChartSetInteger(0, CHART_SHOW_GRID,         0);
   ChartSetInteger(0, CHART_SHOW_VOLUMES,      CHART_VOLUME_HIDE);
   ChartSetInteger(0, CHART_SHOW_PERIOD_SEP,   0);
   ChartSetInteger(0, CHART_SHOW_ASK_LINE,     0);
   ChartSetInteger(0, CHART_SHOW_BID_LINE,     1);
   ChartSetInteger(0, CHART_SHOW_OHLC,         0);
   ChartSetInteger(0, CHART_SHOW_ONE_CLICK,    0);
   ChartSetInteger(0, CHART_MODE,              CHART_CANDLES);
   ChartSetInteger(0, CHART_SHOW_TRADE_LEVELS, 1);
   ChartRedraw();
  }

void KP_RestoreChartTheme()
  {
   if(!kp_ch_applied)
      return;
   for(int i=0; i<KP_NCHPROPS; i++)
      ChartSetInteger(0, (ENUM_CHART_PROPERTY_INTEGER)kp_ch_props[i], kp_ch_saved[i]);
   kp_ch_applied = false;
   ChartRedraw();
  }

#endif // KP_THEME_MQH
