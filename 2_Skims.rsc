///////////////////////////////////////////////////
//
//	2_SKIMS.RSC:
//
//	This script calls skimming (ground access 
//  data extraction) procedures for the 
//	Airport Choice Model (ACM).
//
//	Adapted from Renee Alsup's GISDK scripts 
//  by Chrissy Bernardo, September 2015
//
///////////////////////////////////////////////////


// Main macro to call steps of the process
Macro "Skims Main"(Args)
	
	RunMacro("G30 File Close All")
	
	shared baseyear
	shared buildyear
	
	baseyear = Args.[Base Year]
	buildyear = Args.[Build Year]
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
	
	// Standard Time of Day Periods
	TODarray = {"AM","MD","PM","NT"}
	
	// Run (Base/Build) reference names
	runname = {"Base", "Build"}
	
	stepname = null
	
	For rr = 1 to runname.length do
		for tt = 1 to TODarray.length do 
	
			if !RunMacro("Check Inputs", MainDir, InDir+"2_Skims\\") then do stepname = "Check Skim Inputs" goto quit end

			if !RunMacro("Update National Fixed Cost", MainDir, InDir, WDir+"2_Skims\\", OutDir+"2_Skims\\", TODarray[tt], runname[rr]) then do stepname = "Update National Fixed Cost" goto quit end
						
				RunMacro("close everything")
			
			if !RunMacro("Update TH-TDFM Costs", MainDir, InDir, WDir+"2_Skims\\", OutDir+"2_Skims\\", TODarray[tt], runname[rr]) then do stepname = "Update TH-TDFM Costs" goto quit end
			
				RunMacro("close everything")
			
			if !RunMacro("Update TH-TDFM Skims", MainDir, InDir, WDir+"2_Skims\\", OutDir+"2_Skims\\", TODarray[tt], runname[rr]) then do stepname = "Update TH-TDFM Skims" goto quit end
						
				RunMacro("close everything")
				
			if !RunMacro("Update National Skims", MainDir, InDir, WDir+"2_Skims\\", OutDir+"2_Skims\\", TODarray[tt], runname[rr]) then do stepname = "Update National Skims" goto quit end
						
				RunMacro("close everything")		

			if !RunMacro("Combine Highway Skims", MainDir, InDir, WDir+"2_Skims\\", OutDir+"2_Skims\\", TODarray[tt], runname[rr]) then do stepname = "Combine Highway Skims" goto quit end
						
				RunMacro("close everything")

		 	// Run Transit Skims for AM/MD only
			if TODarray[tt] = "AM" or TODarray[tt] = "MD" then do
				if !RunMacro("Update Transit Skims", MainDir, InDir, WDir+"2_Skims\\", OutDir+"2_Skims\\", TODarray[tt], runname[rr]) then do stepname = "Update Transit Skims" goto quit end
					RunMacro("close everything")	
			end
				
		end //TOD
	end //base/build

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
//====================================================
// 	*Placeholder*
//====================================================	 	
	retval = 1
	
	return(retval)
	
endMacro // Check Inputs

Macro "Update National Fixed Cost"(MainDir, InDir, WDir, OutDir, TODper, ref)
			
// ======================================================
//   Calculate Fixed Cost for National Links
// ======================================================
	retval = 1
	infile = InDir+"3_Geog\\"+ref+"\\FullMerged_Network.dbd"
	TOD = TODper

	// Open Network Layer 
	info = GetDBInfo(infile)
	scp = info[1]
	layer = GetDBLayers(infile)

	map = CreateMap("Location", {{"Scope", scp},{"Auto Project", "True"}})
	line_lyr = AddLayer(map, layer[2], infile, layer[2])
	node_lyr = AddLayer(map, layer[1], infile, layer[1])

	Setlayer(line_lyr)
	line_struct = GetTableStructure(line_lyr)
	Setlayer(node_lyr)
	node_struct = GetTableStructure(node_lyr)

	Setlayer(line_lyr)


	// Select Links to Edit and Set National Fixed Cost 

	NHTS = SelectbyQuery("NHTS Links", "Several",  "Select * where FCLASS=null", )

	AUTOFIX = GetDataVector(line_lyr+"|NHTS Links","AUTOFIX",)
	HOV2FIX = GetDataVector(line_lyr+"|NHTS Links","HOV2FIX",)
	HOV3FIX = GetDataVector(line_lyr+"|NHTS Links","HOV3FIX",)
	HOV4FIX = GetDataVector(line_lyr+"|NHTS Links","HOV4FIX",)
	TAXIFIX = GetDataVector(line_lyr+"|NHTS Links","TAXIFIX",)
	TRUCKFIX = GetDataVector(line_lyr+"|NHTS Links","TRUCKFIX",)
	COMMFIX = GetDataVector(line_lyr+"|NHTS Links","COMMFIX",)
	SOVTOLL = GetDataVector(line_lyr+"|NHTS Links","SOVTOLL",)
	HOV2TOLL = GetDataVector(line_lyr+"|NHTS Links","HOV2TOLL",)
	HOV3TOLL = GetDataVector(line_lyr+"|NHTS Links","HOV3TOLL",)
	TRUKTOLL = GetDataVector(line_lyr+"|NHTS Links","TRUKTOLL",)
	Length = GetDataVector(line_lyr+"|NHTS Links","Length",)

	HOV2TOLL = SOVTOLL
	HOV3TOLL = SOVTOLL
	TRUKTOLL = SOVTOLL

	   auto_vott_array ={28.3, 31.6, 27.5, 26.5} // AM, MD, PM , NT

	   if TOD = "AM" then auto_vott = auto_vott_array[1]
	   if TOD = "MD" then auto_vott = auto_vott_array[2]
	   if TOD = "PM" then auto_vott = auto_vott_array[3]
	   if TOD = "NT" then auto_vott = auto_vott_array[4]

	   hov2_vott= 2*auto_vott
	   hov3_vott= 3*auto_vott
	   hov4_vott= 4*auto_vott   

	AUTOFIX = (20*Length + 0.5*SOVTOLL)/auto_vott
	HOV2FIX = (20*Length + 0.5*HOV2TOLL)/hov2_vott
	HOV3FIX = (20*Length + 0.5*HOV3TOLL)/hov3_vott
	HOV4FIX = (20*Length + 0.5*HOV3TOLL)/hov4_vott
	TAXIFIX = 0.0*Length
	TRUCKFIX = (43.4*Length + TrukToll)/83.33
	COMMFIX = (19.2*Length + SOVTOLL) / 75

	SetDataVector(line_lyr+"|NHTS Links","AUTOFIX",AUTOFIX,)
	SetDataVector(line_lyr+"|NHTS Links","HOV2FIX",HOV2FIX,)
	SetDataVector(line_lyr+"|NHTS Links","HOV3FIX",HOV3FIX,)
	SetDataVector(line_lyr+"|NHTS Links","HOV4FIX",HOV4FIX,)
	SetDataVector(line_lyr+"|NHTS Links","TAXIFIX",TAXIFIX,)
	SetDataVector(line_lyr+"|NHTS Links","TRUCKFIX",TRUCKFIX,)
	SetDataVector(line_lyr+"|NHTS Links","COMMFIX",COMMFIX,)


	quit:
		return(retval)
Endmacro // Update National Fixed Cost


Macro "Update TH-TDFM Costs"(MainDir, InDir, WDir, OutDir, TODper, ref)
			
