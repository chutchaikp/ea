//+------------------------------------------------------------------+
//|                                        EA_MACD_TRAILING_STOP.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+

#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.05"

#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>

CSymbolInfo       m_symbol;
CPositionInfo m_position;
CTrade trade;

input int breakeven_value = 600; // GOLD# 600, GBPJPY# 400
input double sell_buy_volume = 0.01; // Lots
input int max_sl_point = 300; // Maximum SL points

// Outside trade time - check if positionsTotal > 0 so close them all

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int hour_start = 0; // Start Hour (utc+2)
int hour_end = 18; // End Hour (utc+2)

int running_no = 0;
input int MACD_FastEMA = 12;            // MACD Fast EMA period
input int MACD_SlowEMA = 26;            // MACD Slow EMA period
input int MACD_SignalPeriod = 9;        // MACD Signal period

datetime lastbar_timeopen; // LOR_;

struct Data_
  {
   double            ask_;
   double            bid_;
   double            spread_;
   MqlDateTime       timeMarket_;
   MqlDateTime       timeGMT_;
   int               positionsTotal_;
  };
Data_ data_ = { 0, 0, 0};

struct FVG
  {
   string            type_; // none, bullish, bearish
   double            top_;
   double            bottom_;
   string            signal_; // buy, sell
  };
FVG fvg_ = { "none", 0, 0, "none" };

struct MACD
  {
   double            current_macd_;
   double            previous_macd_;
   double            current_signal_;
   double            previous_signal_;
   string            signal_; // buy, sell
  };
MACD macd_ = { -1, -1, -1, -1, "none" };

//bool market_opening = false;
//int market_open_hour = 0; // UTC+2  market time ?
//int market_close_hour = 20; // UTC+2 market time ?

bool isDebug = true;

