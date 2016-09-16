///////////////////////////////////////////////////
//
//	1_WEIGHTING.RSC:
//
//	This script contains the Level 1-4 weighting
//  procedure for the Airport Choice Model (ACM).
//
//	Adapted from Renee Alsup's SPSS & Stata Codes
//  by Chrissy Bernardo, August 2015
//
///////////////////////////////////////////////////


// Main macro to call steps of weighting process
Macro "Weighting Main"(Args)
	
	RunMacro("G30 File Close All")
	
	shared futyears
	shared nonresSEDgrowth 
	shared nonresINCgrowth 
	
	futyears = Args.[Weighting Years]
	nonresSEDgrowth = Args.[NonResidentSEDGrowth]
	nonresINCgrowth = Args.[NonResidentIncomeGrowth]
	Scen = Args.[Scenario Name]
	
	ScenDir = ParseString(Args.[Base Directory], "\\")
	
	MainDir = null
	for ii = 1 to ScenDir.length - 2 do
		MainDir = MainDir + ScenDir[ii] + "\\"
	end
	
	Scen = ScenDir[ScenDir.length]

	
	// Standard Scenario Directory Structure
	InDir 	= MainDir+"1_Scen\\"+Scen+"\\1_Inputs\\"
	WDir 	= MainDir+"\\3_RunBin\\"
	OutDir	= MainDir+"1_Scen\\"+Scen+"\\2_Outputs\\"
	
	stepname = null
	
	if !RunMacro("Check Inputs", MainDir, InDir+"1_Weighting\\") then do stepname = "Check Inputs" goto quit end
	
	if !RunMacro("Income Weights", MainDir, InDir+"1_Weighting\\", WDir+"1_Weighting\\", OutDir+"1_Weights\\") then do stepname = "Calculate Income Weights" goto quit end
	
	if !RunMacro("Level 1", MainDir, InDir+"1_Weighting\\", WDir+"1_Weighting\\", OutDir+"1_Weights\\") then do stepname = "Level 1 Weighting" goto quit end // SED Forecasts
	
	if !RunMacro("Level 2", MainDir, InDir+"1_Weighting\\", WDir+"1_Weighting\\", OutDir+"1_Weights\\") then do stepname = "Level 2 Weighting" goto quit end // Growth in Real Income
	
	if !RunMacro("Level 3", MainDir, InDir+"1_Weighting\\", WDir+"1_Weighting\\", OutDir+"1_Weights\\") then do stepname = "Level 3 Weighting" goto quit end // Scale to match Total Enplanements

	if !RunMacro("Level 4", MainDir, InDir+"1_Weighting\\", WDir+"1_Weighting\\", OutDir+"1_Weights\\") then do stepname = "Level 4 Weighting" goto quit end // Scale to match Enplanements by Airport
	

	quit:
		if stepname <> null	then
			ShowMessage("Model failed at Step: "+stepname)
		else return(1)
endMacro


Macro "Check Inputs"(MainDir, InDir)
 shared futyears
//====================================================
// 	CHECK INPUT FILES FOR ALL FUTURE YEARS
//  DEFINED IN "FUTYEARS"
//====================================================	 	
	nyears = futyears.length
	SEDDir = InDir	
	ENPDir = InDir
	retval = 1
	
	// SED
	SED = OpenTable("SED", "DBASE", {SEDDir + "SED_COUNTY.DBF", })
	struct = GetTableStructure(SED)
	
	dim INC[nyears]
	dim EMP[nyears]
	dim POP[nyears]
	
	for ii = 1 to nyears do
		yr = futyears[ii]
		INC[ii] = "INCPC"+yr
		EMP[ii] = "EMP"+yr
		POP[ii] = "POP"+yr
	end
	
	
	for ii = 1 to nyears do
		exists = false
			for jj = 1 to struct.length do
				if struct[jj][1] = INC[ii] then do
					exists = true
					continue
				end
			end
		if exists = true then continue 
		else do ShowMessage("Missing Income Per Capita Data for Year 20"+ futyears[ii]+" in SED file: "+SEDDir + "SED_COUNTY.DBF")	
				retval = 0 end
	end
	
	for ii = 1 to nyears do
		exists = false
			for jj = 1 to struct.length do
				if struct[jj][1] = EMP[ii] then do
					exists = true
					continue
				end
			end
		if exists = true then continue 
		else do ShowMessage("Missing Employment Data for Year 20"+ futyears[ii]+" in SED file: "+SEDDir + "SED_COUNTY.DBF")	
				retval = 0 end
	end	
	
	for ii = 1 to nyears do
		exists = false
			for jj = 1 to struct.length do
				if struct[jj][1] = POP[ii] then do
					exists = true
					continue
				end
			end
		if exists = true then continue 
		else do ShowMessage("Missing Population Data for Year 20"+ futyears[ii]+" in SED file: "+SEDDir + "SED_COUNTY.DBF")
				retval = 0 end	
	end	

	// ENPLANEMENTS
	ENPfcast = OpenTable("Enplanement Forecasts", "CSV", {ENPDir+"Enplanement_Forecasts.csv", })
	struct = GetTableStructure(ENPfcast)
	
	dim ENP[nyears]
	
	for ii = 1 to nyears do
		yr = futyears[ii]
		ENP[ii] = "ENP"+yr
	end
	
	
	for ii = 1 to nyears do
		exists = false
			for jj = 1 to struct.length do
				if struct[jj][1] = ENP[ii] then do
					exists = true
					continue
				end
			end
		if exists = true then continue 
		else do ShowMessage("Missing Enplanement Forecast for Year 20"+ futyears[ii]+" in Enplanements file: "+ENPDir+"Enplanement_Forecasts.csv")	
				retval = 0 end
	end
	
	CloseView(SED)
	CloseView(ENPfcast)
	
	return(retval)
	