// ======================================================
//   Calculate Fixed Cost and Update Travel Times 
//   For TH-TDFM Links
// ======================================================
	retval = 1
	infile = InDir+"3_Geog\\"+ref+"\\FullMerged_Network.dbd"
	TOD = TODper

	timenet = InDir+"\\2_Skims\\"+ref+"\\1_Hwy\\1_HNet\\"+TOD+"\\"+TOD+"_bus.bin"
	dirfile = InDir+"\\2_Skims\\"+ref+"\\1_Hwy\\1_HNet\\"+TOD+"\\"+TOD+"_Link_Dir.dbf"
	outfile = InDir+"\\2_Skims\\"+ref+"\\1_Hwy\\2_HASN\\assn_"+TOD+"_bus.bin"


	TODVals = OpenTable("TOD Network Values","FFB",{timenet,},)
	TODDirs = OpenTable("TOD Directions","DBase",{dirfile,},)
	TODFlows = OpenTable("TOD Output","FFB",{outfile,},)

	// ********************* Open Network Layer ********************************************************

	info = GetDBInfo(infile)
	scp = info[1]
	layer = GetDBLayers(infile)

	map = CreateMap("Location", {{"Scope", scp},{"Auto Project", "True"}})
	line_lyr = AddLayer(map, layer[2], infile, layer[2])
	node_lyr = AddLayer(map, layer[1], infile, layer[1])

	Setlayer(line_lyr)
	line_struct = GetTableStructure(line_lyr)
	Setlayer(node_lyr)
	node_struct = GetTableStructure(node_lyr)

	Setlayer(line_lyr)

	viewnet = JoinViews("Networks Joined", line_lyr+".ID",TODVals+".ID",)
	viewdir = JoinViews("Direction File Joined", line_lyr+".ID",TODDirs+".ID",)
	viewflow = JoinViews("Output File Joined", line_lyr+".ID",TODFlows+".ID1",)

	// ********************* Update Link Directions ****************************************************

	Setview(viewdir)

	DirLinks = SelectbyQuery("Dir Links", "Several", "Select * where [TOD Directions].Dir<>null AND [TOD Directions].Dir<>NetworkLinks.Dir",)

	while DirLinks <> 0 do

	DirVal = GetDataVector(viewdir+"|Dir Links",TODDirs+".Dir",)
	DirVal1 = GetDataVector(viewdir+"|Dir Links",line_lyr+".Dir",)

	DirVal1 = if (DirVal<>null) then DirVal else DirVal1

	SetDataVector(viewdir+"|Dir Links",line_lyr+".Dir",DirVal1,)

	DirLinks = SelectbyQuery("Dir Links", "Several", "Select * where [TOD Directions].Dir<>null AND [TOD Directions].Dir<>NetworkLinks.Dir",)

	end

	// ********************* Update THTDFM Travel Times ************************************************

	Setview(viewflow)

	TimeLinks = SelectbyQuery("Time Links", "Several", "Select * where ID1<>null",)

	TimeAB = GetDataVector(viewflow+"|Time Links","AB_Time",)
	TimeBA = GetDataVector(viewflow+"|Time Links","BA_Time",)
	TimeAB1 = GetDataVector(viewflow+"|Time Links","TIMEAB",)
	TimeBA1 = GetDataVector(viewflow+"|Time Links","TIMEBA",)
	DirVal2 = GetDataVector(viewflow+"|Time Links",line_lyr+".Dir",)

	TimeAB1 = if (TimeAB<>null AND DirVal2<>-1) then TimeAB else if (TimeAB=null AND DirVal2<>-1) then TimeAB1 else null
	TimeBA1 = if (TimeBA<>null AND DirVal2<>1) then TimeBA else if (TimeBA=null AND DirVal2<>1) then TimeBA1 else null

	SetDataVector(viewflow+"|Time Links","TIMEAB",TimeAB1,)
	SetDataVector(viewflow+"|Time Links","TIMEBA",TimeBA1,)


	// ********************* Update THTDFM Fixed Costs *************************************************
	Setview(viewnet)

	NetLinks = SelectbyQuery("Net Links", "Several", "Select * where [TOD Network Values].ID<>null",)

	AUTOFIX = GetDataVector(viewnet+"|Net Links",TODVals+".AUTOFIX",)
	HOV2FIX = GetDataVector(viewnet+"|Net Links",TODVals+".HOV2FIX",)
	HOV3FIX = GetDataVector(viewnet+"|Net Links",TODVals+".HOV3FIX",)
	HOV4FIX = GetDataVector(viewnet+"|Net Links",TODVals+".HOV4FIX",)
	TAXIFIX = GetDataVector(viewnet+"|Net Links",TODVals+".TAXIFIX",)
	TRUCKFIX = GetDataVector(viewnet+"|Net Links",TODVals+".TRUCKFIX",)
	COMMFIX = GetDataVector(viewnet+"|Net Links",TODVals+".COMMFIX",)

	AUTOFIX1 = GetDataVector(viewnet+"|Net Links",line_lyr+".AUTOFIX",)
	HOV2FIX1 = GetDataVector(viewnet+"|Net Links",line_lyr+".HOV2FIX",)
	HOV3FIX1 = GetDataVector(viewnet+"|Net Links",line_lyr+".HOV3FIX",)
	HOV4FIX1 = GetDataVector(viewnet+"|Net Links",line_lyr+".HOV4FIX",)
	TAXIFIX1 = GetDataVector(viewnet+"|Net Links",line_lyr+".TAXIFIX",)
	TRUCKFIX1 = GetDataVector(viewnet+"|Net Links",line_lyr+".TRUCKFIX",)
	COMMFIX1 = GetDataVector(viewnet+"|Net Links",line_lyr+".COMMFIX",)

	AUTOFIX1 = if (AUTOFIX<>null) then AUTOFIX else AUTOFIX1
	HOV2FIX1 = if (HOV2FIX<>null) then HOV2FIX else HOV2FIX1
	HOV3FIX1 = if (HOV3FIX<>null) then HOV3FIX else HOV3FIX1
	HOV4FIX1 = if (HOV4FIX<>null) then HOV4FIX else HOV4FIX1
	TAXIFIX1 = if (TAXIFIX<>null) then TAXIFIX else TAXIFIX1
	TRUCKFIX1 = if (TRUCKFIX<>null) then TRUCKFIX else TRUCKFIX1
	COMMFIX1 = if (COMMFIX<>null) then COMMFIX else COMMFIX1



	SetDataVector(viewnet+"|Net Links",line_lyr+".AUTOFIX",AUTOFIX1,)
	SetDataVector(viewnet+"|Net Links",line_lyr+".HOV2FIX",HOV2FIX1,)
	SetDataVector(viewnet+"|Net Links",line_lyr+".HOV3FIX",HOV3FIX1,)
	SetDataVector(viewnet+"|Net Links",line_lyr+".HOV4FIX",HOV4FIX1,)
	SetDataVector(viewnet+"|Net Links",line_lyr+".TAXIFIX",TAXIFIX1,)
	SetDataVector(viewnet+"|Net Links",line_lyr+".TRUCKFIX",TRUCKFIX1,)
	SetDataVector(viewnet+"|Net Links",line_lyr+".COMMFIX",COMMFIX1,)

	// ********************* Calculate Generalized Cost ************************************************

	GLCAB = GetDataVector(line_lyr+"|","GLCAUTO_AB",)
	GLCBA = GetDataVector(line_lyr+"|","GLCAUTO_BA",)

	AUTOFIX = GetDataVector(line_lyr+"|","AUTOFIX",)

	TimeAB = GetDataVector(line_lyr+"|","TIMEAB",)
	TimeBA = GetDataVector(line_lyr+"|","TIMEBA",)

	Length = GetDataVector(line_lyr+"|","Length",)

	GLCAB = AUTOFIX + TimeAB*1.0 
	GLCBA = AUTOFIX + TimeBA*1.0

	SetDataVector(line_lyr+"|","GLCAUTO_AB",GLCAB,)
	SetDataVector(line_lyr+"|","GLCAUTO_BA",GLCBA,)



	quit:
		return(retval)
Endmacro // Update TH - TDFM Costs




Macro "Update TH-TDFM Skims" (MainDir, InDir, WDir, OutDir, TODper, ref)
 Runmacro("TCB Init")

// ======================================================
// Update TH-TDFM Skims, Calculating new shortest paths
// ======================================================

retval = 1
infile = InDir+"3_Geog\\"+ref+"\\FullMerged_Network.dbd"
TOD = TODper

OutPath = OutDir+"\\"+ref+"\\1_Hwy\\"

// ********************* Open Network Layer ********************************************************

// Input Files
highway_file=infile

// Output Files
 
HighwayNetwork = OutPath+TOD+"_GLC_THTDFM.net"

// Open highway network
    cc = GetDBInfo(highway_file)
    dd = CreateMap("yyy",{{"Scope",cc[1]}, {"Auto Project", "True"}})
   
    baselyrs = GetDBLayers(highway_file)

    line_lyr = AddLayer(dd , "tierOne", highway_file, baselyrs[2])
    NodeLayer = AddLayer(dd, "Node", highway_file, baselyrs[1])
    
SetLayerVisibility("Node", "True")
SetLayer("tierOne")
	       

	       	
// ********************* Create Network File *******************************************************
       	
	  	thenetwork = CreateNetwork( ,HighwayNetwork,"Highway Network",
		    				{
		    				{"GLCAUTO","GLCAUTO_AB","GLCAUTO_BA"},
		    				{"Dist","Length","Length"},
		    				{"C Time","TIMEAB","TIMEBA"},
		    				{"SOVTOLL","SOVTOLL","SOVTOLL"}
    						},,)
    						
	Opts = null
	Opts.Input.Database = highway_file
	Opts.Input.Network = HighwayNetwork
	Opts.Input.[Centroids Set] = {highway_file+"|Node", "Node", "Centroids", "Select * where Centroid=1 AND ID=TAZ"}
	Opts.Global.VOI = 1
	
    retval = RunMacro("TCB Run Operation", "Highway Network Setting", Opts, &Ret)
 
 
	Setview("tierOne")
	
// ********************* Generate Skims ************************************************************

     Opts = null
     Opts.Input.Network = HighwayNetwork
     Opts.Input.[Origin Set] = {highway_file+"|Node", "Node", "BPM Nodes", "Select * where Centroid=1 AND ID=TAZ"}
     Opts.Input.[Destination Set] = {highway_file+"|Node", "Node", "NY Airports", "Select * where AIR_NY<>null"}
     Opts.Input.[Via Set] = {highway_file+"|Node", "Node"}
     Opts.Field.Minimize = "GLCAUTO"
     Opts.Field.Nodes = "Node.ID"
     Opts.Field.[Skim Fields] = {{"Dist", "All"}, {"C Time", "All"}, {"SOVTOLL", "All"}}
     Opts.Output.[Output Matrix].Label = TOD+" Shortest Path"
     Opts.Output.[Output Matrix].[File Name] = OutPath+TOD+"_GLC_Skim_THTDFM.mtx"

     retval = RunMacro("TCB Run Procedure", "TCSPMAT", Opts, &Ret)
    
     if !retval then goto quit
     
// Extract Airport Node ID's for Skim Field Names     
	SetView("Node")
	nApts = SelectByQuery("Airports", "Several", "Select * where AIR_NY <> null")
	ExportView("Node|Airports", "CSV", WDir + "Airport_Nodes.csv", {"ID", "AIR_NY", "AIRPORT", "Transit_Node"}, {{"CSV Header", 1},{"Indexed Fields", "AIR_NY"}})
	AptNodes = OpenTable("AptNodes", "CSV", {WDir + "Airport_Nodes.csv", })
	nodeID = GetDataVector(AptNodes+"|", "ID", )
	APID = GetDataVector(AptNodes+"|", "AIR_NY", )
	AptName = GetDataVector(AptNodes+"|", "AIRPORT", )
	dim nodeIDstring[nodeID.length]
	for k = 1 to nodeID.length do
		nodeIDstring[k] = i2s(nodeID[k])
	end

