*****************************************************************************
Program Description  : MOMENTUM PORTFOLIOS OF JEGADEESH AND TITMAN (JF, 1993) 
                       USING MONTHLY RETURNS FROM CRSP
Modified by  : Yun Ling, USC
Date Modified  : 2011/6/16
*****************************************************************************;

%let wrds = wrds.wharton.upenn.edu 4016;
options comamid=TCP remote=WRDS;
signon username=_prompt_;

libname loclib3 'C:\Users\yling\Study\Summar 2011\summer project\Q3';
rsubmit;
libname yling '/home/usc/yling';

options source nocenter ls=72 ps=max;
options obs=max;

%let J=6; 
%let K=6; 
%let begyear1=1965; 
%let endyear1=1989; 
%let begyear2=1965;
%let endyear2=2003;
%let begyear3=1990;
%let endyear3=2003;
%let begyear=1965;
%let endyear=2003;

*****************************************************************************
1. Select Common Stocks form NYSE/AMEX (use exchange and share info)
*****************************************************************************;
* Merge crsp.mseall (exchcd,shrcd) to crsp.msf (keep date permno ret);
proc sql;
    create table msex1
    as select a.permno, a.date, a.ret, b.exchcd, b.shrcd
    from crsp.msf(keep=date permno ret) as a
    left join crsp.mseall(keep=date permno exchcd shrcd) as b
    on a.permno=b.permno and a.date= b.date;
quit;

* Select all common stocks from NYSE/AMEX using exchcd and shrcd;
proc sort data=msex1; by permno date; run;

data msex2;
    set msex1;
    by permno date;
    retain lexchcd lshrcd;
    if first.permno then 
      do;
        lexchcd = exchcd ;
        lshrcd  = shrcd;
      end;
    else 
      do;
       if missing(exchcd) then exchcd = lexchcd;
           else lexchcd = exchcd;
       if missing(shrcd)  then shrcd = lshrcd;
           else lshrcd = shrcd;
      end;
	* Carry-on to fill missing exchange and share Codes;
	if exchcd in (1,2); * NYSE/AMEX;
	* exchcd: one digit, Page 37: NYSE/AMEX/NASDAQ/NYSE ARCA;
    if shrcd in (10,11) and not missing(ret); * Common Stocks;
	* shrcd: two digits, Page 78;
	* Additional years of lagged return for portfolio formation and holding;
	if (&begyear-2)<=year(date)<=&endyear;
    drop lexchcd lshrcd shrcd exchcd;
run;

*********************************************************************************
2. CREATE MOMENTUM MEASURES Based on PAST 6 (J) Month Compounded Returns;
*********************************************************************************;

proc sql; * IMPORTANT1;
    create table umd
    as select distinct a.permno, a.date, exp(sum(log(1+b.ret)))-1 as cum_return
    from msex2 (keep=permno date) as a, msex2 as b
    where a.permno=b.permno and 0<=intck('month', b.date, a.date)<&J
	/* only keep the obs that 0<=a.date-b.date<J, for any t=a.date, one group is defined as 
	(permno,t) from a with (permno, t-(J-1)(possibly)), (permno, t-(J-2)),...(permno,t) from b
	<=J obs in one group */
  	group by a.permno, a.date
	/* note that the group is defined by a's variable permno and date: to create cummulated return for each obs */
  	having count(b.ret)=&J;
	/* only apply to the groups where there are exactly J rather than less than J obs, count is cout nonmissing #
	note that for the first first J-1 group defined by permno a.date, there are only 1,2,...J-1 obs in one group 
	so group is from J's date: without having start from 1st date*/
quit; 

proc sort data=umd; by date; run;
/* group by date to rank cum_return into 10 groups and generate group-class var momr*/
proc rank data=umd out=umd1 group=10;
    by date;
    var cum_return;
    ranks momr;
run;

data umd2;
    set umd1(drop=cum_return);
    momr=momr+1;
	label momr = "Momentum Portfolio";
run;

*************************************************************************************
4. Assign Ranks to the Next 6 (K) Months After Portfolio Formation
*************************************************************************************;
/* Portfolio return are average monthly returns rebalanced monthly: one form_date and holding_date 
(from form_date+1 to +K) except for the last K-1 form_date
Note that we're using end-of-month ret to specify this month, so formation is from -(J-1) to 0
and holding is from 1 to K*/

proc sql; * IMPORTANT2;
    create table msfx2
    as select distinct a.momr, a.date as form_date, a.permno, b.date, b.ret
    from umd2 as a, msex2 as b
    where a.permno=b.permno 
     and 0<intck('month',a.date,b.date)<=&K;
quit;

*************************************************************************************
5. Calculate Equally-Weighted Average Monthly Returns
*************************************************************************************;
proc sort data=msfx2; by date momr form_date; run;

