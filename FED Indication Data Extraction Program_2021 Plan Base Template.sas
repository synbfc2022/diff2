options obs = Max;
options compress = yes;

libname lib 'E:\Data\Planning\FICC';
libname lib2 'E:\Data\FIIC\Original_data\dec_2020';

/*output location*/
*libname out 'X:\Actuarial\DC_Actuarial\Portfolio Modeling Toolkit\Indication Models\Overall Rate Indications\Master Templates\FED Indication Data Extraction Program';
*%let outputfile='X:\Actuarial\DC_Actuarial\Portfolio Modeling Toolkit\Indication Models\Overall Rate Indications\Master Templates\FED Indication Data Extraction Program\Fed Test Indication data_2020Q4.csv';
%let outputfile='X:\Actuarial\DC_Actuarial\CL\Rate Adequacy\Overall Indications\2020Q4\Liability\Sas Output\Fed Indication Data National Umb.csv';


/*************************************************/
/*Common sas include location for Fed assumptions*/
%let MktDim_2016='X:\Actuarial\DC_Actuarial\CL\Rate Adequacy\Overall Indications\2020Q4\Sas Includes\Fed\Market_Dimension_201606.xlsx';

filename sasinclu 'X:\Actuarial\DC_Actuarial\CL\Rate Adequacy\Overall Indications\2020Q4\Sas Includes\Fed';
%include sasinclu(PolGrp_mapping) ;
%include sasinclu(PolGrp2_mapping) ;
%include sasinclu(IndustryCodeToBusClass_mapping) ;
%include sasinclu(PlanningSegment_Sector_mapping) ;

/*OLF */
%include sasinclu(OnLevelFactors_Live) ;
%include sasinclu(OnLevelFactors_Wave) ;

/*CDF's*/
/**********/
%include sasinclu(ClaimLevelCDF_2020Q4) ;

/*ibnyr claim cnt split*/
%include sasinclu(ibnyr_split_factors_2020q4) ;

/************************************************/
/*sas include location for NBI CL assumptions*/
filename sasincl2 'X:\Actuarial\DC_Actuarial\CL\Rate Adequacy\Overall Indications\2020Q4\Sas Includes\CL';

/*Loss Trends*/
/*************/
%include sasincl2(Loss_Trends_2020);
%let ExtractionQuarter = "Q4";
%let LastDataYear = 2020;

%let TrendtoDate = '1JAN2023'd;

/*Premium Trends*/
/*************/
%include sasincl2(PremiumTrendLiab_2020);

/*Large Loss Threshold - CGL-200K UMB-1M*/
/**********************/
%let LLThreshold = 1000000; 

/*Select the Extraction Segment you would like to extract data for*/
*%let MyExtractionSegment = "MM-Liab";
*%let MyExtractionSegment = "MM-Umb";
*%let MyExtractionSegment = "MM-Prop";
*%let MyExtractionSegment = "MM-Auto";
*%let MyExtractionSegment = "National-Liab";
%let MyExtractionSegment = "National-Umb";
*%let MyExtractionSegment = "National-Prop";
*%let MyExtractionSegment = "National-Auto";
*%let MyExtractionSegment = "SmallBus-Liab";
*%let MyExtractionSegment = "SmallBus-Umb";
*%let MyExtractionSegment = "SmallBus-Prop";
*%let MyExtractionSegment = "SmallBus-Auto";

/******************************************************************************************/
data plandata_live;
	set lib.ficc_combine_2020q4;
	where platform='LIVE';
run;

/*if account does not exist in latest MktDim mapping file, use older version of the file*/
data Mkt_matched Mkt_notmatched;
	set plandata_live;
	if Marketdimension='NA' then output Mkt_notmatched;
	else output Mkt_matched;
run;

proc import out=Mktdim_old datafile=&MktDim_2016 dbms=xlsx replace; 
run;

proc sort data=Mktdim_old nodupkey;
	by account_no Desc;
run;

proc sort data=Mkt_notmatched;
	by account_no;
run;

data Mkt_notmatched_new;
	merge Mkt_notmatched (in=a drop=MarketDimension)
		  MktDim_old;
	by account_no;
	if a;

	length MarketDimension $15.;
	if Desc='Mid Market' then MarketDimension='MIDMARKET';
	else if Desc='Small Business' then MarketDimension='SMALL BUSINESS';
	else if Desc='Personal' then MarketDimension='PERSONAL';
	else MarketDimension='MIDMARKET';
run;

data plandata_live2;
	set Mkt_matched Mkt_notmatched_new;
