# Copyright (C) 2001-2003 Tresys Technology, LLC
# see file 'COPYING' for use and warranty information 

# TCL/TK GUI for SE Linux policy analysis
# Requires tcl and tk 8.3+, with BWidgets 

##############################################################
# ::ApolTop
#  
# The top level GUI
##############################################################
namespace eval ApolTop {
	# All capital letters is the convention for variables defined via the Makefile.
	variable bwidget_version	""
	variable status 		""
	variable polversion 		""
	variable policy_type		""
	variable binary_policy_type	"binary"
	variable source_policy_type	"source"
	variable filename 		""
	# The following is used with opening a policy for loading all or pieces of a policy. 
	# The option defaults to 0 (or all portions of the policy).
	variable policy_open_option	0
	variable policyConf_lineno	""
	variable polstats 		""
	# The version number is defined as a magical string here. This is later configured in the make environment.
	variable gui_ver 		APOL_GUI_VERSION 
	variable copyright_date		"2001-2004"
	# install_dir is a magical string to be defined via the makefile!
	variable apol_install_dir	APOL_INSTALL_DIR
	variable recent_files
	variable num_recent_files 	0
	variable most_recent_file 	-1
	# The max # can be changed by the .apol file
	variable max_recent_files 	5
	# env array element HOME is an environment variable
	variable dot_apol_file 		"[file join "$::env(HOME)" ".apol"]"
	variable goto_line_num
	# Default GUI settings
	variable prevCursor		arrow
	variable default_bg_color
	variable text_font		""
	variable title_font		""
	variable dialog_font		""
	variable general_font		""
	variable temp_recent_files	""
	variable query_file_ext 	".qf"
	# Main window dimension defaults
        variable top_width             1000
        variable top_height            700
	
	# Top-level dialog widgets
	variable helpDlg
	set helpDlg .apol_helpDlg
	variable searchDlg
	set searchDlg .searchDlg
	variable goto_Dialog
	set goto_Dialog .goto_Dialog
	variable options_Dialog
	set options_Dialog .options_Dialog
	
	######################
	# Other global widgets
	variable mainframe
	variable textbox_policyConf
	variable searchDlg_entryBox
	variable gotoDlg_entryBox
	# Main top-level notebook widget
	variable notebook
	# Subordinate notebook widgets
	variable components_nb
	variable rules_nb
	
	# Search-related variables
	variable searchString		""
	variable case_Insensitive	0
	variable regExpr 		0
	variable srch_Direction		"down"
	variable policy_is_open		0
	
	# Notebook tab IDENTIFIERS; NOTE: We name all tabs after their related namespace qualified names.
	# We use the prefix 'Apol_' for all notebook tabnames. Note that the prefix must end with an 
	# underscore and that that tabnames may NOT have a colon.
	variable tabName_prefix		"Apol_"
	variable components_tab 	"Apol_Components"
    	variable rules_tab 		"Apol_Rules"
	variable types_tab		"Apol_Types"
	variable terules_tab		"Apol_TE"
	variable roles_tab		"Apol_Roles"
	variable rbac_tab		"Apol_RBAC"
	variable class_perms_tab	"Apol_Class_Perms"
	variable users_tab		"Apol_Users"
	variable initial_sids_tab	"Apol_Initial_SIDS"
	variable cond_bools_tab		"Apol_Cond_Bools"
	variable cond_rules_tab		"Apol_Cond_Rules"
	variable policy_conf_tab	"Apol_PolicyConf"
	variable analysis_tab		"Apol_Analysis"
	 
	variable tk_msgBox_Wait

# "contents" indicates which aspects of the policy are included in the current opened policy file
# indicies into this array are:
# 	classes
#	perms			(inlcudes common perms)
#	types			(include attribs)
#	te_rules		(all type enforcement rules)
#	roles			
#	rbac			(all role rules)
#	users
        variable contents

# initialize the recent files list
	for {set i 0} {$i<$max_recent_files } {incr i} {
		set recent_files($i) ""
	}

# NOTE: We no longer need to include these tab files at run-time; instead
#	we create a single.tcl file at compile time.
# below allows separate files for each "tab" on the app
#    set pwd [pwd]
#    cd [file dirname [info script]]
#    variable MYDIR [pwd]
#    foreach script {
#	types_tab.tcl terules_tab.tcl \
#	roles_tab.tcl rbac_tab.tcl \
#	classes_perms_tab.tcl users_tab.tcl policyconf.tcl
#   } {
#	namespace inscope :: source $script
#    }
#    cd $pwd    

	# store the default background color for use when diabling widgets
	set default_bg_color [. cget -background] 

}

proc ApolTop::is_policy_open {} {
	return $ApolTop::policy_is_open
}

proc ApolTop::get_install_dir {} {
	return $ApolTop::apol_install_dir
}

########################################################################
# ::load_perm_map_fileDlg -- 
#	- Called from Advanced menu
proc ApolTop::load_perm_map_fileDlg {} {
	variable mainframe
	set rt [Apol_Perms_Map::load_perm_map_fileDlg $mainframe]
	if {$rt == 0} {
		ApolTop::configure_edit_pmap_menu_item 1
	}
	return 0
}

########################################################################
# ::load_perm_map_mlsDlg --
#	- Called from Advanced menu
proc ApolTop::load_perm_map_mlsDlg {} {
	variable mainframe
	set rt [Apol_Perms_Map::load_perm_map_mlsDlg $mainframe]
	if {$rt == 0} {
		ApolTop::configure_edit_pmap_menu_item 1
	}
	return 0
}

########################################################################
# ::load_default_perm_map_Dlg --
#	- Called from Advanced menu
proc ApolTop::load_default_perm_map_Dlg {} {
	variable mainframe
	set rt [Apol_Perms_Map::load_default_perm_map_Dlg $mainframe]
	if {$rt == 0} {
		ApolTop::configure_edit_pmap_menu_item 1
	}
	return 0
}

########################################################################
# ::configure_edit_pmap_menu_item --
#	-
proc ApolTop::configure_edit_pmap_menu_item {enable} {
	variable mainframe
	
	if {$enable} {
		[$mainframe getmenu pmap_menu] entryconfigure last -state normal -label "Edit perm map..."
	} else {
		[$mainframe getmenu pmap_menu] entryconfigure last -state disabled -label "Edit perm map... (Not loaded)"	     
	}
	return 0
}

proc ApolTop::disable_tkListbox { my_list_box } {
        global tk_version

        if {$tk_version >= "8.4"} {
	    $my_list_box configure -state disabled
        } else {
	    set class_name [winfo class $my_list_box]
	    # Insert for the class name in bindtags list
	    if {$class_name != ""} {
		set idx [lsearch -exact [bindtags $my_list_box] $class_name]
		if {$idx != -1} {
		    bindtags $my_list_box [lreplace [bindtags $my_list_box] $idx $idx]
		} else {
		    # The default bindtag is already unavailable so just return
		    return
		}
	    } else {
		tk_messageBox -parent $ApolTop::mainframe -icon error -type ok -title "Error" -message \
			"Could not determine the class name of the widget."
		return -1
	    }
	}
	return
}

proc ApolTop::enable_tkListbox { my_list_box } {
        global tk_version

        if { $tk_version >= "8.4"} {
	    $my_list_box configure -state normal
	} else {
	    set class_name [winfo class $my_list_box]
	    # Insert for the class name in the bindtags list
	    if {$class_name != ""} {
		set idx [lsearch -exact [bindtags $my_list_box] $class_name]
		if {$idx != -1} {
		    #default class bindtag already defined, so return
		    return
		}
		bindtags $my_list_box [linsert [bindtags $my_list_box] 1 $class_name]
	    } else {
		tk_messageBox -parent $ApolTop::mainframe -icon error -type ok -titls "Error" -message \
			"Could not determine the class name of the widget."
		return -1
	    }
	}
	return
}

# ------------------------------------------------------------------------------
#  Command ApolTop::change_comboBox_state
# ------------------------------------------------------------------------------
proc ApolTop::change_comboBox_state {cb_value combo_box} {
	selection clear -displayof $combo_box

	if {$cb_value} {
		$combo_box configure -state normal -entrybg white
	} else {
		$combo_box configure -state disabled -entrybg $ApolTop::default_bg_color
	}
	
	return 0
}

# ------------------------------------------------------------------------------
#  Command ApolTop::popup_listbox_Menu
# ------------------------------------------------------------------------------
proc ApolTop::popup_listbox_Menu { global x y popup callbacks list_box} {
	focus -force $list_box
	
	set selected_item [$list_box get active]
	if {$selected_item == ""} {
		return
	}
	# Getting global coordinates of the application window (of position 0, 0)
	set gx [winfo rootx $global]	
	set gy [winfo rooty $global]
	
	# Add the global coordinates for the application window to the current mouse coordinates
	# of %x & %y
	set cmx [expr $gx + $x]
	set cmy [expr $gy + $y]
	
	$popup delete 0 end
	foreach callback $callbacks {
		$popup add command -label "[lindex $callback 0]" -command "[lindex $callback 1] $selected_item"
	}
	
	# Posting the popup menu
	tk_popup $popup $cmx $cmy
	
	return 0
}

