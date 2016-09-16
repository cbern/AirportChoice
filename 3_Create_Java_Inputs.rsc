///////////////////////////////////////////////////
//
//	3_CREATE_JAVA_INPUTS.RSC:
//
//	This script combines the weighted survey 
//  file with skims and airport data to create
//	the "build" and "base" input files for the 
//  Java switching model.
//
//	Chrissy Bernardo, September 2015
//
///////////////////////////////////////////////////


// Main macro to call steps of the process
Macro "Create Inputs Main"(Args)
	
	RunMacro("G30 File Close All")
	
	shared baseyear
	shared buildyear
	shared futyears
	shared Scen
	
	baseyear = Args.[Base Year]
	buildyear = Args.[Build Year]
	futyears = Args.[Weighting Years]
	
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
	

			if !RunMacro("Check Inputs", MainDir, InDir) then do stepname = "Check Skim Inputs" goto quit end

			if !RunMacro("Prepare Survey Data", MainDir, InDir, WDir+"3_Java_Inputs\\", OutDir+"3_Switching_Model\\1_In\\") then do stepname = "Prepare Survey Data" goto quit end
			
				RunMacro("close everything")
				
			if !RunMacro("Add Airport Attributes", MainDir, InDir, WDir+"3_Java_Inputs\\", OutDir+"3_Switching_Model\\1_In\\") then do stepname = "Add Airport Attributes" goto quit end
						
				RunMacro("close everything")
		
			if !RunMacro("Add Skim Values", MainDir, InDir, WDir+"3_Java_Inputs\\", OutDir+"3_Switching_Model\\1_In\\") then do stepname = "Add Skim Values" goto quit end
						
				RunMacro("close everything")
				
			if !RunMacro("Impute Missing Skim Values", MainDir, InDir, WDir+"3_Java_Inputs\\", OutDir+"3_Switching_Model\\1_In\\") then do stepname = "Impute Missing Skim Values" goto quit end
						
				RunMacro("close everything")				
		
			if !RunMacro("Finalize For Java", MainDir, InDir, WDir+"3_Java_Inputs\\", OutDir+"3_Switching_Model\\1_In\\") then do stepname = "Finalize For Java" goto quit end
						
				RunMacro("close everything")
 
	quit:
		if stepname <> null	then
			ShowMessage("Model failed at Step: "+stepname)
		else return(1)
endMacro

Macro "close everything"
    maps = GetMaps()
    if maps <> null then do
        for i = 1 to maps[1].length do
            SetMapSaveFlag(maps[1][i],"False")
            end
        end
    RunMacro("G30 File Close All")
 
EndMacro

Macro "Check Inputs"(MainDir, InDir)
 shared baseyear
 shared buildyear
 shared futyears
//====================================================
// 	CHECK INPUT FILES FOR BASE AND FUTURE YEARS 
//====================================================	 	
retval=1
basefound = 0
buildfound = 0

for ii = 1 to futyears.length do
	if futyears[ii] = i2s(baseyear-2000) then basefound = 1
	if futyears[ii] = i2s(buildyear-2000) then buildfound = 1
end

if baseyear = 0 then do
	retval = 0
	ShowMessage("Error: Base year ("+i2s(baseyear)+") not included in Level 1-4 Weighting Process")
end

if buildyear = 0 then do
	retval = 0
	ShowMessage("Error: Build year ("+i2s(buildyear)+") not included in Level 1-4 Weighting Process")
end
	

return(retval)
	
endMacro // Check Inputs


Macro "Prepare Survey Data"(MainDir, InDir, WDir, OutDir)

