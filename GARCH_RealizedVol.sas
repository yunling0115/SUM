*****************************************************************************
Program Description  : GARCH and Realized Volatility
Created by  : Yun Ling, USC
Date Created  : 2011/6/24
*****************************************************************************
Measures fo stock market volatility:
	(1) ex ante measure constructed 'GARCH' model 
		estimated using daily returns
	(2) ex post measure called 'realized volatiltiy' that is contructed
		each day from all 5-min returns over the trading day
****************************************************************************;
%let wrds = wrds.wharton.upenn.edu 4016;
options comamid=TCP remote=WRDS;
signon username=_prompt_;

options linesize=72 nocenter nodate;

libname ylingQ4 '/home/usc/yling/Q4' server=wrds;

rsubmit;
libname ylingQ4 '/home/usc/yling/Q4';



******************************************************************************************
1. ex ante volatiltiy using crsp.dsf:
------------------------------------------------------------------------------------------
(1) SPY 01Jan2005-31Dec2008
(2) GARCH(1,1) model that is in (2), (3) of AB paper, report est and stderr
(3) Note: AB estimated the model by QML (quasi-MLE), use the same approach for estimation
******************************************************************************************;

* (1) Extract data;

proc sql;
	create table ylingQ4.Exante_temp1
	as select distinct a.permno, b.ticker, a.date, a.ret
	from crsp.dsf as a, crsp.dse (where=(ticker='SPY')) as b
	where a.permno = b.permno and 2005<=year(a.date)<=2008
	order by date;
run;
quit;
proc print data=ylingQ4.Exante_temp1 (obs=50);
run;

* (2) use full info MLE to estimate;

/* use proc model */
proc model data = ylingQ4.Exante_temp1 outparms=ylingQ4.Exante1;
	parms phi 0.3 alpha 0.3 beta 0.3;
	/* mean model */
	ret = 0;
	/* variance model */
	h.ret = phi + alpha*xlag(resid.ret**2,mse.ret) + beta*xlag(h.ret,mse.ret);
	/* fit the model */
	fit ret / method = marquardt fiml; 
run;
* check;
proc print data=ylingQ4.Exante1;
run;

/* use proc autoreg */
rsubmit;
proc autoreg data = ylingQ4.Exante_temp1 outest=ylingQ4.Exante2 (rename=(_AH_0=phi _AH_1=alpha _GH_1=beta) keep=_AH_0 _AH_1 _GH_1);
     model ret= / garch = ( q=1,p=1 ) dist = t;
	 output out = ylingQ4.Exante_temp2 ht=garchv2; /* ht is the fitted value */
run;
* check;
proc print data=ylingQ4.Exante_temp2 (obs=50);
run;
* check (exactly same parameters);
proc print data=ylingQ4.Exante2;
run;
* plot;

endrsubmit;
goptions reset=all border;
symbol1 i=join l=1 c=red;
proc gplot data=ylingQ4.Exante_temp2;
	plot garchv2*date / haxis=0 to 300 by 30
                 hminor=3
				 vminor=1;
run;
quit;



******************************************************************************************
2. ex post volatiltiy using taq.cq:
------------------------------------------------------------------------------------------
(1) SPY 01Jan2005-31Dec2008
(2) compute a realized volatility for each day using a 5-min returns
(3) prices are taken to be the average of the bid and ask quotes
(4) Note: the observations in the data will not be exactly 5-min apart -> *
******************************************************************************************;
* note: qc data from 8:00 to 20:00 (included), open from 9:30 to 16:00 (excluded);


* (1) not using macro to run a small sample to extract 5-min return;
/*--------------------------------------------------------------------------------------------*/

rsubmit;
proc sql;
	create table temp
	as select a.date, a.time, log((sum(a.ofr*a.ofrsiz)/sum(a.ofrsiz)+sum(a.bid*a.bidsiz)/sum(a.bidsiz))/2) as logprice
	from taq.cq_20050103 (	where=(symbol="SPY" 
			and time between "9:30:00"t and "16:00:00"t 
			and mod(time-"9:30:00"t,"00:05:00"t)=0
			and bid>0 and ofr>0 and ofr ne 201000.99 /* 201000.99 missing bid or ofr */
			and bidsiz>0 and ofrsiz>0
			and mode not in (4,7,9,11,13,14,15,19,20,27,28))
			) as a
	group by date, time;
