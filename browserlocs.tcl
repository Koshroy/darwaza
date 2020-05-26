oo::class create browserlocs {
    variable InsertPtr
    variable Locations

    constructor {} {
        set InsertPtr 0
        set Locations {}
    }

    # Chop history to end at InsertPtrex $at (includes $at)
    method Chophist {at} {
        # if {$at < 0} {
        #     set endloc 0 
        # } else {
        #     set endloc $at
        # }
        return [lrange $Locations 0 $at]
    }

    method addloc {loc} {
        # No need to chop history if we are at the end of
        # the history list
        if {$InsertPtr == [llength $Locations]} {
            set choppedlocs $Locations
        } else {
            set choppedlocs [my Chophist [expr $InsertPtr - 1]]
        }
        incr InsertPtr
        lappend choppedlocs $loc
        set Locations $choppedlocs
    }

    method current {} {
        return [lindex $Locations [expr $InsertPtr - 1]]
    }

    method back {} {
        if {$InsertPtr != 0} {
            set InsertPtr [expr $InsertPtr - 1]
        }
    }

    method forward {} {
        if {$InsertPtr < [llength $Locations]} {
            incr InsertPtr
        }
    }

    method putsState {} {
        puts "InsertPtr: $InsertPtr | Locations: $Locations"
    }
}