# ------------------------------------------------------------------------------
#  Command ApolTop::popup_Tab_Menu
# ------------------------------------------------------------------------------
proc ApolTop::popup_Tab_Menu { window x y popupMenu callbacks page } {
	if {$page == ""} {
		return
	}
	
	# Getting global coordinates of the application window (of position 0, 0)
	set gx [winfo rootx $window]	
	set gy [winfo rooty $window]
	
	# Add the global coordinates for the application window to the current mouse coordinates
	# of %x & %y
	set cmx [expr $gx + $x]
	set cmy [expr $gy + $y]
	
	set page [ApolTop::get_tabname $page]
	$popupMenu delete 0 end
	foreach callback $callbacks {
		$popupMenu add command -label "[lindex $callback 0]" -command "[lindex $callback 1] $page"
	}
		
	# Posting the popup menu
   	tk_popup $popupMenu $cmx $cmy
   	
   	return 0
}

################################################################################
# ::get_tabname -- 
#	args:	
#		- tabID - the tabID provided from the Notebook::bindtabs command
#
# Description: 	There is a bug with the BWidgets 1.7.0 Notebook widget where the 
#	  	tabname is stripped of its' first 2 characters AND an additional 
#		string, consisting of a colon followed by an embedded widget name 
#		from the tab, is appended. For example, the tab name will be 
#		'sults1:text' instead of 'Results1".
#
proc ApolTop::get_tabname {tab} {	
	variable tabName_prefix
	
	set idx [string last ":" $tab]
	if {$idx != -1} {
		# Strip off the last ':' and any following characters from the end of the string
		set tab [string range $tab 0 [expr $idx - 1]]
	}
	set prefix_len [string length $tabName_prefix]
	if {[string range $tab 0 $prefix_len] == $tabName_prefix} {
		return $tab
	}
	
	set tmp $tabName_prefix
	set idx [string first "_" $tab]
	if {$idx == -1} {
		return $tab
	}
	set tab_fixed [append tmp [string range $tab [expr $idx + 1] end]]
	return $tab_fixed
}

proc ApolTop::set_Focus_to_Text { tab } {
	variable components_nb
	variable rules_nb
	
	$ApolTop::mainframe setmenustate Disable_SearchMenu_Tag normal
	# The load query menu option should be enabled across all tabs. 
	# However, we disable the save query menu option if it this is not the Analysis or TE Rules tab.
	# Currently, these are the only tabs providing the ability to save queries. It would be too trivial
	# to allow saving queries for the other tabs.
	$ApolTop::mainframe setmenustate Disable_LoadQuery_Tag normal
	set ApolTop::policyConf_lineno ""
	
	set tab [ApolTop::get_tabname $tab]	
	switch -exact -- $tab \
		$ApolTop::components_tab {
			$ApolTop::mainframe setmenustate Disable_SaveQuery_Tag disabled
			ApolTop::set_Focus_to_Text [$components_nb raise]
		} \
		$ApolTop::rules_tab {
			ApolTop::set_Focus_to_Text [$rules_nb raise]
		} \
		$ApolTop::types_tab {
			Apol_Types::set_Focus_to_Text
		} \
		$ApolTop::terules_tab {
			$ApolTop::mainframe setmenustate Disable_SaveQuery_Tag normal 
			set raisedPage [$Apol_TE::notebook_results raise]
			if {$raisedPage != ""} {
				Apol_TE::set_Focus_to_Text $raisedPage
			} else {
				focus [$ApolTop::rules_nb getframe $ApolTop::terules_tab]
			}
		} \
		$ApolTop::roles_tab {
			$ApolTop::mainframe setmenustate Disable_SaveQuery_Tag disabled
			Apol_Roles::set_Focus_to_Text
		} \
		$ApolTop::rbac_tab {
			$ApolTop::mainframe setmenustate Disable_SaveQuery_Tag disabled
			Apol_RBAC::set_Focus_to_Text
		} \
		$ApolTop::class_perms_tab {
			$ApolTop::mainframe setmenustate Disable_SaveQuery_Tag disabled
			Apol_Class_Perms::set_Focus_to_Text
		} \
		$ApolTop::users_tab {
			$ApolTop::mainframe setmenustate Disable_SaveQuery_Tag disabled
			Apol_Users::set_Focus_to_Text
		} \
		$ApolTop::analysis_tab {
			$ApolTop::mainframe setmenustate Disable_SaveQuery_Tag normal
			$ApolTop::mainframe setmenustate Disable_SearchMenu_Tag disabled
		} \
		$ApolTop::policy_conf_tab {
			$ApolTop::mainframe setmenustate Disable_SaveQuery_Tag disabled
			Apol_PolicyConf::set_Focus_to_Text
		} \
		$ApolTop::initial_sids_tab {
			$ApolTop::mainframe setmenustate Disable_SaveQuery_Tag disabled
			Apol_Initial_SIDS::set_Focus_to_Text
		} \
		$ApolTop::cond_bools_tab {
			$ApolTop::mainframe setmenustate Disable_SaveQuery_Tag disabled
			Apol_Cond_Bools::set_Focus_to_Text
		} \
		$ApolTop::cond_bools_tab {
			$ApolTop::mainframe setmenustate Disable_SaveQuery_Tag disabled
			Apol_Cond_Rules::set_Focus_to_Text
		} \
		default { 
			return 
		}
	
	return 0
}

########################################################################
# ::textSearch --
# 	- Search for an instances of a given string in a text widget and
# 	- selects matching text..
#
# Arguments:
# w -			The window in which to search.  Must be a text widget.
# str -			The string to search for. BUG NOTE: '-' as first character throws an error.
# case_Insensitive	Whether to ignore case differences or not
# regExpr		Whether to treat $str as a regular expression and match it against the text 
# srch_Direction	What direction to search in the text. (-forward or -backward)
#
proc ApolTop::textSearch { w str case_Insensitive regExpr srch_Direction } {
	if {$str == ""} {
		return 0
	}
			
	# Local variables to hold search options. Initialized to space characters. 
	set case_opt " "
	set regExpr_opt " "
	set direction_opt " "
	
	# Setting search options.
	if { $case_Insensitive } {
		set case_opt "-nocase"
	}
	if { $regExpr } {
		set regExpr_opt "-regexp"
	}
	if { $srch_Direction == "down" } {
		set direction_opt "-forward"
		# Get the current insert position. 
		set cur_srch_pos [$w index insert]
	} else {
		set direction_opt "-backward"
		# Get the first character index of the current selection.
		set cur_srch_pos [lindex [$w tag ranges sel] 0]
	}
	
	if { $cur_srch_pos == "" } {
		set cur_srch_pos "1.0"
	}
	
	# Remove any selection tags.
	$w tag remove sel 0.0 end
		
	# Set the command string and strip out any space characters (meaning that an option was not selected).
	# BUG NOTE: Currently, there is a bug with text widgets' search command. It does not
	# handle a '-' as the first character in the string. 
	set cmd "$w search -count cur_srch_pos_length $case_opt $regExpr_opt $direction_opt"
	set rt [catch {set cur_srch_pos [eval $cmd {"$str"} $cur_srch_pos] } err]
	
	# Catch any error performing the search command and display error message to user.
	if { $rt != 0 } {
		tk_messageBox -parent $ApolTop::searchDlg -icon error -type ok -title "Search Error" -message \
				"$err"
		return -1
	}
	
	# Prompt the user if a match was not found.	
	if { $cur_srch_pos == "" } {
		# NOTE: Use vwait command.to block the application if the event hasn't completed.
		# This is because when Return button is hit multiple times a TCL/TK bug is being
		# thrown:can't read "::tk::FocusGrab(...)
		# The problem is that tkMessageBox summarily destroys the old window -
		# which screws up SetFocusGrab's private variables because SetFocusGrab isn't reentrant.
		set ApolTop::tk_msgBox_Wait  \
			[tk_messageBox -parent $ApolTop::searchDlg -icon warning -type ok -title "Search Failed" -message \
					"Search string not found!"]
		vwait ApolTop::tk_msgBox_Wait
	} else {	
		# Set the insert position in the text widget. 
		# If the direction is down, set the mark to index of the END character in the match.
		# If the direction is up, set the mark to the index of the FIRST character in the match.
		$w mark set insert "$cur_srch_pos + $cur_srch_pos_length char"
		$w tag add sel $cur_srch_pos "$cur_srch_pos + $cur_srch_pos_length char"
		
		# Adjust the view in the window.
		$w see $cur_srch_pos
	}
	
	return 0
}

##############################################################
# ::search
#  	- Search raised text widget for a string
# 
proc ApolTop::search {} {
	variable searchString
	variable case_Insensitive	
	variable regExpr 		
	variable srch_Direction
	variable notebook
	variable components_nb
	variable rules_nb
	variable components_tab 	
    	variable rules_tab 		
	variable policy_conf_tab	
	variable analysis_tab	
	
	set raised_tab [$notebook raise]	
	switch -- $raised_tab \
    		$policy_conf_tab {
    			${policy_conf_tab}::search $searchString $case_Insensitive $regExpr $srch_Direction
    		} \
    		$analysis_tab {
    			${analysis_tab}::search $searchString $case_Insensitive $regExpr $srch_Direction
    		} \
    		$rules_tab {
    			[$rules_nb raise]::search $searchString $case_Insensitive $regExpr $srch_Direction
    		} \
    		$components_tab {
    			[$components_nb raise]::search $searchString $case_Insensitive $regExpr $srch_Direction
    		} \
    		default {
    			puts "Invalid raised tab!"
    		}  
	
	return 0
}