run;
data my_ret2;
	set temp;
	ret2 = (logprice-lag(logprice))**2/((time-lag(time))/"06:30:00"t); * (s^2*dt) adjusted to daily;
run;
proc append base=hoho data=my_ret2 (where=(not missing(ret2)));
run;
proc print data=hoho;
run;
/*--------------------------------------------------------------------------------------------*/


* (2) using macro to run a small sample to extract 5-min return (2 days, 1 month, 1 year);
/*--------------------------------------------------------------------------------------------*/
rsubmit;
* delete dataset;
proc datasets library=ylingQ4;
   delete Y05toY08;
run;
* define the macro;
%macro taq_volatility(type=cq,begyyyymmdd=,endyyyymmdd=,outfile=) / des="calculated daily realized volatiltiy";
	data &outfile;
		input date time logprice ret2;
		format date yymmddn8. time time.;
		date=.; time=.; logprice=.; ret2=.;
	run;
	%let type=%lowcase(&type);
	%let begdate = %sysfunc(inputn(&begyyyymmdd,yymmdd8.));
	%let enddate = %sysfunc(inputn(&endyyyymmdd,yymmdd8.));
	/* For each date in the DATE range */
	%do d=&begdate %to &enddate; 
		/* If the corresponding dataset exists */
		%let yyyymmdd=%sysfunc(putn(&d,yymmddn8.));
		%if %sysfunc(exist(taq.&type._&yyyymmdd)) %then
			%do;
		
				/* Insert codes */
				/* Note (July 29): should use the DOW loop rather than proc sql, and the spreadpct<0.1 */
				
				proc sql;
					create table temp
					as select a.date, a.time, log((sum(a.ofr*a.ofrsiz)/sum(a.ofrsiz)+sum(a.bid*a.bidsiz)/sum(a.bidsiz))/2) as logprice
					from taq.&type._&yyyymmdd (where=(symbol="SPY" 
						and time between "9:30:00"t and "16:00:00"t 
						and mod(time-"9:30:00"t,"00:05:00"t)=0
						and bid>0 and bid<ofr<201000.99  
						and (ofr-bid)/(ofr+bid)<0.1
						and bidsiz>0 and ofrsiz>0
						and mode not in (0,4,7,9,11,13,14,15,19,20,27,28))
						) as a
					group by date, time;
				run;
				
				/* Revised on July 29 */
				/*
				data temp (keep=date time logprice);
					sum_ofr=0; sum_ofrsiz=0; sum_bid=0; sum_bidsiz=0;
					do until(last.time);
						set taq.&type._&yyyymmdd;
						by date time;
						where symbol="SPY" and 
						 	time between "9:30:00"t and "16:00:00"t
							and mod(time-"9:30:00"t,"00:05:00"t)=0
						 	and bid>0 and bid<ofr and
						 	(ofr-bid)/(ofr+bid)<0.1
						 	and bidsiz>0 and ofrsiz>0
						 	and mode not in (4,7,9,11,13,14,15,19,20,27,28);
						sum_ofr=sum(sum_ofr,ofr*ofrsiz);
						sum_ofrsiz=sum(sum_ofrsiz,ofrsiz);
						sum_bid=sum(sum_bid,bid*bidsiz);
						sum_bidsiz=sum(sum_bidsiz,bidsiz);
					end;
					if sum_ofr>0 and sum_bid>0 then do;
						logprice=log((sum_ofr/sum_ofrsiz+sum_bid/sum_bidsiz)/2);
						output;
					end;
				run;
				*/	

				data my_ret2;
					set temp;
					ret2 = (logprice-lag(logprice))**2/((time-lag(time))/"06:30:00"t); * (s^2*dt) adjusted to daily;
				run;
				
				/*
				proc print data=my_ret2;
				run;
				
				proc contents data=my_ret2;
				run;
				*/
				
				proc append base=&outfile data=my_ret2 (where=(not missing(logprice)));
				run;
				/* End */

			%end;
	%end;