// ======================================================
//   Prepare Survey Data for Base/Build Files
// ======================================================
shared baseyear
shared buildyear
shared futyears
shared Scen

	/////////////////////////////////////////////////////
	// Export selected fields from weighted survey file
	/////////////////////////////////////////////////////
	WSurv = OpenTable("Weighted Survey", "CSV", {MainDir+"1_Scen\\"+Scen+"\\2_Outputs\\" + "1_Weights\\AIRPAX_Survey_Level_4.csv", })
			
	
	setview(WSurv)
	nbus = SelectByQuery("Business", "Several",  "Select * where tripurp = 1", )
	nnbus = SelectByQuery("NonBusiness", "Several",  "Select * where tripurp = 2", )
	
	if baseyear = 2010 then
		basefields = {"recno", "EXPF_10_PASS", "apid", "mode", "car", "dropoff", "othmode", "oco_id", "resident", "TRAVSIZE_R", "gen", "age", "incgroup", "income", "int_dest", "o_zip", "mod_per", "dest", "distanceEUC", "st_hr", "st_min", "ap_hr", "ap_min"}
	else
		basefields = {"recno", "FUT4_"+i2s(baseyear-2000), "apid", "mode", "car", "dropoff", "othmode", "oco_id", "resident", "TRAVSIZE_R", "gen", "age", "incgroup", "income", "int_dest", "o_zip", "mod_per", "dest", "distanceEUC", "st_hr", "st_min", "ap_hr", "ap_min"}
		
	if buildyear = 2010 then 
		buildfields = {"recno", "EXPF_10_PASS", "apid", "mode", "car", "dropoff", "othmode", "oco_id", "o_zip", "mod_per", "TRAVSIZE_R", "int_dest", "dest", "distanceEUC", "st_hr", "st_min", "ap_hr", "ap_min"}
	else
		buildfields = {"recno", "FUT4_"+i2s(buildyear-2000), "apid", "mode", "car", "dropoff", "othmode", "oco_id", "o_zip", "mod_per", "TRAVSIZE_R", "int_dest", "dest", "distanceEUC", "st_hr", "st_min", "ap_hr", "ap_min"}
	
	ExportView(WSurv+"|Business", "FFB", WDir+"Base_business.bin", basefields, )
	ExportView(WSurv+"|NonBusiness", "FFB", WDir+"Base_nonbusiness.bin", basefields, )
	
	ExportView(WSurv+"|Business", "FFB", WDir+"Build_business.bin", buildfields, )
	ExportView(WSurv+"|NonBusiness", "FFB", WDir+"Build_nonbusiness.bin", buildfields, )
	
	
	
	///////////////////////////////////////////////////
	// Re-code variables for use in switching model
	///////////////////////////////////////////////////	
	purposes = {"business", "nonbusiness"}
	for bb = 1 to purposes.length do
		
		// BASE FILE
		Base = OpenTable("Base", "FFB", {WDir+"Base_"+purposes[bb]+".bin", })
		strct = null
		strct = GetTableStructure(Base)

		for i = 1 to strct.length do
			// Read in existing fields, adding field name to the end of each 
			strct[i] = strct[i] + {strct[i][1]}					
		end

		// New fields
		strct = strct +{{"weight", 	 "Real", 12, 4, False, , , , , , , null},
						{"airport",  "Integer", 5, 0, False, , , , , , , null},
						{"occ", 	 "Integer", 5, 0, False, , , , , , , null},
						{"female", 	 "Integer", 5, 0, False, , , , , , , null},
						{"othgen", 	 "Integer", 5, 0, False, , , , , , , null},
						{"manhattn", "Integer", 5, 0, False, , , , , , , null},
						{"agelow", 	 "Integer", 5, 0, False, , , , , , , null},
						{"agehigh",  "Integer", 5, 0, False, , , , , , , null},
						{"ageref", 	 "Integer", 5, 0, False, , , , , , , null},
						{"incref", 	 "Integer", 5, 0, False, , , , , , , null},
						{"inclow", 	 "Integer", 5, 0, False, , , , , , , null},
						{"inchigh",	 "Integer", 5, 0, False, , , , , , , null},
						{"smprty", 	 "Integer", 5, 0, False, , , , , , , null},
						{"lgprty", 	 "Integer", 5, 0, False, , , , , , , null},
						{"ZIP", 	 "Integer", 5, 0, False, , , , , , , null}}

		ModifyTable(Base, strct)

		if baseyear = 2010 then 
			weight = GetDataVector(Base+"|", "EXPF_10_PASS", )
		else
			weight = GetDataVector(Base+"|", "FUT4_"+i2s(baseyear-2000), )		
		
		SetDataVector(Base+"|", "weight", weight, )	

		airport = GetDataVector(Base+"|", "apid", )
		SetDataVector(Base+"|", "airport", airport, )		

		occ = GetDataVector(Base+"|", "TRAVSIZE_R", )
		SetDataVector(Base+"|", "occ", occ, )		

		resident = GetDataVector(Base+"|", "resident", )
		resident = if resident = 1 or resident = 2 then 1 else 0
		SetDataVector(Base+"|", "resident", resident, )

		female = GetDataVector(Base+"|", "gen", )
		female = if female > 0 then female - 1 else 0 // originally, gen = 1 if Male, 2 if Female
		SetDataVector(Base+"|", "female", female, )	

		othgen = GetDataVector(Base+"|", "gen", )
		othgen = if othgen = 0 then 1 else 0
		SetDataVector(Base+"|", "othgen", othgen, )		

		manhattn = GetDataVector(Base+"|", "oco_id", )
		manhattn = if manhattn = 1 then 1 else 0
		SetDataVector(Base+"|", "manhattn", manhattn, )	

		age = GetDataVector(Base+"|", "age", )
		agelow = age
		agelow = if agelow < 3 then 1 else 0
		SetDataVector(Base+"|", "agelow", agelow, )	

		agehigh = age
		agehigh = if agehigh > 4 and agehigh < 8 then 1 else 0
		SetDataVector(Base+"|", "agehigh", agehigh, )	

		ageref = age
		ageref = if ageref = 8 then 1 else 0 
		SetDataVector(Base+"|", "ageref", ageref, )		

		inc = GetDataVector(Base+"|", "income", )
		incref = inc
		incref = if incref = 0 then 1 else 0
		SetDataVector(Base+"|", "incref", incref, )	

		inclow = inc
		inclow = if inclow = 1 or inclow = 2 or inclow = 3 then 1 else 0
		SetDataVector(Base+"|", "inclow", inclow, )		

		inchigh = inc
		inchigh = if inchigh >= 8 then 1 else 0
		SetDataVector(Base+"|", "inchigh", inchigh, )

		smprty = GetDataVector(Base+"|", "TRAVSIZE_R", )
		smprty = if smprty <= 3 and smprty > 1 then 1 else 0 // replicate logic for estimation data
		SetDataVector(Base+"|", "smprty", smprty, )	

		lgprty = GetDataVector(Base+"|", "TRAVSIZE_R", )
		lgprty = if lgprty >= 4 then 1 else 0
		SetDataVector(Base+"|", "lgprty", lgprty, )	

		int_dest = GetDataVector(Base+"|", "int_dest", )
		SetDataVector(Base+"|", "int_dest", int_dest, )	
		
		// Pick up corrected zipcode for joining skims
		zipLU = OpenTable("ZipLookUp", "CSV", {MainDir+"0_Param\\2_LUT\\ZIPcode.csv", })
		JV = JoinViews("Base+Zip", Base+".o_zip", zipLU+".o_zip", )
		fixedzip = GetDataVector(JV+"|", "PZIP5", )
		SetDataVector(JV+"|", "ZIP", fixedzip, )
		closeview(JV)

		closeview(Base)

		// BUILD FILE
		Build = OpenTable("Build", "FFB", {WDir+"Build_"+purposes[bb]+".bin", })
		strct = null
		strct = GetTableStructure(Build)

		for i = 1 to strct.length do
			// Read in existing fields, adding field name to the end of each 
			strct[i] = strct[i] + {strct[i][1]}					
		end

		// New fields
		strct = strct +{{"weight", 	 "Real", 12, 4, False, , , , , , , null},
						{"occ", "Integer", 5, 0, False, , , , , , , null},
						{"airport", "Integer", 5, 0, False, , , , , , , null},
						{"ZIP", "Integer", 5, 0, False, , , , , , , null}}

		ModifyTable(Build, strct)

		if buildyear = 2010 then 
			weight = GetDataVector(Build+"|", "EXPF_10_PASS", )
		else
			weight = GetDataVector(Build+"|", "FUT4_"+i2s(buildyear-2000), )

		SetDataVector(Build+"|", "weight", weight, )	
		

		airport = GetDataVector(Build+"|", "apid", )
		SetDataVector(Build+"|", "airport", airport, )				
		
		int_dest = GetDataVector(Build+"|", "int_dest", )
		SetDataVector(Build+"|", "int_dest", int_dest, )
		
		occ = GetDataVector(Build+"|", "TRAVSIZE_R", )
		SetDataVector(Build+"|", "occ", occ, )	
				
		// Pick up corrected zipcode for joining skims
		zipLU = OpenTable("ZipLookUp", "CSV", {MainDir+"0_Param\\2_LUT\\ZIPcode.csv", })
		JV = JoinViews("Base+Zip", Build+".o_zip", zipLU+".o_zip", )
		fixedzip = GetDataVector(JV+"|", "PZIP5", )
		SetDataVector(JV+"|", "ZIP", fixedzip, )
		closeview(JV)				

		closeview(Build)

	end //loop over purposes (bus/nonbus)
	
	
	retval = 1
	quit:
		return(retval)
Endmacro // Prepare Survey Data