# ------------------------------------------------------------------------------
#  Command ApolTop::_getIndexValue
# ------------------------------------------------------------------------------
proc ApolTop::getIndexValue { path value } { 
    set listValues [Widget::getMegawidgetOption $path -values]

    return [lsearch -glob $listValues "$value*"]
}

# ------------------------------------------------------------------------------
#  Command ApolTop::_mapliste
# ------------------------------------------------------------------------------
proc ApolTop::_mapliste { path } {
    set listb $path.shell.listb
    if { [Widget::cget $path -state] == "disabled" } {
        return
    }
    if { [set cmd [Widget::getMegawidgetOption $path -postcommand]] != "" } {
        uplevel \#0 $cmd
    }
    if { ![llength [Widget::getMegawidgetOption $path -values]] } {
        return
    }

    ComboBox::_create_popup $path
    ArrowButton::configure $path.a -relief sunken
    update

    $listb selection clear 0 end
    BWidget::place $path.shell [winfo width $path] 0 below $path
    wm deiconify $path.shell
    raise $path.shell
    BWidget::grab local $path

    return $listb
}

# ------------------------------------------------------------------------------
#  Command ApolTop::_create_popup
# ------------------------------------------------------------------------------
proc ApolTop::_create_popup { path entryBox key } { 
    # Getting value from the entry subwidget of the combobox 
    # and then checking its' length
    set value  [Entry::cget $path.e -text]
    set len [string length $value]
    
    # Key must be an alphanumeric ASCII character.  
    if { [string is alpha $key] } {
	    #ComboBox::_unmapliste $path
	    set idx [ ApolTop::getIndexValue $path $value ]  
	    
	    if { $idx != -1 } {
	    # Calling setSelection function to set the selection to the index value
	    	ApolTop::setSelection $idx $path $entryBox $key
	    }
    } 
    
    if { $key == "Return" } {
    	    # If the dropdown box visible, then we just select the value and unmap the list.
    	    if {[winfo exists $path.shell.listb] && [winfo viewable $path.shell.listb]} {
    	    	    set index [$path.shell.listb curselection]
	    	    if { $index != -1 } {
		        if { [ComboBox::setvalue $path @$index] } {
			    set cmd [Widget::getMegawidgetOption $path -modifycmd]
		            if { $cmd != "" } {
		                uplevel \#0 $cmd
		            }
		        }
		    }
	    	ComboBox::_unmapliste $path
	    	focus -force .
	    }
    }
    
    return 0
}

######################################################################
#  Command: ApolTop::tklistbox_select_on_key_callback
#  Arguments: Takes a tk listbox widget, its' associated list, and 
#	      the key pressed. Handles lowercase and uppercase key
#	      values.
#
proc ApolTop::tklistbox_select_on_key_callback { path list_items key } {     
	if {$path == ""} {
		tk_messageBox \
			-icon error \
			-type ok \
			-title "Error" \
			-message "No listbox pathname provided." \
			-parent $mainframe
	}
	if {[string is alpha $key]} {
		set low_key_str [string tolower $key]
		set matches [lsearch -regexp $list_items "^\[$key$low_key_str\]"]
		if {$matches != -1} {
			$path selection clear 0 end
			$path selection set [lindex $matches 0]
			$path see [lindex $matches 0]
		}
	}
	
	return 0
}

# ------------------------------------------------------------------------------
#  Command ApolTop::setSelection
# ------------------------------------------------------------------------------
proc ApolTop::setSelection { idx path entryBox key } {
    if {$idx != -1} {
	set listb [ApolTop::_mapliste $path]
	$listb selection set $idx
	$listb activate $idx
	$listb see $idx
    } 
    
    return 0
}

##############################################################
# ::load_query_info
#  	- Call load_query proc for valid tab
# 
proc ApolTop::load_query_info {} {
	variable notebook 
	variable rules_tab
	variable terules_tab
	variable analysis_tab
	variable rules_nb
	variable mainframe
	
	set query_file ""
        set types {
		{"Query files"		{$ApolTop::query_file_ext}}
    	}
	set query_file [tk_getOpenFile -filetypes $types -title "Select Query to Load..." \
		-defaultextension $ApolTop::query_file_ext -parent $mainframe]
	if {$query_file != ""} {
		if {[file exists $query_file] == 0 } {
			tk_messageBox -icon error -type ok -title "Error" \
				-message "File $query_file does not exist." -parent $mainframe
			return -1
		}
		set rt [catch {set f [::open $query_file]} err]
		if {$rt != 0} {
			tk_messageBox -icon error -type ok -title "Error" \
				-message "Cannot open $query_file: $err"
			return -1
		}
		# Search for the analysis type line
		gets $f line
		set query_id [string trim $line]
		while {[eof $f] != 1} {
			# Skip empty lines and comments
			if {$query_id == "" || [string compare -length 1 $query_id "#"] == 0} {
				gets $f line
				set query_id [string trim $line]
				continue
			}
			break
		}

		switch -- $query_id \
	    		$analysis_tab {
	    			set rt [catch {${analysis_tab}::load_query_options $f $mainframe} err]
	    			if {$rt != 0} {
	    				tk_messageBox -icon error -type ok -title "Error" \
						-message "$err"
					return -1
				}
	    			$notebook raise $analysis_tab
	    		} \
	    		$terules_tab {
	    			if {[string equal [$rules_nb raise] $ApolTop::terules_tab]} {
	    				set rt [catch {${ApolTop::terules_tab}::load_query_options $f $mainframe} err]
	    				if {$rt != 0} {
		    				tk_messageBox -icon error -type ok -title "Error" \
							-message "$err"
						return -1
					}
	    				$notebook raise $rules_tab
	    				$rules_nb raise $ApolTop::terules_tab
	    			}
	    		} \
	    		default {
	    			tk_messageBox -icon error -type ok -title "Error" \
					-message "Invalid query ID."
	    		}
	    	ApolTop::set_Focus_to_Text [$notebook raise]
	    	::close $f
	}
    	return 0  
}

##############################################################
# ::save_query_info
#  	- Call save_query proc for valid tab
# 
proc ApolTop::save_query_info {} {
	variable notebook 
	variable rules_tab
	variable terules_tab
	variable analysis_tab
	variable rules_nb
	variable mainframe
	
	# Make sure we only allow saving from the Analysis and TERules tabs
	set raised_tab [$notebook raise]

	if {![string equal $raised_tab $analysis_tab] && ![string equal $raised_tab $rules_tab]} {
		tk_messageBox -icon error -type ok -title "Save Query Error" \
			-message "You cannot save a query from this tab! \
			You can only save from the Policy Rules->TE Rules tab and the Analysis tab."
		return -1
    	} 
    	if {[string equal $raised_tab $rules_tab] && ![string equal [$rules_nb raise] $terules_tab]} {
		tk_messageBox -icon error -type ok -title "Save Query Error" \
			-message "You cannot save a query from this tab! \
			You can only save from the Policy Rules->TE Rules tab and the Analysis tab."
		return -1
	}
			    		
	set query_file ""
        set types {
		{"Query files"		{$ApolTop::query_file_ext}}
    	}
    	set query_file [tk_getSaveFile -title "Save Query As?" \
    		-defaultextension $ApolTop::query_file_ext \
    		-filetypes $types -parent $mainframe]
	if {$query_file != ""} {
		set rt [catch {set f [::open $query_file w+]} err]
		if {$rt != 0} {
			return -code error $err
		}	
		switch -- $raised_tab \
	    		$analysis_tab {
	    			puts $f "$analysis_tab"
	    			set rt [catch {${analysis_tab}::save_query_options $f $query_file} err]
	    			if {$rt != 0} {
	    				::close $f
	    				tk_messageBox -icon error -type ok -title "Save Query Error" \
						-message "$err"
					return -1
				}
	    		} \
	    		$rules_tab {
	    			if {[string equal [$rules_nb raise] $terules_tab]} {
	    				puts $f "$terules_tab"	
	    				set rt [catch {${terules_tab}::save_query_options $f $query_file} err]
	    				if {$rt != 0} {
	    					::close $f
		    				tk_messageBox -icon error -type ok -title "Save Query Error" \
							-message "$err"
						return -1
					}
	    			}
	    		} \
	    		default {
	    			::close $f
	    			tk_messageBox -icon error -type ok -title "Save Query Error" \
					-message "You cannot save a query from this tab!"
				return -1
	    		}  
	    	::close $f
	}	  
	
	
    		
    	return 0
}

