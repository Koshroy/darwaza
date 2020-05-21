package require uri
package require tls

uri::register gemini {
    variable schemepart $uri::http::schemepart
}

proc uri::SplitGemini {url} {
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

proc fetch {url} {
    array set url_split [uri::split $url]
    set sock [tls::socket $url_split(host) $url_split(port)]
    chan puts -nonewline $sock [string cat $url "\r\n"]
    chan flush $sock
    set resp [chan read $sock]
    chan close $sock
    return $resp
}