endMacro // Check Inputs

Macro "Income Weights"(MainDir, InDir, WDir, OutDir)
 shared futyears
//====================================================
// 	CALCULATE INCOME WEIGHTS
//  Based on Woods & Poole Per Capita Income Forecasts.
//  Used for Hotel Room forecasts (Level 1) and 
//	Level 2 weighting procedure.
//====================================================		
	retval = 1
	SurvIn = MainDir + "0_Param\\"
	SEDDir = InDir	
	
	// Create Temporary Weight file
	CopyFile(SEDDir + "SED_COUNTY.DBF", WDir+"Inc_Whts_temp.dbf")
	WHTS = OpenTable("IncomeWeights", "DBASE", {WDir+"Inc_Whts_temp.dbf", })
	
	strct = GetTableStructure(WHTS)

	for i = 1 to strct.length do
		// Read in existing fields, adding field name to the end of each 
		strct[i] = strct[i] + {strct[i][1]}					
	end
	// New fields
	dim futfields[futyears.length*3]
	for j = 1 to futyears.length do	
		yr = futyears[j]
		futfields[3*(j-1)+1] = {"LOW"+yr, 	"Real", 12, 7, False, , , , , , , null}
		futfields[3*(j-1)+2] = {"MED"+yr, 	"Real", 12, 7, False, , , , , , , null}
		futfields[3*(j-1)+3] = {"HIGH"+yr, 	"Real", 12, 7, False, , , , , , , null}
	end
	
	strct = strct +{{"LOW10", 		"Real", 12, 7, False, , , , , , , null},
					{"MED10", 		"Real", 12, 7, False, , , , , , , null},
					{"HIGH10", 		"Real", 12, 7, False, , , , , , , null},
					{"LOW05mod", 	"Real", 12, 7, False, , , , , , , null},
					{"MED05mod", 	"Real", 12, 7, False, , , , , , , null},
					{"HIGH05mod", 	"Real", 12, 7, False, , , , , , , null}
					}
	strct = strct + futfields
	ModifyTable(WHTS, strct)
	
	// Look Up 2005 "Modeled" Proportions
	BaseInc = OpenTable("BaseIncomeData", "CSV", {MainDir+"0_Param\\1_Data\\Base_Years_Income_Data.csv", })
	JV = JoinViews("WHTS+BaseInc", WHTS+".CO_ID", BaseInc+".CO_ID", )
	IncGroupLU = OpenTable("IncomeGroupLookup", "CSV", {MainDir+"0_Param\\2_LUT\\Income_Lookup.csv", })
	formula = "Round(RatioToReg00*20, 0)/20"
	expr = CreateExpression(JV, "RndRatioToReg", formula, )
	JV2 = JoinViews("WHTS+Base+IncLU-Base", JV+".RndRatioToReg", IncGroupLU+".RatioToBaseYearInc", )		

	L = GetDataVector(JV2+"|", "Lprop", )
	M = GetDataVector(JV2+"|", "Mprop", )
	H = GetDataVector(JV2+"|", "Hprop", )
	SetDataVector(JV2+"|", "LOW05mod", L, )
	SetDataVector(JV2+"|", "MED05mod", M, )
	SetDataVector(JV2+"|", "HIGH05mod", H, )
	CloseView(JV2)	
	
	dim years [futyears.length+1]
	years[1] = "10"
	for jj = 1 to futyears.length do
		years[jj+1] = futyears[jj]
	end
	
	for ii = 1 to years.length do	
		yr = years[ii]	
		
		// Calculate Future Year Income Ratio to 2010
		if yr = "10" then formula = "INCPC"+yr+" / INCPC05" else formula = "INCPC"+yr+" / INCPC10"
		expr = CreateExpression(JV, "Ratio10_"+yr, formula, )	
		
		// Calculate Ratio of Future Year to Regional 2000
		formula = "RatioToReg00 * Ratio10_"+yr
		expr = CreateExpression(JV, "Ratio2000"+yr, formula, )	
		
		// Look Up Future Year "Modeled" Proportions
		formula = "Min(Max(Round(RATIO2000"+yr+" * 20, 0)/20, 0.55), 1.95)"	// 0.55 and 1.95 are the extremes of the lookup table Income_Lookup.csv
		expr = CreateExpression(JV, "RndRATIO2000"+yr, formula, )
		JV2 = JoinViews("WHT+Base+IncLU-FUT"+yr, JV+".RndRATIO2000"+yr, IncGroupLU+".RatioToBaseYearInc", )

		// Calculate Change in Modeled Values
		formula = "Lprop / LOW05mod "
		expr = CreateExpression(JV2, "Lchg", formula, )		
		formula = "Mprop / MED05mod "
		expr = CreateExpression(JV2, "Mchg", formula, )	
		formula = "Hprop / HIGH05mod "
		expr = CreateExpression(JV2, "Hchg", formula, )			

		// Calculate Incremental Change
		formula = "Lchg * Lprop05 "
		expr = CreateExpression(JV2, "Lincr", formula, )
		formula = "Mchg * Mprop05 "
		expr = CreateExpression(JV2, "Mincr", formula, )	
		formula = "Hchg * Hprop05 "
		expr = CreateExpression(JV2, "Hincr", formula, )		

		// Calculate Normalized Change
		formula = "Lincr / (Lincr + Mincr + Hincr)"
		expr = CreateExpression(JV2, "Lnorm", formula, )
		formula = "Mincr / (Lincr + Mincr + Hincr)"
		expr = CreateExpression(JV2, "Mnorm", formula, )	
		formula = "Hincr / (Lincr + Mincr + Hincr)"
		expr = CreateExpression(JV2, "Hnorm", formula, )

		// Calculate Weights
		formula = "Lnorm / Lprop05"
		expr = CreateExpression(JV2, "WTLOW", formula, )
		SetRecordsValues(JV2+"|", {{"LOW"+yr}, }, "Formula", {expr}, )
		formula = "Mnorm / Mprop05"
		expr = CreateExpression(JV2, "WTMED", formula, )	
		SetRecordsValues(JV2+"|", {{"MED"+yr}, }, "Formula", {expr}, )
		formula = "Hnorm / Hprop05"
		expr = CreateExpression(JV2, "WTHIGH", formula, )	
		SetRecordsValues(JV2+"|", {{"HIGH"+yr}, }, "Formula", {expr}, )		

		CloseView(JV2)
		
		dim expfields[4+futyears.length*3]
		expfields[1]="CO_ID"
		expfields[2]="LOW10"
		expfields[3]="MED10"
		expfields[4]="HIGH10"
		for jj = 1 to futyears.length do
			expfields[3*(jj-1)+5] = "LOW"+futyears[jj]
			expfields[3*(jj-1)+6] = "MED"+futyears[jj]
			expfields[3*(jj-1)+7] = "HIGH"+futyears[jj]
		end
		// Export Weights
		ExportView(WHTS+"|", "DBASE", WDir+"Inc_Whts.dbf", expfields, )
		
	end	// Forecast Years
	CloseView(JV)
	return(retval)
	RunMacro("G30 File Close All")