* Portfolio monthly return series;
proc means data = msfx2 noprint;
    by date momr form_date;
    var ret;
    output out = msfx3 mean=ret;
run;

* Portfolio average monthly return;
proc sort data=msfx3; by date momr;
    where year(date) between &begyear and &endyear;
run;

proc means data = msfx3 noprint;
    by date momr;
    var ret;
    output out = ewretdat mean= ewret;
run;

* Split files and save to my remote disk;
data yling.ewretdat_1965_1989;
	set ewretdat;
	where year(date) between &begyear1 and &endyear1;
run;
data yling.ewretdat_1965_2003;
	set ewretdat;
	where year(date) between &begyear2 and &endyear2;
run;
data yling.ewretdat_1990_2003;
	set ewretdat;
	where year(date) between &begyear3 and &endyear3;
run;


* Output momentum groups stat;

proc sort data=yling.ewretdat_1965_1989; by momr ; run;
Title "&J/&K portfolio: &begyear1-&endyear1";
proc means data=yling.ewretdat_1965_1989 mean t probt; 
    class momr;
    var ewret;
run;

proc sort data=yling.ewretdat_1965_2003; by momr ; run;
Title "&J/&K portfolio: &begyear2-&endyear2";
proc means data=yling.ewretdat_1965_2003 mean t probt; 
    class momr;
    var ewret;
run;
proc sort data=yling.ewretdat_1990_2003; by momr ; run;
Title "&J/&K portfolio: &begyear3-&endyear3";
proc means data=yling.ewretdat_1990_2003 mean t probt; 
    class momr;
    var ewret;
run;
*************************************************************************************
6. Calculate Buy-Sell Portfolio Returns
*************************************************************************************;
proc sort data=ewretdat; by date momr; run;
proc transpose data=ewretdat out=ewretdat2 
  (rename = (_1=SELL _2=PORT2 _3=PORT3 _4=PORT4 _5=PORT5
             _6=PORT6 _7=PORT7 _8=PORT8 _9=PORT9 _10=BUY));
   by date;
   id momr;
   var ewret;
run;
data ewretdat3;
	set ewretdat2;
	BUY_SELL=BUY-SELL;
run;

* Split files and save to my remote disk;
data yling.ewretdat3_1965_1989;
	set ewretdat3;
	where year(date) between &begyear1 and &endyear1;
run;
data yling.ewretdat3_1965_2003;
	set ewretdat3;
	where year(date) between &begyear2 and &endyear2;
run;
data yling.ewretdat3_1990_2003;
	set ewretdat3;
	where year(date) between &begyear3 and &endyear3;
run;

Title "BUY-SELL &J/&K portfolio: &begyear1-&endyear1";
proc means data=yling.ewretdat3_1965_1989 n mean t probt;
    var Sell Buy Buy_Sell;
run;
Title "BUY-SELL &J/&K portfolio: &begyear2-&endyear2";
proc means data=yling.ewretdat3_1965_2003 n mean t probt;
    var Sell Buy Buy_Sell;
run;
Title "BUY-SELL &J/&K portfolio: &begyear3-&endyear3";
proc means data=yling.ewretdat3_1990_2003 n mean t probt;
    var Sell Buy Buy_Sell;
run;

*************************************************************************************;
endrsubmit;
signoff;

/*
Title "BUY-SELL &J/&K portfolio: &begyear1-&endyear1";
proc means data=loclib3.ewretdat3_1965_1989 n mean t probt;
    var Sell Buy Buy_Sell;
	ods output Summary=loclib3.summary_1965_1989;
run;
Title "BUY-SELL &J/&K portfolio: &begyear2-&endyear2";
proc means data=loclib3.ewretdat3_1965_2003 n mean t probt;
    var Sell Buy Buy_Sell;
	ods output Summary=loclib3.summary_1965_2003;
run;
Title "BUY-SELL &J/&K portfolio: &begyear3-&endyear3";
proc means data=loclib3.ewretdat3_1990_2003 n mean t probt;
    var Sell Buy Buy_Sell;
	ods output Summary=loclib3.summary_1990_2003;
run;
proc export data=loclib3.summary_1965_1989 outfile="C:\Users\yling\Study\Summer 2011\summer project\Q3\summary_1965_1989.csv" dbms=csv replace; 
run;
proc export data=loclib3.summary_1965_2003 outfile="C:\Users\yling\Study\Summer 2011\summer project\Q3\summary_1965_2003.csv" dbms=csv replace; 
run;
proc export data=loclib3.summary_1990_2003 outfile="C:\Users\yling\Study\Summer 2011\summer project\Q3\summary_1990_2003.csv" dbms=csv replace; 
run;
*/
