# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "AUTO_POL" -parent ${Page_0}
  ipgui::add_param $IPINST -name "BTN_ACTIVE_LOW" -parent ${Page_0}
  ipgui::add_param $IPINST -name "CLK_HZ" -parent ${Page_0}
  ipgui::add_param $IPINST -name "DEBOUNCE_MS" -parent ${Page_0}
  ipgui::add_param $IPINST -name "SETTLE_MS" -parent ${Page_0}


}

proc update_PARAM_VALUE.AUTO_POL { PARAM_VALUE.AUTO_POL } {
	# Procedure called to update AUTO_POL when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.AUTO_POL { PARAM_VALUE.AUTO_POL } {
	# Procedure called to validate AUTO_POL
	return true
}

proc update_PARAM_VALUE.BTN_ACTIVE_LOW { PARAM_VALUE.BTN_ACTIVE_LOW } {
	# Procedure called to update BTN_ACTIVE_LOW when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.BTN_ACTIVE_LOW { PARAM_VALUE.BTN_ACTIVE_LOW } {
	# Procedure called to validate BTN_ACTIVE_LOW
	return true
}

proc update_PARAM_VALUE.CLK_HZ { PARAM_VALUE.CLK_HZ } {
	# Procedure called to update CLK_HZ when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.CLK_HZ { PARAM_VALUE.CLK_HZ } {
	# Procedure called to validate CLK_HZ
	return true
}

proc update_PARAM_VALUE.DEBOUNCE_MS { PARAM_VALUE.DEBOUNCE_MS } {
	# Procedure called to update DEBOUNCE_MS when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.DEBOUNCE_MS { PARAM_VALUE.DEBOUNCE_MS } {
	# Procedure called to validate DEBOUNCE_MS
	return true
}

proc update_PARAM_VALUE.SETTLE_MS { PARAM_VALUE.SETTLE_MS } {
	# Procedure called to update SETTLE_MS when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.SETTLE_MS { PARAM_VALUE.SETTLE_MS } {
	# Procedure called to validate SETTLE_MS
	return true
}


proc update_MODELPARAM_VALUE.CLK_HZ { MODELPARAM_VALUE.CLK_HZ PARAM_VALUE.CLK_HZ } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.CLK_HZ}] ${MODELPARAM_VALUE.CLK_HZ}
}

proc update_MODELPARAM_VALUE.DEBOUNCE_MS { MODELPARAM_VALUE.DEBOUNCE_MS PARAM_VALUE.DEBOUNCE_MS } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.DEBOUNCE_MS}] ${MODELPARAM_VALUE.DEBOUNCE_MS}
}

proc update_MODELPARAM_VALUE.SETTLE_MS { MODELPARAM_VALUE.SETTLE_MS PARAM_VALUE.SETTLE_MS } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.SETTLE_MS}] ${MODELPARAM_VALUE.SETTLE_MS}
}

proc update_MODELPARAM_VALUE.AUTO_POL { MODELPARAM_VALUE.AUTO_POL PARAM_VALUE.AUTO_POL } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.AUTO_POL}] ${MODELPARAM_VALUE.AUTO_POL}
}

proc update_MODELPARAM_VALUE.BTN_ACTIVE_LOW { MODELPARAM_VALUE.BTN_ACTIVE_LOW PARAM_VALUE.BTN_ACTIVE_LOW } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.BTN_ACTIVE_LOW}] ${MODELPARAM_VALUE.BTN_ACTIVE_LOW}
}

