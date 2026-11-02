# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "ENABLE" -parent ${Page_0}
  ipgui::add_param $IPINST -name "GAMMA" -parent ${Page_0}
  ipgui::add_param $IPINST -name "POSTER_LEVELS" -parent ${Page_0}
  ipgui::add_param $IPINST -name "SAT_Q8" -parent ${Page_0}


}

proc update_PARAM_VALUE.ENABLE { PARAM_VALUE.ENABLE } {
	# Procedure called to update ENABLE when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.ENABLE { PARAM_VALUE.ENABLE } {
	# Procedure called to validate ENABLE
	return true
}

proc update_PARAM_VALUE.GAMMA { PARAM_VALUE.GAMMA } {
	# Procedure called to update GAMMA when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.GAMMA { PARAM_VALUE.GAMMA } {
	# Procedure called to validate GAMMA
	return true
}

proc update_PARAM_VALUE.POSTER_LEVELS { PARAM_VALUE.POSTER_LEVELS } {
	# Procedure called to update POSTER_LEVELS when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.POSTER_LEVELS { PARAM_VALUE.POSTER_LEVELS } {
	# Procedure called to validate POSTER_LEVELS
	return true
}

proc update_PARAM_VALUE.SAT_Q8 { PARAM_VALUE.SAT_Q8 } {
	# Procedure called to update SAT_Q8 when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.SAT_Q8 { PARAM_VALUE.SAT_Q8 } {
	# Procedure called to validate SAT_Q8
	return true
}


proc update_MODELPARAM_VALUE.ENABLE { MODELPARAM_VALUE.ENABLE PARAM_VALUE.ENABLE } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.ENABLE}] ${MODELPARAM_VALUE.ENABLE}
}

proc update_MODELPARAM_VALUE.GAMMA { MODELPARAM_VALUE.GAMMA PARAM_VALUE.GAMMA } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.GAMMA}] ${MODELPARAM_VALUE.GAMMA}
}

proc update_MODELPARAM_VALUE.SAT_Q8 { MODELPARAM_VALUE.SAT_Q8 PARAM_VALUE.SAT_Q8 } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.SAT_Q8}] ${MODELPARAM_VALUE.SAT_Q8}
}

proc update_MODELPARAM_VALUE.POSTER_LEVELS { MODELPARAM_VALUE.POSTER_LEVELS PARAM_VALUE.POSTER_LEVELS } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.POSTER_LEVELS}] ${MODELPARAM_VALUE.POSTER_LEVELS}
}