run;

/*loss data does not have Grading, get it from account database*/
data premdata lossdata;
	set plandata_live2;
	if claimnumber='' then output premdata;
	else output lossdata;
run;

proc sort data=lib2.account out=account_info (keep=account_no grading) nodupkey;
	by account_no;
run;

proc sort data=lossdata (drop=grading);
	by account_no;
run;

data lossdata;
	merge lossdata (in=a)
		  account_info;
	by account_no;
	if a;

	/*in planning data, PolGrp & LOB are blank for losses, need to define these fields*/
	length RiskE $10.;
	if risk='' then RiskE=Policy_type;
	else RiskE=risk;

	length polgrp_key $20.;
	polgrp_key=cats(Policy_Type)||cats(RiskE);

	length PolGrp $8. LOB $10.;
	if LOB='' then do;
		PolGrp = put(polgrp_key,$PolGrp.);
		LOB = put(polgrp_key,$LOB.);
	end;
run;

/*for premium data, get asl from raw table ST_FEDREF_PRODUCT*/
data asl_mapping (keep=policy_type product_type asl);
	set staging2.st_fedref_product;

	asl = input(substr(Groups,1,3),3.);
run;

proc sort data=asl_mapping nodupkey;
	by policy_type product_type asl;
run;

proc sort data=premdata (drop=asl);
	by policy_type product_type;
run;

data premdata;
	merge premdata (in=a)
		  asl_mapping;
	by policy_type product_type;
	if a;
run;

data plandata_live3;
	set premdata lossdata;

	length Profit_Centre $15.;
	if substr(Grading,1,2) = '50' and MarketDimension not in ('PERSONAL' 'SMALL BUSINESS') then Profit_Centre='National';
	else if MarketDimension in ('MIDMARKET' 'NA') then do;
		if province in ('ON' 'PQ' 'NB' 'NL' 'NS' 'PE') then Profit_Centre='Trad-East';
		else Profit_Centre='Trad-West';
	end;
	else Profit_Centre=MarketDimension;

	if MarketDimension = 'NA' then MarketDimension = 'MIDMARKET';
	
	length PolGrp2 $8. ;
	PolGrp2 = put(polgrp,$PolGrp_new.);

	IncurredLoss=rpt_loss;
	UltimateLoss=sum(rpt_loss,ibnr);

	/*define Minor Line*/
	length MinorLine $15.;

	if LOB='Liability' then do;
		if PolGrp = 'UMB' then MinorLine='Umb';
		else MinorLine='CGL';
	end;
	else MinorLine=LOB;
run;

data plandata_wave;
	set lib.ficc_combine_2020q4;
	where platform='WAVE';

	length Profit_Centre $15.;
	if MarketDimension in ('MIDMARKET') then do;
		if province in ('ON' 'PQ' 'NB' 'NL' 'NS' 'PE') then Profit_Centre='Trad-East';
		else Profit_Centre='Trad-West';
	end;
	else Profit_Centre=MarketDimension;

	
	Business_Class = put(Industry_Code,$BusClass.);

	/*define Minor Line*/
	length MinorLine $15.;

	if LOB='Liability' then do;
		if PolGrp = 'UMB' then MinorLine='Umb';
		else MinorLine='CGL';
	end;
	else MinorLine=LOB;

	/*remap asl 50-58 as asl 15, because we don't have trend factors for asl 50-58*/
	if asl ge 50 and asl le 58 then 
		asl=15;

	IncurredLoss=sum(paid,paid_alae,reserve,reserve_alae);
	UltimateLoss=sum(paid,paid_alae,reserve,reserve_alae,ibnr);
run;