// Export Skims to BIN
	skim = OpenMatrix(OutPath+TOD+"_GLC_Skim_THTDFM.mtx", )

	cores = {"Dist (Skim)", "C Time (Skim)", "SOVTOLL (Skim)"}
	corenames = {"Dist", "Time", "Toll"}
	for ii = 1 to cores.length do
		mc = CreateMatrixCurrency(skim, cores[ii], , , )
		ExportMatrix(mc, nodeIDstring, "Rows", "FFB", WDir+"tempTAZskim.bin",)
	
		// Aggregate Skims to Zip-Code
			TAZskim = OpenTable("TAZSkims", "FFB", {WDir+"tempTAZskim.bin", })
			
			// Rename fields from NodeID #'s to Airport Names
			strct = GetTableStructure(TAZskim)
			for i = 1 to strct.length do
				origname = strct[i][1]
				for j = 1 to nApts do
					if origname = i2s(nodeID[j]) then strct[i][1] = AptName[j]	
				end
				strct[i] = strct[i] + {origname}
			end
			ModifyTable(TAZskim, strct)			
			
		fields = GetFields(TAZskim, "All")
		dim fieldspec[strct.length - 1, 3]
		for jj = 2 to strct.length do
			fieldspec[jj-1][1] = fields[1][jj]
			fieldspec[jj-1][2] = "Average"
			fieldspec[jj-1][3] = "Factor"
			fieldvec = GetDataVector(TAZskim+"|", fields[1][jj], )
			fieldvec = if fieldvec = null then 1 else fieldvec
			SetDataVector(TAZskim+"|", fields[1][jj], fieldvec, )
		end

		SED = OpenTable("SED", "dBASE", {InDir+"2_Skims\\"+ref+"\\3_SED\\TAZ_to_Zip.dbf", })
		JV = JoinViews("TAZSkims+SED", TAZskim+".origin", SED+".TAZID", )

		exprtemp = CreateExpression(JV, "Factortemp", "EMPTOT * EMPFAC + HHNUM * HHFAC", )
		expr = CreateExpression(JV, "Factor", "If "+exprtemp+" = 0 or "+exprtemp+" = null then 1 else "+exprtemp, )
		
		ZIPskim = AggregateTable("ZipSkims", JV+"|", "FFB", OutPath+TOD+"_"+corenames[ii]+"_Skim_THTDFM_ZIP.bin", "pzip5", 
								fieldspec, {{"Missing as zero"}})
								
			strct = null
			strct = GetTableStructure(ZIPskim)
			for i = 1 to strct.length do
				origname = strct[i][1]
				
				if origname contains "Avg " then strct[i][1] = right(origname, len(origname) - 4) 	
			
				strct[i] = strct[i] + {origname}
			end
			ModifyTable(ZIPskim, strct)		
			
		closeview(JV)
		closeview(TAZskim)
			
	end	

	
    quit:
         Return( RunMacro("TCB Closing",retval, ) )
         
endMacro // Update TH-TDFM Skims


Macro "Update National Skims" (MainDir, InDir, WDir, OutDir, TODper, ref)
 Runmacro("TCB Init")

// ======================================================
// Update National Network Skims, 
// Calculating new shortest paths
// ======================================================

retval = 1
infile = InDir+"3_Geog\\"+ref+"\\FullMerged_Network.dbd"
TOD = TODper

OutPath = OutDir+"\\"+ref+"\\1_Hwy\\"


// ********************* Open Network Layer ********************************************************

// Input Files
highway_file=infile

// Output Files
 
HighwayNetwork = OutPath+TOD+"_GLC_National.net"

// Open highway network
    cc = GetDBInfo(highway_file)
    dd = CreateMap("yyy",{{"Scope",cc[1]}, {"Auto Project", "True"}})
   
    baselyrs = GetDBLayers(highway_file)

    line_lyr = AddLayer(dd , "tierOne", highway_file, baselyrs[2])
    NodeLayer = AddLayer(dd, "Node", highway_file, baselyrs[1])
    
SetLayerVisibility("Node", "True")
SetLayer("tierOne")
	       

	       	
// ********************* Create Network File *******************************************************
       	
	  	thenetwork = CreateNetwork( ,HighwayNetwork,"Highway Network",
		    				{
		    				{"GLCAUTO","GLCAUTO_AB","GLCAUTO_BA"},
		    				{"Dist","Length","Length"},
		    				{"C Time","TIMEAB","TIMEBA"},
		    				{"SOVTOLL","SOVTOLL","SOVTOLL"}
    						},,)
    						
	Opts = null
	Opts.Input.Database = highway_file
	Opts.Input.Network = HighwayNetwork
	Opts.Input.[Centroids Set] = {highway_file+"|Node", "Node", "Centroids", "Select * where Centroid=1 AND TAZ=ID"}
	Opts.Global.VOI = 1
	
    retval = RunMacro("TCB Run Operation", "Highway Network Setting", Opts, &Ret)
 
 
	Setview("tierOne")
	
// ********************* Generate Skims ************************************************************

     Opts = null
     Opts.Input.Network = HighwayNetwork
     Opts.Input.[Origin Set] = {highway_file+"|Node", "Node", "Natnl Nodes", "Select * where Centroid=1 AND ID<>TAZ"}
     Opts.Input.[Destination Set] = {highway_file+"|Node", "Node", "NY Airports", "Select * where AIR_NY<>null"}
     Opts.Input.[Via Set] = {highway_file+"|Node", "Node"}
     Opts.Field.Minimize = "GLCAUTO"
     Opts.Field.Nodes = "Node.ID"
     Opts.Field.[Skim Fields] = {{"Dist", "All"}, {"C Time", "All"}, {"SOVTOLL", "All"}}
     Opts.Output.[Output Matrix].Label = TOD+" Shortest Path"
     Opts.Output.[Output Matrix].[File Name] = OutPath+TOD+"_GLC_Skim_National.mtx"

     retval = RunMacro("TCB Run Procedure", "TCSPMAT", Opts, &Ret)
    
     if !retval then goto quit
     
// Extract Airport Node ID's for Skim Field Names     
	SetView("Node")
	nApts = SelectByQuery("Airports", "Several", "Select * where AIR_NY <> null")
	ExportView("Node|Airports", "CSV", WDir + "Airport_Nodes.csv", {"ID", "AIR_NY", "AIRPORT", "Transit_Node"}, {{"CSV Header", 1}})
	AptNodes = OpenTable("AptNodes", "CSV", {WDir + "Airport_Nodes.csv", })
	nodeID = GetDataVector(AptNodes+"|", "ID", )
	APID = GetDataVector(AptNodes+"|", "AIR_NY", )
	AptName = GetDataVector(AptNodes+"|", "AIRPORT", )
	dim nodeIDstring[nodeID.length]
	for k = 1 to nodeID.length do
		nodeIDstring[k] = i2s(nodeID[k])
	end	
     
// Export Skims to BIN
	skim = OpenMatrix(OutPath+TOD+"_GLC_Skim_National.mtx", )
	
	cores = {"Dist (Skim)", "C Time (Skim)", "SOVTOLL (Skim)"}
	corenames = {"Dist", "Time", "Toll"}
	for ii = 1 to cores.length do
		mc = CreateMatrixCurrency(skim, cores[ii], , , )
		ExportMatrix(mc, nodeIDstring, "Rows", "FFB", OutPath+TOD+"_"+corenames[ii]+"_Skim_National.bin", )
		
		// Rename fields from NodeID #'s to Airport Names
		skimtable = OpenTable("National Skim Table", "FFB", {OutPath+TOD+"_"+corenames[ii]+"_Skim_National.bin", })
		strct = GetTableStructure(skimtable)
		for i = 1 to strct.length do
			origname = strct[i][1]
			for j = 1 to nApts do
				if origname = i2s(nodeID[j]) then strct[i][1] = AptName[j]	
			end
			strct[i] = strct[i] + {origname}
		end
		ModifyTable(skimtable, strct)	
		
		closeview(skimtable)
		
	end
	

    quit:
         Return( RunMacro("TCB Closing",retval, ) )

endMacro // Update National Skims


Macro "Combine Highway Skims" (MainDir, InDir, WDir, OutDir, TODper, ref)

