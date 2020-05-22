package require uri
package require tls

namespace eval ::gemini {
    namespace export fetch linetype
}

uri::register gemini {
    variable schemepart $uri::http::schemepart
}

# uri::Split<Scheme> is the command called when trying to
# call uri::split on a uri.
# This will be called when we call uri::fetch [gemini://cool.website]
proc uri::SplitGemini {url} {
    # The easiest way to hook into the uri package and add our own
    # gemini scheme is to simply piggyback off what html already offers
    # us.
    # So:
    # 1. Take the url and change the scheme to point to http
    # 2. Call uri::SplitHttpInner, the helper function that
    #    both uri::SplitHttp and uri::SplitHttps use under
    #    the hood
    # 3. Set some sane defaults, i.e. if the port is not provided
    #    initialize it to 1965
    # 4. Return the split array
    set sub_url [string map {gemini:// http://} $url]
    array set split_url [uri::SplitHttpInner gemini $sub_url]
    if {$split_url(port) eq ""} {
        set split_url(port) 1965
    }

    if {$split_url(host) eq ""} {
        set split_url(port) "127.0.0.1"
    }

    return [array get split_url]
}

proc ::gemini::mime_type {header} {
    set code_len 2
    set mime_start_ind [expr $code_len + 1]
    set mime_end_ind [expr [string first ";" $header $mime_start_ind] - 1]
    # If we know that the mime type has to at least start at the end of
    # the status code, and that there is no way that we found the
    # mimetype, so we are in error.
    # This is a more restrictive check than $mime_end_ind < 0
    if { $mime_end_ind < $code_len} {
        return ""
    }
    return [string range $header $mime_start_ind $mime_end_ind]
}

proc ::gemini::fetch {url args} {
    # TODO: Use Getopt
    foreach {opt val} $args {
        if {$opt == {-linehandler}} {
            set linehandler $val
        }
    }

    set has_linehandler [info exists linehandler]
    array set url_split [uri::split $url]
    set sock [tls::socket $url_split(host) $url_split(port)]
    puts -nonewline $sock [string cat $url "\r\n"]
    flush $sock

    gets $sock header ;# Grab the header line from the socket
    set code [string range $header 0 1]

    if {[expr [string index $code 0] eq 5]} {
        error "Error fetching Resource: $body"
    }

    set body ""

    while {[gets $sock line] >= 0} {
        if $has_linehandler {
            eval [list {*}$linehandler $line]
        } else {
            # gets strips trailing newlines from the line
            # so if we want to concatenate lines into a body
            # string and return that, then we should put the
            # newlines back in. Gemini uses CR-LF.
            set body [string cat $body $line "\r\n"]
        }
    }

    # If we have a linehandler, then there is no need to
    # return a response, so let's clean up and return early
    if $has_linehandler {
        close $sock
        return
    }

    set resp(code) $code
    set resp(mime_type) [mime_type $header]
    set resp(body) $body

    return [array get resp]
}

proc ::gemini::linetype {line} {
    if {[regexp "^#+\s*" $line]} {
        return markdown
    } elseif {[regexp "^=>\s*" $line]} {
        return link
    } elseif {[regexp "^```" $line]} {
        return raw
    } else {
        return text
    }
}
