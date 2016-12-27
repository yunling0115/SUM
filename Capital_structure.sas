*****************************************************************************
Program Description  : CAPITAL STRUCTURE 1990-PRESENT
Created by  : Yun Ling, USC
Date Created  : 2011/6/20
********************************************************************************************************************
* Variables to Collect:
(1) debt(liabilities:LT) 
(2) equity(shareholder's equity:SEQ)
	debt+equity:LSE 
(3) dividend payout ratio(dividend-common/income before extraordinary iterms-adjusted for common stock equivalents) 
	dividends common/ordinary:DVC
	income before extraordinary iterms-adjusted for common stock equivalents:IBADJ
(4) firm profitability(earnings before interst/book value of assets)
	earnings before interst:EBITDA 
(5) firm size(Market Value of Equity: price per shares times shares outstanding)
	price per share (price closed:PRCC_C) (annually, monthly data at PDE under compustat folder)
	Number of Shares Outstanding:CSHO
(6) percentage of fixed assets(fixed assets=tangible assets) 
	intengibles:INTAN
	total asset:AT
(7) market/book ratio
	bookvalue of equity (equity:SEQ) 
(8) cash flow: P33 (we measure profitability as cashflow from operations normalized by the book value of assets)
	thus, cashflow = EBITDA
(*) year dummies 
(*) interaction terms
*******************************************************************************************************************;

%let wrds = wrds.wharton.upenn.edu 4016;
options comamid=TCP remote=WRDS;
signon username=_prompt_;

libname loclib2 'C:\Users\yling\Study\Summar 2011\summer project\Q2';
rsubmit;
libname ylingQ2 '/home/usc/yling/Q2';
* libname compna '/wrds/comp/sasdata/na/';

options source nocenter ls=72 ps=max;
option obs=max;

%let begyear=1990;
%let endyear=2010;
*  Selected data items (GVKEY, DATADATE, FYEAR and FYR are automatically included);
%let cvars= LT AT SEQ LSE INTAN DVC IBADJ CSHO EBITDA PRCC_C;

***************************************************************************************
1. Screening for GVKEY, DATADATE, FYEAR and select variables: US firms from 1990-2010
***************************************************************************************;
proc sql;
*First determine the qualifying GVKEYs;
  create table temp1 as 
  	select * from compna.company
  	where fic = "USA";  
*Initial Extract, for qualifying GVKEYs, DATADATE range and format/type screen;
  create table temp2 (keep=GVKEY DATADATE FYEAR FYR &cvars) as
    select * 
    from temp1 as t, compna.funda as f
    where t.gvkey = f.gvkey
    and year(f.datadate) between &begyear and &endyear+1
    and f.indfmt='INDL' and f.datafmt='STD' and f.popsrc='D' and f.consol='C';
	* to extract the most reliable, standardized data records and to remove potential duplicate records;
*Final screen for FYEAR range;
  create table ylingQ2.data as
    select * from  temp2 as f
    where f.fyear between &begyear and &endyear
    order by f.gvkey, f.datadate;
quit;

*******************************************************************************************
2. Calculate variables needed
*******************************************************************************************;
* clean data;
data ylingQ2.datatemp;
	set ylingQ2.data;
	if LT & AT & SEQ & LSE & INTAN & DVC & IBADJ & CSHO & EBITDA & PRCC_C;
run;
* check;
proc means data=ylingQ2.datatemp min max;
run;
* generate variables;
data ylingQ2.finaldata(drop=datadate fyr at csho dvc ebitda gvkey ibadj intan lse lt prcc_c seq);
	* LHS: DR, DPR
	* RHS: FP, ME, PFA, MBR, CF, YD
	* INT: YD_FP, YD_ME, YD_PFA, YD_MBR, YD_CF;
	set ylingQ2.datatemp; 
	label DR="debt ratio" DPR="dividend payout ratio" BE="book value of equity" FP="firm profitability" CF="cash flow"
		  ME="market value of equity/firm size" PFA="percentage of fixed assets" MBR="market to book ratio" YD="year dummies";
	DR = LT/LSE; * DR: debt ratio;
	DPR = DVC/IBADJ; * DPR: dividend payout ratio;
	BE = SEQ; * BE: book value of equtiy;
	FP = EBITDA/AT; * FP: firm profitability;
	CF = EBITDA; * CF: cash flow;
	ME = PRCC_C*CSHO; * ME: firm size;
	PFA = 1-INTAN/AT; * percentage of fixed assets;
	MBR = ME/BE; * MBR: market to book ratio;
	* YD: year dummies;
	YD1 = (1995<=FYEAR<=2000); 
	YD2 = (FYEAR<1995)+(FYEAR>2000);
	
	YD1_BE = BE*YD1;
	YD1_FP = FP*YD1;
	YD1_ME = ME*YD1;
	YD1_PFA = PFA*YD1;
	YD1_MBR = MBR*YD1;
	YD1_CF = CF*YD1;
	YD2_BE = BE*YD2;	
	YD2_FP = FP*YD2;
	YD2_ME = ME*YD2;
	YD2_PFA = PFA*YD2;
	YD2_MBR = MBR*YD2;
	YD2_CF = CF*YD2;
	
	INPT = 1;
	INPT1 = YD1;
	INPT2 = YD2;
	/*
	%macro combine;
		%let var=BE FP ME PFA MBR CF;
		%do i='BE' 'FP' 'ME' 'PFA' 'MBR' 'CF';
			YD1_&i = &i*YD1;
			YD2_&i = &i*YD2;
		%end;
	%mend;
	*/
	/*
	foreach i in ("be" "fp" "me" "pfa" "mbr" "cf")
		yd1_`i'=`i'*yd1
	end
	*/
		
run;
* check;
rsubmit;
proc means data=ylingQ2.finaldata;
run;
proc contents data=ylingQ2.finaldata;
run;

*******************************************************************************************
2. Run the Regression and generate report
*******************************************************************************************;
* regressions;
rsubmit;
%let y1=DR;
%let y2=DPR;
%let Xa=INPT FP CF ME PFA MBR;
%let Xb=INPT BE FP CF ME PFA MBR YD1;
%let Xc=INPT1 INPT2 YD1_FP YD1_CF YD1_ME YD1_PFA YD1_MBR YD2_FP YD2_CF YD2_ME YD2_PFA YD2_MBR;
proc reg data=ylingQ2.finaldata ;
	* y1;
	model &y1=&Xa/noint;
	model &y1=&Xb/noint;
	model &y1=&Xc/noint;
	test INPT1=INPT2;
	test YD1_FP=YD2_FP;
	test YD1_ME=YD2_ME;
	test YD1_PFA=YD2_PFA;
	test YD1_MBR=YD2_MBR;
	test YD1_CF=YD2_CF;
	* y2;
	model &y2=&Xa/noint;
	model &y2=&Xb/noint;
	model &y2=&Xc/noint;
	test INPT1=INPT2;
	test YD1_FP=YD2_FP;
	test YD1_ME=YD2_ME;
	test YD1_PFA=YD2_PFA;
	test YD1_MBR=YD2_MBR;
	test YD1_CF=YD2_CF;
	output out=ylingQ2.reg;
run;
quit;
*************************************************************************************;

endrsubmit;
signoff;

rsubmit;
proc print data =ylingQ2.reg;
run;
	