// =============================================================================
// Combine Highway Skims from TH-TDFM ("Internal") & National ("External") Areas
// and combine skim values into single file (dist, time, toll)
// =============================================================================

	retval = 1
	TOD = TODper 

	Dir = OutDir+"\\"+ref+"\\1_Hwy\\"
	
	hwy_file = InDir+"3_Geog\\"+ref+"\\FullMerged_Network.dbd"

	
    Lyrs = RunMacro("TCB Add DB Layers", hwy_file) // standard TransCAD macro
    node_layer = Lyrs[1]
    link_layer = Lyrs[2]
 
	
	skims = {"Dist", "Time", "Toll"} // Skim Names
	

	AptNodes = OpenTable("AptNodes", "CSV", {WDir + "Airport_Nodes.csv", })
	airports = v2a(i2s(GetDataVector(AptNodes+"|", "Transit_Node", )))
	airname = v2a(GetDataVector(AptNodes+"|", "AIRPORT", ))	
	APID = v2a(GetDataVector(AptNodes+"|", "AIR_NY", ))
	
	for ss = 1 to skims.length do 
	
		ExtSkim = OpenTable("External Skims", "FFB", {Dir+TOD+"_"+skims[ss]+"_Skim_National.bin", })
		IntSkim = OpenTable("Internal Skims", "FFB", {Dir+TOD+"_"+skims[ss]+"_Skim_THTDFM_ZIP.bin", })
		
		// Export the first file, rename fields, add records for external/national
		if ss =1 then do
			ExportView(IntSkim+"|", "DBASE", Dir+TOD+"_Skim_All_Areas.dbf", , ) 
			newskimtable = OpenTable("NewSkimTable", "DBASE", {Dir+TOD+"_Skim_All_Areas.dbf", })
			strct = GetTableStructure(newskimtable)
			
			// Rename fields from airport names to skimname + airport ID number
			for i = 2 to strct.length do
				origname = strct[i][1]
		
				if origname contains airname[i-1] then strct[i][1] = "hwy" + skims[ss] + i2s(APID[i-1])	
				
				strct[i] = strct[i] + {origname}
			end
			strct[1] = strct[1] + {strct[1][1]}
			ModifyTable(newskimtable, strct)
			
			// Pick up ZipCode values for external skims
			JV = JoinViews("Ext+Zip",ExtSkim+".Origin", node_layer+".ID", )
			ZIParray = v2a(GetDataVector(JV+"|", "ZIP5", ))
			dim ZIParrayarray[ZIParray.length]
			for ii = 1 to ZIParray.length do
				ZIParrayarray[ii] = {ZIParray[ii]}
			end
			closeview(JV)

			// Add records to table for External Zip Codes
			r = AddRecords(newskimtable, {"PZIP5"}, ZIParrayarray, )		
			
		end // first skim
		
		// Add fields for subsequent files
		if ss > 1 then do
			newskimtable = OpenTable("NewSkimTable", "DBASE", {Dir+TOD+"_Skim_All_Areas.dbf", })
			strct = GetTableStructure(newskimtable)

			for i = 1 to strct.length do
				origname = strct[i][1]
				strct[i] = strct[i] + {origname}
			end
			
			for k = 1 to airports.length do
				strct = strct + {{"hwy" + skims[ss] + i2s(APID[k]), "Real", 12, 2, False, , , , , , , null}}
			end
			
			ModifyTable(newskimtable, strct)
			closeview(newskimtable)	
			
		end // skim >1
		
		

			for aa = 1 to airports.length do
			
				// Pickup zipcode for external skims
				ExtZip = JoinViews("Ext+Zip",ExtSkim+".Origin", node_layer+".ID", )
				
				newskimtable = OpenTable("New Skim Table", "DBASE", {Dir+TOD+"_Skim_All_Areas.dbf", })
				
				// Write external skim data into new table
				JV = JoinViews("New+Ext", newskimtable+".PZIP5", ExtZip+".ZIP5", {{"A", },{"Fields",{airname[aa],"Copy"}}})
				setview(JV)
				q = airname[aa] +" <> null"
				n = SelectByQuery("ExtRec", "Several", "Select * where "+q,)
				values = GetDataVector(JV+"|ExtRec", airname[aa], )
				SetDataVector(JV+"|ExtRec", "hwy"+skims[ss] + i2s(APID[aa]), values, )
				closeview(JV)
				
				// Write internal skim data into new table
				if ss <> 1 then do
					JV = JoinViews("New+Int", newskimtable+".PZIP5", IntSkim+".PZIP5", )
					setview(JV)
					n = SelectByQuery("IntRec", "Several", "Select * where "+airname[aa]+" <> null",)
					values = GetDataVector(JV+"|IntRec", airname[aa], )
					SetDataVector(JV+"|IntRec", "hwy"+skims[ss] + i2s(APID[aa]), values, )	
					closeview(JV)
				end
			
			end

	end
	
	
Return(retval)
endMacro // Combine Highway Skims


Macro "Update Transit Skims"(MainDir, InDir, WDir, OutDir, TODper, ref)
			
