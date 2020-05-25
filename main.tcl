package require Tk
package require lambda

source "gemini.tcl"
source "render.tcl"

# History list
set loc_hist [list]

set browser_title "Darwaza"
set start_page "gemini://acidic.website"
set browser_url $start_page
set viewport_contents ""

wm title . "Darwaza"

set address_bar_frame [ttk::frame .r1]
set viewport_frame [ttk::frame .r2]
set status_bar_frame [ttk::frame .r3]
pack $address_bar_frame
pack $viewport_frame
pack $status_bar_frame


set back_btn [ttk::button .r1.back -text ◀ -width 3]
set fwd_btn [ttk::button .r1.forward -text ▶ -width 3]
set address_bar [ttk::entry .r1.address -textvariable browser_url]
set go_btn [ttk::button .r1.go -text "Go!" -command change_url]

set viewport [text .r2.viewport]
set statusbar [ttk::label .r3.statusbar -justify right -text\
                   "Welcome to Darwaza!"]

 
$viewport configure \
    -font $regular_font \
    -bg "#fff8dc"\
    -foreground black\
    -padx 20 -pady 20\
    -insertontime 0


$viewport tag configure h1 -font $h1_font
$viewport tag configure h2 -font $h2_font
$viewport tag configure h3 -font $h3_font

$viewport tag configure link -font $link_font -foreground "#3333cc"
$viewport tag bind link {<Button-1>} {render::linkhandler %x %y}


proc change_url {args} {
    variable viewport
    variable browser_url

    if {[llength $args] == 1} {
        # If the list is a singleton, then we can use it as-is
        set browser_url $args

        # TODO: Remove hack when moving to Tcl object
        render::seturl $args
    }

    $viewport delete 1.0 [$viewport index end]
    render::cleanlinks
    gemini::fetch $browser_url -linehandler $render::render_proc
    lappend loc_hist $browser_url
}


# TODO: Refactor into an object constructor
render::setviewport $viewport
render::seturl $browser_url
render::seturlhandler [namespace code change_url]
# End TODO


pack configure .r1 -fill x
pack configure .r2 -fill both -expand 1
pack $back_btn -side left -padx 2
pack $fwd_btn -side left -padx 2
pack $address_bar -side left -fill both -expand true -padx 3 -pady 3
pack $go_btn -side left -fill both -expand true -padx 3 -pady 3
pack $statusbar -fill x
pack $viewport -side left -fill both -expand 1

focus $address_bar

foreach w [winfo children .r1] {pack configure $w -fill x}
foreach w [winfo children .r2] {pack configure $w -fill both -expand 1}
foreach w [winfo children .r3] {pack configure $w -fill x -expand 1}