data plandata_final;
	set plandata_live3 plandata_wave;
	where MarketDimension ne 'PERSONAL';

	if Profit_Centre = 'National' then MarketDimension='National';

	/*define Region to be used for planning indication*/
	length Region_final $10.;
	if province = 'ON' then Region_final="Ontario";
	else if province = 'PQ' then Region_final="Quebec";
	else if province = 'BC' then Region_final="BC";
	else if province = 'AB' then Region_final="Alberta";
	else if province in ('NB' 'NL' 'NS' 'PE') then Region_final="Atlantic";
	else Region_final="Prairies";

	/*get Planning segment and sector based on Business class; 
	for Live do not use the Sector directly from the planning data as it's based on old definition*/
	length PlanningSegment $45. Sector_new $40.;
	PlanningSegment = put(Business_Class,$PlanningSegment.);

	if platform='Wave' then
		Sector_new = Sector;
	else
		Sector_new = put(Business_Class,$Sector_mapped.);

	BusClassGrouped=put(Business_Class,$BusGroupCode.);


	/*Define Extraction Segment*/
	length ExtractionSegment $15.;

	if Profit_Centre = 'National' then do;
		If LOB = "Liability" and MinorLine ne 'Umb' then ExtractionSegment = "National-Liab";
		else if LOB = "Liability" and MinorLine = 'Umb' then ExtractionSegment = "National-Umb";
		else If LOB = "Property" then ExtractionSegment = "National-Prop";
		else If LOB = "Auto" then ExtractionSegment = "National-Auto";
	end;
	else do;
		if LOB = "Liability" and MinorLine ne 'Umb' and MarketDimension in ("MIDMARKET") then ExtractionSegment = "MM-Liab";
		else if LOB = "Liability" and MinorLine = 'Umb' and MarketDimension in ("MIDMARKET") then ExtractionSegment = "MM-Umb";
		else If LOB = "Property" and MarketDimension in ("MIDMARKET") then ExtractionSegment = "MM-Prop";
		else If LOB = "Auto" and MarketDimension in ("MIDMARKET") then ExtractionSegment = "MM-Auto";
		else If LOB = "Liability" and MinorLine ne 'Umb' and MarketDimension in ("SMALL BUSINESS") then ExtractionSegment = "SmallBus-Liab";
		else If LOB = "Liability" and MinorLine = 'Umb' and MarketDimension in ("SMALL BUSINESS") then ExtractionSegment = "SmallBus-Umb";
		else If LOB = "Property" and MarketDimension in ("SMALL BUSINESS") then ExtractionSegment = "SmallBus-Prop";
		else If LOB = "Auto" and MarketDimension in ("SMALL BUSINESS") then ExtractionSegment = "SmallBus-Auto";
	end;

	/*Filter for Extraction Segment*/
	if ExtractionSegment = &MyExtractionSegment;
run;

/* Trends the losses and IBNR */
data TrendedData;
	set plandata_final;

	/*Trending the losses and IBNR*/
	format TrendKey $55. TrendLine $8. TrendReg $8. TrendSector $45.;

	if LOB = "Auto" then TrendLine = "NGIC"||Cats(LOB);
	else TrendLine = substr(LOB,1,4);

	if Region_final in ('BC' 'Alberta' 'Prairies') then TrendReg = 'Western';
	else TrendReg = Region_final;

	TrendSector = Sector;

	if Trendline in ('NGICAuto') then do;
		if platform='WAVE' then do;
			if autocov in('AB','BI','PD', 'AP','COLL','COMP','DCPD') then TrendSector = Autocov;
			else if autocov ='O44' then TrendSector = 'SEF44';
			else if autocov = 'PHBI' then trendsector = 'BI';
			else if autocov = 'PHPD' then trendsector = 'PD';
			else if autocov = 'SPP' then trendsector = 'SP';
			else if autocov = 'TAX' then trendsector = 'AB';
			else if autocov = 'TORT' then trendsector = 'PD';
			else if autocov = 'TPL' then trendsector = 'BI';
			else if autocov = 'UMC' then trendsector = 'UA';
			else trendsector = 'BI';
		end;
	end;
	
	Trendkey = Cats(TrendLine)||Cats(TrendReg)||Cats(TrendSector);

	pasttrend = input(Trendkey,PastTrend.) ;
	futuretrend = input(trendkey,FutureTrend.) ;
	cutoff = input(trendkey,TrendCutDate.) ;

	if year = &LastDataYear then do;
			if &ExtractionQuarter = 'Q1' then lossdate = MDY(2,15,year);
			else if &ExtractionQuarter = 'Q2' then lossdate = MDY(4,1,year);
			else if &ExtractionQuarter = 'Q3' then lossdate = MDY(5,15,year);
			else if &ExtractionQuarter = 'Q4' then lossdate = MDY(7,1,year);
	end;
	else lossdate = MDY(7,1,year);

	format lossdate yymmdd6.;

	date2 = max(lossdate,cutoff);

	Trendperiod1 = max(intck('Day',lossdate,cutoff)/365.25,0);
	Trendperiod2 = max(intck('Day',date2,&TrendtoDate)/365.25,0);

	TrendFactor = ((1+pasttrend)**TrendPeriod1)*((1+Futuretrend)**TrendPeriod2);

	Trended_Incurred_Loss = IncurredLoss * TrendFactor;
	Trended_IBNR = IBNR * TrendFactor;
	Trended_IBNR_small = IBNR_small * TrendFactor;
	Trended_IBNR_large = IBNR_large * TrendFactor;
	Trended_Ultimate_losses = UltimateLoss * TrendFactor;

