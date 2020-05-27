package require uri
package require tls

namespace eval ::gemini {
    namespace export fetch linetype headerlevel resolve
    namespace export stripMarkdown

    variable max_redirects 5
}

if {[catch {uri::register gemini {
    variable schemepart gemini
}} ErrRegister] == 1} {
    puts "Warning when registering gemini scheme: $ErrRegister"
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

proc ::uri::JoinGemini {args} {
    return [eval [linsert $args 0 uri::JoinHttpInner gemini 1965]]
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

proc ::gemini::ParseCode {code} {
    switch [string index $code 0] {
        2 { return success }
        3 { return redirect }
        4 { return tempfail }
        5 { return failure }
        6 { return certerr }
        default { return failure }
    }
}

proc ::gemini::RedirectTarget {header} {
    set header_split [split [string trim $header]]
    if {[llength $header_split] < 2} {
        return ""
    }

    return [lindex $header_split 1]
}

proc ::gemini::FetchUrl {url linehandler} {
    # Do we have a linehandler to call on each body line received?
    set has_linehandler [expr {$linehandler != ""}]

    # Clean the URL up of trailing whitespace and split it into its
    # constituent parts
    set trim_url [string trim $url]
    array set url_split [uri::split $trim_url]

    # Open a TLS socket to the hostname and port indicated for connection
    # TODO: By default this TLS socket is not setup to validate certs
    set sock [tls::socket $url_split(host) $url_split(port)]

    # Turn newline/special character translation off on the socket
    # and let the OS know that all data on this socket is coming in on
    # UTF-8
    fconfigure $sock -translation binary -encoding {utf-8}

    # Send the initial URL with a trailing CR-LF
    puts -nonewline $sock "$trim_url\x0d\x0a"

    # Flush the socket so we can get a response immediately
    flush $sock

    # The first line in the response is the header, so grab it
    gets $sock header
    # The code is set to the first 2 characters of the response
    set code [string range $header 0 1]

    # Parse the response code
    set resp_type [ParseCode $code]

    # The response has a readable body if the request was successful
    # Use readbody to control whether or not to read the body
    # At this point in time, only successful requests reads the body
    set readbody [expr {$resp_type eq "success"}]

    # Throw appropriate errors for response errors received
    # These errors are unrecoverable errors
    switch $resp_type {
        failure {
            close $sock
            error "Received error fetching $url: $header"
        }

        tempfail {
            close $sock
            error "Received temporary failure fetching $url: $header"
        }

        certerr {
            close $sock
            error "Received certificate error fetching $url: $header"
        }
    }

    # Initialize the body to an empty string
    set body ""

    # Do not read the body if the flag was set as such
    while {$readbody && [gets $sock line] >= 0} {
        # Linehandler is called when there are body lines being read
        # from the socket. If there is no body, then linehandler
        # will never be called
        if $has_linehandler {
            eval $linehandler [list $line]
        } else {
            # gets strips trailing newlines from the line
            # so if we want to concatenate lines into a body
            # string and return that, then we should put the
            # newlines back in. Gemini uses CR-LF.
            set body [string cat $body $line "\r\n"]
        }
    }

    close $sock

    # If we have a body and a linehandler, then there is no need to
    # return a response, so let's clean up and return early
    if {$readbody && $has_linehandler} {
        return
    }

    # If the response was a success, then get a mimetype from it
    if {$resp_type eq "success"} {
        set mime_type [mime_type $header]
    } else {
        set mime_type ""
    }

    # But if we never had a body or we were called without a line handler,
    # then return a response array
    set resp(code) $code
    set resp(header) $header
    set resp(mime_type) $mime_type
    set resp(body) $body
    set resp(resp_type) $resp_type

    return [array get resp]
}

proc ::gemini::fetch {url args} {
    variable max_redirects

    set linehandler ""
    # TODO: Use Getopt
    foreach {opt val} $args {
        if {$opt == {-linehandler}} {
            set linehandler $val
        }
    }

    set redirects 0
    array set resp [FetchUrl $url $linehandler]

    # If the array is empty, then an array was never returned
    # so we presume that the response was successful
    if {[array size resp] == 0} {
        return
    }

    while {$resp(resp_type) eq "redirect"} {
        if {$redirects >= $max_redirects} {
            break
        }

        # Grab the URL the redirect wants us to go to
        set next_url [RedirectTarget $resp(header)]

        # If we weren't able to grab the redirect URL
        # properly, then we are done processing redirects
        # for better or for worse
        if {[string length $next_url] == 0} {
            break
        }

        array set resp [FetchUrl $next_url $linehandler]
        incr redirects
    }

    return [array get resp]
}

proc ::gemini::linetype {line} {
    if {[regexp "^#+\s*" $line]} {
        return markdown
    } elseif {[regexp "^=>\s*" $line]} {
        return link
    } elseif {[regexp "^```.*" $line]} {
        return raw
    } else {
        return text
    }
}

proc ::gemini::headerlevel {line} {
    set len [string length $line]
    if {$len >= 3 && [string range $line 0 2] eq "###"} {
        return h3
    } elseif {$len >= 2 && [string range $line 0 1] eq "##"} {
        return h2
    } elseif {$len >= 1 && [string index $line 0] eq "#"} {
        return h1
    } else {
        return none
    }
}

proc ::gemini::stripMarkdown {str} {
    return [regsub {^#+[[:space:]]*} $str ""]
}

proc ::gemini::splitLink {link} {
    set match [regexp {=>\s+(\S+)(\s+\S.*)?} $link full raw_url text]
    set url [string trim $raw_url]
    set text [string trim $text]
    return [list {url} $url {text} $text]
}

proc ::gemini::resolve {base url} {
    set sub_base [string map {gemini:// http://} $base]
    set resolve_http [uri::resolve $sub_base $url]
    return [string map {http:// gemini://} $resolve_http]
}
