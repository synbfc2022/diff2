/*The purpose of this program is to extract the planning indication data to be used for the 
Harmonized indication template.
The user will use this program to extract data for a particular LOB+Market Dimension.
The csv output of this program will be pasted onto tab[Experience Data] of the 
"Harmonized Model Line Indications - Master Template" file 
*/

options obs = Max;
options compress = yes;
 

/**********************************CONSTANTS USED IN THE PROGRAM************************************/
/************THESE WILL NEED TO BE CHANGED/REVIEWED EVERY TIME THE PROGRAM IS RUN*******************/

/*==========================================================================================================================================================*/
/*===============================================================Global Assumptions=========================================================================*/
/*==========================================================================================================================================================*/
/*==========================================================================================================================================================*/
/*==========================================================================================================================================================*/


/*File Path to Source Data- Combined All company Dataset*/
/******************************************/
LIBNAME Combined 'E:\Data\Planning' ;
%let Filename  = ngic_niic_ncic_2020q4_exclficc;


/*Location of SAS Includes for Global Assumptions*/
/*************************************************/
filename sasinclu 'E:\Data\NGIC\CL\Include';


/*Location of SAS Includes for 2020 planning indication*/
/*************************************************/
filename sasinc20 'X:\Actuarial\DC_Actuarial\CL\Rate Adequacy\Overall Indications\2020Q4\Sas Includes\CL';

/*sas includes for splitting Non-program into smaller planning segments*/
%include sasinc20(NonProgram_PlanningUnit) ;
%include sasinc20(ibccode_to_IndustryCode) ;

/*Loss Trends*/
/*************/
%include sasinc20(Loss_Trends_2020);
%let ExtractionQuarter = "Q4";
%let LastDataYear = 2020;

%let TrendtoDate = '1JAN2023'd;


/*OLF */
/**********/
%include sasinc20(OnLevelFactors) ;


/*CDF's*/
/**********/
%include sasinc20(ClaimLevelCDF_2020Q4) ;


/*Currency Conversion Factors*/
/*****************************/
%include sasinc20(CurrencyConvert) ;

/*Premium Trend*/
%include sasinc20 (PremiumTrendLiab_2020); 


/*IBNYR Split Factors*/
/***********************/
%include sasinc20(ibnyr_split_factors_2020q4) ;

/*Reform Factors*/
/***********************/
/*%include sasinclu(ReformFact) ;*/

/*==========================================================================================================================================================*/
/*===============================================================Assumptions by Line========================================================================*/
/*==========================================================================================================================================================*/
/*==========================================================================================================================================================*/
/*==========================================================================================================================================================*/

/*Select the Extraction Segment that belongs to you*/
%let MyExtractionSegment = "Liability";
*%let MyExtractionSegment = "Property";
*%let MyExtractionSegment = "Automobile";
*%let MyExtractionSegment = "TechRsk-Prop";
*%let MyExtractionSegment = "TechRsk-Cas";
*%let MyExtractionSegment = "SpecialtyRsk";
*%let MyExtractionSegment = "Liab-SmallBus";
*%let MyExtractionSegment = "Prop-SmallBus";
*%let MyExtractionSegment = "Auto-SmallBus";


/*Select the name of the SAS output file (Pretty much the same as above, but without quotes)*/
/********************************************************************************************/
/*Extraction SAS Dataset output path*/
LIBNAME PlanOut 'X:\Actuarial\DC_Actuarial\CL\Rate Adequacy\Overall Indications\2020Q4\Lob Test\Sas Programs\';


/*Extraction SAS Dataset output file name*/
%let MyDataFile = Liability;
*%let MyDataFile = Property;
*%let MyDataFile = Automobile;
*%let MyDataFile = TechRskProp;
*%let MyDataFile = TechRskCas;
*%let MyDataFile = SpecialtyRsk;
*%let MyDataFile = LiabilitySmallBus;
*%let MyDataFile = PropertySmallBus;
*%let MyDataFile = AutomobileSmallBus;


/*Gross Up Indicatator for Participation Adjustment---Choose 1*/
/**************************************************************/
*%let GrossUpIndicator = "Yes"; 
%let GrossUpIndicator = "No"; 


/*Large Loss Threshold - CGL=200K, EODO=200K, UMB=1M*/
/**********************/
*%let LLThreshold = 750000; /*TRs = 750000 Not Applicable for Specialty Risk*/
%include sasinc20 (NGIC_Liab_Thresholds) ; /*Use a SAS include for Specialty Risk*/


/*Indication Data CSV Output file*/
/*********************************/
*%let Indication_output_file = "X:\Actuarial\DC_Actuarial\CL\Rate Adequacy\Overall Indications\2020Q4\Test\Sas Output\Liab Indication MM - test.csv";
%let Indication_output_file='X:\Actuarial\DC_Actuarial\CL\Rate Adequacy\Overall Indications\2020Q4\Liability\Sas Output\NGIC Indication Data Liab MM - correct masstort.csv';
*%let Indication_output_file='X:\Actuarial\DC_Actuarial\CL\Rate Adequacy\Overall Indications\2020Q4\Liability\Sas Output\NGIC Indication Data Liab SB CGL.csv';