endMacro

Macro "Level 1"(MainDir, InDir, WDir, OutDir)
 shared futyears
 shared nonresSEDgrowth
//====================================================
// LEVEL 1: SED-BASED WEIGHTS
//====================================================	
	retval = 1
	SurvIn = MainDir + "0_Param\\1_Data\\"
	SEDDir = InDir
	
	/////////////////////////////////////
	// STEP 1: OPEN AND JOIN INPUT FILES
	/////////////////////////////////////

		// Open 2010 Expanded Survey File
		InFile = OpenTable("Input File", "CSV", {SurvIn + "AIRPAX_SURVEY_2010.csv", })
		ExportView(InFile+"|", "FFB", WDir + "AIRPAX_Survey_Level_1.bin", , )
		L1 = OpenTable("Level 1", "FFB", {WDir + "AIRPAX_Survey_Level_1.bin", })
		L1view = L1+"|"

		// Add Fields
			Setview(L1)
			strct = GetTableStructure(L1)

			for i = 1 to strct.length do
				// Read in existing fields, adding field name to the end of each 
				strct[i] = strct[i] + {strct[i][1]}					
			end
			// New fields
			dim futfields[futyears.length*2]
			for j = 1 to futyears.length do	
				yr = futyears[j]
				futfields[j] = {"TRPWT1_"+yr, "Real", 12, 7, False, , , , , , , null}
				futfields[futyears.length+j] = {"FUT1_"+yr, "Real", 12, 7, False, , , , , , , null}
			end
			strct = strct +{{"OCO_MKT", 	"String", 6, 0, False, , , , , , , null}}
			strct = strct + futfields
			
			ModifyTable(L1, strct)

		OCO_MKT = GetDataVector(L1view, "oco_id", )
		MKT		= GetDataVector(L1view, "MARKET", )
		OCO_MKT	= trim(i2s(OCO_MKT)) + "_" + trim(i2s(MKT))
		SetDataVector(L1view, "OCO_MKT", OCO_MKT, )

		// Aggregate Table by County & Market
		AgSrv = AggregateTable("SurveyByMkt&Cty - Level 1", L1view, "FFB", WDir+"Level_1_Weights.bin", "OCO_MKT",
								{{"oco_id", "DOM", },
								 {"MARKET", "DOM", },
								 {"EXPF_10_PASS", "SUM", }
								 }, )

		Setview(AgSrv)
		strct = null
		strct = GetTableStructure(AgSrv)
		for i = 1 to strct.length do
			strct[i] = strct[i] + {strct[i][1]}
			if strct[i][1] = "EXPF_10_PASS" then strct[i][1] = "TRIPS10" 
			if strct[i][1] = "First oco_id" then strct[i][1] = "oco_id" 
			if strct[i][1] = "First MARKET" then strct[i][1] = "MARKET"
		end
		// New Fields
		strct = strct +{{"POP_GRP", 	"Real", 10, 3, False, , , , , , , null},
						{"ROOMS05", 	"Real", 10, 3, False, , , , , , , null},
						{"ROOMS10", 	"Real", 10, 3, False, , , , , , , null},
						{"MKTRATE", 	"Real", 10, 3, False, , , , , , , null},
						{"CTYMKT", 		"Integer", 10, 0, False, , , , , , , null}
						}	
		dim futfields[futyears.length*3]
		for j = 1 to futyears.length do	
			yr = futyears[j]
			futfields[j]				 	= {"ROOMS"+yr, 	"Real", 10, 3, False, , , , , , , null}
			futfields[futyears.length+j]	= {"TRIPS"+yr, 	"Real", 10, 3, False, , , , , , , null}
			futfields[2*futyears.length+j] 	= {"WHT"+yr+"_1", "Real", 10, 7, False, , , , , , , null}
		end

		strct = strct + futfields	
		ModifyTable(AgSrv, strct)	

		// Join W&P / MPO SED Data 
		SED = OpenTable("SED", "DBASE", {SEDDir + "SED_COUNTY.DBF", })
		JV = JoinViews("AgSrv+SED", AgSrv+".oco_id", SED+".CO_ID", )

		// Join Hotel Data (2010 Rooms per County)
		HOTEL = OpenTable("Hotels", "DBASE", {MainDir + "0_Param\\2_LUT\\HOTEL_RM_CTY.dbf", })
		JV2 = JoinViews("AgSrv+SED+Hotel",JV+".oco_id", HOTEL+".CO_ID", )

		// Join Future Year Real Income Growth Forecast Weights (Used in Hotel Room Forecasts & Level 2 Weighting)
		INC = OpenTable("Income Growth", "DBASE", {WDir + "INC_WHTS.dbf", })
		JV3 = JoinViews("AgSrv+SED+Hotel",JV2+".oco_id", INC+".CO_ID", )

	//////////////////////////////////////////////
	// STEP 2: APPLY HOTEL ROOM REGRESSION MODEL
	//////////////////////////////////////////////
		
		// Calculate Population Group Variable
		ROOMS = GetDataVector(JV3+"|", "ROOMS", )
		POPGRP = GetDataVector(JV3+"|", "POP10", )
		POPGRP = if POPGRP <= 250000 and ROOMS <= 500 then 1 else 
				 if POPGRP <= 250000 and ROOMS > 500 then 2 else 
				 if POPGRP > 250000 and POPGRP <= 500 then 3 else 
				 if POPGRP > 500000 and POPGRP <= 1000 then 4 else
				 if POPGRP >1000000 then 5 
		POPGRP = if ROOMS > 7500000 then 5 else POPGRP
		SetDataVector(JV3+"|", "POP_GRP", POPGRP, )
		
		// Join Hotel Regression Coefficients
		HTLREG = OpenTable("Hotel Regression Coeff", "CSV", {MainDir+"0_Param\\2_LUT\\Hotel_Regression_Coeff.csv", })
		JV4 = JoinViews("AgSrv+SED+Hotel+Coef", JV3+".POP_GRP", HTLREG+".POPGRP", )
		
		// Calculate Calibrated Constants (based on 2010 Rooms)
		const = CreateExpression(JV4, "constant", "max(ROOMS - (POP_C * POP10 + EMP_C * EMP10 + INCPC_C * INCPC10 + LOW_C * LOW10 + MED_C * MED10 + HIGH_C * HIGH10), 0)",)
		
		// Calculate Forecasts, with Calibrated Constants Weighted to Double the Estimated Coefficients
		
		dim fyears [futyears.length+2]
		fyears[1] = "05"
		fyears[2] = "10"
		for jj = 1 to futyears.length do
			fyears[jj+2] = futyears[jj]
		end
		
		for ii = 1 to fyears.length do
			yr = fyears[ii]
			
			// Weighted preliminary forecasts
			if yr = "05" then 
				formula = "POP_C * POP"+yr+" + EMP_C * EMP"+yr+" + INCPC_C * INCPC"+yr+" + " +
						  "LOW_C + MED_C + HIGH_C  + " + 
						  "constant * 2 * EMP"+yr+" / EMP10"

			else 
				formula = "POP_C * POP"+yr+" + EMP_C * EMP"+yr+" + INCPC_C * INCPC"+yr+" + " +
						  "LOW_C * LOW"+yr+" + MED_C * MED"+yr+" + HIGH_C * HIGH"+yr+" + " + 
						  "constant * 2 * EMP"+yr+" / EMP10"
			
			expr = CreateExpression(JV4, "RM"+yr, formula, )			
		end 
		
		for ii = 1 to fyears.length do
			if ii = 2 then continue // Skip for 2010
			yr = fyears[ii]
			
			// Increment Forecast Growth
			formula = "if ROOMS>0 AND RM10>0 then  ROOMS *  RM"+yr+" / RM10 else " +
					  "if ROOMS>0 and RM10<0 then  ROOMS + (RM"+yr+" - RM10) else RM"+yr
			expr = CreateExpression(JV4, "RMS"+yr, formula, )
			
			SetRecordsValues(JV4+"|", {{"ROOMS"+yr}, }, "Formula", {expr}, )
		end
		SetRecordsValues(JV4+"|", {{"ROOMS10"}, }, "Formula", {"RM10"}, )
		
		ROOMS = GetDataVector(JV4+"|", "ROOMS", )
		ROOMS05 = GetDataVector(JV4+"|", "ROOMS05", )
		ROOMS10 = GetDataVector(JV4+"|", "ROOMS10", )
		
		ROOMS10 = if ROOMS > 0 then ROOMS else ROOMS10
		ROOMS05 = if ROOMS05 < 0 then 0 else ROOMS05	
		ROOMS10 = if ROOMS05 > ROOMS10 then ROOMS05 else ROOMS10
		
		SetDataVector(JV4+"|", "ROOMS10", ROOMS10, )
		SetDataVector(JV4+"|", "ROOMS05", ROOMS05, )

		
	/////////////////////////////////////////////////////////////////
	// STEP 3: USE 2010 MARKET RATES TO CALCULATE FUTURE TRIP RATES
	/////////////////////////////////////////////////////////////////
		
		// 2010 Market Rates
		//		Note: Rates are calculated per 100,000 POP and EMP, and per 1000 hotel rooms.
		//		  	  POP and EMP are reported in 000's in SED_County, Hotel rooms are actual number of rooms.
		formula = "if MARKET = 11 or MARKET = 21 or MARKET = 31 or MARKET = 41 then 100 * TRIPS10 / POP10 else " +
				  "if MARKET = 12 or MARKET = 22 or MARKET = 32 or MARKET = 42 then 100 * TRIPS10 / EMP10 else " + 
				  "if MARKET = 33 or MARKET = 43 							   then 1000 * TRIPS10 / ROOMS10 else 0"
		expr = CreateExpression(JV4, "MKTRT", formula, )
		SetRecordsValues(JV4+"|", {{"MKTRATE"}, }, "Formula", {expr}, )
		
		// Future Year Trips
		for ii = 3 to fyears.length do	// only future years 
			yr = fyears[ii]

			formula = "if MARKET = 11 or MARKET = 21 or MARKET = 31 or MARKET = 41 then MKTRATE * POP"+yr+" / 100 else " +
				  	  "if MARKET = 12 or MARKET = 22 or MARKET = 32 or MARKET = 42 then MKTRATE * EMP"+yr+" / 100 else " + 
				      "if MARKET = 33 or MARKET = 43 							   then MKTRATE * ROOMS"+yr+" / 1000 else 0"
			expr = CreateExpression(JV4, "TRP"+yr, formula, )
			
			SetRecordsValues(JV4+"|", {{"TRIPS"+yr}, }, "Formula", {expr}, )
		end		

		CloseView(JV4)
		CloseView(JV3)
		CloseView(JV2)
		CloseView(JV)
		SetView(AgSrv)
		
	/////////////////////////////////////////////////////////////////
	// STEP 4: CALCULATE & APPLY LEVEL 1 WEIGHTS
	/////////////////////////////////////////////////////////////////	
		
		// Calculate Level 1 Weights -- by County & Market
		for ii = 3 to fyears.length do	// only future years 
			yr = fyears[ii]

			formula = "TRIPS"+yr+" / TRIPS10 "
			expr = CreateExpression(AgSrv, "WT"+yr, formula, )
			
			SetRecordsValues(AgSrv+"|", {{"WHT"+yr+"_1"}, }, "Formula", {expr}, )
		end		
		
		CTY = GetDataVector(AgSrv+"|", "oco_id", )
		MKT = GetDataVector(AgSrv+"|", "MARKET", )
		CTYMKT = CTY * 100 + MKT
		SetDataVector(AgSrv+"|", "CTYMKT", CTYMKT, )
		
		// Calculate Level 1 Weights for Sample Enumeration (by survey record)
		SetView(L1)		
		
		JV = JoinViews("Level1Surv+Whts", L1+".CTYMKT", AgSrv+".CTYMKT", )
		

		for ii = 3 to fyears.length do	// only future years 
			yr = fyears[ii]
			nonresrate = nonresSEDgrowth[ii-2] // global input
			
			OCO = GetDataVector(JV+"|", AgSrv+".oco_id", )
			WT = GetDataVector(JV+"|", "WHT"+yr+"_1", )
			WT = if OCO = 999 then nonresrate else WT
			SetDataVector(JV+"|", "TRPWT1_"+yr, WT, )
		
		end		
		
		PASS10 = GetDataVector(JV+"|", "EXPF_10_PASS", )
		
		// Apply Weights, Calculate Trips
		for ii = 3 to fyears.length do	// only future years
			yr = fyears[ii]
			
			TRWT = GetDataVector(JV+"|", "TRPWT1_"+yr, )
			TRWT = if TRWT = null then 1 else TRWT
			FUT = PASS10 * TRWT
			SetDataVector(JV+"|", "FUT1_"+yr, FUT, )
		
		end
		
		CloseView(JV)
		
		ExportView(L1+"|", "CSV", OutDir + "AIRPAX_Survey_Level_1.csv", , {{"CSV Header", "True"}})
		
		return(retval)
		
