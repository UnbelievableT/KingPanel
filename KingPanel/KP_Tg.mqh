//+------------------------------------------------------------------+
//| KP_Tg.mqh - KING PANEL V1.4                                      |
//| Telegram delivery: drains the KP_Push event queue to a user bot  |
//| and sends a daily digest at reset. Optional; off unless a bot    |
//| token + chat id are configured. Requires the user to whitelist   |
//| https://api.telegram.org in Tools > Options > Expert Advisors.   |
//+------------------------------------------------------------------+
#ifndef KP_TG_MQH
#define KP_TG_MQH

bool   g_tg_failed = false;   // last send failed (header shows a red TG)
string g_tg_token = "";
string g_tg_chat  = "";
bool   g_tg_daily = false;
bool   g_tg_hinted = false;
datetime g_tg_last_digest = 0;
datetime g_tg_next_try = 0;

bool KPTG_On()
  {
   return (StringLen(g_tg_token) > 10 && StringLen(g_tg_chat) > 0 &&
           !(bool)MQLInfoInteger(MQL_TESTER));
  }

// URL-encode the few characters that break x-www-form-urlencoded
string KPTG_Enc(string s)
  {
   StringReplace(s, "%", "%25");
   StringReplace(s, "&", "%26");
   StringReplace(s, "+", "%2B");
   StringReplace(s, "#", "%23");
   StringReplace(s, "\n", "%0A");
   return s;
  }

bool KPTG_Send(const string text)
  {
   if(!KPTG_On())
      return false;
   string url = "https://api.telegram.org/bot" + g_tg_token + "/sendMessage";
   string body = "chat_id=" + g_tg_chat + "&text=" + KPTG_Enc(text);
   char data[], result[];
   StringToCharArray(body, data, 0, WHOLE_ARRAY, CP_UTF8);
   ArrayResize(data, ArraySize(data) - 1);   // strip trailing NUL
   string headers = "Content-Type: application/x-www-form-urlencoded\r\n";
   string rheaders = "";
   ResetLastError();
   // keep the blocking window short: this runs on the chart thread
   int code = WebRequest("POST", url, headers, 1200, data, result, rheaders);
   if(code != 200)
      g_tg_failed = true;
   else
      g_tg_failed = false;
   if(code == -1)
     {
      if(!g_tg_hinted)
        {
         g_tg_hinted = true;
         KPT_RiskMsg(LL("Telegram: whitelist https://api.telegram.org in Options>Experts",
                        "Telegram: 请在 选项>EA交易 白名单加入 https://api.telegram.org"));
        }
      return false;
     }
   return (code == 200);
  }

// drain events queued by KP_Push (single chokepoint for all alerts).
// WebRequest is synchronous and stalls the chart thread, so at most one
// send per tick and never while a burst is still arriving.
void KPTG_Drain()
  {
   if(!KPTG_On())
     {
      if(g_push_queue_n > 0)
         g_push_queue_n = 0;
      return;
     }
   if(g_push_queue_n <= 0)
      return;
   // batch EVERY queued line - dropping the tail would silently lose
   // exactly the alerts a burst (a guard cascade) is made of
   string text = "";
   for(int i=0; i<g_push_queue_n; i++)
      text += (i > 0 ? "\n" : "") + g_push_queue[i];
   g_push_queue_n = 0;
   if(StringLen(text) > 3500)
      text = StringSubstr(text, 0, 3500) + " ...";
   KPTG_Send("[KING PANEL] " + text);
  }

// daily digest shortly after the prop-day reset
void KPTG_DigestTick()
  {
   if(!KPTG_On() || !g_tg_daily)
      return;
   datetime a = KP_ResetAnchor(TimeCurrent());
   if(g_tg_last_digest >= a)
      return;
   if(TimeCurrent() < a + 120)          // give the rebuild time to roll over
      return;
   if(g_last_rebuild < a)
      return;
   if(TimeCurrent() < g_tg_next_try)    // failed-send backoff
      return;

   // the prop day that just ended: closes from a-86400 up to a
   double dnet = 0, worst = 0;
   int dtrd = 0, dwin = 0;
   for(int k=g_close_n-1; k>=0; k--)
     {
      int i = g_close_order[k];
      if(g_pos[i].close_time >= a)
         continue;
      if(g_pos[i].close_time < a - 86400)
         break;
      dnet += g_pos[i].net;
      dtrd++;
      if(g_pos[i].net >= 0) dwin++;
      if(g_pos[i].net < worst) worst = g_pos[i].net;
     }
   double dwr = (dtrd > 0 ? 100.0*dwin/dtrd : 0);
   bool ok = KPTG_Send(StringFormat(
      LL("[KING PANEL] daily digest %s\nnet %.2f | trades %d | win %.0f%% | worst %.2f\n"
         "equity %.2f | balance %.2f | total net %.2f | maxDD %.1f%%",
         "[KING PANEL] 每日摘要 %s\n净盈亏 %.2f | 笔数 %d | 胜率 %.0f%% | 最差 %.2f\n"
         "净值 %.2f | 余额 %.2f | 累计净利 %.2f | 最大回撤 %.1f%%"),
      TimeToString(a - 86400, TIME_DATE), dnet, dtrd, dwr, worst,
      g_acc.equity, g_acc.balance, g_tot.net, g_tot.max_dd_pct));
   if(ok)
     {
      g_tg_last_digest = a;
      KP_StoreSet("tg_digest", (double)(long)a);
     }
   else
      g_tg_next_try = TimeCurrent() + 300;
  }

void KPTG_Load(const string token, const string chat, const bool daily)
  {
   g_tg_token = token;
   g_tg_chat  = chat;
   g_tg_daily = daily;
   g_tg_last_digest = (datetime)(long)KP_StoreGet("tg_digest", 0);
  }

#endif // KP_TG_MQH