##############################################################
# ::display_searchDlg
#  	- Display the search dialog
# 
proc ApolTop::display_searchDlg {} {
	variable searchDlg
	variable searchDlg_entryBox
	global tcl_platform
	
	if { [$ApolTop::notebook raise] == $ApolTop::analysis_tab } {
		return
	}
	# Checking to see if window already exists. If so, it is destroyed.
	if { [winfo exists $searchDlg] } {
		raise $searchDlg
		focus $searchDlg_entryBox
		$searchDlg_entryBox selection range 0 end
		return
	}
	
	# Create the toplevel dialog window and set its' properties.
	toplevel $searchDlg
	wm protocol $searchDlg WM_DELETE_WINDOW "destroy $searchDlg"
	wm withdraw $searchDlg
	wm title $searchDlg "Find"
	
	if {$tcl_platform(platform) == "windows"} {
		wm resizable $ApolTop::searchDlg 0 0
	} else {
		bind $ApolTop::searchDlg <Configure> { wm geometry $ApolTop::searchDlg {} }
	}
    
	# Display results window
	set sbox [frame $searchDlg.sbox]
	set lframe [frame $searchDlg.lframe]
	set rframe [frame $searchDlg.rframe]
	set lframe_top [frame $lframe.lframe_top]
	set lframe_bot [frame $lframe.lframe_bot]
	set lframe_bot_left [frame $lframe_bot.lframe_bot_left]
	set lframe_bot_right [frame $lframe_bot.lframe_bot_right]
	
	set lbl_entry [label $lframe_top.lbl_entry -text "Find What:"]
	set searchDlg_entryBox [entry $lframe_top.searchDlg_entryBox -bg white -textvariable ApolTop::searchString ]
	set b_findNext [button $rframe.b_findNext -text "Find Next" \
		      -command { ApolTop::search }]
	set b_cancel [button $rframe.b_cancel -text "Cancel" \
		      -command "destroy $searchDlg"]
	set cb_case [checkbutton $lframe_bot_left.cb_case -text "Case Insensitive" -variable ApolTop::case_Insensitive]
	set cb_regExpr [checkbutton $lframe_bot_left.cb_regExpr -text "Regular Expressions" -variable ApolTop::regExpr]
	set directionBox [TitleFrame $lframe_bot_right.directionBox -text "Direction" ]
	set dir_up [radiobutton [$directionBox getframe].dir_up -text "Up" -variable ApolTop::srch_Direction \
			 -value up ]
    	set dir_down [radiobutton [$directionBox getframe].dir_down -text "Down" -variable ApolTop::srch_Direction \
			 -value down ]
	
	# Placing display widgets
	pack $sbox -expand yes -fill both -padx 5 -pady 5
	pack $lframe -expand yes -fill both -padx 5 -pady 5 -side left
	pack $rframe -expand yes -fill both -padx 5 -pady 5 -side right
	pack $lframe_top -expand yes -fill both -padx 5 -pady 5 -side top
	pack $lframe_bot -expand yes -fill both -padx 5 -pady 5 -side bottom
	pack $lframe_bot_left -expand yes -fill both -padx 5 -pady 5 -side left 
	pack $lframe_bot_right -expand yes -fill both -padx 5 -pady 5 -side right
	pack $lbl_entry -expand yes -fill both -side left 
	pack $searchDlg_entryBox -expand yes -fill both -side right
	pack $b_findNext $b_cancel -side top -expand yes -fill x
	pack $cb_case $cb_regExpr -expand yes -side top -anchor nw
	pack $directionBox -side left -expand yes -fill both
	pack $dir_up $dir_down -side left -anchor center 
	
	# Place a toplevel at a particular position
	#::tk::PlaceWindow $searchDlg widget center
	wm deiconify $searchDlg
	focus $searchDlg_entryBox 
	$searchDlg_entryBox selection range 0 end
	bind $ApolTop::searchDlg <Return> { ApolTop::search }
	
	return 0
}	

########################################################################
# ::goto_line
#  	- goes to indicated line in text box
# 
proc ApolTop::goto_line { line_num textBox } {
	variable notebook
	
	if {[string is integer -strict $line_num] != 1} {
		tk_messageBox -icon error \
			-type ok  \
			-title "Invalid line number" \
			-message "$line_num is not a valid line number"
		return 0
	}
	# Remove any selection tags.
	$textBox tag remove sel 0.0 end
	$textBox mark set insert ${line_num}.0 
	$textBox see ${line_num}.0 
	$textBox tag add sel $line_num.0 $line_num.end
	focus -force $textBox
	
	return 0
}

##############################################################
# ::call_tabs_goto_line_cmd
#  	-  
proc ApolTop::call_tabs_goto_line_cmd { } {
	variable goto_line_num
	variable notebook
	variable components_nb
	variable rules_nb
	variable components_tab 	
    	variable rules_tab 		
	variable policy_conf_tab	
	variable analysis_tab		
	
	set raised_tab [$notebook raise]	
	switch -- $raised_tab \
    		$policy_conf_tab {
    			${policy_conf_tab}::goto_line $goto_line_num
    		} \
    		$analysis_tab {
    			${analysis_tab}::goto_line $goto_line_num
    		} \
    		$rules_tab {
    			[$rules_nb raise]::goto_line $goto_line_num
    		} \
    		$components_tab {
    			[$components_nb raise]::goto_line $goto_line_num
    		} \
    		default {
    			return -code error
    		}  
    	
	return 0
}

 ##############################################################
# ::display_options_Dlg
#  	-  
proc ApolTop::display_options_Dlg { } {
	variable options_Dialog
	global tcl_platform
	
	# create dialog
    	if { [winfo exists $options_Dialog] } {
    		raise $options_Dialog
    		return 0
    	}
    	toplevel $options_Dialog
   	wm protocol $options_Dialog WM_DELETE_WINDOW "destroy $options_Dialog"
    	wm withdraw $options_Dialog
    	wm title $options_Dialog "Tool Options"
    	
	set open_opts_f [TitleFrame $options_Dialog.open_opts_f -text "Open policy options"]
	set lframe [frame [$open_opts_f getframe].lframe]
	set rframe [frame [$open_opts_f getframe].rframe]

	set cb_all [radiobutton $lframe.cb_all -text "All" -variable ApolTop::policy_open_option -value 0]
	set cb_pass1 [radiobutton $lframe.cb_pass1 -text "Pass 1 policy only" -variable ApolTop::policy_open_option -value 1]
	set cb_te_only [radiobutton $lframe.cb_te_only -text "TE policy only" -variable ApolTop::policy_open_option -value 2]
	set cb_types_roles [radiobutton $rframe.cb_types_roles -text "Types and roles only" -variable ApolTop::policy_open_option -value 3]
	set cb_classes_perms [radiobutton $rframe.cb_classes_perms -text "Classes and permissions only" -variable ApolTop::policy_open_option -value 4]
	set cb_rbac [radiobutton $rframe.cb_rbac -text "RBAC policy only" -variable ApolTop::policy_open_option -value 5]
	
	set b_ok  [button $options_Dialog.b_ok -text "OK" -width 6 -command { destroy $ApolTop::options_Dialog }]
	
	pack $b_ok -side bottom -padx 5 -pady 5 -anchor center
	pack $open_opts_f -side left -anchor nw -fill both -expand yes -padx 5 -pady 5
	pack $lframe $rframe -side left -anchor nw -fill both -expand yes
	pack $cb_all $cb_pass1 $cb_te_only $cb_types_roles $cb_classes_perms $cb_rbac -side top -anchor nw
	
	# Place a toplevel at a particular position
    	#::tk::PlaceWindow $options_Dialog widget center
	wm deiconify $options_Dialog
	
	return 0
}

##############################################################
# ::display_goto_line_Dlg
#  	-  
proc ApolTop::display_goto_line_Dlg { } {
	variable notebook
	variable goto_Dialog
	variable gotoDlg_entryBox
	global tcl_platform
	
	if { [$ApolTop::notebook raise] == $ApolTop::analysis_tab } {
		return
	}
	# create dialog
    	if { [winfo exists $goto_Dialog] } {
    		raise $goto_Dialog
    		focus $gotoDlg_entryBox
    		return 0
    	}
    	toplevel $goto_Dialog
   	wm protocol $goto_Dialog WM_DELETE_WINDOW "destroy $goto_Dialog"
    	wm withdraw $goto_Dialog
    	wm title $goto_Dialog "Goto"
    	
    	if {$tcl_platform(platform) == "windows"} {
		wm resizable $ApolTop::goto_Dialog 0 0
	} else {
		bind $ApolTop::goto_Dialog <Configure> { wm geometry $ApolTop::goto_Dialog {} }
	}
	# Clear the previous line number
	set ApolTop::goto_line_num ""
	set gotoDlg_entryBox [entry $goto_Dialog.gotoDlg_entryBox -textvariable ApolTop::goto_line_num -width 10 ]
	set lbl_goto  [label $goto_Dialog.lbl_goto -text "Goto:"]
	set b_ok      [button $goto_Dialog.ok -text "OK" -width 6 -command { ApolTop::call_tabs_goto_line_cmd; destroy $ApolTop::goto_Dialog}]
	set b_cancel  [button $goto_Dialog.cancel -text "Cancel" -width 6 -command { destroy $ApolTop::goto_Dialog }]
	
	pack $lbl_goto $gotoDlg_entryBox -side left -padx 5 -pady 5 -anchor nw
	pack $b_ok $b_cancel -side left -padx 5 -pady 5 -anchor ne
	
	# Place a toplevel at a particular position
    	#::tk::PlaceWindow $goto_Dialog widget center
	wm deiconify $goto_Dialog
	focus $gotoDlg_entryBox
	bind $ApolTop::goto_Dialog <Return> { ApolTop::call_tabs_goto_line_cmd; destroy $ApolTop::goto_Dialog }
	
	return 0
}