/*================================================================================================================================================================*/
/*============================================================================PROGRAM START=======================================================================*/
/*================================================================================================================================================================*/
/*================================================================================================================================================================*/
/*================================================================================================================================================================*/


/* Combind Data read in,clean up and filter for extraction team */
DATA CombinedCleaned; 
	SET combined.&Filename;
	where Entity ne "TOKIO";

	length MajorLineOrg $4.;

	MajorlineOrg = Majorline;

	/*Ontario request to exclude the following program*/
	if regionName = "Ontario" and initiative_new = "CG&P" and MM_CODE in ("440")  then do;
       exclude =  'CancPrg'; 
       CustomerSegment = "CANCELLED";
    end;

	/*T&L request to exclude Challenger and Salvatore*/
	if Entity='NCIC' and policy in ('P7174444' 'P71714444B') then do;
		exclude =  'CancPol'; 
		CustomerSegment = "CANCELLED";
	end;
	else if RegionName="Atlantic" and Sector = "Transportation & Logistics" and Brokercode in ('4121' '6500059' '6500169') then do;
		exclude =  'CancBroker'; 
		CustomerSegment = "CANCELLED";
	end;
		

	if Sector = "Specialty Risk" then do;
		if CustomerSegment in ('Corporate','Guarantee/Warranty - Guarantee Solutions', 'Guarantee/Warranty - Transportation Program',
					'Marine - Commercial Marine','Marine - Pleasurecraft','Niche','Petcare','QC Marine Expert - Pleasurecraft' 
					'Executive & Professional Solutions' 'Dealerships') then exclude =  '';
		else exclude = 'CancPrg';
	end;

	if RegionName = "Runoff" or Sector in('Unknown','Runoff', '') then Exclude = 'Runoff';


/*notes on ibnr variables*/
	/*IBNER = INDEMNITY ONLY IBNER*/
	/*ALAE_NER = EXPENSE ONLY IBNER*/
	/*IBNYR = INDEMNITY ONLY IBNYR*/
	/*ALAE_NYR = EXPENSE ONLY IBNYR*/
	/*TOTAL IBNR IS EQUAL TO: IBNR = IBNER + ALAE_NER +IBNYR + ALAE_NYR*/


/*Initial Data filtering*/


/*Incurred Losses*/
	IncurredLosses = sum(Paid,Reserve,Paid_ALAE,Reserve_ALAE);

/*IBNER and IBNYR Variables*/
	TotalIBNER = sum(IBNER,ALAE_NER);
	TotalIBNYR = sum(IBNYR,ALAE_NYR);


/*Ultimate Loss without IBNYR*/
	UltimateClaim = sum(IncurredLosses, TotalIBNER);

/*Ultimate Loss with IBNYR*/
	UltimateLosses = sum(IncurredLosses, IBNR);


/*Extraction Segment*/
	length ExtractionSegment $15.;

	If MajorLine = "Liab" and MarketDimension in("MIDMARKET") then ExtractionSegment = "Liability";
	else If MajorLine = "Prop" and MarketDimension in("MIDMARKET") then ExtractionSegment = "Property";
	else If MajorLine = "Auto" and MarketDimension in("MIDMARKET","TECHNICAL RISK") then ExtractionSegment = "Automobile";
	else If MajorLine = "Liab" and MarketDimension in("TECHNICAL RISK") then ExtractionSegment = "TechRsk-Cas";
	else If MajorLine = "Prop" and MarketDimension in("TECHNICAL RISK") then ExtractionSegment = "TechRsk-Prop";
	else If MajorLine = "Liab" and MarketDimension in("SMALL BUSINESS") then ExtractionSegment = "Liab-SmallBus";
	else If MajorLine = "Prop" and MarketDimension in("SMALL BUSINESS") then ExtractionSegment = "Prop-SmallBus";
	else If MajorLine = "Auto" and MarketDimension in("SMALL BUSINESS") then ExtractionSegment = "Auto-SmallBus";

	if Sector = "Specialty Risk" then ExtractionSegment = "SpecialtyRsk";
	*If ENTITY = "NCIC" then ExtractionSegment = "Automobile";


/*Minor Line Variable*/
	length MinorLine $15.;

		if ExtractionSegment in ("Liability","Liab-SmallBus") then do;
		if MajorCoverage in ("CGL","Umb") then MinorLine = MajorCoverage;
		else if MajorCoverage in ("EO","DO") then MinorLine = "EO & DO";
		else if Entity = "NCIC" and MajorLine = "Liab" then MinorLine = "CGL"; /****NEW****/
	end;
	else MinorLine = MajorLine;


	/*NCIC MajorLine to Auto*/
	*If ENTITY = "NCIC" then MajorLine = "Auto";


