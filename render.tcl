package require Tk

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

namespace eval ::render {
    # Context object passed into callbacks
    variable context

    # Array mapping line types to procs that render the line type
    variable render_linetype_funcs

    # Extension points to allow overwriting of the underlying render
    # procs
    variable render_line_proc render_proc

    # TODO: Refactor this namespace into a Renderer object
    # that can hold implicit state
    #
    # I'm not a big fan of having a namespace variable that holds
    # the implicit viewport and links for all render functions to write to.
    # I think I need to explore some alternate approaches,
    # such as maybe the Tcl object system, or passing along a
    # curried render function, but for now, this is the simplest
    # way to go.
    variable viewport link_table curr_url urlhandler
    set link_list {} ;# Empty list

    namespace export render_proc setviewport render_line_proc
    namespace export render_line
    namespace export linkhandler seturlhandler

    array set render_linetype_funcs \
        [list markdown renderMarkdown\
             text renderText\
             link renderLink\
             raw renderText ]

    proc renderMarkdown {line viewport context} {
        set post [gemini::stripMarkdown $line]
        $viewport insert end\
            [string cat [gemini::stripMarkdown $line] "\n"]\
            [list \
                 [gemini::headerlevel $line]\
                 -spacing3 $::regular_font_size]
    }

    proc renderLink {line viewport context} {
        variable link_list
        
        array set link_split [gemini::splitLink $line]
        lappend link_list $link_split(url)
        if {$link_split(text) eq ""} {
            set render_text $link_split(url)
        } else {
            set render_text $link_split(text)
        }
        $viewport insert end [string cat $render_text "\n"] link
    }

    proc renderText {line viewport context} {
        $viewport insert end [string cat $line "\n"]
    }

    proc render_line {linetype line viewport context} {
        variable render_linetype_funcs

        $render_linetype_funcs($linetype) $line $viewport $context
    }

    set render_line_proc [namespace code render_line]
    proc render {line} {
        variable render_line_proc
        variable link_list

        eval $render_line_proc \
            [gemini::linetype $line] [list $line] $::viewport ::context
    }

    set render_proc [namespace code render]

    proc setviewport {vp} {
        variable viewport
        set viewport $vp
    }

    proc linkhandler {xpos ypos} {
        variable viewport
        variable curr_url
        variable urlhandler

        set textpos [$viewport index "@$xpos,$ypos"]
        set link [textpostolink $textpos]
        set resolved_link [gemini::resolve $curr_url $link]
        eval $urlhandler [list $resolved_link]
    }

    proc textpostolink {textpos} {
        variable viewport
        variable link_list
        
        set ranges [$viewport tag ranges link]
        set linkcnt -1
        foreach {start end} $ranges {
            incr linkcnt
            if {($start <= $textpos) && ($textpos < $end)} {
                return [lindex $link_list $linkcnt]
            }
        }
    }

    # TODO: Remove after migrated to object constructor
    proc seturl {url} {
        variable curr_url

        set curr_url $url
    }

    proc seturlhandler {handler} {
        variable urlhandler

        set urlhandler $handler
    }

    # TODO: Ugly hack to deal with single namespace
    # this needs to be refactored into an object
    proc cleanlinks {} {
        variable link_list

        set link_list {}
    }
}