proc ApolTop::create { } {
	variable notebook 
	variable mainframe  
	variable components_nb
	variable rules_nb
        variable bwidget_version
       
	# Menu description
	set descmenu {
	"&File" {} file 0 {
	    {command "&Open..." {} "Open a new policy"  {}  -command ApolTop::openPolicy}
	    {command "&Close" {} "Close an opened polocy"  {} -command ApolTop::closePolicy}
	    {separator}
	    {command "E&xit" {} "Exit policy analysis tool" {} -command ApolTop::apolExit}
	    {separator}
	    {cascad "&Recent files" {} recent 0 {}}
	
	}
	"&Search" {} search 0 {      
	    {command "&Find...                    (C-s)" {Disable_SearchMenu_Tag} "Find"  \
	    	{} -command ApolTop::display_searchDlg }
	    {command "&Goto Line...           (C-g)" {Disable_SearchMenu_Tag} "Goto Line"  \
	    	{} -command ApolTop::display_goto_line_Dlg }
	}
	"&Query" {} query 0 {
	    {command "&Load query..." {Disable_LoadQuery_Tag} "Load query"  \
	    	{} -command "ApolTop::load_query_info" }
	    {command "&Save query..." {Disable_SaveQuery_Tag} "Save query"  \
	    	{} -command "ApolTop::save_query_info" }
	    {command "&Policy Summary" {Disable_Summary} "Display summary statics" {} -command ApolTop::popupPolicyStats }
	}
	"&Advanced" all options 0 {
	    {cascad "&Permission Mappings" {Perm_Map_Tag} pmap_menu 0 {}}
	    {command "&Tool Options..." {} "Tool options"  \
	    	{} -command "ApolTop::display_options_Dlg" }
        }
	"&Help" {} helpmenu 0 {
	    {command "&General Help" {all option} "Show help" {} -command {ApolTop::helpDlg "Help" "apol_help.txt"}}
	    {command "&Domain Transition Analysis" {all option} "Show help" {} -command {ApolTop::helpDlg "Domain Transition Analysis Help" "dta_help.txt"}}
	    {command "&Information Flow Analysis" {all option} "Show help" {} -command {ApolTop::helpDlg "Information Flow Analysis Help" "iflow_help.txt"}}
	    {command "&Object Classes and Permissions" {all option} "Show help" {} -command {ApolTop::helpDlg "Object Classes/Permissions Help" "obj_perms_help.txt"}}
	    {command "&About" {all option} "Show about box" {} -command ApolTop::aboutBox}
	}
	}
	
	set mainframe [MainFrame .mainframe -menu $descmenu -textvariable ApolTop::status]
	[$mainframe getmenu pmap_menu] insert 0 command -label "Edit perm map... (Not loaded)" -command "Apol_Perms_Map::display_perm_mappings_Dlg"
	[$mainframe getmenu pmap_menu] insert 0 separator
	[$mainframe getmenu pmap_menu] insert 0 command -label "Load Perm Map from MLS file..." -command "ApolTop::load_perm_map_mlsDlg"
	[$mainframe getmenu pmap_menu] insert 0 command -label "Load Perm Map from file..." -command "ApolTop::load_perm_map_fileDlg"
	[$mainframe getmenu pmap_menu] insert 0 separator
	[$mainframe getmenu pmap_menu] insert 0 command -label "Load Default Perm Map" -command "ApolTop::load_default_perm_map_Dlg"
	$mainframe addindicator -textvariable ApolTop::policyConf_lineno -width 14
	$mainframe addindicator -textvariable ApolTop::polstats -width 88
	$mainframe addindicator -textvariable ApolTop::polversion -width 19 
	
	# Disable menu items since a policy is not yet loaded.
	$ApolTop::mainframe setmenustate Disable_SearchMenu_Tag disabled
	$ApolTop::mainframe setmenustate Perm_Map_Tag disabled
	$ApolTop::mainframe setmenustate Disable_SaveQuery_Tag disabled
	$ApolTop::mainframe setmenustate Disable_LoadQuery_Tag disabled
	$ApolTop::mainframe setmenustate Disable_Summary disabled
		
	# NoteBook creation
	set frame    [$mainframe getframe]
	set notebook [NoteBook $frame.nb]
	
	# Create Top-level tab frames	
	set components_frame [$notebook insert end $ApolTop::components_tab -text "Policy Components"]
	set rules_frame [$notebook insert end $ApolTop::rules_tab -text "Policy Rules"]
	Apol_Analysis::create $notebook
	Apol_PolicyConf::create $notebook
	
	# Create subordinate tab frames
	set components_nb [NoteBook $components_frame.components_nb]
	set rules_nb [NoteBook $rules_frame.rules_nb]
	
	# Subtabs for the main policy components tab.
	Apol_Types::create $components_nb
	Apol_Class_Perms::create $components_nb
	Apol_Roles::create $components_nb
	Apol_Users::create $components_nb
	Apol_Cond_Bools::create $components_nb
	Apol_Initial_SIDS::create $components_nb
	
	# Subtabs for the main policy rules tab
	Apol_TE::create $rules_nb
	Apol_RBAC::create $rules_nb
	Apol_Cond_Rules::create $rules_nb
	
	$components_nb compute_size
	pack $components_nb -fill both -expand yes -padx 4 -pady 4
	$components_nb raise [$components_nb page 0]
	$components_nb bindtabs <Button-1> { ApolTop::set_Focus_to_Text }
	
	$rules_nb compute_size
	pack $rules_nb -fill both -expand yes -padx 4 -pady 4
	$rules_nb raise [$rules_nb page 0]
	$rules_nb bindtabs <Button-1> { ApolTop::set_Focus_to_Text }
	
	bind . <Control-s> {ApolTop::display_searchDlg}
	bind . <Control-g> {ApolTop::display_goto_line_Dlg}
	
	$notebook compute_size
	pack $notebook -fill both -expand yes -padx 4 -pady 4
	$notebook raise [$notebook page 0]
	$notebook bindtabs <Button-1> { ApolTop::set_Focus_to_Text }	
	pack $mainframe -fill both -expand yes
	
	return 0
}

# Saves user data in their $HOME/.apol file
proc ApolTop::writeInitFile { } {
	variable dot_apol_file 
	variable num_recent_files
	variable recent_files
	variable text_font		
	variable title_font
	variable dialog_font
	variable general_font
	variable policy_open_option
	
	set rt [catch {set f [open $dot_apol_file w+]} err]
	if {$rt != 0} {
		tk_messageBox -icon error -type ok -title "Error" \
			-message "$err"
		return
	}
	puts $f "recent_files"
	puts $f $num_recent_files
	for {set i 0} {$i < $num_recent_files} {incr i} {
 		puts $f $recent_files($i)
 	}
	# free the recent files array
	array unset recent_files

	puts $f "\n"
	puts $f "# Font format: family ?size? ?style? ?style ...?"
	puts $f "# Possible values for the style arguments are as follows:"
	puts $f "# normal bold roman italic underline overstrike\n#\n#"
	puts $f "# NOTE: When configuring fonts, remember to remove the following "
	puts $f "# \[window height\] and \[window width\] entries before starting apol. "
	puts $f "# Not doing this may cause widgets to be obscured when running apol."
	puts $f "\[general_font\]"
	if {$general_font == ""} {
		puts $f "Helvetica 10"
	} else {
		puts $f "$general_font" 
	}
	puts $f "\[title_font\]"
	if {$title_font == ""} {
		puts $f "Helvetica 10 bold italic"
	} else {
		puts $f "$title_font"  
	}
	puts $f "\[dialog_font\]"
	if {$dialog_font == ""} {
		puts $f "Helvetica 10"
	} else {
		puts $f "$dialog_font"
	}
	puts $f "\[text_font\]"
	if {$text_font == ""} {
		puts $f "fixed"
	} else {
		puts $f "$text_font"
	}
        puts $f "\[window_height\]"
        puts $f [winfo height .]
        puts $f "\[window_width\]"
        puts $f [winfo width .]
        puts $f "\[policy_open_option\]"
        puts $f $policy_open_option
	close $f
	return 0
}


