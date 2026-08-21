//+------------------------------------------------------------------+
//| KP_Canvas.mqh - KING PANEL V1.5                                  |
//| CCanvas wrapper: text, widgets (sparkline/gauge/bars), hit map   |
//+------------------------------------------------------------------+
#ifndef KP_CANVAS_MQH
#define KP_CANVAS_MQH

#include <Canvas/Canvas.mqh>
#include "KP_Theme.mqh"

#define KP_OBJ "KP5_PANEL"

CCanvas    g_cv;
int        g_cv_w = 0;
int        g_cv_h = 0;
bool       g_cv_ready = false;

//--- click hit regions ----------------------------------------------
struct KPHit
  {
   int               x, y, w, h;
   int               id;
   long              arg;
   string            sarg;
  };
KPHit g_hits[512];
int   g_hit_count = 0;

void KPC_ClearHits() { g_hit_count = 0; }

void KPC_AddHit(const int x, const int y, const int w, const int h,
                const int id, const long arg=0, const string sarg="")
  {
   if(g_hit_count >= 512)
      return;
   g_hits[g_hit_count].x = x;  g_hits[g_hit_count].y = y;
   g_hits[g_hit_count].w = w;  g_hits[g_hit_count].h = h;
   g_hits[g_hit_count].id = id;
   g_hits[g_hit_count].arg = arg;
   g_hits[g_hit_count].sarg = sarg;
   g_hit_count++;
  }

// returns hit index or -1 (topmost = last added wins)
int KPC_HitTest(const int x, const int y)
  {
   for(int i=g_hit_count-1; i>=0; i--)
      if(x >= g_hits[i].x && x < g_hits[i].x + g_hits[i].w &&
         y >= g_hits[i].y && y < g_hits[i].y + g_hits[i].h)
         return i;
   return -1;
  }

//--- canvas lifecycle -----------------------------------------------
bool KPC_Create(const int x, const int y, const int w, const int h)
  {
   // XRGB_NOALPHA, not ARGB_*: GDI text rendering does not preserve the
   // alpha channel, so with an alpha-aware format every antialiased
   // glyph edge becomes semi-transparent and composites against the
   // CHART instead of the panel - that is what makes text look fuzzy.
   // The panel is fully opaque by design, so ignoring alpha is correct.
   // a leftover object from a hard-killed instance would make every
   // future CreateBitmapLabel fail, bricking the panel permanently
   if(ObjectFind(0, KP_OBJ) >= 0)
      ObjectDelete(0, KP_OBJ);
   if(!g_cv.CreateBitmapLabel(0, 0, KP_OBJ, x, y, w, h, COLOR_FORMAT_XRGB_NOALPHA))
      return false;
   ObjectSetInteger(0, KP_OBJ, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, KP_OBJ, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, KP_OBJ, OBJPROP_ZORDER, 100);
   g_cv_w = w; g_cv_h = h;
   g_cv_ready = true;
   return true;
  }

void KPC_Destroy()
  {
   if(g_cv_ready)
      g_cv.Destroy();
   g_cv_ready = false;
  }

void KPC_Move(const int x, const int y)
  {
   ObjectSetInteger(0, KP_OBJ, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, KP_OBJ, OBJPROP_YDISTANCE, y);
  }

void KPC_EnsureSize(const int w, const int h)
  {
   if(w == g_cv_w && h == g_cv_h)
      return;
   g_cv.Resize(w, h);
   g_cv_w = w; g_cv_h = h;
  }

void KPC_Update() { g_cv.Update(true); }

//--- primitives ------------------------------------------------------
void KPC_Fill(const int x, const int y, const int w, const int h, const uint clr)
  {
   if(w <= 0 || h <= 0) return;
   g_cv.FillRectangle(x, y, x+w-1, y+h-1, clr);
  }

void KPC_Frame(const int x, const int y, const int w, const int h, const uint clr)
  {
   g_cv.Rectangle(x, y, x+w-1, y+h-1, clr);
  }

void KPC_HLine(const int x1, const int x2, const int y, const uint clr)
  {
   g_cv.LineHorizontal(x1, x2, y, clr);
  }

void KPC_VLine(const int x, const int y1, const int y2, const uint clr)
  {
   g_cv.LineVertical(x, y1, y2, clr);
  }

// dotted grid lines (1px dot every 3px)
void KPC_HDot(const int x1, const int x2, const int y, const uint clr)
  {
   for(int x=x1; x<=x2; x+=3)
      g_cv.PixelSet(x, y, clr);
  }

