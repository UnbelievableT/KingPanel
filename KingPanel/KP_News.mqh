//+------------------------------------------------------------------+
//| KP_News.mqh - KING PANEL V1.1                                    |
//| Economic calendar: native MT5 calendar API + chart marks + alerts|
//+------------------------------------------------------------------+
#ifndef KP_NEWS_MQH
#define KP_NEWS_MQH

#include "KP_Theme.mqh"

struct KPNewsRow
  {
   ulong             vid;         // calendar value id (alert dedupe)
   datetime          time;
   string            cur;         // currency code
   int               importance;  // 1 low 2 moderate 3 high
   string            name;
   string            v_prev;
   string            v_fcst;
   string            v_act;
  };

KPNewsRow g_news[];
int       g_news_count  = 0;
bool      g_news_ok     = true;
datetime  g_news_last   = 0;
int       g_news_filter = 2;      // list filter: min importance shown

//--- alert / chart-mark settings (persisted) ------------------------
bool      g_news_alert_on  = true;
int       g_news_stars     = 3;   // alert & marks: importance >= stars
int       g_news_lead_min  = 15;  // alert lead minutes
bool      g_news_marks_on  = true;

//--- currency filter (bitmask over fixed major list + OTH) ----------
#define KPN_NCUR 10
string    KPN_CurName[KPN_NCUR] = {"USD","EUR","GBP","JPY","AUD","NZD","CAD","CHF","CNY","OTH"};
int       g_news_curmask = 0;     // bit i = KPN_CurName[i] enabled

int KPN_CurBit(const string cur)
  {
   for(int i=0; i<KPN_NCUR-1; i++)
      if(cur == KPN_CurName[i])
         return i;
   return KPN_NCUR - 1;   // OTH
  }

bool KPN_CurOK(const string cur)
  {
   return ((g_news_curmask >> KPN_CurBit(cur)) & 1) == 1;
  }

int KPN_MaskFromCSV(const string csv)
  {
   int mask = 0;
   string parts[];
   int n = StringSplit(csv, ',', parts);
   for(int i=0; i<n; i++)
     {
      string s = parts[i];
      StringTrimLeft(s);
      StringTrimRight(s);
      StringToUpper(s);
      for(int j=0; j<KPN_NCUR; j++)
         if(s == KPN_CurName[j])
            mask |= (1 << j);
     }
   if(mask == 0)
      mask = 1 | 2 | 8;   // USD EUR JPY
   return mask;
  }

ulong     g_alerted[];
int       g_alerted_n = 0;

#define KP_NEWSVL "KP5_NEWSVL_"

void KPN_LoadSettings(const bool def_alert, const int def_stars,
                      const int def_lead, const bool def_marks,
                      const string def_curs)
  {
   g_news_alert_on = (KP_StoreGet("news_alert", def_alert ? 1 : 0) > 0.5);
   g_news_stars    = (int)KP_StoreGet("news_stars", MathMax(1, MathMin(3, def_stars)));
   g_news_lead_min = (int)KP_StoreGet("news_lead", MathMax(1, MathMin(120, def_lead)));
   g_news_marks_on = (KP_StoreGet("news_marks", def_marks ? 1 : 0) > 0.5);
   g_news_filter   = (int)KP_StoreGet("news_filter", 2);
   if(g_news_filter < 1 || g_news_filter > 3)
      g_news_filter = 2;
   g_news_curmask  = (int)KP_StoreGet("news_curmask", KPN_MaskFromCSV(def_curs));
   if(g_news_curmask <= 0 || g_news_curmask >= (1 << KPN_NCUR))
      g_news_curmask = KPN_MaskFromCSV(def_curs);
  }

void KPN_SaveSettings()
  {
   KP_StoreSet("news_alert", g_news_alert_on ? 1 : 0);
   KP_StoreSet("news_stars", g_news_stars);
   KP_StoreSet("news_lead",  g_news_lead_min);
   KP_StoreSet("news_marks", g_news_marks_on ? 1 : 0);
   KP_StoreSet("news_filter", g_news_filter);
   KP_StoreSet("news_curmask", g_news_curmask);
  }