# Reads in user data from their $HOME/.apol file 
proc ApolTop::readInitFile { } {
	variable dot_apol_file
	variable max_recent_files 
	variable recent_files
	variable text_font		
	variable title_font
	variable dialog_font
	variable general_font
	variable temp_recent_files
	variable top_height
        variable top_width
	variable policy_open_option
	
	# if it doesn't exist, we'll create later
	if {[file exists $dot_apol_file] == 0 } {
		return
	}
	set rt [catch {set f [open $dot_apol_file]} err]
	if {$rt != 0} {
		tk_messageBox -icon error -type ok -title "Error" \
			-message "Cannot open .apol file ($rt: $err)"
		return
	}
	
	# Flags for key words
	set max_recent_flag 0
	set recent_files_flag 0
	
	gets $f line
	set tline [string trim $line]
	while {1} {
		if {[eof $f] && $tline == ""} {
			break
		}
		if {[string compare -length 1 $tline "#"] == 0 || [string is space $tline]} {
			gets $f line
			set tline [string trim $line]
			continue
		}
		switch $tline {
		        "\[window_height\]" {
			        gets $f line
			        set tline [string trim $line]
			        if {[eof $f] == 1 && $tline == ""} {
				    puts "EOF reached trying to read window_height."
			   	    continue
			        }
			        if {[string is integer $tline] != 1} {
				    puts "window_height was not given as an integer ($line) and is ignored"
				    break
			        }
			        set top_height $tline
			}
		        "\[window_width\]" {
			        gets $f line
			        set tline [string trim $line]
			        if {[eof $f] == 1 && $tline == ""} {
				    puts "EOF reached trying to read window_width."
				    continue
			        }
			        if {[string is integer $tline] != 1} {
				    puts "window_width was not given as an integer ($line) and is ignored"
				    break
			        }
			        set top_width $tline
			}
		        "\[title_font\]" {
				gets $f line
				set tline [string trim $line]
				if {[eof $f] == 1 && $tline == ""} {
					puts "EOF reached trying to read title font."
					continue
				}
				set title_font $tline
			}
			"\[dialog_font\]" {
				gets $f line
				set tline [string trim $line]
				if {[eof $f] == 1 && $tline == ""} {
					puts "EOF reached trying to read dialog font."
					continue
				}
				set dialog_font $tline
			}
			"\[text_font\]" {
				gets $f line
				set tline [string trim $line]
				if {[eof $f] == 1 && $tline == ""} {
					puts "EOF reached trying to read text font."
					continue
				}
				set text_font $tline
			}
			"\[general_font\]" {
				gets $f line
				set tline [string trim $line]
				if {[eof $f] == 1 && $tline == ""} {
					puts "EOF reached trying to read general font."
					continue
				}
				set general_font $tline
			}
			"\[policy_open_option\]" {
				gets $f line
				set tline [string trim $line]
				if {[eof $f] == 1 && $tline == ""} {
					puts "EOF reached trying to read open policy option."
					continue
				}
				set policy_open_option $tline
			}
		
			# The form of [max_recent_file] is a single line that follows
			# containing an integer with the max number of recent files to 
			# keep.  The default is 5 if this is not specified.  A number larger
			# than 10 will be set to 10.  A number of less than 2 is set to 2.
			"max_recent_files" {
				# we shouldn't be getting the max number after reading in the file names
				if {$recent_files_flag == 1} {
					puts "Key word max_recent_files found after recent file names read; ignored"
					# read next line which should be max num
					gets $ line
					continue
				}
				if {$max_recent_flag == 1} {
					puts "Key word max_recent_flag found twice in file!"
					continue
				}
				set max_recent_flag 1
				gets $f line
				set tline [string trim $line]
				if {[eof $f] == 1 && $tline == ""} {
					puts "EOF reached trying to read max_recent_file."
					continue
				}
				if {[string is integer $tline] != 1} {
					puts "max_recent_files was not given as an integer ($line) and is ignored"
				} else {
					if {$tline>10} {
						set max_recent_files 10
					} elseif {$tline < 2} {
						set max_recent_files 2
					}
					else {
						set max_recent_files $tline
					}
				}
			}
			# The form of this key in the .apol file is as such
			# 
			# [recent_files]
			# 5			(# indicating how many file names follows)
			# filename1
			# filename2
			# ...			
			"recent_files" {
				if {$recent_files_flag == 1} {
					puts "Key word recent_files found twice in file!"
					continue
				}
				set recent_files_flag 1
				gets $f line
				set tline [string trim $line]
				if {[eof $f] == 1 && $tline == ""} {
					puts "EOF reached trying to read num of recent files."
					continue
				}
				if {[string is integer $tline] != 1} {
					puts "number of recent files was not given as an integer ($line) and is ignored"
					# at this point we don't support anything else so just break from loop
					break
				} elseif {$tline < 0} {
					puts "number of recent was less than 0 and is ignored"
					# at this point we don't support anything else so just break from loop
					break
				}
				set num $tline
				# read in the lines with the files
				for {set i 0} {$i<$num} {incr i} {
					gets $f line
					set tline [string trim $line]
					if {[eof $f] == 1 && $tline == ""} {
						puts "EOF reached trying to read recent file name $num."
						break
					}
					# check if stored num is greater than max; if so just ignore the rest
					if {$i >= $max_recent_files} {
						continue
					}
					
					# Add to recent files list.
					set temp_recent_files [lappend temp_recent_files $tline]
				}
			}
			default {
				puts "Unrecognized line in .apol: $line"
			}
		}
		
		gets $f line
		set tline [string trim $line]
	}
	close $f	
	return 0
}


# Add a policy file to the recently opened
proc ApolTop::addRecent {file} {
	variable mainframe
	variable recent_files
	variable num_recent_files
    	variable max_recent_files
    	variable most_recent_file
    	
    	if {$num_recent_files < $max_recent_files} {
    		set x $num_recent_files
    		set less_than_max 1
    	} else {
    		set x $max_recent_files 
    		set less_than_max 0
    	}
	
	# First check if already in recent file list
	for {set i 0} {$i < $x } {incr i} {
		if {[string equal $file $recent_files($i)]} {
 			return
 		}
	}
	if {$num_recent_files < $max_recent_files} {
		#list not full, just add to list and insert into menu
		set recent_files($num_recent_files) $file
		[$mainframe getmenu recent] insert 0 command -label "$recent_files($num_recent_files)" -command "ApolTop::openPolicyFile $recent_files($num_recent_files) 0"
		set most_recent_file $num_recent_files
		incr num_recent_files
	} else {
		#list is full, need to replace one
		#find oldest entry
		if {$most_recent_file != 0} {
			set oldest [expr $most_recent_file - 1]
		} else {
			set oldest [expr $max_recent_files - 1]
		}
		[$mainframe getmenu recent] delete $recent_files($oldest)
		set recent_files($oldest) $file
		[$mainframe getmenu recent] insert 0 command -label "$recent_files($oldest)" -command "ApolTop::openPolicyFile $recent_files($oldest) 0"
		set most_recent_file $oldest
	}	
	return	
}

proc ApolTop::helpDlg {title file_name} {
    variable contents
    variable helpDlg
    set helpDlg .apol_helpDlg
    
    # Checking to see if output window already exists. If so, it is destroyed.
    if { [winfo exists $helpDlg] } {
    	destroy $helpDlg
    }
    toplevel $helpDlg
    wm protocol $helpDlg WM_DELETE_WINDOW "destroy $helpDlg"
    wm withdraw $helpDlg
    wm title $helpDlg "$title"

    set hbox [frame $helpDlg.hbox ]
    # Display results window
    set sw [ScrolledWindow $hbox.sw -auto none]
    set resultsbox [text [$sw getframe].text -bg white -wrap none]
    $sw setwidget $resultsbox
    set okButton [Button $hbox.okButton -text "OK" \
		      -command "destroy $helpDlg"]
    # go to the script dir to find the help file
    set script_dir  [apol_GetScriptDir "$file_name"]
    set helpfile "$script_dir/$file_name"
    
    # Placing display widgets
    pack $hbox -expand yes -fill both -padx 5 -pady 5
    pack $okButton -side bottom
    pack $sw -side left -expand yes -fill both 
    # Place a toplevel at a particular position
    #::tk::PlaceWindow $helpDlg widget center
    wm deiconify $helpDlg
    
    $resultsbox delete 1.0 end
    set rt [catch {set f [open $helpfile]} err]
    if {$rt != 0} {
    	$resultsbox insert end $err
    } else {
    	$resultsbox insert end [read $f]
    	close $f
    }
    $resultsbox configure -state disabled
   	 
    return
}

proc ApolTop::makeTextBoxReadOnly {w} {
	    $w configure -state disabled
	    $w mark set insert 0.0
	    $w mark set anchor insert
	    focus $w
	    
	    return 0
}

proc ApolTop::setBusyCursor {} {
	variable prevCursor
	set prevCursor [. cget -cursor] 
    	. configure -cursor watch
    	update idletasks
	return
}

proc ApolTop::resetBusyCursor {} {
	variable prevCursor
	. configure -cursor $prevCursor
    	update idletasks
	return
}

