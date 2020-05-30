#!/usr/bin/env wish

package require Tk
package require lambda

source "gemini.tcl"
source "render.tcl"
source "browserlocs.tcl"

set regular_font_family "Georgia"
set regular_font_size 22
set regular_font [font create "view_regular"\
                      -family $regular_font_family\
                      -size $regular_font_size]
set mono_font [font create "view_mono" -family "Courier" -size 22]

set h1_font [font create "view_h1" -family $regular_font_family -size 42]
set h2_font [font create "view_h2" -family $regular_font_family -size 38]
set h3_font [font create "view_h3" -family $regular_font_family -size 32]

set link_font [font create "view_link"\
                   -family $regular_font_family\
                   -size $regular_font_size]

set spacer_font [font create "view_spacer"\
                     -family $regular_font_family -size 10]

# History list
set locs [browserlocs new]

set browser_title "Darwaza"
set start_page "gemini://gemini.circumlunar.space/"
set browser_url $start_page
set viewport_contents ""
set statusbar_contents "Welcome to Darwaza!"

wm title . "Darwaza"
wm iconphoto . [image create photo -file "./icon.png"]

set address_bar_frame [ttk::frame .r1]
set viewport_frame [ttk::frame .r2]
set status_bar_frame [ttk::frame .r3]
pack $address_bar_frame
pack $viewport_frame
pack $status_bar_frame


set back_btn [ttk::button .r1.back -text ◀ -width 3\
                  -command {browsermove back}]
set fwd_btn [ttk::button .r1.forward -text ▶ -width 3\
                 -command {browsermove forward}]
set address_bar [ttk::entry .r1.address -textvariable browser_url]
bind $address_bar {<Return>} change_url
set go_btn [ttk::button .r1.go -text "Go!" -command change_url]

set viewport [text .r2.viewport]
set viewscroll [scrollbar .r2.scrollbar]
set statusbar [ttk::label .r3.statusbar\
                   -justify right\
                   -textvariable statusbar_contents]
 
$viewport configure \
    -font $regular_font \
    -bg "#fff8dc"\
    -foreground black\
    -padx 20 -pady 20\
    -insertontime 0\
    -wrap word

$viewport tag configure h1 -font $h1_font -foreground "#d14432"
$viewport tag configure h2 -font $h2_font -foreground "#d14432"
$viewport tag configure h3 -font $h3_font -foreground "#d14432"

$viewport tag configure link\
    -font $link_font\
    -foreground "#3e52cc"\

$viewport tag bind link {<Button-1>} {render::linkhandler %x %y}
$viewport tag bind link {<Enter>} {
    $viewport configure -cursor hand1
}
$viewport tag bind link {<Leave>} {
    $viewport configure -cursor arrow
}

$viewport configure -yscrollcommand {$viewscroll set}
$viewscroll configure -command {$viewport xview}


# Disable all keypresses in the text viewport from inserting
# text, effectively making this a read-only widget
bind $viewport <KeyPress> break

proc goto_url {url} {
    variable viewport
    variable browser_url
    variable locs
    variable hist_ind
    variable statusbar_contents

    set browser_url $url
    render::seturl $browser_url

    $viewport delete 1.0 [$viewport index end]
    render::cleanlinks

    set statusbar_contents "Fetching $url"
    set fetch [catch\
                   {gemini::fetch $browser_url\
                        -linehandler $render::render_proc}\
                   ErrFetch]

    if {$fetch == 1} {
        set statusbar_contents "Error fetching $url: $ErrFetch"
    } else {
        set statusbar_contents "Success fetching $url"
    }
}

proc change_url {args} {
    variable viewport
    variable locs
    variable hist_ind
    variable browser_url

    if {[llength $args] == 1} {
        # If the list is a singleton, then we can use it as-is
        set next_url $args
    } else {
        set next_url $browser_url
    }

    goto_url $next_url

    $locs addloc $browser_url
}


proc browsermove {dir} {
    variable locs

    $locs $dir
    set curr_url [$locs current]
    goto_url $curr_url
}


# TODO: Refactor into an object constructor
render::setviewport $viewport
render::seturl $browser_url
render::seturlhandler [namespace code change_url]
render::setregularfontsize $regular_font_size
# End TODO


pack configure .r1 -fill x
pack configure .r2 -fill both -expand 1
pack $back_btn -side left -padx 2
pack $fwd_btn -side left -padx 2
pack $address_bar -side left -fill both -expand true -padx 3 -pady 3
pack $go_btn -side left -fill both -expand true -padx 3 -pady 3
pack $statusbar -fill x
pack $viewport -side left -fill both -expand 1
pack $viewscroll -side right

focus $address_bar



foreach w [winfo children .r1] {pack configure $w -fill x}
foreach w [winfo children .r2] {pack configure $w -fill both -expand 1}
foreach w [winfo children .r3] {pack configure $w -fill x -expand 1}