endMacro	// Level 1


Macro "Level 2"(MainDir, InDir, WDir, OutDir)
 shared futyears
 shared nonresINCgrowth
//====================================================
// LEVEL 2: REAL INCOME GROWTH
//====================================================	
	retval = 1
	SEDDir = InDir 
			
	L1 = OpenTable("Level 1", "FFB", {WDir + "AIRPAX_Survey_Level_1.bin", })
	ExportView(L1+"|", "FFB", WDir + "AIRPAX_Survey_Level_2.bin", , )
	CloseView(L1)		
	L2 = OpenTable("Level 2", "FFB", {WDir + "AIRPAX_Survey_Level_2.bin", })
			
	
	/////////////////////////////////////////////////////////////////
	// STEP 1: ADD FIELDS
	/////////////////////////////////////////////////////////////////
		
		Setview(L2)
		strct = GetTableStructure(L2)

		for i = 1 to strct.length do
			// Read in existing fields, adding field name to the end of each array
			strct[i] = strct[i] + {strct[i][1]}					
		end
		// New fields
		dim futfields[futyears.length]
		for j = 1 to futyears.length do
			futfields[j] = {"FUT2_"+futyears[j], 	"Real", 12, 3, False, , , , , , , null}
		end
		
		strct = strct + futfields

		ModifyTable(L2, strct)	
			
	/////////////////////////////////////////////////////////////////
	// STEP 2: JOIN LEVEL 2 WEIGHTS
	/////////////////////////////////////////////////////////////////	
		
		INC = OpenTable("Income Growth", "DBASE", {WDir + "INC_WHTS.dbf", })
		JV = JoinViews("L2+IncWhts",L2+".oco_id", INC+".CO_ID", )
						
		for ii = 1 to futyears.length do	
			yr = futyears[ii]
			
			LOW = GetDataVector(JV+"|", "LOW"+yr, )
			SetDataVector(JV+"|", "LOW"+yr, LOW, )
			MED = GetDataVector(JV+"|", "MED"+yr, )
			SetDataVector(JV+"|", "MED"+yr, MED, )
			HIH = GetDataVector(JV+"|", "HIGH"+yr, )
			SetDataVector(JV+"|", "HIGH"+yr, HIH, )
		
		end		
				
	/////////////////////////////////////////////////////////////////
	// STEP 3: APPLY LEVEL 2 WEIGHTS
	/////////////////////////////////////////////////////////////////	
		
		// Residents of the 54 Counties
		for ii = 1 to futyears.length do
			yr = futyears[ii]
			formula = "if INCGROUP = 1 and TRIPTYPE < 3 then FUT1_"+yr+" * LOW"+yr+" else " +
					  "if INCGROUP = 2 and TRIPTYPE < 3 then FUT1_"+yr+" * MED"+yr+" else " +
					  "if INCGROUP = 3 and TRIPTYPE < 3 then FUT1_"+yr+" * HIGH"+yr+" else 0"	  
			expr = CreateExpression(JV, "tempFUT2_"+yr, formula, )	
		end
		
		
		for ii = 1 to futyears.length do
			yr = futyears[ii]
			nonresgrowth = nonresINCgrowth[ii]

			formula = "if TRIPTYPE > 2 then FUT1_"+yr+" * "+r2s(nonresgrowth)+" else "+
				      "if TRIPTYPE < 3 and (INCGROUP >0) = 0 then FUT1_"+yr+" else tempFUT2_"+yr	  
			expr = CreateExpression(JV, "temp2FUT2_"+yr, formula, )
			SetRecordsValues(JV+"|", {{"FUT2_"+yr}, }, "Formula", {expr}, )	
			
		end	
		
		ExportView(L2+"|", "CSV", OutDir + "AIRPAX_Survey_Level_2.csv", , {{"CSV Header", "True"}})
		CloseView(JV)
		CloseView(L2)
		CloseView(INC)
		return(retval)