proc ApolTop::popupPolicyStats {} {
	variable polversion
	variable policy_type
	variable contents
	
	set rt [catch {set pstats [apol_GetStats]}]
	if {$rt != 0} {
		tk_messageBox -icon error -type ok -title "Error" \
			-message "No policy file currently opened"
		return 
	}
	foreach item $pstats {
		set rt [scan $item "%s %d" key val]
		if {$rt != 2} {
			tk_messageBox -icon error -type ok -title "Error" -message "apol_GetStats: $rt"
			return
		}
		set stats($key) $val
	}
	
	# Build the output based on what was collected in the policy
	# (for now, only perms and classes are optionally collected (really a compile time option!)
	if {$contents(classes) == 0} {
		set classes "not collected"
	} else {
		set classes $stats(classes)
	}
	if {$contents(perms) == 0 } {
		set perms "not collected"
		set common_perms "not collected"
	} else {
		set common_perms $stats(common_perms)
		set perms $stats(perms)
	}
	
	set w .polstatsbox
	catch {destroy $w}
	toplevel $w
	
	label $w.1 -justify left \
		-text "Policy Summary Statistics\n "
	set labelf [frame $w.labelf]
		
	set left_text "\
Policy Version:\n\
Policy Type:\n\n\
Number of Classes and Permissions\n\
     \tObject Classes:\n\
     \tCommon Perms:\n\
     \tPermissions:\n\n\
Number of Types and Attributes:\n\
     \tTypes:\n\
     \tAttributes:\n\n\
Number of Type Enforcement Rules:\n\
     \tallow:\n\
     \tneverallow:\n\
     \tclone (pre v.11):\n\
     \ttype_transition.:\n\
     \ttype_change:\n\
     \ttype_member:\n\
     \tauditallow:\n\
     \tauditdeny:\n\
     \tdontaudit:\n\n\
Number of Roles:\n\
     \tRoles:\n\n\
Number of RBAC Rules:\n\
     \tallow:\n\
     \trole_transition:\n\n\
Number of Users:\n\
     \tusers:\n\n\
Number of Initial SIDs:\n\
     \tSIDs:\n\n\
Number of Booleans:\n\
     \tBools:\n"
     
     	set right_text "\
$polversion\n\
$policy_type\n\n\
\n\
$classes\n\
$common_perms\n\
$perms\n\n\
\n\
$stats(types)\n\
$stats(attribs)\n\n\
\n\
$stats(teallow)\n\
$stats(neverallow)\n\
$stats(clone)\n\
$stats(tetrans)\n\
$stats(techange)\n\
$stats(temember)\n\
$stats(auditallow)\n\
$stats(auditdeny)\n\
$stats(dontaudit)\n\n\
\n\
$stats(roles)\n\n\
\n\
$stats(roleallow)\n\
$stats(roletrans)\n\n\
\n\
$stats(users)\n\n\
\n\
$stats(sids)\n\n\
\n\
$stats(cond_bools)\n"

	set left_label  [label $labelf.left -justify left -text $left_text]
	set right_label [label $labelf.right -justify left -text $right_text]
     	button $w.close -text Close -command "catch {destroy $w}" -width 10
	
	pack $w.close -side bottom -anchor center 
	pack $w.1 -side top -anchor center
	pack $labelf -side top -anchor nw -fill both -expand yes -padx 5 -pady 5
	pack $left_label $right_label -side left -anchor nw -fill both -expand yes
	wm title $w "Policy Summary"
	wm iconname $w "policy summary"
	wm geometry $w +50+60
    	return		
}

proc ApolTop::showPolicyStats {} {
	variable polstats 
	variable contents
	set rt [catch {set pstats [apol_GetStats]}]
	if {$rt != 0} {
		tk_messageBox -icon error -type ok -title \
			-message "No policy file currently opened"
		return 
	}
	foreach item $pstats {
		set rt [scan $item "%s %d" key val]
		if {$rt != 2} {
			tk_messageBox -icon error -type ok -title "Error" -message "apol_GetStats: $rt"
			return
		}
		set stats($key) $val
	}
	set polstats ""
	if {$contents(classes) == 1} {
		append polstats "Classes: $stats(classes)   "
	}
	if {$contents(perms) == 1} {
		append polstats "Perms: $stats(perms)   "
	}
	append polstats "Types: $stats(types)   Attribs: $stats(attribs)   "
	append polstats "TE rules: [expr $stats(teallow) + $stats(neverallow) + 	\
		$stats(auditallow) + $stats(auditdeny) + $stats(clone)  +  $stats(dontaudit) +	\
		$stats(tetrans) + $stats(temember) + $stats(techange)]   "
	append polstats "Roles: $stats(roles)"
	append polstats "   Users: $stats(users)"
	return
}

proc ApolTop::aboutBox {} {
     variable gui_ver
     variable copyright_date
     
     set lib_ver [apol_GetVersion]
     tk_messageBox -icon info -type ok -title "About SELinux Policy Analysis Tool" -message \
	"Security Policy Analysis Tool for Security Enhanced Linux \n\nCopyright (c) $copyright_date\nTresys Technology, LLC\nwww.tresys.com/selinux\n\nGUI Version ($gui_ver)\nLib Version ($lib_ver)"
     return
}

proc ApolTop::unimplemented {} {
	tk_messageBox -icon warning \
		-type ok \
		-title "Unimplemented" \
		-message \
		"This command is not currently implemented."
	
	return
}

proc ApolTop::closePolicy {} {
        variable contents
	variable filename 
	variable polstats
	variable polversion
	variable policy_is_open	
	
	set polversion ""
	set filename ""
	set polstats ""
	set contents(classes)	0
	set contents(perms)	0
	set contents(types)	0
	set contents(te_tules)	0
	set contents(roles)	0
	set contents(rbac)	0
	set contents(users)	0
	array unset contents
	
	wm title . "SE Linux Policy Analysis"
	Apol_Perms_Map::close $ApolTop::mainframe 
	Apol_Class_Perms::close
	Apol_Types::close
	Apol_TE::close
	Apol_Roles::close
        Apol_RBAC::close
        Apol_Users::close
        Apol_Initial_SIDS::close
        Apol_Cond_Bools::close
        Apol_Cond_Rules::close
        Apol_Analysis::close 
        Apol_PolicyConf::close      
	ApolTop::set_Focus_to_Text [$ApolTop::notebook raise]
	set rt [catch {apol_ClosePolicy} err]
	if {$rt != 0} {
		tk_messageBox -icon error -type ok -title "Error closing policy" \
			-message "There was an error closing the policy: $err."
	} 
	set policy_is_open 0
	$ApolTop::mainframe setmenustate Disable_SearchMenu_Tag disabled
	# Disable Edit perm map menu item since a perm map is not yet sloaded.
	$ApolTop::mainframe setmenustate Perm_Map_Tag disabled	
	$ApolTop::mainframe setmenustate Disable_SaveQuery_Tag disabled
	$ApolTop::mainframe setmenustate Disable_LoadQuery_Tag disabled
	$ApolTop::mainframe setmenustate Disable_Summary disabled
	# We make sure that the initial SIDs tab is re-enabled, b/c a binary policy may have been opened
	# and this tab would have been disabled. 
	$ApolTop::components_nb itemconfigure $ApolTop::initial_sids_tab -state normal
	ApolTop::enable_disable_conditional_widgets 1
	
	return 0
}

proc ApolTop::open_apol_modules {file} {
	set rt [catch {Apol_Class_Perms::open} err]
	if {$rt != 0} {
		return -code error $err
	}
	set rt [catch {Apol_Types::open} err]
	if {$rt != 0} {
		return -code error $err
	}	
	set rt [catch {Apol_TE::open} err]
	if {$rt != 0} {
		return -code error $err
	}
	set rt [catch {Apol_Roles::open} err]
	if {$rt != 0} {
		return -code error $err
	}
	set rt [catch {Apol_RBAC::open} err]
	if {$rt != 0} {
		return -code error $err
	}
	set rt [catch {Apol_Users::open} err]
	if {$rt != 0} {
		return -code error $err
	}
	set rt [catch {Apol_Initial_SIDS::open} err]
	if {$rt != 0} {
		return -code error $err
	}
	set rt [catch {Apol_Cond_Bools::open} err]
	if {$rt != 0} {
		return -code error $err
	}
	set rt [catch {Apol_Cond_Rules::open} err]
	if {$rt != 0} {
		return -code error $err
	}
	set rt [catch {Apol_Analysis::open} err]
	if {$rt != 0} {
		return -code error $err
	}
	set rt [catch {Apol_PolicyConf::open $file} err]
	if {$rt != 0} {
		return -code error $err
	}
 	return 0
 }
 
proc ApolTop::enable_disable_conditional_widgets {enable} {
	set tab [$ApolTop::notebook raise] 
	switch -exact -- [ApolTop::get_tabname $tab] \
		$ApolTop::components_tab {
			if {[ApolTop::get_tabname [$ApolTop::components_nb raise]] == $ApolTop::cond_bools_tab} {
				if {$enable} {
					$ApolTop::components_nb raise $ApolTop::cond_bools_tab
				} else {
					$ApolTop::components_nb raise [$ApolTop::components_nb pages 0]
				}
			}				
		} \
		$ApolTop::rules_tab {
			if {[ApolTop::get_tabname [$ApolTop::rules_nb raise]] == $ApolTop::cond_rules_tab} {
				if {$enable} {
					$ApolTop::rules_nb raise $ApolTop::cond_rules_tab
				} else {
					$ApolTop::rules_nb raise [$ApolTop::rules_nb pages 0]
				}
			}
		} \
		default { 
		}
		
	if {$enable} {
		$ApolTop::components_nb itemconfigure $ApolTop::cond_bools_tab -state normal
		$ApolTop::rules_nb itemconfigure $ApolTop::cond_rules_tab -state normal
	} else {
		$ApolTop::components_nb itemconfigure $ApolTop::cond_bools_tab -state disabled
		$ApolTop::rules_nb itemconfigure $ApolTop::cond_rules_tab -state disabled
	}
			
	Apol_TE::enable_disable_conditional_widgets $enable
	return 0
}

proc ApolTop::set_initial_open_policy_state {} {
	set rt [catch {set version_num [apol_GetPolicyVersionNumber]} err]
	if {$rt != 0} {
		return -code error $err
	}

	if {$version_num < 16} {
		ApolTop::enable_disable_conditional_widgets 0
	} 
	
	if {$ApolTop::policy_type == $ApolTop::binary_policy_type} {
   		$ApolTop::components_nb itemconfigure $ApolTop::initial_sids_tab -state disabled
   	}   	
   	
	ApolTop::set_Focus_to_Text [$ApolTop::notebook raise]  
	# Enable perm map menu items since a policy is now open.
	$ApolTop::mainframe setmenustate Perm_Map_Tag normal
	$ApolTop::mainframe setmenustate Disable_Summary normal
	$ApolTop::mainframe setmenustate Disable_SearchMenu_Tag normal	
	ApolTop::configure_edit_pmap_menu_item 0
	
   	return 0
}
 