void KPC_VDot(const int x, const int y1, const int y2, const uint clr)
  {
   for(int y=y1; y<=y2; y+=3)
      g_cv.PixelSet(x, y, clr);
  }

//--- text ------------------------------------------------------------
// align: 0 left, 1 center, 2 right (baseline = top)
void KPC_Text(const int x, const int y, const string txt, const uint clr,
              const string font, const double pt, const int align=0,
              const bool bold=false)
  {
   g_cv.FontSet(font, KP_F(pt), (bold ? FW_SEMIBOLD : FW_NORMAL));
   uint flags = TA_TOP | (align == 1 ? TA_CENTER : (align == 2 ? TA_RIGHT : TA_LEFT));
   g_cv.TextOut(x, y, txt, clr, flags);
  }

int KPC_TextW(const string txt, const string font, const double pt,
              const bool bold=false)
  {
   g_cv.FontSet(font, KP_F(pt), (bold ? FW_SEMIBOLD : FW_NORMAL));
   uint w = 0, h = 0;
   TextGetSize(txt, w, h);
   return (int)w;
  }

// numeric text (mono font)
void KPC_Num(const int x, const int y, const string txt, const uint clr,
             const double pt, const int align=0, const bool bold=false)
  {
   KPC_Text(x, y, txt, clr, KP_FontMono, pt, align, bold);
  }

// value text: monospace for pure ASCII (column alignment), CJK font as
// soon as the string carries a localized word - Consolas has no CJK
// glyphs and would render tofu boxes
bool KPC_HasCJK(const string s)
  {
   int n = StringLen(s);
   for(int i=0; i<n; i++)
      if(StringGetCharacter(s, i) > 127)
         return true;
   return false;
  }

void KPC_Val(const int x, const int y, const string txt, const uint clr,
             const double pt, const int align=0, const bool bold=false)
  {
   KPC_Text(x, y, txt, clr, (KPC_HasCJK(txt) ? KP_FontCJK : KP_FontMono),
            pt, align, bold);
  }

// UI label text: mono in English mode, CJK font in Chinese mode
void KPC_Lbl(const int x, const int y, const string txt, const uint clr,
             const double pt, const int align=0, const bool bold=false)
  {
   KPC_Text(x, y, txt, clr, (KP_Lang == 0 ? KP_FontMono : KP_FontCJK),
            pt, align, bold);
  }

//--- widget: area sparkline -----------------------------------------
// domain_n > n : data occupies only the left n/domain_n fraction of the
// width (growing live curve instead of stretching few samples full-width)
void KPC_Spark(const int x, const int y, const int w, const int h,
               const double &data[], const int n,
               const uint line_clr, const uint fill_clr,
               const bool baseline_zero=false, const int domain_n=0)
  {
   if(n < 2 || w < 4 || h < 4)
      return;
   double mn = data[0], mx = data[0];
   for(int i=1; i<n; i++)
     {
      if(data[i] < mn) mn = data[i];
      if(data[i] > mx) mx = data[i];
     }
   if(baseline_zero)
     {
      if(mn > 0) mn = 0;
      if(mx < 0) mx = 0;
     }
   double rng = mx - mn;
   bool flat = (rng < MathMax(0.0000001, MathAbs(mx) * 0.0000001));
   if(!flat && !baseline_zero)
     {
      // 7% padding so the line never hugs the borders
      double pad = rng * 0.07;
      mn -= pad;
      mx += pad;
      rng = mx - mn;
     }

   int used_w = w;
   if(domain_n > n)
     {
      used_w = (int)MathRound((double)w * n / domain_n);
      if(used_w < 8) used_w = 8;
     }

   if(flat)
     {
      // flat series: centered horizontal line, no fake amplitude
      int fy = y + h/2;
      g_cv.LineHorizontal(x, x + used_w - 1, fy, line_clr);
      g_cv.FillCircle(x + used_w - 1, fy, 2, line_clr);
      return;
     }

   int pts = MathMin(n, used_w);
   int px[], py[];
   ArrayResize(px, pts);
   ArrayResize(py, pts);
   for(int i=0; i<pts; i++)
     {
      int di = (int)MathRound((double)i * (n-1) / (pts-1));
      double v = data[di];
      px[i] = x + (int)MathRound((double)i * (used_w-1) / (pts-1));
      py[i] = y + (h-1) - (int)MathRound((v - mn) / rng * (h-1));
     }
   for(int i=0; i<pts; i++)
      g_cv.LineVertical(px[i], py[i], y + h - 1, fill_clr);
   g_cv.PolylineAA(px, py, line_clr);
   g_cv.FillCircle(px[pts-1], py[pts-1], 2, line_clr);
  }