//--- format a calendar long value (x / 1e6) -------------------------
string KPN_Val(const long raw, const int digits, const int unit, const int mult)
  {
   if(raw == LONG_MIN)
      return "--";
   double v = raw / 1000000.0;
   string s = DoubleToString(v, MathMax(0, MathMin(digits, 3)));
   switch(mult)
     {
      case CALENDAR_MULTIPLIER_THOUSANDS: s += "K"; break;
      case CALENDAR_MULTIPLIER_MILLIONS:  s += "M"; break;
      case CALENDAR_MULTIPLIER_BILLIONS:  s += "B"; break;
      case CALENDAR_MULTIPLIER_TRILLIONS: s += "T"; break;
     }
   if(unit == CALENDAR_UNIT_PERCENT)
      s += "%";
   return s;
  }

//--- chart vertical-line marks --------------------------------------
void KPN_ClearMarks()
  {
   ObjectsDeleteAll(0, KP_NEWSVL);
  }

// registry of created labels: repositioning must never churn objects
#define KPN_LANES 6
ulong    g_mark_vid[];
datetime g_mark_time[];
int      g_mark_len[];
int      g_mark_n    = 0;
string   g_mark_fp   = "";
double   g_mark_pmax = 0, g_mark_pmin = 0;
long     g_mark_secpp = 0;

long KPN_SecPerPx()
  {
   long wpx   = ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   long wbars = ChartGetInteger(0, CHART_WIDTH_IN_BARS);
   int  psec  = PeriodSeconds(_Period);
   if(wpx > 0 && wbars > 0)
      return (long)MathMax(1, (double)wbars * psec / wpx);
   return 60;
  }

// text labels only up to H1: on D1/W1 all events collapse into one or
// two bars, labels are unreadable and object churn makes charts laggy
bool KPN_LabelsOn()
  {
   return (PeriodSeconds(_Period) <= 3600);
  }

// reposition existing labels only (no create/delete); skips entirely
// when neither the price range nor the zoom changed
void KPN_LayoutLabels()
  {
   if(g_mark_n <= 0)
      return;
   double pmax = ChartGetDouble(0, CHART_PRICE_MAX);
   double pmin = ChartGetDouble(0, CHART_PRICE_MIN);
   long secpp = KPN_SecPerPx();
   if(pmax == g_mark_pmax && pmin == g_mark_pmin && secpp == g_mark_secpp)
      return;
   g_mark_pmax = pmax;
   g_mark_pmin = pmin;
   g_mark_secpp = secpp;
   double rng = pmax - pmin;
   if(rng <= 0)
      return;
   datetime lane_end[KPN_LANES];
   for(int l=0; l<KPN_LANES; l++)
      lane_end[l] = 0;
   for(int i=0; i<g_mark_n; i++)
     {
      datetime span = (datetime)((g_mark_len[i] * 6 + 12) * secpp);
      int lane = -1;
      for(int l=0; l<KPN_LANES; l++)
         if(lane_end[l] <= g_mark_time[i]) { lane = l; break; }
      if(lane < 0)
        {
         lane = 0;
         for(int l=1; l<KPN_LANES; l++)
            if(lane_end[l] < lane_end[lane])
               lane = l;
        }
      lane_end[lane] = g_mark_time[i] + span;
      ObjectSetDouble(0, KP_NEWSVL + "T" + (string)g_mark_vid[i],
                      OBJPROP_PRICE, pmax - rng * (0.030 + 0.042 * lane));
     }
   ChartRedraw();
  }

// mark row eligibility for chart marks
bool KPN_MarkOK(const int i, const datetime now)
  {
   return (g_news[i].importance >= g_news_stars &&
           KPN_CurOK(g_news[i].cur) &&
           g_news[i].time >= now && g_news[i].time <= now + 48*3600);
  }