Macro "Add Airport Attributes"(MainDir, InDir, WDir, OutDir)
shared Scen			
// ======================================================
//   Add Airport-Specific Attributes to Survey/Base File
// ======================================================
	
	AptNodes = OpenTable("AptNodes", "CSV", {MainDir+"\\3_RunBin\\2_Skims\\Airport_Nodes.csv", })
	airname = v2a(GetDataVector(AptNodes+"|", "AIRPORT", ))	
	APID = GetDataVector(AptNodes+"|", "AIR_NY", )	
	
	airfields = null
	// Define new airport attribute fields
	for a = 1 to APID.length do
		airfields = airfields + {{"avgyld"+i2s(APID[a]), "Real", 12, 4, False, , , , , , , null},	 // Airport Data
								 {"parkcst"+i2s(APID[a]), "Real", 12, 4, False, , , , , , , null},
								 {"domflts"+i2s(APID[a]), "Real", 12, 4, False, , , , , , , null},
								 {"inlflts"+i2s(APID[a]), "Real", 12, 4, False, , , , , , , null},
								 {"odomflts"+i2s(APID[a]), "Real", 12, 4, False, , , , , , , null},
								 {"oinlflts"+i2s(APID[a]), "Real", 12, 4, False, , , , , , , null},
								 {"gauge"+i2s(APID[a]), "Real", 12, 4, False, , , , , , , null},
								 {"avgdely"+i2s(APID[a]), "Real", 12, 4, False, , , , , , , null},
								 {"inumapt"+i2s(APID[a]), "Real", 12, 4, False, , , , , , , null},
								 {"airtrn"+i2s(APID[a]), "Real", 12, 4, False, , , , , , , null},
								 {"avgfare"+i2s(APID[a]), "Real", 12, 4, False, , , , , , , null},
								 
								 {"sflaflts"+i2s(APID[a]), "Real", 12, 4, False, , , , , , , null},	// Flights to major destinations
								 {"losaflts"+i2s(APID[a]), "Real", 12, 4, False, , , , , , , null},
								 {"mcoflts"+i2s(APID[a]), "Real", 12, 4, False, , , , , , , null},
								 {"chiflts"+i2s(APID[a]), "Real", 12, 4, False, , , , , , , null},
								 {"bayaflts"+i2s(APID[a]), "Real", 12, 4, False, , , , , , , null},
								 {"lhrflts"+i2s(APID[a]), "Real", 12, 4, False, , , , , , , null},
								 {"atlflts"+i2s(APID[a]), "Real", 12, 4, False, , , , , , , null},
								 {"baltflts"+i2s(APID[a]), "Real", 12, 4, False, , , , , , , null},
								 {"tpaflts"+i2s(APID[a]), "Real", 12, 4, False, , , , , , , null},
								 {"lasflts"+i2s(APID[a]), "Real", 12, 4, False, , , , , , , null},
								 {"rswflts"+i2s(APID[a]), "Real", 12, 4, False, , , , , , , null},
								 {"bosflts"+i2s(APID[a]), "Real", 12, 4, False, , , , , , , null},
								 {"dfwflts"+i2s(APID[a]), "Real", 12, 4, False, , , , , , , null},
								 {"dtwflts"+i2s(APID[a]), "Real", 12, 4, False, , , , , , , null},
								 {"sjuflts"+i2s(APID[a]), "Real", 12, 4, False, , , , , , , null},
								 {"phxflts"+i2s(APID[a]), "Real", 12, 4, False, , , , , , , null},
								 {"denflts"+i2s(APID[a]), "Real", 12, 4, False, , , , , , , null},
								 {"mspflts"+i2s(APID[a]), "Real", 12, 4, False, , , , , , , null},
								 {"bufflts"+i2s(APID[a]), "Real", 12, 4, False, , , , , , , null},
								 {"myrflts"+i2s(APID[a]), "Real", 12, 4, False, , , , , , , null},
								 {"yyzflts"+i2s(APID[a]), "Real", 12, 4, False, , , , , , , null},
								 {"rduflts"+i2s(APID[a]), "Real", 12, 4, False, , , , , , , null},
								 {"msyflts"+i2s(APID[a]), "Real", 12, 4, False, , , , , , , null},
								 {"seaflts"+i2s(APID[a]), "Real", 12, 4, False, , , , , , , null},
								 {"stlflts"+i2s(APID[a]), "Real", 12, 4, False, , , , , , , null},
								 {"housflts"+i2s(APID[a]), "Real", 12, 4, False, , , , , , , null},
								 
								 {"whudson"+i2s(APID[a]), "Real", 12, 4, False, , , , , , , null},	// River Xing Data
								 {"ehudson"+i2s(APID[a]), "Real", 12, 4, False, , , , , , , null},
								 {"delwr"+i2s(APID[a]), "Real", 12, 4, False, , , , , , , null}}
	end
	
	airfields = airfields + 	{   {"sfladest", "Real", 12, 4, False, , , , , , , null},	// Flight Data
									{"losadest", "Real", 12, 4, False, , , , , , , null},
									{"mcodest", "Real", 12, 4, False, , , , , , , null},
									{"chidest", "Real", 12, 4, False, , , , , , , null},
									{"bayadest", "Real", 12, 4, False, , , , , , , null},
									{"lhrdest", "Real", 12, 4, False, , , , , , , null},
									{"atldest", "Real", 12, 4, False, , , , , , , null},
									{"baltdest", "Real", 12, 4, False, , , , , , , null},
									{"tpadest", "Real", 12, 4, False, , , , , , , null},
									{"lasdest", "Real", 12, 4, False, , , , , , , null},
									{"rswdest", "Real", 12, 4, False, , , , , , , null},
									{"bosdest", "Real", 12, 4, False, , , , , , , null},
									{"dfwdest", "Real", 12, 4, False, , , , , , , null},
									{"dtwdest", "Real", 12, 4, False, , , , , , , null},
									{"sjudest", "Real", 12, 4, False, , , , , , , null},
									{"phxdest", "Real", 12, 4, False, , , , , , , null},
									{"dendest", "Real", 12, 4, False, , , , , , , null},
									{"mspdest", "Real", 12, 4, False, , , , , , , null},
									{"bufdest", "Real", 12, 4, False, , , , , , , null},
									{"myrdest", "Real", 12, 4, False, , , , , , , null},
									{"yyzdest", "Real", 12, 4, False, , , , , , , null},
									{"rdudest", "Real", 12, 4, False, , , , , , , null},
									{"msydest", "Real", 12, 4, False, , , , , , , null},
									{"seadest", "Real", 12, 4, False, , , , , , , null},
									{"stldest", "Real", 12, 4, False, , , , , , , null},
									{"housdest", "Real", 12, 4, False, , , , , , , null},
									{"othdest", "Real", 12, 4, False, , , , , , , null}}
	
	ref = { "base","build"}
	
	RivXing = OpenTable("River Crossings", "CSV", {MainDir + "0_Param\\2_LUT\\River_Crossings.csv", })
	
	for ii = 1 to ref.length do
	
		AptData = OpenTable("Airport Data", "CSV", {InDir + "4_Airport_Data\\Airport_Data_"+ref[ii]+".csv", })
		YldData = OpenTable("Yield Data", "CSV", {InDir + "4_Airport_Data\\Airport_Yield_"+ref[ii]+".csv", })
		
		purposes={"business", "nonbusiness"}
		for bb = 1 to purposes.length do // purposes

			Surv = OpenTable("SurveyFile", "FFB", {WDir+ref[ii]+"_"+purposes[bb]+".bin", })
			
			// Add airport data fields
			strct = null
			strct = GetTableStructure(Surv)
			for i = 1 to strct.length do 
				strct[i] = strct[i] + {strct[i][1]}					
			end
			strct = strct + airfields
			
			ModifyTable(Surv, strct)
			
			// Calculate destination indicator variables
			dest = GetDataVector(Surv+"|", "dest", )
			dest = if dest = "MIA" or dest = "FLL" or dest = "PBI" then 1 else 0
			SetDataVector(Surv+"|", "sfladest", dest, )	
			
			dest = GetDataVector(Surv+"|", "dest", )
			dest = if dest = "LAX" or dest = "LGB" or dest = "BUR" or dest = "SNA" or dest = "ONT" then 1 else 0
			SetDataVector(Surv+"|", "losadest", dest, )				
			
			dest = GetDataVector(Surv+"|", "dest", )
			dest = if dest = "MCO" then 1 else 0
			SetDataVector(Surv+"|", "mcodest", dest, )				
			
			dest = GetDataVector(Surv+"|", "dest", )
			dest = if dest = "ORD" or dest = "MDW" then 1 else 0
			SetDataVector(Surv+"|", "chidest", dest, )		
			
			dest = GetDataVector(Surv+"|", "dest", )
			dest = if dest = "SFO" or dest = "SJC" or dest = "OAK" then 1 else 0
			SetDataVector(Surv+"|", "bayadest", dest, )	
			
			dest = GetDataVector(Surv+"|", "dest", )
			dest = if dest = "LHR" then 1 else 0
			SetDataVector(Surv+"|", "lhrdest", dest, )	
			
			dest = GetDataVector(Surv+"|", "dest", )
			dest = if dest = "ATL" then 1 else 0
			SetDataVector(Surv+"|", "atldest", dest, )
			
			dest = GetDataVector(Surv+"|", "dest", )
			dest = if dest = "BWI" or dest = "DCA" or dest = "IAD" then 1 else 0
			SetDataVector(Surv+"|", "baltdest", dest, )	
			
			dest = GetDataVector(Surv+"|", "dest", )
			dest = if dest = "TPA" then 1 else 0
			SetDataVector(Surv+"|", "tpadest", dest, )		
			
			dest = GetDataVector(Surv+"|", "dest", )
			dest = if dest = "LAS" then 1 else 0
			SetDataVector(Surv+"|", "lasdest", dest, )			
			
			dest = GetDataVector(Surv+"|", "dest", )
			dest = if dest = "BOS" then 1 else 0
			SetDataVector(Surv+"|", "bosdest", dest, )
			
			dest = GetDataVector(Surv+"|", "dest", )
			dest = if dest = "RSW" then 1 else 0
			SetDataVector(Surv+"|", "rswdest", dest, )
			
			dest = GetDataVector(Surv+"|", "dest", )
			dest = if dest = "DFW" then 1 else 0
			SetDataVector(Surv+"|", "dfwdest", dest, )			
			
			dest = GetDataVector(Surv+"|", "dest", )
			dest = if dest = "DTW" then 1 else 0
			SetDataVector(Surv+"|", "dtwdest", dest, )		
			
			dest = GetDataVector(Surv+"|", "dest", )
			dest = if dest = "SJU" then 1 else 0
			SetDataVector(Surv+"|", "sjudest", dest, )	
			
			dest = GetDataVector(Surv+"|", "dest", )
			dest = if dest = "PHX" then 1 else 0
			SetDataVector(Surv+"|", "phxdest", dest, )
			
			dest = GetDataVector(Surv+"|", "dest", )
			dest = if dest = "DEN" then 1 else 0
			SetDataVector(Surv+"|", "dendest", dest, )			
			
			dest = GetDataVector(Surv+"|", "dest", )
			dest = if dest = "MSP" then 1 else 0
			SetDataVector(Surv+"|", "mspdest", dest, )			
			
			dest = GetDataVector(Surv+"|", "dest", )
			dest = if dest = "BUF" then 1 else 0
			SetDataVector(Surv+"|", "bufdest", dest, )
			
			dest = GetDataVector(Surv+"|", "dest", )
			dest = if dest = "MYR" then 1 else 0
			SetDataVector(Surv+"|", "myrdest", dest, )	
			
			dest = GetDataVector(Surv+"|", "dest", )
			dest = if dest = "YYZ" then 1 else 0
			SetDataVector(Surv+"|", "yyzdest", dest, )	
			
			dest = GetDataVector(Surv+"|", "dest", )
			dest = if dest = "RDU" then 1 else 0
			SetDataVector(Surv+"|", "rdudest", dest, )
			
			dest = GetDataVector(Surv+"|", "dest", )
			dest = if dest = "MSY" then 1 else 0
			SetDataVector(Surv+"|", "msydest", dest, )			
			
			dest = GetDataVector(Surv+"|", "dest", )
			dest = if dest = "SEA" then 1 else 0
			SetDataVector(Surv+"|", "seadest", dest, )	
			
			dest = GetDataVector(Surv+"|", "dest", )
			dest = if dest = "STL" then 1 else 0
			SetDataVector(Surv+"|", "stldest", dest, )	
			
			dest = GetDataVector(Surv+"|", "dest", )
			dest = if dest = "IAH" or dest = "HOU" then 1 else 0
			SetDataVector(Surv+"|", "housdest", dest, )		
			
			expr = CreateExpression(Surv, "othdesttemp", "if dest <> \"IAH\" and dest <> \"STL\"  and dest <> \"SEA\" "+
																	   "and dest <> \"MSY\" and dest <> \"RDU\"  and dest <> \"YYZ\" "+	
																	   "and dest <> \"MYR\" and dest <> \"BUF\"  and dest <> \"MSP\" "+	
																	   "and dest <> \"DEN\" and dest <> \"PHX\"  and dest <> \"SJU\" "+	
																	   "and dest <> \"DTW\" and dest <> \"DFW\"  and dest <> \"RSW\" "+	
																	   "and dest <> \"BOS\" and dest <> \"LAS\"  and dest <> \"TPA\" "+	
																	   "and dest <> \"BWI\" and dest <> \"DCA\"  and dest <> \"IAD\" "+	
																	   "and dest <> \"LHR\" and dest <> \"ATL\"  and dest <> \"MCO\" "+	
																	   "and dest <> \"SFO\" and dest <> \"SJC\"  and dest <> \"OAK\" "+
																	   "and dest <> \"ORD\" and dest <> \"MDW\"  and dest <> \"LAX\" "+	
																	   "and dest <> \"LGB\" and dest <> \"SNA\"  and dest <> \"BUR\" "+	
																	   "and dest <> \"ONT\" and dest <> \"MIA\"  and dest <> \"FLL\" "+	
																	   "and dest <> \"PBI\" and dest <> \"HOU\" then 1 else 0"	, )
			SetRecordsValues(Surv+"|", {{"othdest"}, }, "Formula", {expr}, )				
			
			
			// Fill airport-specific data from external file (airport characteristics + flights)
			aptflds = {"parkcst", "domflts", "inlflts", "odomflts", "oinlflts", "gauge", "avgdely", "inumapt", "airtrn",
						"sflaflts", "losaflts",  "mcoflts",  "chiflts", "bayaflts",  "lhrflts",  "atlflts", 
						"baltflts",  "tpaflts",  "lasflts",  "rswflts",  "bosflts",  "dfwflts",  "dtwflts",  
						"sjuflts",  "phxflts",  "denflts",  "mspflts",  "bufflts",  "myrflts",  "yyzflts",  
						"rduflts",  "msyflts",  "seaflts",  "stlflts", "housflts"}

			for ff = 1 to aptflds.length do
				for aa = 1 to APID.length do
					
					fldname = aptflds[ff] + i2s(APID[aa])
					
					rh = LocateRecord(AptData+"|", "APID", {APID[aa]}, {{"Exact", "True"}})
					val = GetRecordValues(AptData, rh, {aptflds[ff]})
					
					SetRecordsValues(Surv+"|", {{fldname}, }, "Value", {val[1][2]}, )	
					
				end
			end
			
			
			// Fill airport-specific average yield and fare data from lookup
			
			recs = GetDataVector(YldData+"|", "intnl", )
			rh = GetFirstRecord(YldData+"|", )
			
			for rr = 1 to recs.length do
				
				intv = GetRecordValues(YldData, rh, {"Intnl"})
				dlov = GetRecordValues(YldData, rh, {"DistLo"})
				dhiv = GetRecordValues(YldData, rh, {"DistHi"})
				
				int = intv[1][2]
				dlo = dlov[1][2]
				dhi = dhiv[1][2]
				
				SetView(Surv)
				numrecs = SelectbyQuery("Intl:"+i2s(int)+" Lo:"+i2s(dlo)+" Hi:"+i2s(dhi), "Several",  
							"Select * where Int_dest=" + i2s(int) + "and DistanceEUC >= " + i2s(round(dlo,0)) + " and DistanceEUC <= " + i2s(round(dhi,0)), )
				
				for aa = 1 to APID.length do
					
					yldv = GetRecordValues(YldData, rh, {"Yield"+i2s(APID[aa])})
					yld = yldv[1][2] / 100
					
					SetRecordsValues(Surv+"|Intl:"+i2s(int)+" Lo:"+i2s(dlo)+" Hi:"+i2s(dhi), {{"avgyld"+i2s(APID[aa])}, }, "Value", {yld}, )
					
				end
				
				if rr = recs.length then continue else rh = GetNextRecord(YldData+"|", rh, )
				
			end
			
			for aa = 1 to APID.length do
				expr = CreateExpression(Surv, "faretemp"+i2s(APID[aa]), "if DistanceEUC >0 then avgyld"+i2s(APID[aa]) + " * DistanceEUC * occ else avgyld"+i2s(APID[aa]) + " * 50 * occ", ) // Assume 50 miles for fare calculation for records where Distance is 0 / missing
				SetRecordsValues(Surv+"|", {{"avgfare"+i2s(APID[aa])}, }, "Formula", {expr}, )			
			end
			
			
			// Fill river-crossing data from lookup table					
			riverflds = {"whudson", "ehudson", "delwr"}
			
			JV = JoinViews("Surv+Riv", Surv+".oco_id", RivXing+".county", )
			
			for rr = 1 to riverflds.length do
				for aa = 1 to APID.length do
					fldname = riverflds[rr] + i2s(APID[aa])
					SetRecordsValues(JV+"|", {{fldname}, }, "Formula", {riverflds[rr] + "_" + i2s(APID[aa])}, )
				end
			end
			
			closeview(JV)	
			
			// Remove DEST field (Java cannot take string variables)
			strct = GetTableStructure(Surv)
			dim modstrct [strct.length - 1]
			n = 1
			for i = 1 to strct.length do
				fldname = strct[i][1]
				if fldname <> "dest" then do
					modstrct[n] = strct[i] + {fldname}		
					n = n +1
				end
			end
			ModifyTable(Surv, modstrct)			
			
			closeview(Surv)

		end //purposes (bus1/nonbus2)
		closeview(AptData)
		closeview(YldData)
		
	end // build/base files
	
	closeview(RivXing)
	
	retval = 1
	quit:
		return(retval)
