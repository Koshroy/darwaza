package require Tk

source "gemini.tcl"

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

set regular_font [font create "view_regular" -family "Georgia" -size 22]
set viewport [text .r2.viewport]
set statusbar [ttk::label .r3.statusbar -justify right -text\
                   "Welcome to Darwaza!"]


$viewport configure -font $regular_font

proc change_url {} {
    array set resp [gemini::fetch $::browser_url]
    $::viewport delete 1.0 [$::viewport index end]
    $::viewport insert 1.0 $resp(body)
}


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