// smart update: objects are re-created ONLY when the eligible event set
// or the settings actually changed (fingerprint); otherwise labels are
// merely repositioned. Object churn on every chart event made D1/W1 lag.
void KPN_UpdateMarks(const bool force=false)
  {
   datetime now = TimeCurrent();

   int   viscount = 0;
   ulong first_vid = 0;
   if(g_news_marks_on && g_news_ok)
      for(int i=0; i<g_news_count && viscount < 40; i++)
         if(KPN_MarkOK(i, now))
           {
            if(viscount == 0)
               first_vid = g_news[i].vid;
            viscount++;
           }

   string fp = StringFormat("%d|%d|%d|%d|%I64d|%d|%I64u",
               (g_news_marks_on && g_news_ok) ? 1 : 0,
               g_news_stars, g_news_curmask,
               KPN_LabelsOn() ? 1 : 0,
               (long)g_news_last, viscount, first_vid);
   if(!force && fp == g_mark_fp)
     {
      KPN_LayoutLabels();   // cheap: price-anchor moves only
      return;
     }
   g_mark_fp = fp;

   KPN_ClearMarks();
   ArrayFree(g_mark_vid);
   ArrayFree(g_mark_time);
   ArrayFree(g_mark_len);
   g_mark_n = 0;
   g_mark_pmax = 0;          // invalidate layout cache
   g_mark_secpp = -1;
   if(viscount == 0)
     {
      ChartRedraw();
      return;
     }

   bool labels = KPN_LabelsOn();
   int made = 0;
   for(int i=0; i<g_news_count && made < 40; i++)
     {
      if(!KPN_MarkOK(i, now))
         continue;
      string name = KP_NEWSVL + (string)g_news[i].vid;
      if(!ObjectCreate(0, name, OBJ_VLINE, 0, g_news[i].time, 0))
         continue;
      color c = (g_news[i].importance == 3 ? C'214,60,68' :
                 g_news[i].importance == 2 ? C'214,168,50' : C'96,104,118');
      ObjectSetInteger(0, name, OBJPROP_COLOR, c);
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetString(0, name, OBJPROP_TEXT,
                      g_news[i].cur + " " + g_news[i].name);
      ObjectSetString(0, name, OBJPROP_TOOLTIP,
                      TimeToString(g_news[i].time, TIME_MINUTES) + "  " +
                      g_news[i].cur + "  " + g_news[i].name);

      if(labels)
        {
         MqlDateTime et;
         TimeToStruct(g_news[i].time, et);
         string nm = g_news[i].name;
         if(StringLen(nm) > 24)
            nm = StringSubstr(nm, 0, 23) + "…";
         string txt = StringFormat("%02d:%02d %s %s", et.hour, et.min,
                                   g_news[i].cur, nm);
         string tname = KP_NEWSVL + "T" + (string)g_news[i].vid;
         if(ObjectCreate(0, tname, OBJ_TEXT, 0, g_news[i].time, 0))
           {
            ObjectSetString(0, tname, OBJPROP_TEXT, txt);
            ObjectSetInteger(0, tname, OBJPROP_COLOR, c);
            ObjectSetString(0, tname, OBJPROP_FONT, "Consolas");
            ObjectSetInteger(0, tname, OBJPROP_FONTSIZE, 7);
            ObjectSetInteger(0, tname, OBJPROP_ANCHOR, ANCHOR_LEFT);
            ObjectSetInteger(0, tname, OBJPROP_BACK, true);
            ObjectSetInteger(0, tname, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, tname, OBJPROP_HIDDEN, true);
            int n = g_mark_n;
            ArrayResize(g_mark_vid,  n+1, 16);
            ArrayResize(g_mark_time, n+1, 16);
            ArrayResize(g_mark_len,  n+1, 16);
            g_mark_vid[n]  = g_news[i].vid;
            g_mark_time[n] = g_news[i].time;
            g_mark_len[n]  = StringLen(txt);
            g_mark_n++;
           }
        }
      made++;
     }
   KPN_LayoutLabels();      // assign lanes for the fresh label set
   ChartRedraw();
  }