Endmacro // Add Airport Attributes


Macro "Add Skim Values"(MainDir, InDir, WDir, OutDir)

// ======================================================
//   Add Skim Values to Base/Build Files
// ======================================================
shared baseyear
shared buildyear
shared futyears
shared Scen
retval = 0

	AptNodes = OpenTable("AptNodes", "CSV", {MainDir+"\\3_RunBin\\2_Skims\\Airport_Nodes.csv", })
	airname = v2a(GetDataVector(AptNodes+"|", "AIRPORT", ))	
	APID = v2a(GetDataVector(AptNodes+"|", "AIR_NY", ))	
	closeview(AptNodes)
	
	ref = { "base","build"}
	TODarray = {"AM","MD","PM","NT"}
	
	for ii = 1 to ref.length do
		
		HwyAM = OpenTable("HwyAM", "DBASE", {MainDir+"1_Scen\\"+Scen+"\\2_Outputs\\2_Skims\\"+ref[ii]+"\\1_Hwy\\AM_Skim_All_Areas.dbf", })
		HwyMD = OpenTable("HwyMD", "DBASE", {MainDir+"1_Scen\\"+Scen+"\\2_Outputs\\2_Skims\\"+ref[ii]+"\\1_Hwy\\MD_Skim_All_Areas.dbf", })
		HwyPM = OpenTable("HwyPM", "DBASE", {MainDir+"1_Scen\\"+Scen+"\\2_Outputs\\2_Skims\\"+ref[ii]+"\\1_Hwy\\PM_Skim_All_Areas.dbf", })
		HwyNT = OpenTable("HwyNT", "DBASE", {MainDir+"1_Scen\\"+Scen+"\\2_Outputs\\2_Skims\\"+ref[ii]+"\\1_Hwy\\NT_Skim_All_Areas.dbf", })
		HwySkims = {HwyAM, HwyMD, HwyPM, HwyNT}
		
		TrnAM = OpenTable("TrnAM", "DBASE", {MainDir+"1_Scen\\"+Scen+"\\2_Outputs\\2_Skims\\"+ref[ii]+"\\2_Trn\\AM_ZIP_INFIELDS.dbf", })
		TrnMD = OpenTable("TrnMD", "DBASE", {MainDir+"1_Scen\\"+Scen+"\\2_Outputs\\2_Skims\\"+ref[ii]+"\\2_Trn\\MD_ZIP_INFIELDS.dbf", })
		TrnSkims = {TrnAM, TrnMD}
	
		purposes = {"business", "nonbusiness"}
		for bb = 1 to purposes.length do // purposes	
			
			Surv = OpenTable("SurveyFile", "FFB", {WDir+ref[ii]+"_"+purposes[bb]+".bin", })
		
			for aa = 1 to APID.length do

				// Add fields
				strct = null
				strct = GetTableStructure(Surv)
				for i = 1 to strct.length do
					strct[i] = strct[i] + {strct[i][1]}					
				end
				strct = strct +{{"hwytime"+i2s(APID[aa]), 	 "Real", 12, 4, False, , , , , , , null},
								{"hwytoll"+i2s(APID[aa]), 	 "Real", 12, 4, False, , , , , , , null},
								{"hwydist"+i2s(APID[aa]), 	 "Real", 12, 4, False, , , , , , , null},
								{"lbtime"+i2s(APID[aa]), 	 "Real", 12, 4, False, , , , , , , null},
								{"lbfare"+i2s(APID[aa]), 	 "Real", 12, 4, False, , , , , , , null},
								{"lbusiw"+i2s(APID[aa]), 	 "Real", 12, 4, False, , , , , , , null},
								{"lbusxw"+i2s(APID[aa]), 	 "Real", 12, 4, False, , , , , , , null},
								{"lbusac"+i2s(APID[aa]), 	 "Real", 12, 4, False, , , , , , , null},
								{"raltime"+i2s(APID[aa]), 	 "Real", 12, 4, False, , , , , , , null},
								{"ralfare"+i2s(APID[aa]), 	 "Real", 12, 4, False, , , , , , , null},
								{"railiw"+i2s(APID[aa]), 	 "Real", 12, 4, False, , , , , , , null},
								{"railxw"+i2s(APID[aa]), 	 "Real", 12, 4, False, , , , , , , null},
								{"railac"+i2s(APID[aa]), 	 "Real", 12, 4, False, , , , , , , null},
								{"cbtime"+i2s(APID[aa]), 	 "Real", 12, 4, False, , , , , , , null},
								{"cbfare"+i2s(APID[aa]), 	 "Real", 12, 4, False, , , , , , , null},
								{"cbusiw"+i2s(APID[aa]), 	 "Real", 12, 4, False, , , , , , , null},
								{"cbusxw"+i2s(APID[aa]), 	 "Real", 12, 4, False, , , , , , , null},
								{"cbusac"+i2s(APID[aa]), 	 "Real", 12, 4, False, , , , , , , null},
								{"txfare"+i2s(APID[aa]), 	 "Real", 12, 4, False, , , , , , , null},
								{"srcost"+i2s(APID[aa]), 	 "Real", 12, 4, False, , , , , , , null}}
				ModifyTable(Surv, strct)	

				for dd = 1 to TODarray.length do
					
					Hwy = HwySkims[dd]
					Trn = if dd = 1 or dd = 2 then TrnSkims[dd] else if dd = 3 then TrnSkims[1] else if dd = 4 then TrnSkims[2]
					
					JVhw   = JoinViews("Surv+"+Hwy, Surv+".zip", Hwy+".PZIP5", )
					JVhwtr = JoinViews("Surv+"+Hwy+"+"+Trn, JVhw+".zip", Trn+".PZIP5", )
					
					SetView(JVhwtr)
					selname = TODarray[dd]+"records"
					n = SelectbyQuery(selname, "Several",  "Select * where mod_per=" + i2s(dd), )
					
					/////////////////////////////
					// Highway & Transit Skims
					/////////////////////////////
										
					hwytime = GetDataVector(JVhwtr+"|"+selname, Hwy+".hwytime"+i2s(APID[aa]), )
					SetDataVector(JVhwtr+"|"+selname, Surv+".hwytime"+i2s(APID[aa]), hwytime, )	
					
					hwytoll = GetDataVector(JVhwtr+"|"+selname, Hwy+".hwytoll"+i2s(APID[aa]), )
					hwytoll = hwytoll / 100 // Convert from cents to dollars
					SetDataVector(JVhwtr+"|"+selname, Surv+".hwytoll"+i2s(APID[aa]), hwytoll, )	
					
					hwydist = GetDataVector(JVhwtr+"|"+selname, Hwy+".hwydist"+i2s(APID[aa]), )
					SetDataVector(JVhwtr+"|"+selname, Surv+".hwydist"+i2s(APID[aa]), hwydist, )	
					
					lbtime = GetDataVector(JVhwtr+"|"+selname, Trn+".lbtime"+i2s(APID[aa]), )
					lbtime = if lbtime = 0 or lbtime = null then 999 else lbtime
					SetDataVector(JVhwtr+"|"+selname, Surv+".lbtime"+i2s(APID[aa]), lbtime, )	
					
					lbfare = GetDataVector(JVhwtr+"|"+selname, Trn+".lbfare"+i2s(APID[aa]), )
					lbfare = nulltozero(lbfare)
					SetDataVector(JVhwtr+"|"+selname, Surv+".lbfare"+i2s(APID[aa]), lbfare, )	
					
					lbusiw = GetDataVector(JVhwtr+"|"+selname, Trn+".lbusiw"+i2s(APID[aa]), )
					lbusiw = nulltozero(lbusiw)
					SetDataVector(JVhwtr+"|"+selname, Surv+".lbusiw"+i2s(APID[aa]), lbusiw, )	
					
					lbusxw = GetDataVector(JVhwtr+"|"+selname, Trn+".lbusxw"+i2s(APID[aa]), )
					lbusxw = nulltozero(lbusxw)
					SetDataVector(JVhwtr+"|"+selname, Surv+".lbusxw"+i2s(APID[aa]), lbusxw, )	
					
					lbusac = GetDataVector(JVhwtr+"|"+selname, Trn+".lbusac"+i2s(APID[aa]), )
					lbusac = nulltozero(lbusac)
					SetDataVector(JVhwtr+"|"+selname, Surv+".lbusac"+i2s(APID[aa]), lbusac, )
										
					cbtime = GetDataVector(JVhwtr+"|"+selname, Trn+".cbtime"+i2s(APID[aa]), )
					SetDataVector(JVhwtr+"|"+selname, Surv+".cbtime"+i2s(APID[aa]), cbtime, )	
					
					cbfare = GetDataVector(JVhwtr+"|"+selname, Trn+".cbfare"+i2s(APID[aa]), )
					cbfare = cbfare
					SetDataVector(JVhwtr+"|"+selname, Surv+".cbfare"+i2s(APID[aa]), cbfare, )	
					
					cbusiw = GetDataVector(JVhwtr+"|"+selname, Trn+".cbusiw"+i2s(APID[aa]), )
					SetDataVector(JVhwtr+"|"+selname, Surv+".cbusiw"+i2s(APID[aa]), cbusiw, )	
					
					cbusxw = GetDataVector(JVhwtr+"|"+selname, Trn+".cbusxw"+i2s(APID[aa]), )
					SetDataVector(JVhwtr+"|"+selname, Surv+".cbusxw"+i2s(APID[aa]), cbusxw, )	
					
					cbusac = GetDataVector(JVhwtr+"|"+selname, Trn+".cbusac"+i2s(APID[aa]), )
					SetDataVector(JVhwtr+"|"+selname, Surv+".cbusac"+i2s(APID[aa]), cbusac, )
					
					raltime = GetDataVector(JVhwtr+"|"+selname, Trn+".raltime"+i2s(APID[aa]), )
					raltime = if raltime = 0 or raltime = null then 999 else raltime
					SetDataVector(JVhwtr+"|"+selname, Surv+".raltime"+i2s(APID[aa]), raltime, )	
					
					ralfare = GetDataVector(JVhwtr+"|"+selname, Trn+".ralfare"+i2s(APID[aa]), )
					ralfare = nulltozero(ralfare)
					SetDataVector(JVhwtr+"|"+selname, Surv+".ralfare"+i2s(APID[aa]), ralfare, )
					
					railiw = GetDataVector(JVhwtr+"|"+selname, Trn+".railiw"+i2s(APID[aa]), )
					railiw = nulltozero(railiw)
					SetDataVector(JVhwtr+"|"+selname, Surv+".railiw"+i2s(APID[aa]), railiw, )
					
					railxw = GetDataVector(JVhwtr+"|"+selname, Trn+".railxw"+i2s(APID[aa]), )
					railxw = nulltozero(railxw)
					SetDataVector(JVhwtr+"|"+selname, Surv+".railxw"+i2s(APID[aa]), railxw, )
					
					railac = GetDataVector(JVhwtr+"|"+selname, Trn+".railac"+i2s(APID[aa]), )
					railac = nulltozero(railac)
					SetDataVector(JVhwtr+"|"+selname, Surv+".railac"+i2s(APID[aa]), railac, )
					
					////////////////////////////////
					// Special Skims: Charter Bus
					////////////////////////////////
					n = SelectByQuery("XBusMissing", "Several",  "Select * where ("+Surv+".cbtime"+i2s(APID[aa])+" = null or "+Surv+".cbtime"+i2s(APID[aa])+" = 0) and mod_per=" + i2s(dd), )
					
					cbtime = GetDataVector(JVhwtr+"|XBusMissing", Hwy+".hwytime"+i2s(APID[aa]), )
					cbtime = cbtime * 1.7	// based on regression analysis of survey records, done in 2006 (original ACM)
					SetDataVector(JVhwtr+"|XBusMissing", Surv+".cbtime"+i2s(APID[aa]), cbtime, )
					
					hwydist = GetDataVector(JVhwtr+"|XBusMissing", Hwy+".hwydist"+i2s(APID[aa]), )
					cbfare = GetDataVector(JVhwtr+"|XBusMissing", Hwy+".hwytoll"+i2s(APID[aa]), )
					cbfare = 0.062 + 0.871 * cbfare / 100 + 0.209 * hwydist 	// based on regression analysis of survey records, done in 2006 (original ACM)
					//cbfare = 0.247 * hwydist // from Renee's script
					SetDataVector(JVhwtr+"|XBusMissing", Surv+".cbfare"+i2s(APID[aa]), cbfare, )
					
					cbusiw = cbtime
					cbusiw = nulltozero(cbtime-cbtime) // set to 0 (all travel time is contained in cbtime)
					SetDataVector(JVhwtr+"|XBusMissing", Surv+".cbusiw"+i2s(APID[aa]), cbusiw, )	
					
					cbusxw = cbtime
					cbusxw = nulltozero(cbtime-cbtime) // set to 0 (all travel time is contained in cbtime)
					SetDataVector(JVhwtr+"|XBusMissing", Surv+".cbusxw"+i2s(APID[aa]), cbusxw, )		
					
					cbusac = cbtime
					cbusac = nulltozero(cbtime-cbtime) // set to 0 (all travel time is contained in cbtime)
					SetDataVector(JVhwtr+"|XBusMissing", Surv+".cbusac"+i2s(APID[aa]), cbusac, )	
					
					///////////////////////////////
					// Special Skims: Taxi Fares
					///////////////////////////////
					
					Taxi = OpenTable("TaxiFares", "CSV", {MainDir+"0_Param\\2_LUT\\TaxiFare"+i2s(APID[aa])+".csv", })

					recs = GetRecordCount(Taxi, )
					rh = GetFirstRecord(Taxi+"|", )

					for rr = 1 to recs do

						cntyv = GetRecordValues(Taxi, rh, {"County"})
						dminv = GetRecordValues(Taxi, rh, {"DistMin"})
						dmaxv = GetRecordValues(Taxi, rh, {"DistMax"})
						basev = GetRecordValues(Taxi, rh, {"BaseFare"})
						fpmiv = GetRecordValues(Taxi, rh, {"FarePerMile"})
						dredv = GetRecordValues(Taxi, rh, {"DistRed"})
						minfv = GetRecordValues(Taxi, rh, {"MinFare"})

						cnty = i2s(cntyv[1][2])
						dmin = i2s(dminv[1][2])
						dmax = i2s(dmaxv[1][2])
						basefare = r2s(basev[1][2])
						farepermile = r2s(fpmiv[1][2])
						distred = r2s(dredv[1][2])
						minfare = r2s(minfv[1][2])

						SetView(JVhwtr)
						numrecs = SelectbyQuery("S"+i2s(rr)+"_"+i2s(APID[aa])+"_"+i2s(dd), "Several",  
									"Select * where oco_id=" + cnty + " and "+Surv+".hwydist"+i2s(APID[aa])+" >= " + dmin + " and "+Surv+".hwydist"+i2s(APID[aa])+" <= " + dmax, )
						if numrecs > 0 then do
							formula = "1.15 * ("+Surv+".hwytoll"+i2s(APID[aa])+" + max("+basefare+" + "+farepermile+" * ("+Surv+".hwydist"+i2s(APID[aa])+" - "+distred+"), "+minfare+"))"  // Include highway toll and 15% tip
							//formula = "1.15 * (max("+basefare+" + "+farepermile+" * ("+Surv+".hwydist"+i2s(APID[aa])+" - "+distred+"), "+minfare+"))"  // Include 15% tip
							expr = CreateExpression(JVhwtr, "Tx"+i2s(rr)+"_"+i2s(APID[aa])+"_"+i2s(dd), formula, )	
							SetRecordsValues(JVhwtr+"|S"+i2s(rr)+"_"+i2s(APID[aa])+"_"+i2s(dd), {{"txfare"+i2s(APID[aa])}, }, "Formula", {expr}, )					
						end
						
						if rr = recs then continue else rh = GetNextRecord(Taxi+"|", rh, )

					end
					
					closeview(Taxi)


					///////////////////////////////////
					// Shared Ride (Van, etc.) Fares
					///////////////////////////////////
					
					SR = OpenTable("SRFares", "CSV", {MainDir+"0_Param\\2_LUT\\SRFare"+i2s(APID[aa])+".csv", })
					
					JV = JoinViews("Srv+SRfare", Surv+".oco_id", SR+".County", )
					
					formula = "max(basefare + farepermile * ("+Surv+".hwydist"+i2s(APID[aa])+" - distred), minfare)"
					expr1 = CreateExpression(JV, "SRfareTemp", formula, )	
					expr = CreateExpression(JV, "SRfareTempMod", "if "+expr1+" > 0.7 * txfare"+i2s(APID[aa])+" then 0.7 * txfare"+i2s(APID[aa])+" else "+expr1, )
					SetRecordsValues(JV+"|", {{"srcost"+i2s(APID[aa])}, }, "Formula", {expr}, )					
					
					closeview(SR)
					closeview(JV)	
					closeview(JVhw)
					closeview(JVhwtr)	

				end // TOD


			end // airports
			
			closeview(Surv)
			
		end // purposes
		
		for hh = 1 to HwySkims.length do
			closeview(HwySkims[hh])
		end
		
		for tt = 1 to TrnSkims.length do
			closeview(TrnSkims[tt])
		end
		
	end // build/base
	
