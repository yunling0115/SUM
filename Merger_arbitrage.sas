*****************************************************************************
Program Description  : TAKEOVERS 1990-PRESENT
Created by  : Yun Ling, USC
Date Created  : 2011/6/22
****************************************************************************;

%let wrds = wrds.wharton.upenn.edu 4016;
options comamid=TCP remote=WRDS;
signon username=_prompt_;

options linesize=72 nocenter nodate;

***************************************************************************************
1. Calculate the number of takeovers and total market value of takeovers: 1990-present
***************************************************************************************;

* do it locally and save dataset to the server;
libname loclib1 'C:\Users\yling\Study\Summar 2011\summer project\Q1';
libname ylingQ1 '/home/usc/yling/Q1' server=wrds;
libname ylingQ1 '/home/usc/yling/Q1';

* var: ACU ADATE EDATE VDEAL PCT_CASH PCT_STK TCU;
data ylingQ1.elist(drop=EDATE);
	set loclib1.elist;
	YEAR = year(ADATE);
run;
proc contents data=ylingQ1.elist;
run;
proc sql;
	create table ylingQ1.esum
	as select distinct YEAR, sum(VDEAL) as VDEAL, n(ADATE) as N
	from ylingQ1.elist
	group by YEAR;
quit;
* check;
proc contents data=ylingQ1.esum;
run;
proc print data=ylingQ1.esum;
run;
* Two graphs;
goptions reset=all border;
symbol1 interpol=join
        value=dot
        color=_style_;
title1 "Total Market Value of Takeovers by Year (in $Million)";
proc gplot data=ylingQ1.esum;
	plot VDEAL*YEAR / haxis=1990 to 2010 by 1
					  hminor=3
					  vminor=1;
run;
quit;

title1 "Total Number of Takeovers by Year";
proc gplot data=ylingQ1.esum;
	plot N*YEAR / haxis=1990 to 2010 by 1
				  hminor=3
				  vminor=1;
run;
quit;

***************************************************************************************
2. Calculate the fraction of takeovers paid with stock, cash and stock+cash
***************************************************************************************;

* do it locally;
data ylingQ1.elist;
	set ylingQ1.elist;
	if PCT_CASH=100 then PAID = "Cash";
	else if PCT_STK=100 then PAID = "Stk";
	else PAID = "Both";
run;
proc freq data=ylingQ1.elist;
	table PAID;
	table YEAR*PAID;
run;
* chart;
proc chart data=ylingQ1.elist;
	vbar PAID / type=percent;
	title "PCT of CASH, STK, CASH+STK";
run;
proc sql;
	create table ylingQ1.paid
	as select distinct YEAR, sum(PAID="Cash") as CASH, sum(PAID="Stk") as STK, sum(PAID="Both") as BOTH
	from ylingQ1.elist
	group by YEAR;
quit;
data ylingQ1.paid;
	set ylingQ1.paid;
	TOTAL = sum(CASH,STK,BOTH);
	FCASH = CASH*100/TOTAL;
	FSTK = STK*100/TOTAL;
	FBOTH = BOTH*100/TOTAL;
run;
* check;
proc print data=ylingQ1.paid;
run;

* Overlay graphs;
goptions reset=all border;
symbol1 color=red
        interpol=join
        value=dot
        height=2;
symbol2 color=blue
        interpol=join
		value=dot
        height=2;
symbol3 color=green
        interpol=join
		value=dot
        height=2;
axis1 order=(1990 to 2010 by 5) label=none major=(height=2) minor=(height=1) width=3;
axis2 order=(0 to 100 by 10) label=none major=(height=2) minor=(height=1) width=3;
legend1 label=none shape=symbol(4,2) position=(top center inside) mode=share;
title1 "PCT of CASH, STK, CASH+STK by YEAR";
proc gplot data=ylingQ1.paid;
	plot FCASH*YEAR FSTK*YEAR FBOTH*YEAR / overlay legend=legend1
										vref=1990 to 2010 by 5 lvref=1
										haxis=axis1 hminor=4
										vaxis=axis2 vminor=1;
run;
quit;

***************************************************************************************
3. Merge elist, crsp.dsf, and crsp.dsi (estimation period: -30 days)
***************************************************************************************;

* do it on the remote server (much faster);

rsubmit;
libname ylingQ1 '/home/usc/yling/Q1';

