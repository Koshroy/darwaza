package require uri
package require tls

namespace eval ::gemini {
    namespace export fetch
}

uri::register gemini {
    variable schemepart $uri::http::schemepart
}

# uri::Split<Scheme> is the proc called when trying to
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

proc mime_type {header} {
    set code_len 2
    set mime_start_ind [expr $code_len + 1]
    set mime_end_ind [expr [string first ";" $header $mime_start_ind] - 1]
    ;# If we know that the mime type has to at least start at the end of
    ;# the status code, and that there is no way that we found the
    ;# mimetype, so we are in error.
    ;# This is a more restrictive check than $mime_end_ind < 0
    if { $mime_end_ind < $code_len} {
        return ""
    }
    return [string range $header $mime_start_ind $mime_end_ind]
}

proc ::gemini::fetch {url} {
    array set url_split [uri::split $url]
    set sock [tls::socket $url_split(host) $url_split(port)]
    chan puts -nonewline $sock [string cat $url "\r\n"]
    chan flush $sock

    gets $sock header ;# Grab the header line from the socket
    set code [string range $header 0 1]
    if {[string index $code 0] eq 5} {
        error "Error fetching Resource: $header"
    }

    set body [chan read $sock]
    close $sock


    set resp(code) $code
    set resp(mime-type) [mime_type $header]
    set resp(body) $body
    
    return [array get resp]
}