/*Planning Segments*/
	length PlanningSegment $45.;

	if Sector = "Specialty Risk" then PlanningSegment = CustomerSegment;
	else if Sector NE "Specialty Risk" then do;

/*Adding in new planning segment to differentiate CoC business, subject to change*/	
	
		if ENTITY = "NGIC" and CoC_WrapUp_Indicator = "N" then do;
			if initiative_New = "CG&P" then PlanningSegment = "Program";
			else if initiative_New NE "CG&P" then PlanningSegment = "Non-Program";
		end;

		else if ENTITY = "NGIC" and CoC_WrapUp_Indicator = "Y" then do;
			if initiative_New = "CG&P" then PlanningSegment = "BuildersChoiceProgram";
			else if initiative_New NE "CG&P" then PlanningSegment = "BuildersChoiceNon-Program";

		end;

		else if ENTITY = "NIIC" and CoC_WrapUp_Indicator = "N" then PlanningSegment = "Non-Program";
		else if ENTITY = "NIIC" and CoC_WrapUp_Indicator = "Y" then PlanningSegment = "BuildersChoiceNon-Program";
		

		else if ENTITY = "NCIC" then do;
			if CustomerSegment = "" then PlanningSegment = "";
			else if CustomerSegment = '1-4' then PlanningSegment = "Non-Program - NonFleet"; /*NCIC transfer is now put under Non-Program NonFleet*/
            		else if CustomerSegment = '100+' then PlanningSegment = "OASIS 101+";
			else PlanningSegment = "OASIS 5-100";
		end;
/* CoC ends here*/
	end;


	if MarketDimension in("TECHNICAL RISK") and CoC_WrapUp_Indicator = "N" then PlanningSegment = ENTITY; /*FIX For Technical Risk*/
	
	if MarketDimension in("MIDMARKET") and customersegment = "Agriculture" then PlanningSegment = "Agriculture"; /*Agri Split*/

	if MarketDimension in ("SMALL BUSINESS") then PlanningSegment = "Small Business";

	/*Add Fleet and Non-Fleet Indicator to NGIC T&L Policies*/
	if Entity = "NGIC" and Sector = "Transportation & Logistics" and PlanningSegment = "Non-Program" and MajorLine = "Auto" then do; /*Add Fleet To Non-Program*/
		if Fleet = 'F' then PlanningSegment = "Non-Program - Fleet";
		else if Fleet = 'N' then PlanningSegment = "Non-Program - NonFleet";
		else PlanningSegment = "CHECK";
	end;

	/*Add Fleet and Non-Fleet Indicator to NGIC T&L Policies for Property and Liability*/
	if Entity = "NGIC" and Sector = "Transportation & Logistics" and PlanningSegment = "Non-Program" and MajorLine in ('Prop' 'Liab') then do; /*Add Fleet To Non-Program*/
		if Fleet in ('F') then PlanningSegment = "Non-Program - Fleet";
		else if Fleet in ('N') then PlanningSegment = "Non-Program - NonFleet";
		else if Fleet in ('') then PlanningSegment = "Non-Program";
		else PlanningSegment = "CHECK";
	end;

	
	/***NCIC --- Exclude Certain Brokers and Policies***/
	if ENTITY = "NCIC" then do;
		/*Captive*/
		/*Captive policies lapsed on May 1, 2018*/
		*if brokercode in ('6000')  or 
		policy in ('2002005','2006046','2017330','2003482','2025274','2024772','2003123','2025036') then PlanningSegment = "Captive" ;

		/*Excluded Brokers*/
		if Brokercode in ('5890','5223', '4712', '4925', '4199', '3633', '4224', '3834', '4401', '5176', 											
		'5851', '3772', '5157', '3671', '3874', '4235', '4114', '5339', '2990', '4282', '4283', '4481', 										
		'5888', '5594', '3878', '4362', '4471', '4324', '5834', '5729', '5383', '4184', '4185', '2016', '4543', 										
		'4578', '4672', '4531', '5501', '4447', '3539', '4465','3540','3991','4159','4351','4864','5749','5639','5672') then Exclude = "Cancelled Brokers";

		/*Excluded Brokers*/
		if Policy in ('2017329','2017329U','2004330','p7174954','2001341US',
		'2002356','2002356U','2016905','2019619','2019619A','2019619B','2019619C','2019619D','2019619E','2019619F','2019619G','2019619H','2019619I',
		'2019619J','2019619K','2019619L','2019619M','2019619N','2019619O','2019619P','2019619Q') then Exclude = "Cancelled Brokers";
	end;


	/*Exposure Variables*/
	If MajorLine = "Auto" then do;
		Written_Exposure = wveh;
		Earned_Exposure = eveh;	
	end;
	else do;
		Written_Exposure = 0;
		Earned_Exposure = 0;	
	end;


	/*Create TruShield as a region for Small Business*/
	if MarketDimension = "SMALL BUSINESS" and SB_FLAG = "TRUESHIELD" then RegionName = "TruShield";


	/*****Split non-program into smaller planning segments*******/
	/*NIIC data does not have 6digit readiy available, need to map from 4 digit*/
	if entity='NIIC' then IBCCode_6digit=put(IBCCode,$IndustryCode.);

	format PlanningSegment_new $100.;
	if PlanningSegment="Non-Program" and Sector ne "Transportation & Logistics" then do;
		PlanningSegment_new=put(IBCCode_6digit||trim(Sector),$NonProgram_PU.);
	end;
	else PlanningSegment_new=PlanningSegment;

	if PlanningSegment_new="Other" and Sector="Health, Education, & Social Services" then 
		PlanningSegment_new="Education/Social/Other services";
	else if PlanningSegment_new="Other" and Sector="Manufacturing & Resources" then
		PlanningSegment_new="Other Resources and Misc";

	drop PlanningSegment;
	rename PlanningSegment_new=PlanningSegment;


	/*Filter for Team*/
	if ExtractionSegment = &MyExtractionSegment;

