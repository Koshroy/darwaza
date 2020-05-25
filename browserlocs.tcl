oo::object create browserlocs
oo::objdefine browserlocs {
    variable ind
    variable locations

    set ind -1
    set locations {}

    # Chop history to end at index $at (includes $at)
    method chophist {at} {
        if {at < 0} {
            set endloc 0 
        } else {
            set endloc $at
        }
        return [lrange $locations 0 $endloc]
    }

    method Addloc {loc} {
        # No need to chop history if we are at the end of
        # the history list
        if {$ind == [expr [llength $locations] - 1]} {
            set choppedlocs $locations
        } else {
            set choppedlocs [my chophist $ind]
        }
        
        incr ind
        set locations [lappend $choppedlocs $loc]
    }

    method Current {} {
        return [lindex $locations $ind]
    }

    method Back {} {
        if {$ind != 0} {
            set ind [expr $ind - 1]
        }
    }

    method Forward {} {
        if {$ind < [llength $locations]} {
            incr ind
        }
    }

    method PutsState {} {
        puts "Ind: $ind | Locations: $locations"
    }
}