# Do the work to open a policy file:
# file is file name, and recent_flag indicates whether to add this file to list of
# recently opened files (set to 1 if you want to do this).  You would NOT set this
# to 1 if a recently file is being opened with this proc
proc ApolTop::openPolicyFile {file recent_flag} {
	variable contents
	variable polversion
	variable policy_type
	variable policy_is_open	
	variable filename
	variable policy_open_option
	
	ApolTop::closePolicy
	
	set file [file nativename $file]
	if {![file exists $file]} {
		tk_messageBox -icon error \
		-type ok \
		-title "File Does Not Exist" \
		-message "File ($file) does not exist."
		return -1
	} 
	if { ![file readable $file] } {
		tk_messageBox -icon error \
		-type ok \
		-title "Permission Problem" \
		-message \
		"You do not have permission to read $file."
		return -1
	}
 	if {[file isdirectory $file]} {
 		tk_messageBox -icon error \
		-type ok \
		-title "File is Directory" \
		-message \
		"$file is a directory."
		return -1
 	}
 
	# Change the cursor
	set orig_Cursor [. cget -cursor] 
	. configure -cursor watch
	update idletasks
	set rt [catch {apol_OpenPolicy $file $policy_open_option} err]
	if {$rt == 0} {
		#set filename [file tail $file]
		set filename $file
	} else {
		tk_messageBox -icon error -type ok -title "Error with policy file" \
			-message "The selected file does not appear to be a valid SE Linux Policy.\n\n$err" 
		. configure -cursor $orig_Cursor 
		focus -force .
		return -1
	}
	set rt [catch {set polversion [apol_GetPolicyVersionString]}]
	if {$rt != 0} {
		tk_messageBox -icon error -type ok -title "Error" -message "apol_GetPolicyVersionString: $rt"
		return 0
	}
	set rt [catch {set policy_type [apol_GetPolicyType]}]
	if {$rt != 0} {
		tk_messageBox -icon error -type ok -title "Error" -message "apol_GetPolicyType: $rt"
		return 0
	}
	set polversion [append polversion " \($policy_type)"]
	# Set the contents flags to indicate what the opened policy contains
	set rt [catch {set con [apol_GetPolicyContents]} err]
	if {$rt != 0} {
		tk_messageBox -icon error -type ok -title "Error" -message "$err"
		return 0
	}
	foreach item $con {
		set rt [scan $item "%s %d" key val]
		if {$rt != 2} {
			tk_messageBox -icon error -type ok -title "Error" -message "openPolicy (getting contents): $rt"
			return
		}
		set contents($key) $val
	}
	
	ApolTop::showPolicyStats
	set rt [catch {ApolTop::open_apol_modules $file} err]
 	if {$rt != 0} {
 		tk_messageBox -icon error -type ok -title "Error" -message "$err"
		return $rt	
 	}
 	set rt [catch {ApolTop::set_initial_open_policy_state} err]
	if {$rt != 0} {
		tk_messageBox -icon error -type ok -title "Error" -message "$err"
 		return $rt
 	}
	set policy_is_open 1
	
	if {$recent_flag == 1} {
		ApolTop::addRecent $file
	}

	# Change the cursor back to the original and then set the focus to the toplevel.
	. configure -cursor $orig_Cursor 
	focus -force .
	wm title . "SE Linux Policy Analysis - $file"
	
	return 0
}

proc ApolTop::openPolicy {} {
	variable filename 
	variable polversion
	
        set progressval 0
        set file ""
        set types {
		{"Policy conf files"	{.conf}}
		{"All files"		*}
    	}
        catch [set file [tk_getOpenFile -filetypes $types]]
        
        if {$file != ""} {
		ApolTop::openPolicyFile $file 1
	}
	return
}

proc ApolTop::free_call_back_procs { } {
	Apol_Class_Perms::free_call_back_procs
	Apol_Types::free_call_back_procs	
	Apol_TE::free_call_back_procs
	Apol_Roles::free_call_back_procs
	Apol_RBAC::free_call_back_procs
	Apol_Users::free_call_back_procs
	Apol_Initial_SIDS::free_call_back_procs
	Apol_Analysis::free_call_back_procs
	Apol_PolicyConf::free_call_back_procs
	Apol_Cond_Bools::free_call_back_procs
	Apol_Cond_Rules::free_call_back_procs
	return 0
}

proc ApolTop::apolExit { } {
	variable policy_is_open
	if {$policy_is_open} {
		ApolTop::closePolicy
	}
	ApolTop::free_call_back_procs
	ApolTop::writeInitFile
	exit
}

proc ApolTop::load_recent_files { } {
	variable temp_recent_files
	
	foreach r_file $temp_recent_files {
		ApolTop::addRecent $r_file
	}
	# No longer need this variable; so, delete.
	unset temp_recent_files
	return 0
}

proc ApolTop::load_fonts { } {
	variable title_font
	variable dialog_font
	variable general_font
	variable text_font
	
	tk scaling -displayof . 1.0
	# First set all fonts in general; then change specific fonts
	if {$general_font == ""} {
		option add *Font "Helvetica 10"
	} else {
		option add *Font $general_font
	}
	if {$title_font == ""} {
		option add *TitleFrame.l.font "Helvetica 10 bold italic" 
	} else {
		option add *TitleFrame.l.font $title_font  
	}
	if {$dialog_font == ""} {
		option add *Dialog*font "Helvetica 10" 
	} else {
		option add *Dialog*font $dialog_font
	}
	if {$text_font == ""} {
		option add *text*font "fixed"
		set text_font "fixed"
	} else {
		option add *text*font $text_font
	}
	return 0	
}

proc ApolTop::main {} {
	global tk_version
	global tk_patchLevel
	variable top_width
        variable top_height
	variable bwidget_version
	variable notebook
	
	# Prevent the application from responding to incoming send requests and sending 
	# outgoing requests. This way any other applications that can connect to our X 
	# server cannot send harmful scripts to our application. 
	rename send {}
	
	# Load BWidget package into the interpreter
        set rt [catch {set bwidget_version [package require BWidget]} err]
    
	if {$rt != 0 } {
		tk_messageBox -icon error -type ok -title "Missing BWidgets package" -message \
			"Missing BWidgets package.  Ensure that your installed version of \n\
			TCL/TK includes BWidgets, which can be found at\n\n\
			http://sourceforge.net/projects/tcllib"
		exit
	}
	if {[package vcompare $bwidget_version "1.4.1"] == -1} {
		tk_messageBox -icon warning -type ok -title "Package Version" -message \
			"This tool requires BWidgets 1.4.1 or later. You may experience problems\
			while running the application. It is recommended that you upgrade your BWidgets\
			package to version 1.4.1 or greater. See 'Help' for more information."	
	}
	
	# Provide the user with a warning if incompatible Tk and BWidget libraries are being used.
	if {[package vcompare $bwidget_version "1.4.1"] && $tk_version == "8.3"} {
		tk_messageBox -icon error -type ok -title "Error" -message \
			"Your installed Tk version $tk_version includes an incompatible BWidgets $bwidget_version package version. \
			This has been known to cause a tk application to crash.\n\nIt is recommended that you either upgrade your \
			Tk library to version 8.4 or greater or use BWidgets 1.4.1 instead. See the README for more information."	
		exit
	}
	
	# Load the apol package into the interpreter
	set rt [catch {package require apol} err]
	if {$rt != 0 } {
		tk_messageBox -icon error -type ok -title "Missing SE Linux package" -message \
			"Missing the SE Linux package.  This script will not\n\
			work correctly using the generic TK wish program.  You\n\
			must either use the apol executable or the awish\n\
			interpreter."
		exit
	}

	
	wm withdraw .
	wm title . "SE Linux Policy Analysis"
	wm protocol . WM_DELETE_WINDOW "ApolTop::apolExit"
	
	# Read apols' default settings file, gather all font information, create the gui and then load recent files into the menu.
	ApolTop::readInitFile
	ApolTop::load_fonts
	ApolTop::create
	ApolTop::load_recent_files
				
	#    # Configure the geometry for the window manager
	#    set x  [winfo screenwidth .]
	#    set y  [winfo screenheight .]
	#    set width  [ expr $x - ($x/10) ]
	#    set height [ expr $y - ($y/4)  ]
	#    BWidget::place . $width $height center

	# BWidgets packages 1.6+ correctly computes the size of the largest Notebook
	# page when calling its' compute_size command. So, we can use our main notebook 
	# widgets dimensions to set our default size. This should make the widgets display 
	# without obscuring widgets.
	if {[package vcompare $bwidget_version "1.6"] >= 0} {
		set ApolTop::top_width [$notebook cget -width]	
		set ApolTop::top_height [$notebook cget -height]
	} 
        wm geom . ${top_width}x${top_height}
        
     	update idletasks   
	wm deiconify .
	raise .
	focus -force .
	
	return 0
}

#######################################################
# Start script here
ApolTop::main
wm geom . [wm geom .]
