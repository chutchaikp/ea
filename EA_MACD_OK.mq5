//+------------------------------------------------------------------+
//|                                                   EA_MACD_OK.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.03"

double MACDBuffer[];
int macd_handle; // from Def

// ON INIT
int OnInit()
  {
   //macd_handle = iMACD(_Symbol, PERIOD_CURRENT, 12, 26, 9, PRICE_CLOSE);
   //ArraySetAsSeries(macd, true);
   Print(" __MQLBUILD__ = ",__MQLBUILD__,"  __FILE__ = ",__FILE__); 
   Print(" __FUNCTION__ = ",__FUNCTION__,"  __LINE__ = ",__LINE__); 
   Print("__DATE__ = ", __DATETIME__);

   return(INIT_SUCCEEDED);
  }

// ON RELEASE EA
void OnDeinit(const int reason)
  {
    ObjectsDeleteAll(0);
   ChartSetString(0, CHART_COMMENT, "");
   ChartRedraw(0);
  }

// on tick
void OnTick()
  {
   if(GetLastError() > 0)
     {
      Print(GetLastError());
     }

// destination
   macd_handle = iMACD(_Symbol, PERIOD_CURRENT, 12, 26, 9, PRICE_CLOSE);
// sort by desc
   ArraySetAsSeries(MACDBuffer, true);
// start copy
   int copyCount = CopyBuffer(macd_handle, 0, 0, 2, MACDBuffer);
// print output
   datetime dx = TimeCurrent();
   int err_ = GetLastError();   
   string str = StringFormat("  \nMACD: %f \n\ndate: %s \n\ncopy count: %i \n\nerror: %i ", MACDBuffer[0], (string)dx, copyCount, err_);
   Comment(str);
   
// release memory
   ZeroMemory(MACDBuffer);
   ZeroMemory(macd_handle);
   ZeroMemory(dx);
   
   if (err_ > 0) 
      {
         ResetLastError();
      }

  }
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
