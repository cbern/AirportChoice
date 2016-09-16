Macro "Start ACM"
Body:

    compiled_ui = GetInterface()
    { drive , path , fname , ext } = SplitPath(compiled_ui)
    actual_ui = drive + path + "airportchoiceUI.model"
	RunMacro("FlowChart.OpenModel",null,actual_ui,False)
return(1)
endmacro