run;

/*Test Trending Factors*/
proc summary data = TrendedData nway;
	class PolGrp Asl Province year /missing;
	var UltimateLoss Trended_Ultimate_losses pasttrend futuretrend trendFactor;
output out = TrendingTest (Drop = _TYPE_ _FREQ_) sum(UltimateLoss)= UltimateLoss sum(Trended_Ultimate_losses) = Trended_Ultimate_losses mean(pasttrend) = AvgPastTrend Max(pasttrend) = MaxPastTrend Min(pasttrend) = MinPastTrend mean(Futuretrend) = AvgFutureTrend Max(Futuretrend) = MaxFutureTrend Min(Futuretrend) = MinFutureTrend;
run;

/*Premium Trends, Onlevel Factors and Other Adjustments*/
Data FinalAdjustedData;
	set TrendedData;

	/*on-level factors*/
	format OLFKey $90.;
	format PremKey $90.;
	format OLF_LOB $10.;
	format OLF_Region $5.;

	if MinorLine = 'Umb' then OLF_LOB='UMB';
	else OLF_LOB=LOB;

	if region_final in ('Ontario' 'Quebec' 'Atlantic') then OLF_Region='East';
	else OLF_Region='West';
	
	if platform='LIVE' then do;
		OLFKey = cats(platform)||cats(Profit_Centre)||cats(Sector_new)||cats(BusClassGrouped)||cats(Region_final)||cats(OLF_LOB)||cats(year);
		OnlevelFactor = input(OLFKey, OLF_Live.);
	end;
	else if platform='WAVE' then do;
		OLFKey = cats(platform)||cats(LOB)||cats(OLF_Region)||cats(Sector_new)||cats(year);
		OnlevelFactor = input(OLFKey, OLFWave.);
	end;


	/*Premium trend*/
	PremKey = cats(year);
	PremiumTrendFactor = input(PremKey, PremTrend.);


	Onlevel_EP = EP * OnlevelFactor;

	Trended_Onlevel_EP = Onlevel_EP * PremiumTrendFactor;

	ReformFactor = 1;

	Reform_Adj_Trended_Ult_Losses = Trended_Ultimate_Losses * ReformFactor;
	Reform_Adj_Trended_IBNYR = Trended_IBNR * ReformFactor;
	Reform_Adj_Trended_IBNYR_small = Trended_IBNR_small * ReformFactor;
	Reform_Adj_Trended_IBNYR_large = Trended_IBNR_large * ReformFactor;
run;

/*Summarizes Data to a Line level*/
proc summary data = finalAdjustedData nway;
	class platform Account_no Policy effymd expymd term_no ClaimNumber Region_final Profit_Centre province Sector_new year LOB Minorline MarketDimension PolGrp BusClassGrouped PlanningSegment asl cat /missing;
	var WP EP Onlevel_EP Trended_Onlevel_EP paid PAID_ALAE reserve RESERVE_ALAE IncurredLoss ibnr_small ibnr_large ibnr UltimateLoss Trended_Incurred_Loss Trended_IBNR_small Trended_IBNR_large Trended_IBNR Trended_Ultimate_losses Reform_Adj_Trended_Ult_Losses Reform_Adj_Trended_IBNYR Reform_Adj_Trended_IBNYR_small Reform_Adj_Trended_IBNYR_large;
output out = FinalAdjSummarized (Drop = _TYPE_ _FREQ_) sum=;
run;

/*Final Data and identifies the loss type (Small, Large, Cat)*/
Data finalOut;
	set  FinalAdjSummarized;