//--- widget: vertical bars around zero baseline ---------------------
// returns the y of the zero axis
int KPC_Bars(const int x, const int y, const int w, const int h,
             const double &vals[], const int n,
             const uint pos_clr, const uint neg_clr, const uint axis_clr)
  {
   if(n <= 0)
      return y + h/2;
   double mn = 0, mx = 0;
   for(int i=0; i<n; i++)
     {
      if(vals[i] < mn) mn = vals[i];
      if(vals[i] > mx) mx = vals[i];
     }
   double rng = mx - mn;
   if(rng < 0.0000001) rng = 1.0;
   int zero_y = y + (int)MathRound(mx / rng * (h-1));

   double step = (double)w / n;
   int bw = MathMax(1, (int)MathFloor(step) - (step >= 3.0 ? 1 : 0));
   for(int i=0; i<n; i++)
     {
      int bx = x + (int)MathRound(i * step);
      int vy = y + (int)MathRound((mx - vals[i]) / rng * (h-1));
      if(vals[i] >= 0)
         KPC_Fill(bx, vy, bw, MathMax(1, zero_y - vy + 1), pos_clr);
      else
         KPC_Fill(bx, zero_y, bw, MathMax(1, vy - zero_y + 1), neg_clr);
     }
   g_cv.LineHorizontal(x, x + w - 1, zero_y, axis_clr);
   return zero_y;
  }

//--- widget: horizontal bar -----------------------------------------
void KPC_HBar(const int x, const int y, const int w, const int h,
              const double frac, const uint clr, const uint bg)
  {
   KPC_Fill(x, y, w, h, bg);
   double f = MathMax(0.0, MathMin(1.0, frac));
   int fw = (int)MathRound(w * f);
   if(fw > 0)
      KPC_Fill(x, y, fw, h, clr);
  }

//--- widget: ring gauge ---------------------------------------------
double KP_Atan2(const double y, const double x)
  {
   if(x > 0.0)  return MathArctan(y / x);
   if(x < 0.0)  return MathArctan(y / x) + (y >= 0.0 ? M_PI : -M_PI);
   return (y >= 0.0 ? M_PI/2.0 : -M_PI/2.0);
  }

// frac 0..1 sweep clockwise from 12 o'clock
void KPC_Ring(const int cx, const int cy, const int r_out, const int r_in,
              const double frac, const uint clr, const uint bg)
  {
   double f = MathMax(0.0, MathMin(1.0, frac));
   double sweep = f * 2.0 * M_PI;
   for(int dy=-r_out; dy<=r_out; dy++)
      for(int dx=-r_out; dx<=r_out; dx++)
        {
         double d = MathSqrt((double)(dx*dx + dy*dy));
         if(d < r_in - 0.5 || d > r_out + 0.5)
            continue;
         // angle from 12 o'clock, clockwise
         double a = KP_Atan2((double)dx, (double)(-dy));
         if(a < 0) a += 2.0 * M_PI;
         g_cv.PixelSet(cx + dx, cy + dy, (a <= sweep ? clr : bg));
        }
  }

//--- widget: two-segment split bar (left vs right share) ------------
void KPC_SplitBar(const int x, const int y, const int w, const int h,
                  const double left_share, const uint lclr, const uint rclr)
  {
   double f = MathMax(0.0, MathMin(1.0, left_share));
   int lw = (int)MathRound(w * f);
   KPC_Fill(x, y, lw, h, lclr);
   KPC_Fill(x + lw, y, w - lw, h, rclr);
  }

//--- widget: button --------------------------------------------------
void KPC_Button(const int x, const int y, const int w, const int h,
                const string txt, const uint txt_clr, const uint face,
                const int hit_id, const long arg=0, const string sarg="",
                const double pt=7.6, const bool cjk=true)
  {
   KPC_Fill(x, y, w, h, face);
   KPC_Frame(x, y, w, h, KP_SEP);
   int ty = y + (h - KP_S(13)) / 2;
   if(cjk) KPC_Lbl(x + w/2, ty, txt, txt_clr, pt, 1);
   else    KPC_Num(x + w/2, ty, txt, txt_clr, pt, 1);
   KPC_AddHit(x, y, w, h, hit_id, arg, sarg);
  }

#endif // KP_CANVAS_MQH