endMacro	
	
	
	
Macro "Level 3"(MainDir, InDir, WDir, OutDir)
 shared futyears
//====================================================
// LEVEL 3: CONTROL TO 9-AIRPORT ENPLANEMENT FORECASTS
//====================================================	
	retval = 1
	ENPDir = InDir 
			
	L2 = OpenTable("Level 2", "FFB", {WDir + "AIRPAX_Survey_Level_2.bin", })
	ExportView(L2+"|", "FFB", WDir + "AIRPAX_Survey_Level_3.bin", , )
	CloseView(L2)		
	L3 = OpenTable("Level 3", "FFB", {WDir + "AIRPAX_Survey_Level_3.bin", })
			
	
	/////////////////////////////////////////////////////////////////
	// STEP 1: ADD FIELDS
	/////////////////////////////////////////////////////////////////
		
		Setview(L3)
		strct = GetTableStructure(L3)

		for i = 1 to strct.length do
			// Read in existing fields, adding field name to the end of each array
			strct[i] = strct[i] + {strct[i][1]}					
		end
		// New fields
		dim futfields[futyears.length]
		for j = 1 to futyears.length do
			futfields[j] = {"FUT3_"+futyears[j], 	"Real", 12, 3, False, , , , , , , null}
		end
		
		strct = strct + futfields
		ModifyTable(L3, strct)	
		
	/////////////////////////////////////////////////////////////////
	// STEP 2: OPEN ENPLANEMENT FORECASTS, CALCULATE WEIGHT
	/////////////////////////////////////////////////////////////////
		
		ENPfcast = OpenTable("Enplanement Forecasts", "CSV", {ENPDir+"Enplanement_Forecasts.csv", })
		
		for ii = 1 to futyears.length do	
			yr = futyears[ii]
			
			EnpTarget = GetDataVector(ENPfcast+"|", "ENP"+yr, )
			TotEnpTarget = VectorStatistic(EnpTarget, "Sum", )
			
			EnpL2 = GetDataVector(L3+"|", "FUT2_"+yr, )
			TotEnpL2 = VectorStatistic(EnpL2, "Sum", )
			
			EnpL3 = EnpL2 * TotEnpTarget / TotEnpL2
			
			SetDataVector(L3+"|", "FUT3_"+yr, EnpL3, )
		
		end			
			
	
	ExportView(L3+"|", "CSV", OutDir + "AIRPAX_Survey_Level_3.csv", , {{"CSV Header", "True"}})
	closeview(L3)
	closeview(ENPfcast)
	return(retval)