//--- popup alerts ---------------------------------------------------
bool KPN_WasAlerted(const ulong vid)
  {
   for(int i=0; i<g_alerted_n; i++)
      if(g_alerted[i] == vid)
         return true;
   return false;
  }

void KPN_CheckAlerts()
  {
   if(!g_news_alert_on || !g_news_ok)
      return;
   datetime now = TimeCurrent();
   for(int i=0; i<g_news_count; i++)
     {
      if(g_news[i].importance < g_news_stars)
         continue;
      if(!KPN_CurOK(g_news[i].cur))
         continue;
      long dt = (long)(g_news[i].time - now);
      if(dt <= 0 || dt > (long)g_news_lead_min * 60)
         continue;
      if(KPN_WasAlerted(g_news[i].vid))
         continue;
      int n = g_alerted_n;
      ArrayResize(g_alerted, n+1, 32);
      g_alerted[n] = g_news[i].vid;
      g_alerted_n++;
      Alert(StringFormat("[KING PANEL] %s %s  in %d min  (fcst %s / prev %s)",
            g_news[i].cur, g_news[i].name, (int)(dt/60),
            g_news[i].v_fcst, g_news[i].v_prev));
     }
  }

//--- refresh (throttled) --------------------------------------------
void KPN_Refresh(const bool force=false)
  {
   datetime now = TimeCurrent();
   if(!force && g_news_last > 0 && now - g_news_last < 900)
      return;
   g_news_last = now;

   ArrayFree(g_news);
   g_news_count = 0;

   MqlCalendarValue values[];
   ResetLastError();
   datetime from = now - 6 * 3600;
   datetime to   = now + 72 * 3600;
   if(!CalendarValueHistory(values, from, to))
     {
      g_news_ok = false;
      g_news_last = now - 870;   // failed fetch: retry in ~30s, not 15min
      return;
     }
   g_news_ok = true;

   int total = ArraySize(values);
   for(int i=0; i<total && g_news_count < 200; i++)
     {
      MqlCalendarEvent ev;
      if(!CalendarEventById(values[i].event_id, ev))
         continue;
      if(ev.importance == CALENDAR_IMPORTANCE_NONE)
         continue;   // holidays / no-impact rows
      MqlCalendarCountry cn;
      if(!CalendarCountryById(ev.country_id, cn))
         continue;
      if(StringLen(cn.currency) < 3)
         continue;

      KPNewsRow r;
      r.vid        = values[i].id;
      r.time       = values[i].time;
      r.cur        = cn.currency;
      r.importance = (ev.importance == CALENDAR_IMPORTANCE_HIGH ? 3 :
                      ev.importance == CALENDAR_IMPORTANCE_MODERATE ? 2 : 1);
      r.name       = ev.name;
      r.v_prev     = KPN_Val(values[i].prev_value,     ev.digits, (int)ev.unit, (int)ev.multiplier);
      r.v_fcst     = KPN_Val(values[i].forecast_value, ev.digits, (int)ev.unit, (int)ev.multiplier);
      r.v_act      = KPN_Val(values[i].actual_value,   ev.digits, (int)ev.unit, (int)ev.multiplier);

      int n = g_news_count;
      ArrayResize(g_news, n+1, 64);
      // insertion sort by time (calendar output is near-sorted)
      int p = n;
      while(p > 0 && g_news[p-1].time > r.time)
        {
         g_news[p] = g_news[p-1];
         p--;
        }
      g_news[p] = r;
      g_news_count++;
     }

   KPN_UpdateMarks();
  }

// row passes list filters (importance + currency)
bool KPN_RowVisible(const int i)
  {
   return (g_news[i].importance >= g_news_filter && KPN_CurOK(g_news[i].cur));
  }

// count rows passing current filters
int KPN_FilteredCount()
  {
   int c = 0;
   for(int i=0; i<g_news_count; i++)
      if(KPN_RowVisible(i))
         c++;
   return c;
  }

#endif // KP_NEWS_MQH