retval = 1
quit:
	return(retval)
Endmacro // Add Skim Values	


Macro "Impute Missing Skim Values"(MainDir, InDir, WDir, OutDir)
// ======================================================
//   Impute Missing Skim Values
//
//   If chosen mode (rail or local bus) is not available 
//   from skims, impute average travel time from origin zip	
// ======================================================
shared baseyear
shared buildyear
shared futyears
shared Scen
retval = 0

	AptNodes = OpenTable("AptNodes", "CSV", {MainDir+"\\3_RunBin\\2_Skims\\Airport_Nodes.csv", })
	airname = v2a(GetDataVector(AptNodes+"|", "AIRPORT", ))	
	APID = v2a(GetDataVector(AptNodes+"|", "AIR_NY", ))	
	closeview(AptNodes)
	
	ref = { "base","build"}
	
	for ii = 1 to ref.length do
	
		purposes = {"business", "nonbusiness"}
		for bb = 1 to purposes.length do // purposes	
			
			CopyFile(WDir+ref[ii]+"_"+purposes[bb]+".bin", WDir+ref[ii]+"_"+purposes[bb]+"_imputedTT.bin")
			CopyFile(WDir+ref[ii]+"_"+purposes[bb]+".dcb", WDir+ref[ii]+"_"+purposes[bb]+"_imputedTT.dcb")
			Surv = OpenTable("SurveyFile", "FFB", {WDir+ref[ii]+"_"+purposes[bb]+"_imputedTT.bin", })			
			
			// Calculate actual reported travel time
			actualTTexpr = CreateExpression(Surv, "actualTT", "ap_hr * 60 + ap_min - (st_hr * 60 + st_min)", )		
		
			for aa = 1 to APID.length do
		
				// Impute Local Bus
				SetView(Surv)
				numrecsLB = SelectbyQuery("MissingLB_"+airname[aa]+"_"+ref[ii]+"_"+purposes[bb], "Several", 
										"Select * where airport = "+i2s(APID[aa])+" and mode = 8 and lbtime"+i2s(APID[aa])+" = 999", )
				if numrecsLB >0 then do						
					lbtt = AggregateTable("AvgLBZipTT_"+airname[aa]+"_"+ref[ii]+"_"+purposes[bb], Surv+"|MissingLB_"+airname[aa]+"_"+ref[ii]+"_"+purposes[bb], "FFB", WDir+"ImputeLBTT_"+i2s(APID[aa])+"_"+ref[ii]+"_"+purposes[bb]+".bin", "zip", 
										{{"actualTT","Average",}}, )	

					JVimplb = JoinViews("Srv+ImpLB", Surv+".zip", lbtt+".zip", )
					SetView(JVimplb)
					lbustime = GetDataVector(JVimplb+"|", "lbtime"+i2s(APID[aa]), )
					mode = GetDataVector(JVimplb+"|", "mode", )
					airport = GetDataVector(JVimplb+"|", "airport", )
					lbusimpute = GetDataVector(JVimplb+"|", lbtt+".[Avg actualTT]", )
					newlbustime = if lbustime = 999 and lbusimpute > 0 and lbusimpute < 999 then lbusimpute else lbustime
					SetDataVector(JVimplb+"|", "lbtime"+i2s(APID[aa]), newlbustime, )					

					closeview(JVimplb)
					closeview(lbtt)
				end

				// Impute Rail
				SetView(Surv)
				numrecsRL = SelectbyQuery("MissingRL_"+airname[aa]+"_"+ref[ii]+"_"+purposes[bb], "Several", 
										"Select * where airport = "+i2s(APID[aa])+" and mode = 3 and raltime"+i2s(APID[aa])+" = 999", )		
				if numrecsRL >0 then do
					rltt = AggregateTable("AvgRLZipTT_"+airname[aa]+"_"+ref[ii]+"_"+purposes[bb], Surv+"|MissingRL_"+airname[aa]+"_"+ref[ii]+"_"+purposes[bb], "FFB", WDir+"ImputeRLTT_"+i2s(APID[aa])+"_"+ref[ii]+"_"+purposes[bb]+".bin", "zip", 
										{{"actualTT","Average",}}, )							

					JVimprl = JoinViews("Srv+ImpRL", Surv+".zip", rltt+".zip", )
					SetView(JVimprl)
					railtime = GetDataVector(JVimprl+"|", "raltime"+i2s(APID[aa]), )
					mode = GetDataVector(JVimprl+"|", "mode", )
					airport = GetDataVector(JVimprl+"|", "airport", )
					railimpute = GetDataVector(JVimprl+"|", rltt+".[Avg actualTT]", )
					newrailtime = if railtime = 999 and railimpute > 0 and railimpute < 999 then railimpute else railtime
					SetDataVector(JVimprl+"|", "raltime"+i2s(APID[aa]), newrailtime, )

					closeview(JVimprl)	
					closeview(rltt)
				end				
			end // airport
			
		end // purposes
		
	end // build/base			