run;


/* Trends the losses and IBNR */
data TrendedData;
	set CombinedCleaned;

/*Trending the losses and IBNR*/
	format TrendLine $8.;

	Length TrendReg $8. TrendSector $45. TrendKey $55.;

	/*Clean Up Line*/
	if Majorline = "Auto" then TrendLine = cats(Entity)||Cats(MajorLine);
	else TrendLine = MajorLine;

	
	/*Clean Up Region for Trend Mapping*/
	if TrendLine = "Liab" then do;
		TrendReg = RegionName;
	end;	
	else if TrendLine in("Prop","NGICAuto","NGICAuto") then do;
		if entity in ('NIIC','NCIC') then TrendReg = RegionName;
		else do;
			if SPROV in ('60', '66', '65', '64') then TrendReg = "Atlantic";
			else if sprov in ('67') then TrendReg = "Ontario";
			else if sprov in ('68') then TrendReg = "Quebec";
			else if sprov in ('61','62','63', '64', '69','70','71','80','89') then TrendReg = "Western";
			else TrendReg = RegionName;
		end;
	end;
	

	/*Clean Up Sector for Trend Mapping*/
	if Sector in('EO/DO', 'Specialty Risk') then TrendSector = 'Consumer & Business Services'; /*Defaulting SR and  E&O and D&O Sector to use CBS Trends for Now*/
	else TrendSector = Sector;

	if Trendline in ('NGICAuto','NCICAuto') then do;
		if entity = 'NGIC' then do;
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
		else if entity = 'NCIC' then do;
			if MajorlineOrg = "Liab" then TrendSector = "CGL";
			else if MajorLineOrg = "Prop" then do;
				if RISK = "CARGO" then trendSector = "CARGO";
				else TrendSector = "OTHER";
			end;
			else if MajorlineOrg = "Auto" then do;
				if MajorCoverage IN ("1-BODILY-INJ","SEF44") then TrendSector = "BI";
				else if MajorCoverage in("1-DIRECTCOMP") then TrendSector = "DCPD";
				else if MajorCoverage in ("1-PROP-DAM") then TrendSector = "PD";
				else if MajorCoverage in ("2-ACC-BEN", "2-OIAB-CAREG", "2-OIAB-DEATH", "2-OIAB-INCRE", "2-OIAB-INDEX", "2-OIAB-MEREA") then TrendSector = "AB";
				else if MajorCoverage in ("3-COLLISION") then TrendSector = "COLL";
				else if MajorCoverage in ("3-COMPREHENS") then TrendSector = "COMP";
				else if MajorCoverage in ("3-SPEC-PERIL") then TrendSector = "SP";
				else if MajorCoverage in ("4-UNINSMOTOR") then TrendSector = "UA";
				else trendsector = 'MISC';
			end;


		end;

	end;

	

	Trendkey = Cats(TrendLine)||Cats(TrendReg)||Cats(TrendSector);

	pasttrend = input(Trendkey,PastTrend.) ;
	futuretrend = input(trendkey,FutureTrend.) ;
	cutoff = input(trendkey,TrendCutDate.) ;

	pasttrend = input(Cats(TrendLine)||Cats(TrendReg)||Cats(TrendSector),PastTrend.) ;
	futuretrend = input(Cats(TrendLine)||Cats(TrendReg)||Cats(TrendSector),FutureTrend.) ;
	cutoff = input(Cats(TrendLine)||Cats(TrendReg)||Cats(TrendSector),TrendCutDate.) ;
	
	if year = &LastDataYear then do;
			if &ExtractionQuarter = 'Q1' then lossdate = MDY(2,15,year);
			else if &ExtractionQuarter = 'Q2' then lossdate = MDY(4,1,year);
			else if &ExtractionQuarter = 'Q3' then lossdate = MDY(5,15,year);
			else if &ExtractionQuarter = 'Q4' then lossdate = MDY(7,1,year);
	end;
	else lossdate = MDY(7,1,year);

	format lossdate yymmdd6.;

	cutoff1 = MDY(7, 1, &LastDataYear);

	date2 = max(lossdate,cutoff1);

	Trendperiod1 = max(intck('Day',lossdate,cutoff1)/365.25,0);
	Trendperiod2 = max(intck('Day',date2,&TrendtoDate)/365.25,0);

	TrendFactor = ((1+pasttrend)**TrendPeriod1)*((1+Futuretrend)**TrendPeriod2);

	Trended_Ultimate_Claim = UltimateClaim * TrendFactor;
	Trended_Incurred_Loss = IncurredLosses * TrendFactor;
	Trended_IBNYR = TotalIBNYR * TrendFactor;
	Trended_IBNER = TotalIBNER * TrendFactor;
	Trended_IBNR = sum(Trended_IBNYR,Trended_IBNER);
	Trended_Ultimate_losses = sum(Trended_incurred_loss,Trended_IBNYR, Trended_IBNER);