%let J1=5;
%let J2=1;
%let Jest=-30; * estimation period is 30 days before (can also use monthly return;

* adjust format of ADATE of elist;
data ylingQ1.elist;
	set ylingQ1.elist;
	format ADATE yymmddn8.;
run;
* merge elist and crsp.dsf by matching 6-digit CUSIP and extract return information [-5,+5] around ANADATE
(do the same for a.tcu=substr(b.cusip,1,6);

* 1. first trial on crsp.msf dataset;
proc sql;
	create table trial
	as select distinct b.permno as permno, a.adate as adate, b.date as date, b.ret as ret
	from ylingQ1.elist as a left join crsp.msf as b
	on a.acu=substr(b.cusip,1,6) and &Jest<=b.date-a.adate<=&J1  
	order by permno,adate,date;
run;
quit;
data trial;
	set trial;
	if permno;
run;
* check;
proc print data=trial (obs=50);
run;

* 2. merge using crsp.dsf dataset;
rsubmit;
proc sql;
	create table ylingQ1.merged_acu
	as select distinct b.permno as permno, a.*, b.ret, b.date
	from ylingQ1.elist as a, crsp.dsf as b
	where a.acu=substr(b.cusip,1,6) and &Jest-10<=b.date-a.adate<=&J1+2 
	/* &Jest-10 and &J1+2: to gaurantee that there are &Jest and &J1 trading days */  
	having not missing(b.permno)
	order by permno,adate,date; /*group by; having; order by*/
run;
quit;
proc sql;
	create table ylingQ1.merged_tcu
	as select distinct b.permno as permno, a.*, b.ret, b.date
	from ylingQ1.elist as a, crsp.dsf as b
	where a.tcu=substr(b.cusip,1,6) and &Jest-10<=b.date-a.adate<=&J1+2 
	/* &Jest-10 and &J1+2: to gaurantee that there are &Jest and &J1 trading days */  
	having not missing(b.permno)
	order by permno,adate,date; /*group by; having; order by*/
run;
quit;
* check;
proc print data=ylingQ1.merged_acu (obs=10);
run; 
proc print data=ylingQ1.merged_tcu (obs=10);
run; 

* 3. merge using crsp.dsi dataset;
proc sql;
	create table merged2_acu
	as select distinct a.*, b.vwretd as vwretd /*using value weighted return as market return*/
	from ylingQ1.merged_acu as a left join crsp.dsi as b
	on a.date=b.date
	order by permno, adate, date;
run;
quit;
proc sql;
	create table merged2_tcu
	as select distinct a.*, b.vwretd as vwretd /*using value weighted return as market return*/
	from ylingQ1.merged_tcu as a left join crsp.dsi as b
	on a.date=b.date
	order by permno, adate, date;
run;
quit;

***************************************************************************************
4. compute event date counter and split date into estimation and event periods
***************************************************************************************;
proc sql;
	create table finaldata_acu
	as select a.*, sum(date<adate) as befdays /* count days before announced date */
	from merged2_acu as a
	group by permno, adate;
run;
quit;
proc sql;
	create table finaldata_tcu
	as select a.*, sum(date<adate) as befdays /* count days before announced date */
	from merged2_tcu as a
	group by permno, adate;
run;
quit;

proc sort data=finaldata_acu; * still need to sort since first and last are used;
	by permno adate date;
run;
proc sort data=finaldata_tcu; * still need to sort since first and last are used;
	by permno adate date;
run;


rsubmit;
libname ylingQ1 '/home/usc/yling/Q1';
%let J1=5; /* then changed to 1 */
%let Jest=-30; * estimation period is 30 days before (can also use monthly return;

data estper_acu evntper_acu;
	set finaldata_acu;
	by permno adate;
	if first.adate then relday=-befdays-1;
	relday+1;
	if &Jest<=relday<-&J1 then output estper_acu; * 25 trading days for estimation period;
	if -&J1<=relday<=&J1 then output evntper_acu;
run;
data estper_tcu evntper_tcu;
	set finaldata_tcu;
	by permno adate;
	if first.adate then relday=-befdays-1;
	relday+1;
	if &Jest<=relday<-&J1 then output estper_tcu; * 25 trading days for estimation period;
	if -&J1<=relday<=&J1 then output evntper_tcu;
run;


***************************************************************************************
5. compute abnormal returns (CAPM-adjusted and market-adjusted)
***************************************************************************************;

* 1. add CAPM-adjusted abnormal returns;
* compute CAPM alpha beta in estimation period;
data estper_acu; /* calculate alpha and beta only for estimation period>=2 */
	set estper_acu;
	if befdays>=2;
run;
data estper_tcu; /* calculate alpha and beta only for estimation period>=2 */
	set estper_tcu;
	if befdays>=2;
run;
proc reg data=estper_acu outest=reg_acu (rename=(intercept=alpha vwretd=beta)) noprint;
	by permno adate;
	model ret = vwretd;
quit;
proc reg data=estper_tcu outest=reg_tcu (rename=(intercept=alpha vwretd=beta)) noprint;
	by permno adate;
	model ret = vwretd;
quit;

* compute abnormal returns in event period;
proc sql;
	create table data_CAPM_acu
	as select distinct a.*, (a.ret-b.alpha-b.beta*a.vwretd) as ar
	from evntper_acu as a left join reg_acu as b
	on a.permno=b.permno and a.adate=b.adate;
run;
proc sql;
	create table data_CAPM_tcu
	as select distinct a.*, (a.ret-b.alpha-b.beta*a.vwretd) as ar
	from evntper_tcu as a left join reg_tcu as b
	on a.permno=b.permno and a.adate=b.adate;
run;

* 2. add market-adjusted abnormal returns;
data data_market_acu;
	set evntper_acu;
	retx = ret-vwretd;
run;
data data_market_tcu;
	set evntper_tcu;
	retx = ret-vwretd;
run;

* 3. extract subsets such that only abnormal returns are available;
data data_CAPM_acu;
	set data_CAPM_acu;
	if not missing(ar);
run;
data data_CAPM_tcu;
	set data_CAPM_tcu;
	if not missing(ar);
run;
data data_market_acu;
	set data_market_acu;
	if not missing(retx);
run;
data data_market_tcu;
	set data_market_tcu;
	if not missing(retx);
run;

***************************************************************************************
6. compute abnormal returns (CAPM-adjusted and market-adjusted) by relday (counter)
***************************************************************************************;

* CAPM;
/* acquired */
proc sort data=data_CAPM_acu;
	by relday;
run;
proc means data=data_CAPM_acu noprint n mean t prt clm alpha=0.05;
	var ar;
	by relday;
	output out=ylingQ1.data_CAPM1_acu(drop=_type_ _freq_) n= mean= t= prt= lclm= uclm= / autoname;
run;
/* target */
proc sort data=data_CAPM_tcu;
	by relday;
run;
proc means data=data_CAPM_tcu noprint n mean t prt clm alpha=0.05;
	var ar;
	by relday;
	output out=ylingQ1.data_CAPM1_tcu(drop=_type_ _freq_) n= mean= t= prt= lclm= uclm= / autoname;
run;


* market;
/* acquired */
proc sort data=data_market_acu;
	by relday;
run;
proc means data=data_market_acu noprint n mean t prt clm alpha=0.05;
	var retx;
	by relday;
	output out=ylingQ1.data_market1_acu(drop=_type_ _freq_) n= mean= t= prt= lclm= uclm= / autoname;
run;
/* target */
proc sort data=data_market_tcu;
	by relday;
run;
proc means data=data_market_tcu noprint n mean t prt clm alpha=0.05;
	var retx;
	by relday;
	output out=ylingQ1.data_market1_tcu(drop=_type_ _freq_) n= mean= t= prt= lclm= uclm= / autoname;
run;

* gplot;
* Overlay graphs (run locally);
endrsubmit;
goptions reset=all border;
symbol1 color=red
        interpol=join
        value=dot
        height=1;
symbol2 color=blue
        interpol=join
		value=dot
        height=1;
symbol3 color=blue
        interpol=join
		value=dot
        height=1;
axis1 order=(-5 to 5 by 1) label=none major=(height=2) minor=(height=1) width=3;
axis2 order=(-0.005 to 0.015 by 0.001) label=none major=(height=2) minor=(height=1) width=3;
legend1 label=none shape=symbol(4,2) position=(top center inside) mode=share;
/* Acquired */
/*
rsubmit;
data ylingQ1.data_CAPM1_acu5;
	set ylingQ1.data_CAPM1_acu;
proc print data=ylingQ1.data_CAPM1_acu5;
run;
*/
title1 "CAPM: mean and 95% CI (Acquired)";
proc gplot data=ylingQ1.data_CAPM1_acu;
	plot ar_mean*relday ar_uclm*relday ar_lclm*relday / overlay legend=legend1
										vref=-5 to 5 by 1
										haxis=axis1 hminor=4
										vaxis=axis2 vminor=1;
run;
quit;
title1 "market: mean and 95% CI (Acquired)";
proc gplot data=ylingQ1.data_market1_acu;
	plot retx_mean*relday retx_uclm*relday retx_lclm*relday / overlay legend=legend1
										vref=-5 to 5 by 1
										haxis=axis1 hminor=4
										vaxis=axis2 vminor=1;
run;
quit;
/* Target */
title1 "CAPM: mean and 95% CI (Target)";
proc gplot data=ylingQ1.data_CAPM1_tcu;
	plot ar_mean*relday ar_uclm*relday ar_lclm*relday / overlay legend=legend1
										vref=-5 to 5 by 1
										haxis=axis1 hminor=4
										vaxis=axis2 vminor=1;
run;
quit;
title1 "market: mean and 95% CI (Target)";
proc gplot data=ylingQ1.data_market1_tcu;
	plot retx_mean*relday retx_uclm*relday retx_lclm*relday / overlay legend=legend1
										vref=-5 to 5 by 1
										haxis=axis1 hminor=4
										vaxis=axis2 vminor=1;
run;
quit;


* [-&J1,+&J1] ([-5,+5]) window;
* can resplit the estimation period and the event period, here use the same estimation period and event period;

***************************************************************************************
7. calculate the correlation between CAPM-adjusted and market-adjusted returns
***************************************************************************************;

rsubmit;
proc sql;
	create table data_correlation_acu
	as select distinct a.*, b.retx 
	from data_CAPM_acu as a, data_market_acu as b
	where a.permno=b.permno and a.date=b.date
	having not missing(b.retx);
run;
quit;
proc sql;
	create table data_correlation_tcu
	as select distinct a.*, b.retx 
	from data_CAPM_tcu as a, data_market_tcu as b
	where a.permno=b.permno and a.date=b.date
	having not missing(b.retx);
run;
quit;
proc sort data=data_correlation_acu;
	by relday;
run;
proc sort data=data_correlation_tcu;
	by relday;
run;
proc corr data=data_correlation_acu outp=ylingQ1.data_correlation1_acu noprint;
	var ar retx;
	by relday;	 
run;
proc corr data=data_correlation_tcu outp=ylingQ1.data_correlation1_tcu noprint;
	var ar retx;
	by relday;	 
run;
data ylingQ1.data_correlation1_acu(keep=relday corr);
	set ylingQ1.data_correlation1_acu;
	if _type_='CORR' and _name_='ar';
	corr = retx;
run;
data ylingQ1.data_correlation1_tcu(keep=relday corr);
	set ylingQ1.data_correlation1_tcu;
	if _type_='CORR' and _name_='ar';
	corr = retx;
run;
* output correlation;
title1 "Correlation of CAPM-adjusted and market-adjusted returns (Acquired)";
proc print data=ylingQ1.data_correlation1_acu;
run;
title1 "Correlation of CAPM-adjusted and market-adjusted returns (Target)";
proc print data=ylingQ1.data_correlation1_tcu;
run;
* gplot;
/* Acquired */
endrsubmit;
title1 "Correlation of CAPM-adjusted and market-adjusted returns (Acquired)";
axis2 order=(0.8 to 1 by 0.1) label=none major=(height=2) minor=(height=1) width=3;
symbol1 color=red
        interpol=join
        value=dot
        height=2;
proc gplot data=ylingQ1.data_correlation1_acu;
	plot corr*relday / vref=-5 to 5 by 1
					   haxis=axis1 vminor=0
					   vaxis=axis2 vminor=9;
run;
quit;
/* Target */
title1 "Correlation of CAPM-adjusted and market-adjusted returns (Target)";
axis2 order=(0.8 to 1 by 0.1) label=none major=(height=2) minor=(height=1) width=3;
symbol1 color=red
        interpol=join
        value=dot
        height=2;
proc gplot data=ylingQ1.data_correlation1_tcu;
	plot corr*relday / vref=-5 to 5 by 1
					   haxis=axis1 vminor=0
					   vaxis=axis2 vminor=9;
run;
quit;


***************************************************************************************
8. test whether returns are significantly differnet for stock and cash acquisitions
***************************************************************************************;

rsubmit;
* 1. do the test;
proc sort data=data_correlation_acu;
	by paid;
run;
proc sort data=data_correlation_tcu;
	by paid;
run;
proc means data=data_correlation_acu (where=(paid='Cash' or paid='Stk')) noprint;
	var ret;
	by paid;
	output out=ylingQ1.data_diff_acu;
run;
proc means data=data_correlation_tcu (where=(paid='Cash' or paid='Stk')) noprint;
	var ret;
	by paid;
	output out=ylingQ1.data_diff_tcu;
run;
rsubmit;
title "Test of Stk and Cash Takeover Returns (Acquired)";
proc ttest data=ylingQ1.data_diff_acu;
	class paid;
	var ret;
	ods output Ttests=ylingQ1.data_diff1_acu;
run;
title "Test of Stk and Cash Takeover Returns (Target)";
proc ttest data=ylingQ1.data_diff_tcu;
	class paid;
	var ret;
	ods output Ttests=ylingQ1.data_diff1_tcu;
run;

* 2. export output of the test;
title "Test of Stk and Cash Takeover Returns (Acquired)";
proc print data=ylingQ1.data_diff1_acu; 
run;
title "Test of Stk and Cash Takeover Returns (Target)";
proc print data=ylingQ1.data_diff1_tcu; 
run;
