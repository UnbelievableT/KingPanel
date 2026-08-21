//+------------------------------------------------------------------+
//| KP_Fleet.mqh - KING PANEL V1.5                                   |
//| Multi-account overview via the terminal COMMON files folder:     |
//| every panel instance writes a heartbeat snapshot; every instance |
//| lists all snapshots. Works across terminals on the same machine. |
//+------------------------------------------------------------------+
#ifndef KP_FLEET_MQH
#define KP_FLEET_MQH

#define KP_FLEET_PREFIX "KP5_FLEET_"

struct KPFleetRow
  {
   long              login;
   string            server;
   string            currency;
   double            balance;
   double            equity;
   double            floating;
   int               positions;
   double            day_pl;
   bool              locked;
   datetime          ts;         // writer's TimeCurrent at write
   long              age;        // seconds since last heartbeat
  };

bool       g_fleet_on = true;

KPFleetRow g_fleet[];
int        g_fleet_n = 0;
datetime   g_fleet_last_write = 0;
datetime   g_fleet_last_read  = 0;

void KPF_Write()
  {
   if(!g_fleet_on || (bool)MQLInfoInteger(MQL_TESTER))
      return;
   if(TimeCurrent() - g_fleet_last_write < 5)
      return;
   g_fleet_last_write = TimeCurrent();
   string fn = StringFormat("%s%I64d.txt", KP_FLEET_PREFIX, g_acc.login);
   int h = FileOpen(fn, FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ, '\t', CP_UTF8);
   if(h == INVALID_HANDLE)
      return;
   // machine clock, NOT broker time: readers on other brokers must be
   // able to judge freshness without cross-server timezone skew
   FileWriteString(h, StringFormat("%I64d;%s;%s;%.2f;%.2f;%.2f;%d;%.2f;%d;%I64d",
      g_acc.login, g_acc.server, g_acc.currency,
      g_acc.balance, g_acc.equity, g_acc.floating_pl,
      g_acc.positions, KPT_DayPL(), (KPT_Locked() ? 1 : 0),
      (long)TimeLocal()));
   FileClose(h);
  }

void KPF_Read()
  {
   if(TimeCurrent() - g_fleet_last_read < 5)
      return;
   g_fleet_last_read = TimeCurrent();
   ArrayFree(g_fleet);
   g_fleet_n = 0;

   string fn;
   long search = FileFindFirst(KP_FLEET_PREFIX + "*.txt", fn, FILE_COMMON);
   if(search == INVALID_HANDLE)
      return;
   do
     {
      int h = FileOpen(fn, FILE_READ|FILE_TXT|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE, '\t', CP_UTF8);
      if(h == INVALID_HANDLE)
         continue;
      string line = FileReadString(h);
      FileClose(h);
      string p[];
      if(StringSplit(line, ';', p) < 10)
         continue;
      KPFleetRow r;
      r.login     = StringToInteger(p[0]);
      r.server    = p[1];
      r.currency  = p[2];
      r.balance   = StringToDouble(p[3]);
      r.equity    = StringToDouble(p[4]);
      r.floating  = StringToDouble(p[5]);
      r.positions = (int)StringToInteger(p[6]);
      r.day_pl    = StringToDouble(p[7]);
      r.locked    = (StringToInteger(p[8]) == 1);
      r.ts        = (datetime)StringToInteger(p[9]);
      r.age       = (long)(TimeLocal() - r.ts);
      if(r.age > 7*86400)
         continue;            // retired account: expire the ghost row
      int n = g_fleet_n;
      ArrayResize(g_fleet, n+1, 8);
      g_fleet[n] = r;
      g_fleet_n++;
     }
   while(FileFindNext(search, fn));
   FileFindClose(search);
  }

// remove own heartbeat so detaching doesn't leave a ghost row
void KPF_Cleanup()
  {
   if((bool)MQLInfoInteger(MQL_TESTER))
      return;
   FileDelete(StringFormat("%s%I64d.txt", KP_FLEET_PREFIX, g_acc.login),
              FILE_COMMON);
  }

#endif // KP_FLEET_MQH