// Init EA
int OnInit()
  {

   ResetLastError();

   if(!isDebug == true)
     {
      CreateButton();
     }
   else
     {
      ObjectsDeleteAll(0);
      ChartSetString(0, CHART_COMMENT, "");
      ChartRedraw(0);
     }

// BuyTest();

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {

   ObjectsDeleteAll(0);
   ChartSetString(0, CHART_COMMENT, "");
   ChartRedraw(0);
  }

// New data comming
void OnTick()
  {
   int err_ = GetLastError();
   if(err_ > 0)
     {
      Print("Error code: ", err_);
      Comment(StringFormat("Error code: %i", err_));
      return;
     }

   if(!InTimeRange())
     {
      if(PositionsTotal() > 0)
        {
         PositionCloseAll();
        }

      Comment("Waiting.....");
      return;
     }

   InitialData();

   return;

   if(IsNewBar(false) == true)
     {
      if(PositionsTotal() == 0)
        {
         if(fvg_.signal_ == "buy" && macd_.signal_ == "buy")
           {
            // Order_(ORDER_TYPE_BUY);
            Alert("Buy now!");
           }
         if(fvg_.signal_ == "sell" && macd_.signal_ == "sell")
           {
            // Order_(ORDER_TYPE_SELL);
            Alert("Sell now!");
           }
        }
      else
        {
         // ApplyTrailingStop();
         DynamicTrailingStop();
        }
     }
  }

// Follow trade time each assets template, check in google docs
bool InTimeRange()
  {

   if(isDebug == true)
     {
      datetime time = iTime(_Symbol, PERIOD_CURRENT, 0);

      MqlDateTime tm;

      TimeToStruct(time, tm);

      //         PrintFormat("Server time: %s\n- Year: %u\n- Month: %02u\n- Day: %02u\n- Hour: %02u\n- Min: %02u\n- Sec: %02u\n- Day of Year: %03u\n- Day of Week: %u (%s)",
      //               (string)time, tm.year, tm.mon, tm.day, tm.hour, tm.min, tm.sec, tm.day_of_year, tm.day_of_week, EnumToString((ENUM_DAY_OF_WEEK)tm.day_of_week));
      //
      if(tm.hour >= hour_start && tm.hour <= hour_end)
        {
         return true;
        }
      return false;
     }

   TimeCurrent(data_.timeMarket_);
   if(data_.timeMarket_.hour >= hour_start && data_.timeMarket_.hour <= hour_end)
     {
      return true;
     }
   return false;
  }

//  // Apply a trailing stop to all positions
//void ApplyTrailingStop() {
//   for (int i = 0; i < PositionsTotal(); i++) {
//      ulong ticket = PositionGetTicket(i);
//      if (PositionSelectByTicket(ticket)) {
//         double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
//         double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
//         int positionType = PositionGetInteger(POSITION_TYPE);
//         double sl = PositionGetDouble(POSITION_SL);
//         double trailingStopPrice;
//         if (positionType == POSITION_TYPE_BUY) {
//            trailingStopPrice = currentPrice - TrailingStopPips * _Point;
//            if (trailingStopPrice > entryPrice && (sl < trailingStopPrice || sl == 0)) {
//               trailingStopPrice = NormalizeDouble(trailingStopPrice, _Digits);
//               PositionModify(ticket, trailingStopPrice, 0);
//               Print("Trailing stop updated for Buy: ", trailingStopPrice);
//            }
//         } else if (positionType == POSITION_TYPE_SELL) {
//            trailingStopPrice = currentPrice + TrailingStopPips * _Point;
//            if (trailingStopPrice < entryPrice && (sl > trailingStopPrice || sl == 0)) {
//               trailingStopPrice = NormalizeDouble(trailingStopPrice, _Digits);
//               PositionModify(ticket, trailingStopPrice, 0);
//               Print("Trailing stop updated for Sell: ", trailingStopPrice);
//            }
//         }
//      }
//   }
//}

// Check MACD for Buy/Sell signals
void CheckMACDSignals()
  {

   double macdMain[], macdSignal[];
   int macdHandle = iMACD(NULL, _Period, MACD_FastEMA, MACD_SlowEMA, MACD_SignalPeriod, PRICE_CLOSE);

   if(macdHandle < 0)
     {
      Print("Failed to create MACD handle");
      return;
     }

   ArraySetAsSeries(macdMain, true);
   ArraySetAsSeries(macdSignal, true);
   
   CopyBuffer(macdHandle, 0, 0, 3, macdMain);   // MACD main line
   
   
   return;
   
   
   CopyBuffer(macdHandle, 1, 0, 3, macdSignal); // MACD signal line
   
   
   
   
   
   double currentMACD = macdMain[0];
   double previousMACD = macdMain[1];
   double currentSignal = macdSignal[0];
   double previousSignal = macdSignal[1];

   macd_.current_macd_ = currentMACD;
   macd_.previous_macd_ = previousMACD;

   macd_.current_signal_ = currentSignal;
   macd_.previous_signal_ = previousSignal;



   if(currentMACD > currentSignal)
     {
      macd_.signal_ = "buy";
      Print(StringFormat("FVG - %s MACD - %s", fvg_.signal_, macd_.signal_));
     }
   else
      if(currentMACD < currentSignal)
        {
         macd_.signal_ = "sell";
         Print(StringFormat("FVG - %s MACD - %s", fvg_.signal_, macd_.signal_));
        }

   IndicatorRelease(macdHandle);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CheckFVGSignals()
  {
   IsBullishFVG(1);
   IsBearishFVG(1);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsBullishFVG(int shift = 0)
  {
   double high2Ago = iHigh(_Symbol, PERIOD_CURRENT, 2 + shift); // High[shift + 2];
   double lowNow = iLow(_Symbol, PERIOD_CURRENT, 0 + shift);    // Low[shift];

   if(high2Ago < lowNow)
     {
      fvg_.type_ = "bullish";
      fvg_.signal_ = "buy";
      fvg_.top_ = lowNow;
      fvg_.bottom_ = high2Ago;

      DrawFVGMarker(shift, true);

      // Print("FVG - buy");
      Print(StringFormat("FVG - %s MACD - %s", fvg_.signal_, macd_.signal_));
     }

   return (high2Ago < lowNow);
  }

// Check FVG if Bearish
bool IsBearishFVG(int shift = 0)
  {
   double low2Ago = iLow(_Symbol, PERIOD_CURRENT, 2 + shift);
   double highNow = iHigh(_Symbol, PERIOD_CURRENT, 0 + shift);

   if(low2Ago > highNow)
     {
      fvg_.type_ = "bearish";
      fvg_.signal_ = "sell";
      fvg_.top_ = low2Ago;
      fvg_.bottom_ = highNow;

      DrawFVGMarker(shift, false);

      // Print("FVG - sell");
      Print(StringFormat("FVG - %s MACD - %s", fvg_.signal_, macd_.signal_));
     }

   return (low2Ago > highNow);
  }

// Draw FVG to chart
void DrawFVGMarker(int shift, bool bullish)
  {
   color markerColor = bullish ? clrYellow : clrBlue;
   string markerName = bullish ? "BullishFVG_" : "BearishFVG_";
   markerName += IntegerToString(shift);

//   double startPrice = bullish ? iLow(_Symbol, PERIOD_CURRENT, 2) : iHigh(_Symbol, PERIOD_CURRENT, 2);
//   double endPrice = bullish ? iHigh(_Symbol, PERIOD_CURRENT, 0) : iLow(_Symbol, PERIOD_CURRENT, 0);//
//// Draw rectangle for FVG
//   ObjectCreate(0, markerName, OBJ_RECTANGLE, 0, iTime(_Symbol, PERIOD_CURRENT, 2), startPrice, iTime(_Symbol, PERIOD_CURRENT, 0), endPrice);

   double startPrice = bullish == false ?
                       iLow(_Symbol, PERIOD_CURRENT, 2 + shift) :
                       iHigh(_Symbol, PERIOD_CURRENT, 2 + shift);
   double endPrice = bullish == false ?
                     iHigh(_Symbol, PERIOD_CURRENT, 0 + shift) :
                     iLow(_Symbol, PERIOD_CURRENT, 0 + shift);


   ObjectCreate(0, markerName, OBJ_RECTANGLE, 0,
                iTime(_Symbol, PERIOD_CURRENT, 2 + shift),
                startPrice,
                iTime(_Symbol, PERIOD_CURRENT, 0 + shift),
                endPrice);

   ObjectSetInteger(0, markerName, OBJPROP_COLOR, markerColor);
   ObjectSetInteger(0, markerName, OBJPROP_WIDTH, 1);
  }

// Close all positions
void PositionCloseAll()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(m_position.SelectByIndex(i))
        {
         if(m_position.Symbol() == Symbol())
           {
            ulong ticket_ = m_position.Ticket();
            string str_ = StringFormat(" Ticket: %s closed! ", (string)ticket_);
            Alert(str_);
            trade.PositionClose(ticket_);
           }
        }
     }
   int err_ = GetLastError();
   if(err_ > 0)
     {
      Print("Error: ", err_);
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void Order_(ENUM_ORDER_TYPE order_type)
  {
   if(order_type == ORDER_TYPE_SELL)
     {
      double sl_ = fvg_.top_ + data_.spread_;
      sl_ = fvg_.top_ - data_.ask_ > max_sl_point ? data_.ask_ + max_sl_point : sl_; // set SL <= 300
      string comment_ = StringFormat("exe-%u fvgtop: %f spread: %f sl: %f", running_no++, fvg_.top_, data_.spread_, sl_);
      trade.Sell(sell_buy_volume, _Symbol, data_.bid_, sl_, 0, comment_);
     }
   else
     {
      double sl_ = fvg_.bottom_ - data_.spread_;
      sl_ = data_.bid_ - fvg_.bottom_ > max_sl_point ? data_.bid_ - max_sl_point : sl_; // set SL <= 300
      string comment_ = StringFormat("exe-%u fvgbottom: %f spread: %f sl: %f", running_no++, fvg_.bottom_, data_.spread_, sl_);
      trade.Buy(sell_buy_volume, _Symbol, data_.ask_, sl_, 0, comment_);
     }

   Print("Retcode: ", trade.ResultRetcode()," Description: ", trade.ResultRetcodeDescription());
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void InitialData()
  {
   int err_ = GetLastError();

   if(err_ > 0)
     {
      Print(err_, " - Something went wrong!");
      data_.ask_ = -1;
      data_.bid_ = -1;

      ResetLastError();
      return;
     }

// store data in global vars for general purpose ?

   CheckFVGSignals();
   
   CheckMACDSignals();

   return;

   datetime bar_start_time = iTime(_Symbol, PERIOD_CURRENT, 0);
   datetime tick_time = TimeCurrent();

   double open_price = iOpen(_Symbol,PERIOD_CURRENT,0);
   data_.ask_ = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
   data_.bid_ = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);
   data_.spread_ = MathAbs(data_.ask_-data_.bid_);
   data_.positionsTotal_ = PositionsTotal();

   TimeCurrent(data_.timeMarket_);
   TimeGMT(data_.timeGMT_);

   string status_ = InTimeRange() == true ? "OK - " + (string)__RANDOM__ : "waiting...until hour " + (string)hour_start ;
   string str_ = StringFormat(
                    "\n%u-%02u-%02u %02u:%02u:%02u" +
                    "\nMarket.hour:  %i \nGMT.hour:    %i " +
                    "\n\nAsk:        %f" +
                    "\nBid:         %f" +
                    "\n\nbar time: %s\ntick time: %s " +
                    "\n\nfvg:      %s \ntop:      %f \nbottom: %f" +

                    "\n\nmacd.current.macd: %f \nmacd.current.signal: %f \nmacd.signal: %s" +

                    "\n\n\n\n \n\n\n\n " +
                    "\n\nprice.diff: %s" +
                    "\n\npoint: %f --> %f" +
                    "\n\nStatus: %s",
                    data_.timeMarket_.year, data_.timeMarket_.mon, data_.timeMarket_.day, data_.timeMarket_.hour, data_.timeMarket_.min, data_.timeMarket_.sec,
                    data_.timeMarket_.hour, data_.timeGMT_.hour,
                    data_.ask_,
                    data_.bid_,
                    (string)bar_start_time, (string)tick_time,
                    fvg_.type_, fvg_.top_, fvg_.bottom_,

                    macd_.current_macd_, macd_.current_signal_, macd_.signal_,

                    (string)(MathAbs(open_price-data_.bid_)),
                    _Point, MathAbs(open_price-data_.bid_)/_Point,
                    status_
                 );
   Comment(str_);
  }

//bool HasPositionBUY()
//  {
//   for(int i = data_.positionsTotal_ - 1; i >= 0; i--)
//     {
//      if(m_position.SelectByIndex(i))
//        {
//         if(m_position.Symbol() == Symbol())
//           {
//            //trade.PositionClose(m_position.Ticket());
//            if(m_position.PositionType() == POSITION_TYPE_BUY)
//              {
//               return true;
//              }
//           }
//        }
//     }
//   return false;
//  }

//bool HasPositionSELL()
//  {
//   for(int i = data_.positionsTotal_ - 1; i >= 0; i--)
//     {
//      if(m_position.SelectByIndex(i))
//        {
//         if(m_position.Symbol() == Symbol())
//           {
//            //trade.PositionClose(m_position.Ticket());
//            if(m_position.PositionType() == POSITION_TYPE_SELL)
//              {
//               return true;
//              }
//           }
//        }
//     }
//   return false;
//  }

// Define trailing stop settings
int GetTrailingStopPips()
  {
   switch(Period())
     {
      case PERIOD_M1:
         return 10;  // 10 pips trailing for M1
      case PERIOD_M5:
         return 15;  // 15 pips trailing for M5
      case PERIOD_M15:
         return 20;  // 20 pips trailing for M15
      case PERIOD_M30:
         return 25;  // 25 pips trailing for M30
      case PERIOD_H1:
         return 30;  // 30 pips trailing for H1
      case PERIOD_H4:
         return 50;  // 50 pips trailing for H4
      case PERIOD_D1:
         return 100; // 100 pips trailing for Daily
      default:
         return 20;  // Default for unknown timeframes
     }
  }

// Function to move stop-loss dynamically as profit increases
void DynamicTrailingStop()
  {

   int err_ = GetLastError();
   if(err_ > 0)
     {
      Print("Error code: ", err_);
     }

   double entryPrice, stopLossPrice, trailingStopPrice, currentPrice;
   double spread = data_.spread_ * _Point; // SymbolInfoDouble(_Symbol, SYMBOL_SPREAD) * _Point;
   int trailingPips = GetTrailingStopPips();

   if(PositionsTotal() > 0)
     {
      for(int i = 0; i < PositionsTotal(); i++)
        {
         ulong ticket = PositionGetTicket(i);
         if(PositionSelectByTicket(ticket))
           {
            string symbol = PositionGetString(POSITION_SYMBOL);
            if(symbol == _Symbol)
              {
               double sl = PositionGetDouble(POSITION_SL);
               long positionType = PositionGetInteger(POSITION_TYPE);

               entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
               currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);

               if(positionType == POSITION_TYPE_BUY)
                 {
                  trailingStopPrice = currentPrice - trailingPips * _Point; // *****
                  if(trailingStopPrice > entryPrice && (sl < trailingStopPrice || sl == 0))
                    {
                     stopLossPrice = NormalizeDouble(trailingStopPrice, _Digits);
                     //PositionModify(ticket, stopLossPrice, 0);
                     trade.PositionModify(ticket, stopLossPrice, 0);
                     Print("Stop loss moved to secure profit for Buy: ", stopLossPrice);
                    }
                 }
               else
                  if(positionType == POSITION_TYPE_SELL)
                    {
                     trailingStopPrice = currentPrice + trailingPips * _Point;
                     if(trailingStopPrice < entryPrice && (sl > trailingStopPrice || sl == 0))
                       {
                        stopLossPrice = NormalizeDouble(trailingStopPrice, _Digits);
                        //PositionModify(ticket, stopLossPrice, 0);
                        trade.PositionModify(ticket, stopLossPrice, 0);
                        Print("Stop loss moved to secure profit for Sell: ", stopLossPrice);
                       }
                    }
              }
           }
        }
     }
  }

// BREAKEVEN - pending now - move stop loss
void BreakEven()
  {
   int err_ = GetLastError();
   if(err_ > 0)
     {
      Print("Something went wrong! ", err_, GetLastError());
      return;
     }

// double Ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
// double Bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);
// double Spread = MathAbs(Ask-Bid);//
//double points = _Point;
//double digits = _Digits;
//string symb = _Symbol;

   for(int i = data_.positionsTotal_ - 1; i >= 0; i--)
     {
      if(m_position.SelectByIndex(i))
        {
         double price_current = m_position.PriceCurrent() ; // unit is usd
         double price_open = m_position.PriceOpen(); // unit is usd
         double sl = m_position.StopLoss(); // unit is usd
         double profit = m_position.Profit(); // usd
         ENUM_POSITION_TYPE ptype = m_position.PositionType();

         //         string breakeven_log =
         //            StringFormat("profit: %f currentprice: %f sl: %f current.to.sl.points: %f current.to.open.points: %f",
         //               profit,
         //               price_current,
         //               sl,
         //               (price_current-sl)/_Point,
         //               (price_current-price_open)/_Point
         //
         //            );
         //         Print(break even_log);
         //         Print( StringFormat( "Ask: %f Bid: %f", data_.ask_, data_.bid_ ));

         if(m_position.Symbol() == Symbol())
           {
            if(m_position.PositionType() == POSITION_TYPE_SELL)
              {
               double diff_current_to_sl = MathAbs(price_current - sl) ;
               double diff_current_to_open = MathAbs(price_current - price_open);
               if((diff_current_to_sl/_Point) > breakeven_value)
                 {
                  double new_sl = price_current + (diff_current_to_sl/2); // do move stop loss *****
                  trade.PositionModify(m_position.Ticket(), NormalizeDouble(new_sl, _Digits), 0);
                  Print(StringFormat("Breakeven - %i - %s ", trade.ResultRetcode(), trade.ResultRetcodeDescription()));
                 }
              }
            else
               if(m_position.PositionType() == POSITION_TYPE_BUY)
                 {
                  double diff_current_to_sl = price_current - sl ;
                  double diff_current_to_open = price_current - price_open;
                  if((diff_current_to_sl/_Point) > breakeven_value || (diff_current_to_open/_Point) > breakeven_value)
                    {
                     double new_sl = price_current - (diff_current_to_sl/2); // do move stop loss ***
                     trade.PositionModify(m_position.Ticket(), NormalizeDouble(new_sl, _Digits), 0);
                     Print(StringFormat("Breakeven - %i - %s ", trade.ResultRetcode(), trade.ResultRetcodeDescription()));
                    }
                 }
           }
        }
     }
  }

// Prevent dup cal
bool IsNewBar(const bool print_log=true)
  {
   static datetime bartime=0; // store open time of the current bar
//--- get open time of the zero bar
   datetime currbar_time=iTime(_Symbol,_Period,0);
//--- if open time changes, a new bar has arrived
   if(bartime!=currbar_time)
     {
      bartime=currbar_time;
      lastbar_timeopen=bartime;
      // LOR_=bartime;
      //--- display data on open time of a new bar in the log
      if(print_log && !(MQLInfoInteger(MQL_OPTIMIZATION)||MQLInfoInteger(MQL_TESTER)))
        {
         //--- display a message with a new bar open time
         PrintFormat("%s: new bar on %s %s opened at %s",__FUNCTION__,_Symbol,
                     StringSubstr(EnumToString(_Period),7),
                     TimeToString(TimeCurrent(),TIME_SECONDS));
         //--- get data on the last tick
         MqlTick last_tick;
         if(!SymbolInfoTick(Symbol(),last_tick))
            Print("SymbolInfoTick() failed, error = ",GetLastError());
         //--- display the last tick time up to milliseconds
         PrintFormat("Last tick was at %s.%03d",
                     TimeToString(last_tick.time,TIME_SECONDS),last_tick.time_msc%1000);
        }
      //--- we have a new bar
      return (true);
     }
//--- no new bar
   return (false);
  }












//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CreateButton()
  {
   ObjectCreate(0, "Button1", OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, "Button1", OBJPROP_XSIZE, 100);
   ObjectSetInteger(0, "Button1", OBJPROP_YSIZE, 50);
   ObjectSetString(0, "Button1", OBJPROP_TEXT, "Close positions");
   ObjectSetInteger(0,"Button1",OBJPROP_COLOR,clrRed);
   ObjectSetInteger(0, "Button1", OBJPROP_CORNER,CORNER_RIGHT_LOWER);
   ObjectSetInteger(0, "Button1", OBJPROP_XDISTANCE, 120);
   ObjectSetInteger(0, "Button1", OBJPROP_YDISTANCE, 65);

//ObjectCreate(0, "ButtonBreakeven", OBJ_BUTTON, 0, 0, 0);
//ObjectSetInteger(0, "ButtonBreakeven", OBJPROP_XSIZE, 130);
//ObjectSetInteger(0, "ButtonBreakeven", OBJPROP_YSIZE, 80);
//ObjectSetString(0, "ButtonBreakeven", OBJPROP_TEXT, "Breakeven");
//ObjectSetInteger(0,"ButtonBreakeven",OBJPROP_COLOR,clrBlue);
//ObjectSetInteger(0, "ButtonBreakeven", OBJPROP_CORNER,CORNER_LEFT_LOWER);
//ObjectSetInteger(0, "ButtonBreakeven", OBJPROP_XDISTANCE, 160);
//ObjectSetInteger(0, "ButtonBreakeven", OBJPROP_YDISTANCE, 100);

   ObjectCreate(0, "ButtonBuy", OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, "ButtonBuy", OBJPROP_XSIZE, 100);
   ObjectSetInteger(0, "ButtonBuy", OBJPROP_YSIZE, 50);
   ObjectSetString(0, "ButtonBuy", OBJPROP_TEXT, "BUY");
   ObjectSetInteger(0,"ButtonBuy",OBJPROP_COLOR,clrBlue);
   ObjectSetInteger(0, "ButtonBuy", OBJPROP_CORNER,CORNER_RIGHT_LOWER);
   ObjectSetInteger(0, "ButtonBuy", OBJPROP_XDISTANCE, 230);
   ObjectSetInteger(0, "ButtonBuy", OBJPROP_YDISTANCE, 65);

   ObjectCreate(0, "ButtonReset", OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, "ButtonReset", OBJPROP_XSIZE, 100);
   ObjectSetInteger(0, "ButtonReset", OBJPROP_YSIZE, 50);
   ObjectSetString(0, "ButtonReset", OBJPROP_TEXT, "ButtonReset");
   ObjectSetInteger(0,"ButtonReset",OBJPROP_COLOR,clrBlue);
   ObjectSetInteger(0, "ButtonReset", OBJPROP_CORNER,CORNER_RIGHT_LOWER);
   ObjectSetInteger(0, "ButtonReset", OBJPROP_XDISTANCE, 340);
   ObjectSetInteger(0, "ButtonReset", OBJPROP_YDISTANCE, 65);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,const long& lparam,const double& dparam,const string& sparam)
  {
   if(id==CHARTEVENT_OBJECT_CLICK && StringFind(sparam, "Button1") >=0)
     {
      Print("Button1 clicked");
      Sleep(20);
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);

      PositionCloseAll();
     }
   else
      if(id==CHARTEVENT_OBJECT_CLICK && StringFind(sparam, "ButtonBreakeven") >=0)
        {
         Sleep(20);
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         Print("ButtonBreakeven clicked!");

         // BreakEven();
        }
      else
         if(id==CHARTEVENT_OBJECT_CLICK && StringFind(sparam, "ButtonBuy") >=0)
           {
            Sleep(20);
            ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
            Print("ButtonBuy clicked!");

            BuyTest();
           }
         else
            if(id==CHARTEVENT_OBJECT_CLICK && StringFind(sparam, "ButtonReset") >=0)
              {
               Sleep(20);
               ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
               Print("ButtonReset clicked!");

               RestError();
              }
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void BuyTest()
  {
   double ask_ = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid_ = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double spread_ = MathAbs(ask_ - bid_);

   int trailingPips = GetTrailingStopPips();
   double stopLossPrice = ask_ - spread_ - (trailingPips * _Point);

   stopLossPrice = NormalizeDouble(stopLossPrice, _Digits);
   if(!trade.Buy(0.01, _Symbol, ask_, stopLossPrice, 0, "test buy"))
     {
      Print("Something went wrong! ", trade.ResultRetcode(), trade.ResultRetcodeDescription());
     }
   Print("Buy: ", stopLossPrice);
   int err_ = GetLastError();
   if(err_ > 0)
     {
      Print("Error code: ", err_);
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void RestError()
  {
   ResetLastError();
  }

//+------------------------------------------------------------------+
