///////////////////////////////////////////////////
//
//	4_RUN_JAVA_MODEL.RSC:
//
//	This script writes a properties file
//  and batch file to run the Java-based
//  switching model. It then calls the 
//  batch file to execute the model.
//
//  Chrissy Bernardo, October 2015
//
///////////////////////////////////////////////////


// Main macro to call steps of the process
Macro "Run Java Main"(Args)
	
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
	

	stepname = null
	

			if !RunMacro("Check Inputs", MainDir, InDir+"2_Skims\\") then do stepname = "Check Skim Inputs" goto quit end

			if !RunMacro("Write Java Call Files", MainDir, OutDir+"3_Switching_Model\\1_In\\", OutDir+"3_Switching_Model\\2_Out\\") then do stepname = "Write Java Call Files" goto quit end
						
				RunMacro("close everything")
				
			if !RunMacro("Run Model", MainDir, OutDir+"3_Switching_Model\\1_In\\", OutDir+"3_Switching_Model\\2_Out\\") then do stepname = "Run Model" goto quit end
						
				RunMacro("close everything")


	quit:
		if stepname <> null	then do
			ShowMessage("Model failed at Step: "+stepname)
			return(0)
		end
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
// 	CHECK INPUT FILES FOR BASE AND FUTURE YEARS -- MAYBE JUST SET UP "BASE" AND "BUILD" FOLDERS FOR SKIM INPUTS?
//====================================================	 	
	retval = 1
	
	return(retval)
	
endMacro // Check Inputs

Macro "Write Java Call Files"(MainDir, InDir, OutDir)
			
// ========================================================
//   Write Properties and Batch File for Calling Java Model
// ========================================================
	retval = 0
	
	base1 = OpenTable("Base Business", "CSV", {InDir + "base_business.csv", })
	busrecs = GetRecordCount(base1, )
	closeview(base1)
	
	base2 = OpenTable("Base NonBusiness", "CSV", {InDir + "base_nonbusiness.csv", })
	nonbusrecs = GetRecordCount(base2, )	
	closeview(base2)
	
	InDirJ = substitute(InDir, "\\", "/", )
	OutDirJ = substitute(OutDir, "\\", "/", )
	coeffDir = MainDir + "0_Param\\4_Model\\"
	coeffDirJ = substitute(coeffDir, "\\", "/", )
	codeDir = MainDir + "2_Code\\2_Java\\"
		
	propertiesfinal = codeDir + "config\\airportChoice.properties"
	properties = InDir + "airportChoice.properties"
	batchfile = InDir + "runAirportChoice.bat"
	batchfinal = codeDir + "runAirportChoice.bat"
		
		////////////////////////////
		// Write Properties File
		////////////////////////////
		
		if GetFileInfo(properties) <> null 
			then do DeleteFile(properties) end

		f = OpenFile(properties, "w+")	
		

		WriteLine(f, trim("# Purposes - Business and non-business                                                     "))
		WriteLine(f, trim("##############################################                                             "))
		WriteLine(f, trim("# BUSINESS                                                                                 "))
		WriteLine(f, trim("##############################################                                             "))
		WriteLine(f, trim("business.numrecords = "+i2s(busrecs)+"                                                     "))
		WriteLine(f, trim("business.base.data.file.name = " + InDirJ + "base_business.csv                                     "))
		WriteLine(f, trim("business.build.data.file.name = " + InDirJ + "build_business.csv                                   "))
		WriteLine(f, trim("business.coefficient.file.name = " + coeffDirJ + "coefficients_business.csv                       "))
		WriteLine(f, trim("business.constants.file.name = " + coeffDirJ + "constants_business.csv                            "))
		WriteLine(f, trim("business.out.file.name = " + OutDirJ + "switch_probabilities_business.csv                                          "))
		WriteLine(f, trim("business.airport.mode.summary.file.name = " + OutDirJ + "airport_mode_summary_business.csv        "))
		WriteLine(f, trim("business.airport.origin.summary.file.name = " + OutDirJ + "airport_origin_summary_business.csv    "))
		WriteLine(f, trim("business.probability.file.name = " + OutDirJ + "base_probabilities_business.csv                   "))
		WriteLine(f, trim("                                                                                           "))
		WriteLine(f, trim("##############################################                                             "))
		WriteLine(f, trim("# NON-BUSINESS                                                                             "))
		WriteLine(f, trim("##############################################                                             "))
		WriteLine(f, trim("nonbusiness.numrecords = "+i2s(nonbusrecs)+"                                               "))
		WriteLine(f, trim("nonbusiness.base.data.file.name = " + InDirJ + "base_nonbusiness.csv                                  "))
		WriteLine(f, trim("nonbusiness.build.data.file.name = " + InDirJ + "build_nonbusiness.csv                                "))
		WriteLine(f, trim("nonbusiness.coefficient.file.name = " + coeffDirJ + "coefficients_nonbusiness.csv                    "))
		WriteLine(f, trim("nonbusiness.constants.file.name = " + coeffDirJ + "constants_nonbusiness.csv                         "))
		WriteLine(f, trim("nonbusiness.out.file.name = " + OutDirJ + "switch_probabilities_nonbusiness.csv                                       "))
		WriteLine(f, trim("nonbusiness.airport.mode.summary.file.name = " + OutDirJ + "airport_mode_summary_nonbusiness.csv     "))
		WriteLine(f, trim("nonbusiness.airport.origin.summary.file.name = " + OutDirJ + "airport_origin_summary_nonbusiness.csv "))
		WriteLine(f, trim("nonbusiness.probability.file.name = " + OutDirJ + "base_probabilities_nonbusiness.csv                "))
		CloseFile(f)

		CopyFile(properties, propertiesfinal)
	
	
		////////////////////////////
		// Write Batch File
		////////////////////////////
		
		if GetFileInfo(batchfile) <> null 
			then do DeleteFile(batchfile) end

		f = OpenFile(batchfile, "w+")

		WriteLine(f, "ECHO %startTime%%Time%                                                                            ")
		WriteLine(f, "ECHO Running Airport Model...                                                                     ")
		WriteLine(f, "                                                                                                  ")
		WriteLine(f, "SET JAVA_64_PATH=\"C:\\Program Files\\Java\\jre7\"")
		WriteLine(f, "SET CLASSPATH=" + codeDir + "*;config")
		WriteLine(f, "SET PROPERTY_FILE=airportChoice")
		WriteLine(f, "                                                                                                  ")
		WriteLine(f, "%JAVA_64_PATH%\\bin\\java -showversion -server switchmodel.JointAirportModeChoice %PROPERTY_FILE% ")
		WriteLine(f, "                                                                                                  ")
		WriteLine(f, "ECHO completed                                                                                    ")
		CloseFile(f)
		
		
		CopyFile(batchfile, batchfinal)	

	retval = 1
	return(retval)