run;


/*Test Trending Factors*/
proc summary data = TrendedData nway;
	class Entity RegionName Sector MajorLine year /missing;
	var UltimateClaim Trended_Ultimate_Claim pasttrend futuretrend trendFactor;
output out = TrendingTest (Drop = _TYPE_ _FREQ_) sum(UltimateClaim)= UltimateClaim sum(Trended_Ultimate_Claim) = Trended_Ultimate_Claim mean(pasttrend) = AvgPastTrend Max(pasttrend) = MaxPastTrend Min(pasttrend) = MinPastTrend mean(Futuretrend) = AvgFutureTrend Max(Futuretrend) = MaxFutureTrend Min(Futuretrend) = MinFutureTrend;
run;
/*
PROC EXPORT DATA = TrendingTest
  OUTFILE = &TrendingTest_output_file replace;
RUN;
*/


/*Premium Trends, Onlevel Factors and Other Adjustments*/
Data FinalAdjustedData;
	set TrendedData;

	format OLFKey $130.;
	format PremKey $70.;
	Length OLFReg $8.;
    if RegionName="TruShield" then OLFReg="Ontario";
    else OLFReg = RegionName;
	
/*	if entity ='NGIC' and PlanningSegment = "Non-Program - NonFleet" then do;
	OLFKey = trim(entity)||trim(line1)||trim(MarketDimension)||trim(RegionName)||trim(Sector)||"Non-Program"||cats(year);
	OnlevelFactor = input(OLFKey, OLF.);
*/
/*change PremKey for Liab - just by year
	PremKey = trim(line1)||trim(RegionName)||trim(Sector)||"Non-Program"||cats(year);*/
/*	PremKey = cats(year);
	PremiumTrendFactor = input(PremKey, PremTrend.);
	end;


	else if entity ='NGIC' and PlanningSegment = "Non-Program - Fleet" then do;
/*	OLFKey = trim(entity)||trim(line1)||trim(MarketDimension)||trim(RegionName)||trim(Sector)||"Non-Program"||cats(year);
	OnlevelFactor = input(OLFKey, OLF.);
*/

/*
	change PremKey for Liab - just by year
	PremKey = trim(line1)||trim(RegionName)||trim(Sector)||"Non-Program"||cats(year);*/
/*	PremKey = cats(year);
	PremiumTrendFactor = input(PremKey, PremTrend.);
	end;

	else if entity ='NGIC' and PlanningSegment = "BuildersChoiceNon-Program" then do;
	OLFKey = trim(entity)||trim(line1)||trim(MarketDimension)||trim(RegionName)||trim(Sector)||"BuildersChoice"||cats(year);
	OnlevelFactor = input(OLFKey, OLF.);
*/
/*change PremKey for Liab - just by year
	PremKey = trim(line1)||trim(RegionName)||trim(Sector)||Trim(PlanningSegment)||cats(year);*/
/*	PremKey = cats(year);
	PremiumTrendFactor = input(PremKey, PremTrend.);
	end;

	else if entity ='NGIC' and PlanningSegment = "BuildersChoiceProgram" then do;

/*	OLFKey = trim(entity)||trim(line1)||trim(MarketDimension)||trim(RegionName)||trim(Sector)||"BuildersChoice"||cats(year);
	OnlevelFactor = input(OLFKey, OLF.);
*/
/*change PremKey for Liab - just by year
	PremKey = trim(line1)||trim(RegionName)||trim(Sector)||Trim(PlanningSegment)||cats(year);*/