endMacro	

Macro "Level 4"(MainDir, InDir, WDir, OutDir)
 shared futyears
//============================================================
// LEVEL 4: CONTROL TO INDIVIDUAL AIRPORT ENPLANEMENT FORECASTS
//============================================================	
	retval = 1
	ENPDir = InDir
			
	L3 = OpenTable("Level 3", "FFB", {WDir + "AIRPAX_Survey_Level_3.bin", })
	ExportView(L3+"|", "FFB", WDir + "AIRPAX_Survey_Level_4.bin", , )
	CloseView(L3)		
	L4 = OpenTable("Level 4", "FFB", {WDir + "AIRPAX_Survey_Level_4.bin", })
			
	
	/////////////////////////////////////////////////////////////////
	// STEP 1: ADD FIELDS
	/////////////////////////////////////////////////////////////////
		
		Setview(L4)
		strct = GetTableStructure(L4)

		for i = 1 to strct.length do
			// Read in existing fields, adding field name to the end of each array
			strct[i] = strct[i] + {strct[i][1]}					
		end
		// New fields
		dim futfields[futyears.length]
		for j = 1 to futyears.length do
			futfields[j] = {"FUT4_"+futyears[j], 	"Real", 12, 3, False, , , , , , , null}
		end
		
		strct = strct + futfields
		ModifyTable(L4, strct)		
		
	/////////////////////////////////////////////////////////////////
	// STEP 2: JOIN ENPLANEMENT FORECASTS, CALCULATE WEIGHTS
	/////////////////////////////////////////////////////////////////
		
		dim fldAg[futyears.length, 3]
		for ii = 1 to futyears.length do	
			yr = futyears[ii]
			fldAg[ii][1] = "FUT3_"+yr
			fldAg[ii][2] = "SUM"
			fldAg[ii][3] = null
			
		end
		
		// Calculate aggregate enplanements by airport, from Level 3
		AgL3 = AggregateTable("L3 Agg by Airport", L4+"|", "FFB", WDir+"Level3AggByAirport.bin", "APID", fldAg, )
		
		// Open Enplanment Forecasts
		ENPfcast = OpenTable("Enplanement Forecasts", "CSV", {ENPDir+"Enplanement_Forecasts.csv", })
		JV = JoinViews("L4+ENP", L4+".APID", ENPfcast+".APT", )
		JV2 = JoinViews("L4+ENP+AgL3", JV+".APID", AgL3+".APID", )
		
		for ii = 1 to futyears.length do	
			yr = futyears[ii]
			
			AptEnpTarget = GetDataVector(JV2+"|", "ENP"+yr, )	
			AptEnpL3 = GetDataVector(JV2+"|", AgL3+".FUT3_"+yr, )
			
			F3 = GetDataVector(JV2+"|", L4+".FUT3_"+yr, )
			
			EnpL4 = F3 * AptEnpTarget / AptEnpL3
			
			SetDataVector(L4+"|", "FUT4_"+yr, EnpL4, )
		
		end			
		
	ExportView(L4+"|", "CSV", OutDir + "AIRPAX_Survey_Level_4.csv", , {{"CSV Header", "True"}})
	return(retval)
endMacro	


