*****************************************************************************
Program Description  : Merge Data from SDC
Created by  : Yun Ling, USC
Date Created  : 2011/6/22
****************************************************************************;
* SDC: select (1) both pct_cash and pct_stk is available, or 
			  (2) pct_cash = 100, or
			  (3) pct_stk = 100
* merge to elsit
****************************************************************************;

libname ylingQ1 'C:\Users\yling\Study\Summar 2011\summer project\Q1';
data ylingQ1.both;
	infile "C:\Users\yling\Study\Summar 2011\summer project\Q1\ylingQ1both.txt";
	input ACU $ 1-6
		  @11 ADATE mmddyy11. 
		  @26 EDATE mmddyy11.
		  @39 VDEAL COMMA13.4
		  @54 PCT_CASH
		  @64 PCT_STK
		  TCU $ 73-78;
	format ADATE date9.
		   EDATE date9.
		   VDEAL 13.4;
run;
* check;
proc print data=ylingQ1.both (obs=30);
run;
data ylingQ1.cash;
	infile "C:\Users\yling\Study\Summar 2011\summer project\Q1\ylingQ1cash.txt";
	input ACU $ 1-6
		  @11 ADATE mmddyy11. 
		  @26 EDATE mmddyy11.
		  @39 VDEAL COMMA13.4
		  @54 PCT_CASH
		  TCU $ 73-78;
	format ADATE date9.
		   EDATE date9.
		   VDEAL 13.4;
	PCT_STK=0;
run;
* check;
proc print data=ylingQ1.cash (obs=30);
run;
data ylingQ1.stk;
	infile "C:\Users\yling\Study\Summar 2011\summer project\Q1\ylingQ1stk.txt";
	input ACU $ 1-6
		  @11 ADATE mmddyy11. 
		  @26 EDATE mmddyy11.
		  @39 VDEAL COMMA13.4
		  @63 PCT_STK
		  TCU $ 73-78;
	format ADATE date9.
		   EDATE date9.
		   VDEAL 13.4;
	PCT_CASH=0;
run;
* check;
proc print data=ylingQ1.stk (obs=30);
run;
data ylingQ1.elist;
	set ylingQ1.both ylingQ1.cash ylingQ1.stk;
	by ADATE;
run;
* check;
proc print data=ylingQ1.elist (obs=100);
run;
proc contents data=ylingQ1.elist;
run;