/*	PremKey = cats(year);
	PremiumTrendFactor = input(PremKey, PremTrend.);
	end;


	else if entity ='NGIC' then do;
/*
	OLFKey = trim(entity)||trim(line1)||trim(MarketDimension)||trim(RegionName)||trim(Sector)||Trim(PlanningSegment)||cats(year);
	OnlevelFactor = input(OLFKey, OLF.);
*/
/*change PremKey for Liab - just by year
	PremKey = trim(line1)||trim(RegionName)||trim(Sector)||Trim(PlanningSegment)||cats(year); */
/*	PremKey = cats(year);
	PremiumTrendFactor = input(PremKey, PremTrend.);
	end;

	else if entity = 'NIIC' then do;

/*	OLFKey = Trim(Entity)||trim(majorline)||trim(RegionName)||trim(Sector)||cats(year);
	OnlevelFactor = input(OLFKey, OLF.);
*/


/*change PremKey for Liab - just by year
	PremKey = Trim(Entity)||trim(majorline)||trim(RegionName)||trim(Sector)||cats(year);*/
	PremKey = cats(year);
	PremiumTrendFactor = input(PremKey, PremTrend.);
	
	if MinorLine = "EO & DO" then PremiumTrendFactor = 1;

	if entity ='NGIC' then do;
	OLFKey = trim(entity)||"Liab"||trim(MarketDimension)||trim(OLFReg)||trim(Sector)||Trim(PlanningSegment)||cats(year);
	OnlevelFactor = input(OLFKey, OLF.);
	end;

	else if entity = 'NIIC' then do;
	OLFKey = trim(Entity)||"Liab"||trim(OLFReg)||trim(Sector)||cats(year);
	OnlevelFactor = input(OLFKey, OLF.);
	end;

	else if entity = 'NCIC' then do;
	OLFKey = trim(entity)||trim(OLFReg)||Trim(fz_gp)||cats(year);
	OnlevelFactor = input(OLFKey, OLF.);
	end;



	/*SPECIAL FACTORS FOR MASTERS BUILDERS RISK*/
	
/* H:\CL\Rate Adequacy\Overall Indications\2017Q4\Liability\MidMarket\Assumptions\Rate Change OnLevel and Premium Trend\OLF working files\Step 3 - Manual Adjustments\Ontario CG&P C&C Masters (721) Adj 2017Q4.xlsx */
	/* OLF: NOT UPDATED */
	if covg = 'MastersBR' then do;
           if year =2009 then OnlevelFactor = 2.274;
			else if year = 2010 then OnlevelFactor = 1.824; 
			else if year = 2011 then OnlevelFactor = 1.604;
    		else if year = 2012 then OnlevelFactor = 1.472;
    		else if year = 2013 then OnlevelFactor = 1.327;
    		else if year = 2014 then OnlevelFactor = 1.209;
    		else if year = 2015 then OnlevelFactor = 1.144;
			else if year = 2016 then OnlevelFactor = 1.105;
			else if year = 2017 then OnlevelFactor = 1.068;
			else if year = 2018 then OnlevelFactor = 1.024;
			else if year = 2019 then OnlevelFactor = 1.000;
			else if year = 2020 then OnlevelFactor = 1.000;
    end;
	
	/*Special Factors for Policy 0874964*/
	/* Source: H:\CL\Rate Adequacy\Overall Indications\2016Q4\Liability\MidMarket\Assumptions\Rate Change OnLevel and Premium Trend\OLF working files\Step 3 - Manual Adjustments\OLF (upto2008)-MIS014 - Final 2016Q4 - adj for ON HESS EODO SME.xlsm */
	if policy in ('0874964') then do;
		OnlevelFactor = 1;
		PremiumTrendFactor = 1;
	end;

	Onlevel_EP = EP * OnlevelFactor;


	Trended_Onlevel_EP = Onlevel_EP * PremiumTrendFactor;

	ReformFactor = 1;

	Reform_Adj_Trended_Ult_Losses = Trended_Ultimate_Losses * ReformFactor;
	Reform_Adjusted_Trended_IBNYR = Trended_IBNYR * ReformFactor;
	Reform_Adj_Trended_UltimateClaim = Trended_Ultimate_Claim * ReformFactor;
run;

/*%let outputfiletest = "X:\Actuarial\DC_Actuarial\CL\Rate Adequacy\Overall Indications\2020Q4\Liability\Sas Output\ngicMMPremKey.csv";

PROC EXPORT DATA = FinalAdjustedData
  OUTFILE = &outputfiletest replace;
RUN;
*/

/* to del
/*PROC SQL NOEXEC;
   SELECT /* MISSING COLUMNS */
  /*    FROM WORK.FINALADJUSTEDDATA t1
      WHERE t1.OLFKey = 'NGICCGLMIDMARKETAtlanticConstruction & ContractingHeavy and civil engi';
QUIT;*/
/*
proc summary data = finalAdjustedData nway;
	class Entity OLFKey OnlevelFactor/missing;
	var WP EP WP_grs EP_grs Onlevel_EP Trended_Onlevel_EP ;
output out = FinalAdjSummarizedOLF (Drop = _TYPE_ _FREQ_) sum=;
run;
to del*/