endMacro // Write Java Call Files

Macro "Run Model"(MainDir, InDir, OutDir)
			
// ========================================================
//   Run Java-based Switching Model, through batch file
// ========================================================
	retval = 0

	
	codeDir = MainDir + "2_Code\\2_Java\\"
	batchfinal = codeDir + "runAirportChoice.bat"	
	batchfile = batchfinal + " > JavaLog.txt" 	
	
	callbatch = codeDir + "runBatch.bat"
	
	logint = codeDir + "JavaLog.txt"
	logfile = OutDir + "JavaLog.txt"
	
	if GetFileInfo(callbatch) <> null 
		then do DeleteFile(callbatch) end	
	
	if GetFileInfo(logfile) <> null 
		then do DeleteFile(logfile) end	
		
	if GetFileInfo(logint) <> null 
		then do DeleteFile(logint) end	
		
	codePath = SplitPath(codeDir)	
	
	f = OpenFile(callbatch, "w+")

	WriteLine(f, codePath[1])
	WriteLine(f, "cd " + codeDir)
	WriteLine(f, batchfile)	
	closefile(f)
		
		// Run batch file
		ret = RunProgram(callbatch, )

		if ret <> 0 then do
			ShowMessage("Batch file failed.") 
			retval = 0
			goto quit 
		end	
		
	CopyFile(logint, logfile)	
	
	JLog = OpenFile(logfile, "r")
	LogArray = ReadArray(JLog)
	
	
	if LogArray = null then do
		retval = 0
		ShowMessage("Java model failed to run.")
		goto quit
	end
	
	if LogArray[LogArray.length] contains "completed" then do
		retval = 1 
		goto quit
	end
	else do
		ShowMessage("Java model failed. Check JavaLog.txt")
		retval = 0
		goto quit
	end

	
	quit:
	return(retval)
endMacro // Run Model