// ======================================================
//   Update Transit Skim Values
// ======================================================
	retval = 1
	TOD = TODper
	
	// ====================================
	// Step 1: Export MTX to DBF by Airport
	// ====================================
		
		// Input files
		inpmat1 = InDir+"2_Skims\\"+ref+"\\2_Trn\\T"+TOD+"DCB.mtx"
		inpmat2 = InDir+"2_Skims\\"+ref+"\\2_Trn\\T"+TOD+"WSB.mtx"
		inpmat3 = InDir+"2_Skims\\"+ref+"\\2_Trn\\T"+TOD+"WCB.mtx"
		inpmat4 = InDir+"2_Skims\\"+ref+"\\2_Trn\\T"+TOD+"DSB.mtx"
		
		outpath = OutDir+"\\"+ref+"\\2_Trn\\"

		AptNodes = OpenTable("AptNodes", "CSV", {WDir + "Airport_Nodes.csv", })
		airports = v2a(i2s(GetDataVector(AptNodes+"|", "Transit_Node", )))
		airname = v2a(GetDataVector(AptNodes+"|", "AIRPORT", ))
		APID = v2a(GetDataVector(AptNodes+"|", "AIR_NY", ))

		dim airfile[airports.length] 
		dim airval[airports.length] 
		for cc = 1 to airports.length do
			airfile[cc] = airname[cc]+"_1"
			airval[cc] = airname[cc]+"_2"
		end
		
		cores = {"FARE","INITIAL WAIT TIME","TRANSFER WAIT TIME","BUSIVTT","XBUSIVTT","RAILIVTT","CRIVTT","FERRYIVTT","ACCOVTT","EGROVTT","XFROVTT","AUTOTIME","AUTOCOST"}
		fieldnames = {"FARE", "IWAIT", "XWAIT", "BUSIV", "XBUSI", "RAILI", "CRIVT", "FERRY", "ACCOV", "EGROV", "XFROV", "AUTOT","ACOST"}
		modes = {"DC_", "WC_", "DS_", "WS_"}

		// Export to DBF by Mode
		
			//********* DRIVE TO COMMUTER RAIL**************

			m1=  openmatrix(inpmat1,)
			core= getmatrixcorenames(m1)

			for i = 1 to core.length -1 do 
			if i =4 then goto next // Skip Number of Transfers

			mc1 = creatematrixcurrency(m1, core[i],,,)
			outfile = outpath+TOD+"_DC_"+core[i]+".dbf"
			ExportMatrix(mc1, airports, "Rows", "DBASE", outfile, null)

			next:
			end//

			//********* WALK TO SUBWAY**************

			m2=  openmatrix(inpmat2,)
			core= getmatrixcorenames(m2)

			for j = 1 to core.length -1 do 
			if j = 4 then goto skip // Skip Number of Transfers
			name =core[j]
			mc2 = creatematrixcurrency(m2, name,,,)
			outfile = outpath+TOD+"_WS_"+core[j]+".dbf"
			ExportMatrix(mc2, airports, "Rows", "DBASE", outfile, null)

			skip:
			end//

			Step2:
			//********* WALK TO COMMUTER RAIL**************

			m3=  openmatrix(inpmat3,)
			core= getmatrixcorenames(m3)

			for i = 1 to core.length -1 do 
			if i =4 then goto nextstep // Skip Number of Transfers

			mc3 = creatematrixcurrency(m3, core[i],,,)
			outfile = outpath+TOD+"_WC_"+core[i]+".dbf"
			ExportMatrix(mc3, airports, "Rows", "DBASE", outfile, null)

			nextstep:
			end//

			//********* DRIVE TO SUBWAY**************

			m4=  openmatrix(inpmat4,)
			core= getmatrixcorenames(m4)

			for j = 1 to core.length -1 do 
			if j = 4 then goto skipstep // Skip Number of Transfers
			name =core[j]
			mc4 = creatematrixcurrency(m4, name,,,)
			outfile = outpath+TOD+"_DS_"+core[j]+".dbf"
			ExportMatrix(mc4, airports, "Rows", "DBASE", outfile, null)

			skipstep:
			end//


		// Export base/dummy table for structure/skeleton
		m1=  openmatrix(inpmat1,)
		core= getmatrixcorenames(m1)
		mc1 = creatematrixcurrency(m1, cores[1],,,)
		outfile = WDir+"BASEtemp.dbf"
		ExportMatrix(mc1, airports, "Rows", "DBASE", outfile, null)

		base = OpenTable("BASE", "DBASE", {outfile,})


		for kk = 1 to modes.length do
			lengthnw = if modes[kk]="DC_" OR modes[kk]="DS_" then fieldnames.length else fieldnames.length-1

			for jj = 1 to lengthnw do
				CreateExpression("BASE",modes[kk]+fieldnames[jj],"1.11",{"Real",10,2})
			end
		end

		FieldsFinal={"ROWS"}

		for kk = 1 to modes.length do
			lengthnw = if modes[kk]="DC_" OR modes[kk]="DS_" then fieldnames.length else fieldnames.length-1
			for jj = 1 to lengthnw do
				FieldsFinal = FieldsFinal+{modes[kk]+fieldnames[jj]}
			end
		end

		for xx = 1 to airname.length do
			ExportView("BASE|","DBASE",outpath+TOD+"_"+airname[xx]+".dbf",FieldsFinal,) 
		end

			maps = GetMaps()
			if maps <> null then do
				for i = 1 to maps[1].length do
					SetMapSaveFlag(maps[1][i],"False")
					end
				end
			RunMacro("G30 File Close All")


		for xx = 1 to airname.length do
			airfile[xx] = OpenTable(airname[xx],"DBASE",{outpath+TOD+"_"+airname[xx]+".dbf"},) 
		end

		for kk = 1 to modes.length do
			lengthnw = if modes[kk]="DC_" OR modes[kk]="DS_" then fieldnames.length else fieldnames.length-1
			for jj = 1 to lengthnw do
				view1 = OpenTable("Current", "DBASE", {outpath+TOD+"_"+modes[kk]+cores[jj]+".dbf"},)

				for yy= 1 to airports.length do
					airval[yy] = GetDataVector(view1+"|","F"+airports[yy],)
					SetDataVector(airfile[yy]+"|",modes[kk]+fieldnames[jj],airval[yy],)
				end
			end
		end		
		
			maps = GetMaps()
			if maps <> null then do
				for i = 1 to maps[1].length do
					SetMapSaveFlag(maps[1][i],"False")
					end
				end
			RunMacro("G30 File Close All")		
			
	// ==============================================
	// Step 2: Aggregate Skims from TAZs to ZIP Codes
	// ==============================================
			zipLU = OpenTable("ZipLookUp", "CSV", {MainDir+"0_Param\\2_LUT\\ZIPcode.csv", })
			ziplisttemp = AggregateTable("ZipCodeList", zipLU+"|", "FFB", WDir+"ZIPlist_temp.bin", "pzip5", 
											{{"PZIP5","MAX",}}, )	
											
			ExportView(ziplisttemp+"|", "FFB", WDir+"ZIPlist.bin", {"Pzip5"}, ) 											
			ziplist = OpenTable("ZipList", "FFB", {WDir+"ZIPlist.bin", })
			strctzip = GetTableStructure(ziplist)
			
			// Add all skim fields to ziplist
			for kk = 1 to modes.length do
				lengthnw = if modes[kk]="DC_" OR modes[kk]="DS_" then fieldnames.length else fieldnames.length-1

				for jj = 1 to lengthnw do
					CreateExpression(ziplist,modes[kk]+fieldnames[jj],"1.1111",{"Real",15,5})
				end
			end

			FieldsFinal={"PZIP5"}

			for kk = 1 to modes.length do
				lengthnw = if modes[kk]="DC_" OR modes[kk]="DS_" then fieldnames.length else fieldnames.length-1
				for jj = 1 to lengthnw do
					FieldsFinal = FieldsFinal+{modes[kk]+fieldnames[jj]}
				end
			end

			ExportView(ziplist+"|","FFB",WDir+"ZIPskimSkeleton.bin",FieldsFinal,) 
			ZipSkel = OpenTable("ZipSkeleton", "FFB", {WDir+"ZIPskimSkeleton.bin", }) 
			for kk = 1 to modes.length do
				lengthnw = if modes[kk]="DC_" OR modes[kk]="DS_" then fieldnames.length else fieldnames.length-1

				for jj = 1 to lengthnw do
					val = GetDataVector(ZipSkel+"|", modes[kk]+fieldnames[jj], )
					val = if val = 1.1111 then 0 else 0
					SetDataVector(ZipSkel+"|", modes[kk]+fieldnames[jj], val, )
				end
			end
			
			
			dim tmodegroup [modes.length]
			for ii = 1 to modes.length do
				tmodegroup[ii] = left(modes[ii], 2)
			end
			
			for aa = 1 to airports.length do 
			
					TAZskim = OpenTable(airname[aa],"DBASE",{outpath+TOD+"_"+airname[aa]+".dbf"},) 		

					fields = GetFields(TAZskim, "All")
					dim fieldspec[fields[1].length - 1, 3]
					for jj = 2 to fields[1].length do
						fieldspec[jj-1][1] = fields[1][jj]
						fieldspec[jj-1][2] = "Average"
						fieldspec[jj-1][3] = "Factor"
					end

					SED = OpenTable("SED", "dBASE", {InDir+"2_Skims\\"+ref+"\\3_SED\\TAZ_to_Zip.dbf", })
					JV = JoinViews("TAZSkims+SED", TAZskim+".ROWS", SED+".TAZID", )

					exprtemp = CreateExpression(JV, "Factortemp", "EMPTOT * EMPFAC + HHNUM * HHFAC", )
					expr = CreateExpression(JV, "Factor", "If "+exprtemp+" = 0 or "+exprtemp+" = null then 1 else "+exprtemp, )	
					
					dc = CreateExpression(JV, "DC", "dc_fare +dc_iwait + dc_xwait + dc_busiv + dc_xbusi + dc_crivt + dc_raili + dc_ferry + dc_accov + dc_egrov + dc_xfrov + dc_autot + dc_acost", )	
					wc = CreateExpression(JV, "WC", "wc_fare +wc_iwait + wc_xwait + wc_busiv + wc_xbusi + wc_crivt + wc_raili + wc_ferry + wc_accov + wc_egrov + wc_xfrov + wc_autot", )	
					ds = CreateExpression(JV, "DS", "ds_fare +ds_iwait + ds_xwait + ds_busiv + ds_xbusi + ds_crivt + ds_raili + ds_ferry + ds_accov + ds_egrov + ds_xfrov + ds_autot + ds_acost", )	
					ws = CreateExpression(JV, "WS", "ws_fare +ws_iwait + ws_xwait + ws_busiv + ws_xbusi + ws_crivt + ws_raili + ws_ferry + ws_accov + ws_egrov + ws_xfrov + ws_autot", )	

				for tt = 1 to tmodegroup.length do
					
					SetView(JV)
					n = SelectByQuery(tmodegroup[tt], "Several",  "Select * where "+tmodegroup[tt]+" > 0", )
					
					ZIPskim = AggregateTable("ZipSkims", JV+"|"+tmodegroup[tt], "FFB", WDir+"Temp"+tmodegroup[tt]+"_ZIP.bin", "pzip5", 
											fieldspec, {{"Missing as zero"}})

						strct = null
						strct = GetTableStructure(ZIPskim)
						for i = 1 to strct.length do
							origname = strct[i][1]

							if origname contains "Avg " then strct[i][1] = right(origname, len(origname) - 4) 	

							strct[i] = strct[i] + {origname}
						end
						ModifyTable(ZIPskim, strct)	
					
					ZipSkel = OpenTable("ZipSkeleton", "FFB", {WDir+"ZIPskimSkeleton.bin", })
					
					JVzip = JoinViews("Zip+"+tmodegroup[tt], "["+ZipSkel+"].PZIP5", "["+ZIPskim+"].Pzip5", )
					SetView(JVzip)
					n = SelectByQuery(tmodegroup[tt], "Several",  "Select * where ["+ZIPskim+"].Pzip5 <> null", )
					if n = 0 then goto skipmode
					numfields = if tmodegroup[tt] = "DC" or tmodegroup[tt] = "DS" then fieldnames.length else fieldnames.length - 1
					
					for ff = 1 to numfields do
						
						skimvals = GetDataVector(JVzip+"|"+tmodegroup[tt], "["+ZIPskim+"]."+modes[tt]+fieldnames[ff], )
						SetDataVector(JVzip+"|"+tmodegroup[tt], "["+ZipSkel+"]."+modes[tt]+fieldnames[ff], skimvals, )
						
					end
					
					goto skipmode
					skipmode:
					closeview(ZipSkel)
					closeview(JVzip)
					closeview(ZIPskim)	
				end //transit mode groups
			

			ZipSkel = OpenTable("ZipSkeleton", "FFB", {WDir+"ZIPskimSkeleton.bin", })
			ExportView(ZipSkel+"|", "DBASE", outpath+TOD+"_"+airname[aa]+"_ZIP.dbf", , )
			
			closeview(ZipSkel)
			closeview(JV)
			closeview(TAZskim)
			closeview(SED)

		end // airports

		closeview(zipLU)
		closeview(ziplist)
			
	// ================================
	// Step 3: Select Best Path by Mode
	// ================================
		

			Air =  outpath+TOD+"_"+airname[1]+"_ZIP.dbf"
			BaseFile = outpath+TOD+"_ZIP_InFields.dbf"
			TempFile = WDir+TOD+"_TempFields.dbf"
			Base1 = OpenTable("Base File", "DBASE", {Air},)

			fields = {"lbtime","lbfare","lbusiw","lbusxw","lbusac","cbtime","cbfare","cbusiw","cbusxw","cbusac","raltime","ralfare","railiw","railxw","railac"}
			fieldnames = {"PZIP5"}

			for ii=1 to fields.length do
				for kk=1 to airname.length do
					fieldnames = fieldnames+{fields[ii]+i2s(APID[kk])}
				end
			end

			for ii=2 to fieldnames.length do
				CreateExpression("Base File", fieldnames[ii], "1.11", {"Real",10,2})
			end

			ExportView("Base File|","DBASE",BaseFile,fieldnames,) 


			newtimes = {"WSBUSIVTT","DSBUSIVTT","WSXBUSIVTT","DSXBUSIVTT","WSRAILIVTT","DSRAILIVTT","WCRAILIVTT","DCRAILIVTT","WSBUSOTH","DSBUSOTH","WSXBUSOTH","DSXBUSOTH"}

			for yy=1 to newtimes.length do
				CreateExpression("Base File", newtimes[yy], "1.11", {"Real",10,2})

			end

			fieldexp = {"PZIP5"}+newtimes

			ExportView("Base File|","DBASE", TempFile, fieldexp,)

			RunMacro("G30 File Close All")


			Base = OpenTable("Zips Table", "DBASE", {BaseFile},)

			for jj=2 to fieldnames.length do
				val1 = GetDataVector(Base+"|",fieldnames[jj],)
				val1 = if val1=0 then 0.00 else 0.00
				SetDataVector(Base+"|",fieldnames[jj],val1,)
			end

			Temp = OpenTable("Temp File", "DBASE", {TempFile},)

			for jj=1 to newtimes.length do
				val2 = GetDataVector(Temp+"|",newtimes[jj],)
				val2 = if val2=0 then 0.0 else 0.0
				SetDataVector(Temp+"|",newtimes[jj],val2,)
			end

			RunMacro("G30 File Close All")

			for ii=1 to airname.length do
				Base = OpenTable("Zips Table", "DBASE", {BaseFile},)
				Temp = OpenTable("Temp File", "DBASE", {TempFile},)

				for jj=1 to newtimes.length do
					val2 = GetDataVector(Temp+"|",newtimes[jj],)
					val2 = if val2=0 then 0.0 else 0.0
					SetDataVector(Temp+"|",newtimes[jj],val2,)
				end

				AirInp = outpath+TOD+"_"+airname[ii]+"_ZIP.dbf"
				AirFile = OpenTable("Air File", "DBASE", {AirInp},)

				TempJoin = JoinViews("Temp Join", AirFile+".PZIP5", Temp+".PZIP5",)

				wsother = GetDataVector(TempJoin+"|","WSBUSOTH",)
				wscrivt = GetDataVector(TempJoin+"|","WS_CRIVT",)
				wsraili = GetDataVector(TempJoin+"|","WS_RAILI",)
				wsferry = GetDataVector(TempJoin+"|","WS_FERRY",)
				wsxubsi = GetDataVector(TempJoin+"|","WS_XBUSI",)

				dsother = GetDataVector(TempJoin+"|","DSBUSOTH",)
				dscrivt = GetDataVector(TempJoin+"|","DS_CRIVT",)
				dsraili = GetDataVector(TempJoin+"|","DS_RAILI",)
				dsferry = GetDataVector(TempJoin+"|","DS_FERRY",)
				dsxubsi = GetDataVector(TempJoin+"|","DS_XBUSI",) 

				wsother = wscrivt+wsraili+wsferry+wsxubsi
				dsother = dscrivt+dsraili+dsferry+dsxubsi

				SetDataVector(TempJoin+"|","WSBUSOTH",wsother,)
				SetDataVector(TempJoin+"|","DSBUSOTH",dsother,)

				SetView(TempJoin)

				BusSelectWS = SelectbyQuery("Bus LinksWS1", "Several", "Select * where WS_BUSIV>0 AND WSBUSOTH=0",)
				BusSelectDS = SelectbyQuery("Bus LinksDS1", "Several", "Select * where DS_BUSIV>0 AND DSBUSOTH=0",)



				wsbusiv = GetDataVector(TempJoin+"|Bus LinksWS1","WS_BUSIV",)
				wsxbusi = GetDataVector(TempJoin+"|Bus LinksWS1","WS_XBUSI",)
				wscrivt = GetDataVector(TempJoin+"|Bus LinksWS1","WS_CRIVT",)
				wsraili = GetDataVector(TempJoin+"|Bus LinksWS1","WS_RAILI",)
				wsferry = GetDataVector(TempJoin+"|Bus LinksWS1","WS_FERRY",)
				wsaccov = GetDataVector(TempJoin+"|Bus LinksWS1","WS_ACCOV",)
				wsegrov = GetDataVector(TempJoin+"|Bus LinksWS1","WS_EGROV",)
				wsxfrov = GetDataVector(TempJoin+"|Bus LinksWS1","WS_XFROV",)
				wsautot = GetDataVector(TempJoin+"|Bus LinksWS1","WS_AUTOT",)
				dsbusiv = GetDataVector(TempJoin+"|Bus LinksDS1","DS_BUSIV",)
				dsxbusi = GetDataVector(TempJoin+"|Bus LinksDS1","DS_XBUSI",)
				dscrivt = GetDataVector(TempJoin+"|Bus LinksDS1","DS_CRIVT",)
				dsraili = GetDataVector(TempJoin+"|Bus LinksDS1","DS_RAILI",)
				dsferry = GetDataVector(TempJoin+"|Bus LinksDS1","DS_FERRY",)
				dsaccov = GetDataVector(TempJoin+"|Bus LinksDS1","DS_ACCOV",)
				dsegrov = GetDataVector(TempJoin+"|Bus LinksDS1","DS_EGROV",)
				dsxfrov = GetDataVector(TempJoin+"|Bus LinksDS1","DS_XFROV",)
				dsautot = GetDataVector(TempJoin+"|Bus LinksDS1","DS_AUTOT",)

				wsbusiv = wsbusiv+wsxbusi+wscrivt+wsraili+wsferry+wsaccov+wsegrov+wsxfrov+wsautot
				dsbusiv = dsbusiv+dsxbusi+dscrivt+dsraili+dsferry+dsaccov+dsegrov+dsxfrov+dsautot

				if BusSelectWS>0 then SetDataVector(TempJoin+"|Bus LinksWS1","WSBUSIVTT",wsbusiv,)
				if BusSelectDS>0 then SetDataVector(TempJoin+"|Bus LinksDS1","DSBUSIVTT",dsbusiv,)
				
			//cb
				wsxother = GetDataVector(TempJoin+"|","WSXBUSOTH",)
				wscrivt = GetDataVector(TempJoin+"|","WS_CRIVT",)
				wsraili = GetDataVector(TempJoin+"|","WS_RAILI",)
				wsferry = GetDataVector(TempJoin+"|","WS_FERRY",)
				wsferry = GetDataVector(TempJoin+"|","WS_FERRY",)

				dsxother = GetDataVector(TempJoin+"|","DSXBUSOTH",)
				dscrivt = GetDataVector(TempJoin+"|","DS_CRIVT",)
				dsraili = GetDataVector(TempJoin+"|","DS_RAILI",)
				dsferry = GetDataVector(TempJoin+"|","DS_FERRY",)

				wsxother = wscrivt+wsraili+wsferry
				dsxother = dscrivt+dsraili+dsferry

				SetDataVector(TempJoin+"|","WSXBUSOTH",wsxother,)
				SetDataVector(TempJoin+"|","DSXBUSOTH",dsxother,)

				SetView(TempJoin)

				XBusSelectWS = SelectbyQuery("XBus LinksWS1", "Several", "Select * where WS_XBUSI>0 AND WSXBUSOTH=0",)
				XBusSelectDS = SelectbyQuery("XBus LinksDS1", "Several", "Select * where DS_XBUSI>0 AND DSXBUSOTH=0",)

				wsbusiv = GetDataVector(TempJoin+"|XBus LinksWS1","WS_BUSIV",)
				wsxbusi = GetDataVector(TempJoin+"|XBus LinksWS1","WS_XBUSI",)
				wscrivt = GetDataVector(TempJoin+"|XBus LinksWS1","WS_CRIVT",)
				wsraili = GetDataVector(TempJoin+"|XBus LinksWS1","WS_RAILI",)
				wsferry = GetDataVector(TempJoin+"|XBus LinksWS1","WS_FERRY",)
				wsaccov = GetDataVector(TempJoin+"|XBus LinksWS1","WS_ACCOV",)
				wsegrov = GetDataVector(TempJoin+"|XBus LinksWS1","WS_EGROV",)
				wsxfrov = GetDataVector(TempJoin+"|XBus LinksWS1","WS_XFROV",)
				wsautot = GetDataVector(TempJoin+"|XBus LinksWS1","WS_AUTOT",)
				dsbusiv = GetDataVector(TempJoin+"|XBus LinksDS1","DS_BUSIV",)
				dsxbusi = GetDataVector(TempJoin+"|XBus LinksDS1","DS_XBUSI",)
				dscrivt = GetDataVector(TempJoin+"|XBus LinksDS1","DS_CRIVT",)
				dsraili = GetDataVector(TempJoin+"|XBus LinksDS1","DS_RAILI",)
				dsferry = GetDataVector(TempJoin+"|XBus LinksDS1","DS_FERRY",)
				dsaccov = GetDataVector(TempJoin+"|XBus LinksDS1","DS_ACCOV",)
				dsegrov = GetDataVector(TempJoin+"|XBus LinksDS1","DS_EGROV",)
				dsxfrov = GetDataVector(TempJoin+"|XBus LinksDS1","DS_XFROV",)
				dsautot = GetDataVector(TempJoin+"|XBus LinksDS1","DS_AUTOT",)

				wsxbusiv = wsbusiv+wsxbusi+wscrivt+wsraili+wsferry+wsaccov+wsegrov+wsxfrov+wsautot
				dsxbusiv = dsbusiv+dsxbusi+dscrivt+dsraili+dsferry+dsaccov+dsegrov+dsxfrov+dsautot

				if XBusSelectWS>0 then SetDataVector(TempJoin+"|XBus LinksWS1","WSXBUSIVTT",wsxbusiv,)
				if xBusSelectDS>0 then SetDataVector(TempJoin+"|XBus LinksDS1","DSXBUSIVTT",dsxbusiv,)
			//cb

				RailSelectWS = SelectbyQuery("Rail LinksWS1", "Several", "Select * where WS_CRIVT+WS_RAILI+WS_FERRY>0",)
				RailSelectDS = SelectbyQuery("Rail LinksDS1", "Several", "Select * where DS_CRIVT+DS_RAILI+DS_FERRY>0",)
				RailSelectWC = SelectbyQuery("Rail LinksWC1", "Several", "Select * where WC_CRIVT+WC_RAILI+WC_FERRY>0",)
				RailSelectDC = SelectbyQuery("Rail LinksDC1", "Several", "Select * where DC_CRIVT+DC_RAILI+DC_FERRY>0",)

				wsbusiv = GetDataVector(TempJoin+"|Rail LinksWS1","WS_BUSIV",)
				wsxbusi = GetDataVector(TempJoin+"|Rail LinksWS1","WS_XBUSI",)
				wscrivt = GetDataVector(TempJoin+"|Rail LinksWS1","WS_CRIVT",)
				wsraili = GetDataVector(TempJoin+"|Rail LinksWS1","WS_RAILI",)
				wsferry = GetDataVector(TempJoin+"|Rail LinksWS1","WS_FERRY",)
				wsaccov = GetDataVector(TempJoin+"|Rail LinksWS1","WS_ACCOV",)
				wsegrov = GetDataVector(TempJoin+"|Rail LinksWS1","WS_EGROV",)
				wsxfrov = GetDataVector(TempJoin+"|Rail LinksWS1","WS_XFROV",)
				wsautot = GetDataVector(TempJoin+"|Rail LinksWS1","WS_AUTOT",)

				wsraili = wsbusiv+wsxbusi+wscrivt+wsraili+wsferry+wsaccov+wsegrov+wsxfrov+wsautot

				if RailSelectWS>0 then SetDataVector(TempJoin+"|Rail LinksWS1","WSRAILIVTT",wsraili,)

				dsbusiv = GetDataVector(TempJoin+"|Rail LinksDS1","DS_BUSIV",)
				dsxbusi = GetDataVector(TempJoin+"|Rail LinksDS1","DS_XBUSI",)
				dscrivt = GetDataVector(TempJoin+"|Rail LinksDS1","DS_CRIVT",)
				dsraili = GetDataVector(TempJoin+"|Rail LinksDS1","DS_RAILI",)
				dsferry = GetDataVector(TempJoin+"|Rail LinksDS1","DS_FERRY",)
				dsaccov = GetDataVector(TempJoin+"|Rail LinksDS1","DS_ACCOV",)
				dsegrov = GetDataVector(TempJoin+"|Rail LinksDS1","DS_EGROV",)
				dsxfrov = GetDataVector(TempJoin+"|Rail LinksDS1","DS_XFROV",)
				dsautot = GetDataVector(TempJoin+"|Rail LinksDS1","DS_AUTOT",)

				dsraili = dsbusiv+dsxbusi+dscrivt+dsraili+dsferry+dsaccov+dsegrov+dsxfrov+dsautot

				if RailSelectDS>0 then SetDataVector(TempJoin+"|Rail LinksDS1","DSRAILIVTT",dsraili,)

				wcbusiv = GetDataVector(TempJoin+"|Rail LinksWC1","WC_BUSIV",)
				wcxbusi = GetDataVector(TempJoin+"|Rail LinksWC1","WC_XBUSI",)
				wccrivt = GetDataVector(TempJoin+"|Rail LinksWC1","WC_CRIVT",)
				wcraili = GetDataVector(TempJoin+"|Rail LinksWC1","WC_RAILI",)
				wcferry = GetDataVector(TempJoin+"|Rail LinksWC1","WC_FERRY",)
				wcaccov = GetDataVector(TempJoin+"|Rail LinksWC1","WC_ACCOV",)
				wcegrov = GetDataVector(TempJoin+"|Rail LinksWC1","WC_EGROV",)
				wcxfrov = GetDataVector(TempJoin+"|Rail LinksWC1","WC_XFROV",)
				wcautot = GetDataVector(TempJoin+"|Rail LinksWC1","WC_AUTOT",)

				wcraili = wcbusiv+wcxbusi+wccrivt+wcraili+wcferry+wcaccov+wcegrov+wcxfrov+wcautot

				if RailSelectWC>0 then SetDataVector(TempJoin+"|Rail LinksWC1","WCRAILIVTT",wcraili,)

				dcbusiv = GetDataVector(TempJoin+"|Rail LinksDC1","DC_BUSIV",)
				dcxbusi = GetDataVector(TempJoin+"|Rail LinksDC1","DC_XBUSI",)
				dccrivt = GetDataVector(TempJoin+"|Rail LinksDC1","DC_CRIVT",)
				dcraili = GetDataVector(TempJoin+"|Rail LinksDC1","DC_RAILI",)
				dcferry = GetDataVector(TempJoin+"|Rail LinksDC1","DC_FERRY",)
				dcaccov = GetDataVector(TempJoin+"|Rail LinksDC1","DC_ACCOV",)
				dcegrov = GetDataVector(TempJoin+"|Rail LinksDC1","DC_EGROV",)
				dcxfrov = GetDataVector(TempJoin+"|Rail LinksDC1","DC_XFROV",)
				dcautot = GetDataVector(TempJoin+"|Rail LinksDC1","DC_AUTOT",)

				dcraili = dcbusiv+dcxbusi+dccrivt+dcraili+dcferry+dcaccov+dcegrov+dcxfrov+dcautot

				if RailSelectDC>0 then SetDataVector(TempJoin+"|Rail LinksDC1","DCRAILIVTT",dcraili,)


			//********* Join Air and Base Files *****************************************************************

				JoinedZip = JoinViews("Air Join", Base+".PZIP5", TempJoin+".[Air File].PZIP5",)

			//********* Select Best Local Bus Path and Add to Input File ****************************************

				SetView(JoinedZip)

				BusSelectWS1 = SelectbyQuery("Bus LinksWS", "Several", "Select * where WSBUSIVTT>0 AND (WSBUSIVTT<DSBUSIVTT OR DSBUSIVTT=0)",) 
				BusSelectDS1 = SelectbyQuery("Bus LinksDS", "Several", "Select * where DSBUSIVTT>0 AND (DSBUSIVTT<WSBUSIVTT OR WSBUSIVTT=0)",)

				wsbusivtt = GetDataVector(JoinedZip+"|Bus LinksWS","WSBUSIVTT",)
				dsbusivtt = GetDataVector(JoinedZip+"|Bus LinksDS","DSBUSIVTT",)

				if BusSelectWS1>0 then SetDataVector(JoinedZip+"|Bus LinksWS","lbtime"+i2s(APID[ii]),wsbusivtt,)
				if BusSelectDS1>0 then SetDataVector(JoinedZip+"|Bus LinksDS","lbtime"+i2s(APID[ii]),dsbusivtt,)

				wsbusfare = GetDataVector(JoinedZip+"|Bus LinksWS","WS_FARE",)
				dsbusfare = GetDataVector(JoinedZip+"|Bus LinksDS","DS_FARE",)

				if BusSelectWS1>0 then SetDataVector(JoinedZip+"|Bus LinksWS","lbfare"+i2s(APID[ii]),wsbusfare,)
				if BusSelectDS1>0 then SetDataVector(JoinedZip+"|Bus LinksDS","lbfare"+i2s(APID[ii]),dsbusfare,)	

				wsbusiw = GetDataVector(JoinedZip+"|Bus LinksWS","WS_IWAIT",)
				dsbusiw = GetDataVector(JoinedZip+"|Bus LinksDS","DS_IWAIT",)

				if BusSelectWS1>0 then SetDataVector(JoinedZip+"|Bus LinksWS","lbusiw"+i2s(APID[ii]),wsbusiw,)
				if BusSelectDS1>0 then SetDataVector(JoinedZip+"|Bus LinksDS","lbusiw"+i2s(APID[ii]),dsbusiw,)

				wsbusxw = GetDataVector(JoinedZip+"|Bus LinksWS","WS_XWAIT",)
				dsbusxw = GetDataVector(JoinedZip+"|Bus LinksDS","DS_XWAIT",)

				if BusSelectWS1>0 then SetDataVector(JoinedZip+"|Bus LinksWS","lbusxw"+i2s(APID[ii]),wsbusxw,)
				if BusSelectDS1>0 then SetDataVector(JoinedZip+"|Bus LinksDS","lbusxw"+i2s(APID[ii]),dsbusxw,)

				dsbusac = GetDataVector(JoinedZip+"|Bus LinksDS","DS_ACOST",)

				if BusSelectDS1>0 then SetDataVector(JoinedZip+"|Bus LinksDS","lbusac"+i2s(APID[ii]),dsbusac,)
				

			//********* Select Best Express Bus Path and Add to Input File ****************************************

				SetView(JoinedZip)

				XBusSelectWS1 = SelectbyQuery("XBus LinksWS", "Several", "Select * where WSXBUSIVTT>0 AND (WSXBUSIVTT<DSXBUSIVTT OR DSXBUSIVTT=0)",) 
				XBusSelectDS1 = SelectbyQuery("XBus LinksDS", "Several", "Select * where DSXBUSIVTT>0 AND (DSXBUSIVTT<WSXBUSIVTT OR WSXBUSIVTT=0)",)

				wsxbusivtt = GetDataVector(JoinedZip+"|XBus LinksWS","WSXBUSIVTT",)
				dsxbusivtt = GetDataVector(JoinedZip+"|XBus LinksDS","DSXBUSIVTT",)

				if XBusSelectWS1>0 then SetDataVector(JoinedZip+"|XBus LinksWS","cbtime"+i2s(APID[ii]),wsxbusivtt,)
				if XBusSelectDS1>0 then SetDataVector(JoinedZip+"|XBus LinksDS","cbtime"+i2s(APID[ii]),dsxbusivtt,)

				wsxbusfare = GetDataVector(JoinedZip+"|XBus LinksWS","WS_FARE",)
				dsxbusfare = GetDataVector(JoinedZip+"|XBus LinksDS","DS_FARE",)

				if XBusSelectWS1>0 then SetDataVector(JoinedZip+"|XBus LinksWS","cbfare"+i2s(APID[ii]),wsxbusfare,)
				if XBusSelectDS1>0 then SetDataVector(JoinedZip+"|XBus LinksDS","cbfare"+i2s(APID[ii]),dsxbusfare,)	

				wsxbusiw = GetDataVector(JoinedZip+"|XBus LinksWS","WS_IWAIT",)
				dsxbusiw = GetDataVector(JoinedZip+"|XBus LinksDS","DS_IWAIT",)

				if XBusSelectWS1>0 then SetDataVector(JoinedZip+"|XBus LinksWS","cbusiw"+i2s(APID[ii]),wsxbusiw,)
				if XBusSelectDS1>0 then SetDataVector(JoinedZip+"|XBus LinksDS","cbusiw"+i2s(APID[ii]),dsxbusiw,)

				wsxbusxw = GetDataVector(JoinedZip+"|XBus LinksWS","WS_XWAIT",)
				dsxbusxw = GetDataVector(JoinedZip+"|XBus LinksDS","DS_XWAIT",)

				if XBusSelectWS1>0 then SetDataVector(JoinedZip+"|XBus LinksWS","cbusxw"+i2s(APID[ii]),wsxbusxw,)
				if XBusSelectDS1>0 then SetDataVector(JoinedZip+"|XBus LinksDS","cbusxw"+i2s(APID[ii]),dsxbusxw,)

				dsxbusac = GetDataVector(JoinedZip+"|XBus LinksDS","DS_ACOST",)

				if XBusSelectDS1>0 then SetDataVector(JoinedZip+"|XBus LinksDS","cbusac"+i2s(APID[ii]),dsxbusac,)				

			//************ Select Rail Best Path and Add to Input File ******************************************

				RailSelectWS1 = SelectbyQuery("Rail LinksWS", "Several", "Select * where WSRAILIVTT>0 AND (WSRAILIVTT<DSRAILIVTT OR DSRAILIVTT=0) AND (WSRAILIVTT<WCRAILIVTT OR WCRAILIVTT=0) AND (WSRAILIVTT<DCRAILIVTT OR DCRAILIVTT=0)",)
				RailSelectDS1 = SelectbyQuery("Rail LinksDS", "Several", "Select * where DSRAILIVTT>0 AND (DSRAILIVTT<WSRAILIVTT OR WSRAILIVTT=0) AND (DSRAILIVTT<WCRAILIVTT OR WCRAILIVTT=0) AND (DSRAILIVTT<DCRAILIVTT OR DCRAILIVTT=0)",)
				RailSelectWC1 = SelectbyQuery("Rail LinksWC", "Several", "Select * where WCRAILIVTT>0 AND (WCRAILIVTT<DSRAILIVTT OR DSRAILIVTT=0) AND (WCRAILIVTT<WSRAILIVTT OR WSRAILIVTT=0) AND (WCRAILIVTT<DCRAILIVTT OR DCRAILIVTT=0)",)
				RailSelectDC1 = SelectbyQuery("Rail LinksDC", "Several", "Select * where DCRAILIVTT>0 AND (DCRAILIVTT<DSRAILIVTT OR DSRAILIVTT=0) AND (DCRAILIVTT<WCRAILIVTT OR WCRAILIVTT=0) AND (DCRAILIVTT<WSRAILIVTT OR WSRAILIVTT=0)",)

				wsrailivtt = GetDataVector(JoinedZip+"|Rail LinksWS","WSRAILIVTT",)
				dsrailivtt = GetDataVector(JoinedZip+"|Rail LinksDS","DSRAILIVTT",)
				wcrailivtt = GetDataVector(JoinedZip+"|Rail LinksWC","WCRAILIVTT",)
				dcrailivtt = GetDataVector(JoinedZip+"|Rail LinksDC","DCRAILIVTT",)

				if RailSelectWS1>0 then SetDataVector(JoinedZip+"|Rail LinksWS","raltime"+i2s(APID[ii]),wsrailivtt,)
				if RailSelectDS1>0 then SetDataVector(JoinedZip+"|Rail LinksDS","raltime"+i2s(APID[ii]),dsrailivtt,)
				if RailSelectWC1>0 then SetDataVector(JoinedZip+"|Rail LinksWC","raltime"+i2s(APID[ii]),wcrailivtt,)
				if RailSelectDC1>0 then SetDataVector(JoinedZip+"|Rail LinksDC","raltime"+i2s(APID[ii]),dcrailivtt,)

				wsrailfare = GetDataVector(JoinedZip+"|Rail LinksWS","WS_FARE",)
				dsrailfare = GetDataVector(JoinedZip+"|Rail LinksDS","DS_FARE",)
				wcrailfare = GetDataVector(JoinedZip+"|Rail LinksWC","WC_FARE",)
				dcrailfare = GetDataVector(JoinedZip+"|Rail LinksDC","DC_FARE",)

				wsrailfare = if (airname[ii]="JFK" AND wsrailfare<>0) then wsrailfare+5 else wsrailfare
				wsrailfare = if (airname[ii]="EWR" AND wsrailfare<>0) then wsrailfare+5.5 else wsrailfare 
				dsrailfare = if (airname[ii]="JFK" AND dsrailfare<>0) then dsrailfare+5 else dsrailfare
				dsrailfare = if (airname[ii]="EWR" AND dsrailfare<>0) then dsrailfare+5.5 else dsrailfare 
				wcrailfare = if (airname[ii]="JFK" AND wcrailfare<>0) then wcrailfare+5 else wcrailfare
				wcrailfare = if (airname[ii]="EWR" AND wcrailfare<>0) then wcrailfare+5.5 else wcrailfare 
				dcrailfare = if (airname[ii]="JFK" AND dcrailfare<>0) then dcrailfare+5 else dcrailfare
				dcrailfare = if (airname[ii]="EWR" AND dcrailfare<>0) then dcrailfare+5.5 else dcrailfare 

				if RailSelectWS1>0 then SetDataVector(JoinedZip+"|Rail LinksWS","ralfare"+i2s(APID[ii]),wsrailfare,)
				if RailSelectDS1>0 then SetDataVector(JoinedZip+"|Rail LinksDS","ralfare"+i2s(APID[ii]),dsrailfare,)
				if RailSelectWC1>0 then SetDataVector(JoinedZip+"|Rail LinksWC","ralfare"+i2s(APID[ii]),wcrailfare,)
				if RailSelectDC1>0 then SetDataVector(JoinedZip+"|Rail LinksDC","ralfare"+i2s(APID[ii]),dcrailfare,)

				wsrailiw = GetDataVector(JoinedZip+"|Rail LinksWS","WS_IWAIT",)
				dsrailiw = GetDataVector(JoinedZip+"|Rail LinksDS","DS_IWAIT",)
				wcrailiw = GetDataVector(JoinedZip+"|Rail LinksWC","WC_IWAIT",)
				dcrailiw = GetDataVector(JoinedZip+"|Rail LinksDC","DC_IWAIT",)

				if RailSelectWS1>0 then SetDataVector(JoinedZip+"|Rail LinksWS","railiw"+i2s(APID[ii]),wsrailiw,)
				if RailSelectDS1>0 then SetDataVector(JoinedZip+"|Rail LinksDS","railiw"+i2s(APID[ii]),dsrailiw,)
				if RailSelectWC1>0 then SetDataVector(JoinedZip+"|Rail LinksWC","railiw"+i2s(APID[ii]),wcrailiw,)
				if RailSelectDC1>0 then SetDataVector(JoinedZip+"|Rail LinksDC","railiw"+i2s(APID[ii]),dcrailiw,)

				wsrailxw = GetDataVector(JoinedZip+"|Rail LinksWS","WS_XWAIT",)
				dsrailxw = GetDataVector(JoinedZip+"|Rail LinksDS","DS_XWAIT",)
				wcrailxw = GetDataVector(JoinedZip+"|Rail LinksWC","WC_XWAIT",)
				dcrailxw = GetDataVector(JoinedZip+"|Rail LinksDC","DC_XWAIT",)

				if RailSelectWS1>0 then SetDataVector(JoinedZip+"|Rail LinksWS","railxw"+i2s(APID[ii]),wsrailxw,)
				if RailSelectDS1>0 then SetDataVector(JoinedZip+"|Rail LinksDS","railxw"+i2s(APID[ii]),dsrailxw,)
				if RailSelectWC1>0 then SetDataVector(JoinedZip+"|Rail LinksWC","railxw"+i2s(APID[ii]),wcrailxw,)
				if RailSelectDC1>0 then SetDataVector(JoinedZip+"|Rail LinksDC","railxw"+i2s(APID[ii]),dcrailxw,)

				dsrailac = GetDataVector(JoinedZip+"|Rail LinksDS","DS_ACOST",)
				dcrailac = GetDataVector(JoinedZip+"|Rail LinksDC","DC_ACOST",)

				if RailSelectDS1>0 then SetDataVector(JoinedZip+"|Rail LinksDS","railac"+i2s(APID[ii]),dsrailac,)
				if RailSelectDC1>0 then SetDataVector(JoinedZip+"|Rail LinksDC","railac"+i2s(APID[ii]),dcrailac,)

				maps = GetMaps()
				if maps <> null then do
					for i = 1 to maps[1].length do
						SetMapSaveFlag(maps[1][i],"False")
						end
					end
				RunMacro("G30 File Close All")

			end

				maps = GetMaps()
				if maps <> null then do
					for i = 1 to maps[1].length do
						SetMapSaveFlag(maps[1][i],"False")
						end
					end
				RunMacro("G30 File Close All")
			
	
	return(retval)
endMacro // Update Transit Skims