%mend taq_volatility;
* use the macro;
options mprint;
%taq_volatility(type=cq,begyyyymmdd=20050101,endyyyymmdd=20081231,outfile=ylingQ4.Y05toY08);
* check;
/*
rsubmit;
proc print data=ylingQ4.Y05toY08;
run;
*/
* about 30 sec, data file 73kb, for 20050101-20050104, 2 trading days;
* about 3 min for Jan2005: 11:36:00 - 11:38:44;
* about 30 min for 2005: 11:51:00 - 12:22:00, file size: 663kb;
* about 2h10min for 20050101-20081231, file size: 2mb;
/*--------------------------------------------------------------------------------------------*/

* cleaning invalid ret2;
rsubmit;
data ylingQ4.Y05toY08;
	set ylingQ4.Y05toY08;
	ret2_2 = (logprice-lag(logprice))**2/((time-lag1(time))/"06:30:00"t); 
	if ret2_2>0;
run;

/*
%put %sysfunc(log(500));
rsubmit;
proc print data=ylingQ4.Y05toY08 (obs=80);
run;

proc means data=ylingQ4.Y05toY08 min max;
run;
*/
* (3) calculate dailiy realized volatility using adjusted 5-min return sqaure;

proc sort data=ylingQ4.Y05toY08;
	by date;
run;
proc means data=ylingQ4.Y05toY08 noprint;
	var ret2_2;
	by date;
	output out=ylingQ4.Expost_temp1(drop=_type_ _freq_) sum=rv;
	label rv=realized volatility;
run;
/*
rsubmit;
proc means data=ylingQ4.Y05toY08 max;
	var logprice;
run;
proc means data=ylingQ4.Expost_temp1 max;
	var rv;
run;
proc print data=ylingQ4.Expost_temp1;
run;
*/

endrsubmit;
goptions reset=all border;
symbol1 l=20 i=join c=green;
proc gplot data=ylingQ4.Expost_temp1;
	plot rv*date / 
                 hminor=3
				 vminor=1;
run;
quit;
goptions reset=all border;
symbol1 l=20 i=join c=green;

proc gplot data=ylingQ4.Y05toY08;
	plot logprice*date / 
                 hminor=3
				 vminor=1;
run;
quit;
proc means data=ylingQ4.Expost_temp1 min max;
	var rv;
run;
rsubmit;
proc means data=ylingQ4.Y05toY08 min max;
	var logprice ret2_2;
run;


******************************************************************************************
3. Combine two parts:
------------------------------------------------------------------------------------------
(1) produce a forecast R-square similar to tthose reported in AB's table 5
(2) produce a plot similar to figure 2 of AB
******************************************************************************************;


rsubmit;
proc datasets library=ylingQ4;
   delete Volatilities;
run;
* (1);
proc sql;
	create table ylingQ4.Volatilities
	as select distinct year(a.date) as year, month(a.date) as month, a.date, a.garchv2 as exante_v2, b.rv as expost_v2 
	from ylingQ4.Exante_temp2 as a, ylingQ4.Expost_temp1 as b
	where a.date=b.date;
run;
rsubmit;
proc reg data=ylingQ4.Volatilities edf outest=ylingQ4.Results(keep=year _RSQ_ Intercept exante_v2);
	model expost_v2 = exante_v2;
run;
rsubmit;
proc print data=ylingQ4.Results;
run;
endrsubmit;
proc export data=ylingQ4.Results outfile="C:\Users\yling\Study\Summar 2011\summer project\Q4\New\Result.csv" DBMS=csv replace;
run;


* (2);
goptions reset=all border;
symbol1 i=join l=1 c=red;
symbol2 l=20 i=join c=green;
title1 "Exante and Expost Daily Volatilities";

proc gplot data=ylingQ4.Volatilities;
	plot exante_v2*date expost_v2*date / overlay legend=legend1
									haxis=0 to 300 by 30
									haxis=axis1 hminor=4
									vaxis=axis2 vminor=1;
run;
quit;