/*Summarizes Data to a Line level*/
proc summary data = finalAdjustedData nway;
	class Entity ClaimNumber Brokercode BrokerName Policy effymd expymd module insured RegionName initiative_new sprov Sector year occupancy IBCCODE MajorLine MinorLine /*majorcoverage autocov*/ MarketDimension customerSegment PlanningSegment SB_FLAG exclude fleet catflag MassTort techrisk Dept_Desc2 currency clips mm_code mmsubcd RSSegment /missing;
	var WP EP WP_grs EP_grs Onlevel_EP Trended_Onlevel_EP Written_Exposure Earned_Exposure paid Paid_grs PAID_ALAE reserve RESERVE_ALAE IncurredLosses TotalIBNER TotalIBNYR ibnr Ultimatelosses Trended_Incurred_Loss Trended_IBNER Trended_Ultimate_Claim Trended_IBNYR Trended_IBNR Trended_Ultimate_losses Reform_Adj_Trended_Ult_Losses Reform_Adjusted_Trended_IBNYR Reform_Adj_Trended_UltimateClaim clmcnt ultcnt;
output out = FinalAdjSummarized (Drop = _TYPE_ _FREQ_) sum=;
run;


/*Final Data and identifies the loss type (Small, Large, Cat)*/
Data finalOut;
	set  FinalAdjSummarized;

/*Split Large/Small/Cat here*/
	format LossType $6.;
	
	/*Grossing Up for Participation*/

	if &GrossUpIndicator = "Yes" then do;
		if EP NE 0 and round(EP_grs,.01) NE 0 then PremGrossUpFactor = round(EP_grs,.01)/EP;
		else PremGrossUpFactor = 1;


		if Paid NE 0 and round(Paid_grs,.01) NE 0 then LossGrossUpFactor = round(Paid_grs,.01)/Paid;
		else LossGrossUpFactor = 1;
	end;
	else if &GrossUpIndicator = "No" then do;
		PremGrossUpFactor = 1;
		LossGrossUpFactor = 1;
	end;


	/*Currency Fix Here*/
	IF ENTITY = "NIIC" and Currency = "USD" then do;
		ExRateKey = CATS(Dept_Desc2)||CATS(Year);
		ExRatePrem = input(CATS(ExRateKey),ExRatePremium.);
		ExRateLoss = input(CATS(ExRateKey),ExRateLoss.);
	end;
	else do;
		ExRatePrem = 1;
		ExRateLoss = 1;
	end;


	Trended_Onlevel_GrsUp_EP = Trended_Onlevel_EP * PremGrossUpFactor * ExRatePrem;
	Ref_Adj_Trended_GrsUp_Ult_Losses = Reform_Adj_Trended_Ult_Losses * LossGrossUpFactor * ExRateLoss;
	Ref_Adj_Trended_GrsUp_IBNYR = Reform_Adjusted_Trended_IBNYR * PremGrossUpFactor * ExRateLoss;
	Ref_Adj_Trended_GrsUp_Ult_Claim = Reform_Adj_Trended_UltimateClaim * LossGrossUpFactor * ExRateLoss;



	/* if Sector = 'Specialty Risk' then Threshold = input(Cats(Majorline),SRLLThreshold.) ;
	else */
	if Minorline = 'EO & DO' then Minorline2 = 'EODO';
		else Minorline2 = Minorline;

	/*Large Loss Thresholds*/	
	Threshold = input(Cats(MinorLine2),LLThreshold.) ;

	
	if Ref_Adj_Trended_GrsUp_Ult_Claim GE Threshold then LossType = "LARGE";
	else if Ref_Adj_Trended_GrsUp_Ult_Claim LT Threshold then LossType = "SMALL";

	if MassTort not in ('') then LossType = "CAT";

	if ClaimNumber = "" then LossType = "IBNYR";

	If ClaimNumber NE "" and IncurredLosses GT 0 then claimcount = 1 ;
	