retval = 1
quit:
	return(retval)
Endmacro // Impute Missing Skim Values


Macro "Finalize For Java"(MainDir, InDir, WDir, OutDir)

// ======================================================
//   Finalize Base/Build Files for the Java Model
// ======================================================
shared baseyear
shared buildyear
shared futyears
shared Scen
retval = 0

ref = {"base", "build"}
	
	for ii = 1 to ref.length do // base/build
		purposes = {"business", "nonbusiness"}
		for bb = 1 to purposes.length do // purposes	
			
			Surv = OpenTable("SurveyFile", "FFB", {WDir+ref[ii]+"_"+purposes[bb]+"_imputedTT.bin", })
			outfile = OutDir + ref[ii]+"_"+purposes[bb]+".csv" // base/build 1/2 .csv
			
			// List of fields to drop
			if ref[ii] = "base" then do
				if baseyear = 2010 then	
					excludefields = {"EXPF_10_PASS", "apid", "car", "dropoff", "othmode", "TRAVSIZE_R", "gen", "age", "incGroup", "income", "st_hr", "st_min", "ap_hr", "ap_min"}
				else 
					excludefields = {"FUT4_"+i2s(baseyear-2000), "apid", "car", "dropoff", "othmode", "TRAVSIZE_R", "gen", "age", "incGroup", "income", "st_hr", "st_min", "ap_hr", "ap_min"}
			end		
			if ref[ii] = "build" then do 
				if buildyear = 2010 then 
					excludefields = {"EXPF_10_PASS", "apid", "car", "dropoff", "othmode", "TRAVSIZE_R", "st_hr", "st_min", "ap_hr", "ap_min"}
				else
					excludefields = {"FUT4_"+i2s(buildyear-2000), "apid", "car", "dropoff", "othmode", "TRAVSIZE_R", "st_hr", "st_min", "ap_hr", "ap_min"}
			end

			
			fieldinfo = GetFields(Surv, "All")
				
			dim keepfields[fieldinfo[1].length - excludefields.length]			
			counter = 1
			for ff = 1 to fieldinfo[1].length do
				fieldname = fieldinfo[1][ff]
				
				exclude = 0
				for ee = 1 to excludefields.length do
					if upper(excludefields[ee]) = upper(fieldname) then exclude = 1
				end

				
				if exclude = 0 then do
					keepfields[counter] = fieldname
					counter = counter + 1
				end
				
			end
			
			ExportView(Surv+"|", "CSV", outfile, keepfields, {{"CSV Header", "True"}}) 
			
			// Java cannot read CSV file with quote around field names
			// The following batch file calls Windows built-in PowerShell
			// to replace all quotes with null in the CSV
			
				fixquotebatch = MainDir + "2_Code\\4_Misc\\ReplaceQuotesBatch.bat"

				if GetFileInfo(fixquotebatch) <> null 
					then do DeleteFile(fixquotebatch) end

				f = OpenFile(fixquotebatch, "w+")

				WriteLine(f, trim("@ECHO OFF                                                                                               "))
				WriteLine(f, trim("SET PowerShellScriptDirectory=" + MainDir + "2_Code\\4_Misc\\					                       "))
				WriteLine(f, trim("SET PowerShellScriptPath=%PowerShellScriptDirectory%ReplaceQuotes.ps1                                   "))
				WriteLine(f, trim("SET PathPlusFile=" + outfile + "                                                        				   "))
				WriteLine(f, trim("PowerShell -NoProfile -ExecutionPolicy Bypass -Command \"& '%PowerShellScriptPath%' %PathPlusFile%\";   "))

				closefile(f)
		
				// Run batch file
				ret = RunProgram(fixquotebatch, )		
			
		end //purposes
	end // base/build

retval = 1
quit:
	return(retval)
Endmacro // Finalize For Java	