/*Split Large/Small/Cat here*/
	format LossType $6.;
		
	PremGrossUpFactor = 1;
	LossGrossUpFactor = 1;

	/*Currency Fix Here*/
		ExRatePrem = 1;
		ExRateLoss = 1;


	Trended_Onlevel_GrsUp_EP = Trended_Onlevel_EP * PremGrossUpFactor * ExRatePrem;
	Ref_Adj_Trended_GrsUp_Ult_Losses = Reform_Adj_Trended_Ult_Losses * LossGrossUpFactor * ExRateLoss;
	Ref_Adj_Trended_GrsUp_IBNYR = Reform_Adj_Trended_IBNYR * PremGrossUpFactor * ExRateLoss;
	Ref_Adj_TrendedGrsUp_IBNYR_small = Reform_Adj_Trended_IBNYR_small * PremGrossUpFactor * ExRateLoss;
	Ref_Adj_TrendedGrsUp_IBNYR_large = Reform_Adj_Trended_IBNYR_large * PremGrossUpFactor * ExRateLoss;


	if Ref_Adj_Trended_GrsUp_Ult_Losses GE &LLThreshold then LossType = "LARGE";
	else if Ref_Adj_Trended_GrsUp_Ult_Losses LT &LLThreshold then LossType = "SMALL";

	if platform = 'LIVE' and CAT not in ('000' '00') and CAT ne . then LossType = "CAT";
	else if platform = 'WAVE' and CAT not in ('000' '00' '') then LossType = "CAT";

	if ClaimNumber = "" then LossType = "IBNYR";

	If ClaimNumber NE "" and IncurredLoss GT 0 then claimcount = 1 ;
	

	/*CDF Factors and Ultimate Claim Count*/

	format CDFRegion $8. CDFLine $8. Type $10.;

	if province in ('NB' 'NS' 'NL' 'PE' 'ON') then CDFRegion="EastxPQ";
	else if province = 'PQ' then CDFRegion=province;
	else CDFRegion="West";

	if LOB='Liability' then CDFLine='CGL';
	else CDFLine=LOB;

	if LOB='Auto' then do;
		if PolGrp in ('AGL' 'PPAUTO' 'COMAUTO') then Type=PolGrp;
		else Type='OtherAuto';
	end;

	if LOB='Auto' then
		CDF = input(Cats(CDFLine)||Cats(CDFRegion)||Cats(Type)||Cats(LossType)||CATS(year),CDF.) ;
	else
		CDF = input(Cats(CDFLine)||Cats(CDFRegion)||Cats(LossType)||CATS(year),CDF.) ;

	ultimateClaimCount = ClaimCount * cdf;

	/*split ibnyr count into small and large*/
	if LOB='Auto' then
		ibnyr_claimcnt_factor = input(Cats(LOB)||Cats(Type)||Cats(CDFRegion),ibnyrlargecount.) ;
	else
		ibnyr_claimcnt_factor = input(Cats(LOB)||Cats(CDFRegion),ibnyrlargecount.) ;

	large_ibnyr_ClaimCnt = (ultimateClaimCount - ClaimCount) * ibnyr_claimcnt_factor;
	small_ibnyr_ClaimCnt = (ultimateClaimCount - ClaimCount) * (1-ibnyr_claimcnt_factor);
	

	if Sum(reserve,RESERVE_ALAE) = 0 then openClaimCount = 0;
	else openClaimCount = UltimateClaimCount;

	/*create dummy variables so that the csv output can directly feed into Harmonized model template*/
	WP_grs=0;
	EP_grs=0;
	Written_Exposure=0;
	Earned_Exposure=0;
	PAID_grs=0;
	TotalIBNER=0;
	TotalIBNYR=ibnr;
	Trended_IBNER=0;
	Trended_IBNYR=Trended_IBNR;
	SB_FLAG='';
	exclude='';
run;

proc summary data = finalOut nway;
	where year GT &LastDataYear-10;
	class LOB MinorLine Region_final Sector_new MarketDimension PlanningSegment SB_FLAG YEAR LossType exclude/missing;
	var WP EP WP_grs EP_grs Onlevel_EP Trended_Onlevel_EP Trended_Onlevel_GrsUp_EP Written_Exposure Earned_Exposure
		paid PAID_grs PAID_ALAE reserve RESERVE_ALAE IncurredLoss TotalIBNER TotalIBNYR ibnr UltimateLoss 
		Trended_Incurred_Loss Trended_IBNER Trended_IBNYR Trended_IBNR Trended_Ultimate_losses Reform_Adj_Trended_Ult_Losses 
		Ref_Adj_Trended_GrsUp_Ult_Losses Reform_Adj_Trended_IBNYR Ref_Adj_Trended_GrsUp_IBNYR OpenClaimCount ClaimCount 
		UltimateClaimCount Ref_Adj_TrendedGrsUp_IBNYR_large Ref_Adj_TrendedGrsUp_IBNYR_small large_ibnyr_ClaimCnt small_ibnyr_ClaimCnt;
output out = FinalIndicationData (Drop = _TYPE_ _FREQ_) sum = ;
run;

PROC EXPORT DATA = FinalIndicationData
  OUTFILE = &outputfile replace;
RUN;