/*CDF Factors and Ultimate Claim Count*/

	format CDFLine $8.;

	/*Clean Up Line*/
	
	if majorline = "Liab" then do;
		 if Entity = "NGIC" then do;
			if trim(MinorLine) in ('EO & DO') then CDFLine = 'EODO';
			  else if MinorLine in ('Umb') then CDFLine = MinorLine;
				else if MinorLine in ('CGL') then do;
					if sector in ('Construction & Contracting') then CDFLine = 'CGLCC';
					else CDFLine = 'CGLxC';
				end;
		end;
		if Entity = "NIIC" then do;
			if Currency = 'CAD' then CDFLine = 'LiabCAD';
				else if Currency = 'USD' then CDFLine = 'LiabUSD';
				else CDF = 'Liab';
		end;
	end;
	else if MajorLine = "Prop" then do;
		if Entity = "NGIC" then CDFLine = MajorLine;
		else if ENTITY = "NIIC" then CDFLIne = "Prop";
	end;
	else if MajorLine = "Auto" then do;
		if Entity = "NGIC" then CDFLine = MajorLine;
		else if ENTITY = "NCIC" then CDFLIne = "Auto";
	end;	

	if Entity = "NCIC" then CDFLine = "Auto";


	CDF = input(Cats(ENTITY)||Cats(RegionName)||Cats(CDFLine)||CATS(year),CDF.) ;


	ultimateClaimCount = ClaimCount * cdf;
	
	if Sum(reserve,RESERVE_ALAE) = 0 then openClaimCount = 0;
	else openClaimCount = UltimateClaimCount;


	/* creating new sector for Builders Choice so it will not be credibility complimented with rest of C&C*/

	if PlanningSegment = "BuildersChoiceNon-Program" or PlanningSegment = "BuildersChoiceProgram" then Sector = "Builders Choice";

	/* combine Tech Risk planning unit NGIC & NIIC into a single P.U due to IFIS to CLIPS transfer, still issues with assumption factors (OLF) */

	if marketdimension = "TECHNICAL RISK" AND PlanningSegment = "NIIC" then PlanningSegment = "NGIC";

	** Renaming T&L Planning Unit;
	if PlanningSegment = "Non-Program - Fleet" then PlanningSegment = "CLIPS Fleet";
	if PlanningSegment = "Non-Program - NonFleet" then PlanningSegment = "CLIPS NonFleet";
	if Sector = "Transportation & Logistics" and PlanningSegment = "Non-Program" then PlanningSegment = "CLIPS T&L Non - Auto";


run;

/*get small, large ibnyr in sas data*/
data finalOut;
	set finalOut;

	if majorline='Liab' then
		ibnyrdollarsfactor = input (cats(minorline)||cats(year),ibnyrlargedollars.);
	else
		ibnyrdollarsfactor = input (cats(minorline)||cats(regionname)||cats(year),ibnyrlargedollars.);

	Large_Adjusted_IBNYR = ref_adj_Trended_GrsUp_IBNYR*ibnyrdollarsfactor;

	Small_Adjusted_IBNYR = ref_adj_Trended_GrsUp_IBNYR*(1-ibnyrdollarsfactor);

	/*if minorline = 'CGL' then do;*/

		ibnyrcountfactor = input (cats(minorline)||cats(year),ibnyrlargecount.);

		if year ge &LastDataYear - 5 then do;
			large_ibnyr_ClaimCnt = (ultimateclaimcount - claimcount)*ibnyrcountfactor;
			small_ibnyr_ClaimCnt = (ultimateclaimcount - claimcount)*(1-ibnyrcountfactor);
		end;

		else if year le &LastDataYear - 5 then do;
			if losstype = 'LARGE' then large_ibnyr_ClaimCnt = ultimateclaimcount - claimcount;
			if losstype = 'SMALL' then small_ibnyr_ClaimCnt = ultimateclaimcount - claimcount;
		end;
	/*end;

	else do;
		if losstype = 'LARGE' then large_ibnyr_ClaimCnt = ultimateclaimcount - claimcount;
		if losstype = 'SMALL' then small_ibnyr_ClaimCnt = ultimateclaimcount - claimcount;
	end;*/

run;

/*
Data PlanOut.&MyDataFile;
	set FinalOut;
run;
*/

/*Need to relook at*/
proc summary data = finalOut nway;
	where year GT &LastDataYear-10;
	class MajorLine MinorLine RegionName Sector MarketDimension PlanningSegment SB_FLAG YEAR LossType exclude /missing;
	var WP EP WP_grs EP_grs Onlevel_EP Trended_Onlevel_EP Trended_Onlevel_GrsUp_EP Written_Exposure Earned_Exposure 
		paid paid_grs PAID_ALAE reserve RESERVE_ALAE IncurredLosses TotalIBNER TotalIBNYR ibnr Ultimatelosses 
		Trended_Incurred_Loss Trended_IBNER Trended_IBNYR Trended_IBNR Trended_Ultimate_losses Reform_Adj_Trended_Ult_Losses 
		Ref_Adj_Trended_GrsUp_Ult_Losses Reform_Adjusted_Trended_IBNYR Ref_Adj_Trended_GrsUp_IBNYR OpenClaimCount ClaimCount 
		UltimateClaimCount Large_Adjusted_IBNYR Small_Adjusted_IBNYR large_ibnyr_ClaimCnt small_ibnyr_ClaimCnt;
output out = FinalIndicationData (Drop = _TYPE_ _FREQ_) sum = ;
run;


PROC EXPORT DATA = FinalIndicationData
  OUTFILE = &Indication_output_File replace;
RUN;