use Cro::Uri;

class Cro::Iri is Cro::Uri {
    grammar GenericParser is Cro::Uri::GenericParser {
        token TOP {
            [ <scheme> || <.panic('Malformed scheme')> ]
            [ ":" || <.panic('Missing : after scheme')> ]
            <ihier-part>
            [ "?" <iquery> ]?
            [ "#" <ifragment> ]?
            [ $ || <.panic('unexpected text at end')> ]
        }
        proto token ihier-part { * }
        token ihier-part:sym<authority> { "//" <iauthority> <ipath-abempty> }
        token ihier-part:sym<absolute>  { <ipath-absolute> }
        token ihier-part:sym<rootless>  { <ipath-rootless> }
        token ihier-part:sym<empty>     { <ipath-empty> }
        token IRI-reference { [ <TOP> | <irelative-ref> ] }
        token absolute-IRI {
            [ <scheme> || <.panic('Malformed scheme')> ]
            [ ":" || <.panic('Missing : after scheme')> ]
            <ihier-part>
            [ "?" <iquery> ]?
        }
        token irelative-ref { <irelative-part> ["?" <iquery>]? ["#" <ifragment>]? }
        proto token irelative-part { * }
        token irelative-part:sym<authority> { "//" <iauthority> <ipath-abempty> }
        token irelative-part:sym<absolute>  { <ipath-absolute> }
        token irelative-part:sym<rootless>  { <ipath-rootless> }
        token irelative-part:sym<empty>     { <ipath-empty> }

        token iauthority {
            [ <iuserinfo> "@" ]?
            <ihost> [ ":" <port> ]?
        }

        token iuserinfo {
            [ <iunreserved> | <pct-encoded> | <sub-delims> | ':' ]*
        }

        proto token ihost { * }
        token ihost:sym<IPv4address> {
            <.IPv4address>
        }
        regex ihost:sym<IPv6address> {
            '[' <( <.IPv6address> )> ']'
        }
        token host:sym<ireg-name> {
            {} [ <iunreserved> | <pct-encoded> | <sub-delims> ]*
        }
        token ipath-abempty  { ["/" <isegment> ]* }
        token ipath-absolute { "/" [ <isegment-nz> [ "/" <isegment> ]* ]? }
        token ipath-noscheme { <isegment-nz-nc> [ "/" <isegment> ]* }
        token ipath-rootless { <isegment-nz> [ "/" <isegment> ]* }
        token ipath-empty    { '' }

        token isegment { <ipchar>* }
        token isegment-nz { <ipchar>+ }
        token isegment-nz-nc { [ <iunreserved> | <pct-encoded> | <sub-delims> | '@' ]+ }

        token ipchar { [ <iunreserved> | <pct-encoded> | <sub-delims> | ':' | '@' ] }
        token iquery { [ <ipchar> | <iprivate> | '/' | '?' ]* }
        token ifragment { [ <ipchar> | '/' | '?' ]* }
        token iunreserved { [ <alnum> | '-' | '.' | '_' | '~' | <ucschar> ] }
        token ucschar { <[\xA0..\xD7FF     \xF900..\xFDCF   \xFDF0..\xFFEF
                          \x10000..\x1FFFD \x20000..\x2FFFD \x30000..\x3FFFD
                          \x40000..\x4FFFD \x50000..\x5FFFD \x60000..\x6FFFD
                          \x70000..\x7FFFD \x80000..\x8FFFD \x90000..\x9FFFD
                          \xA0000..\xAFFFD \xB0000..\xBFFFD \xC0000..\xCFFFD
                          \xD0000..\xDFFFD \xE1000..\xEFFFD ]> }
        token iprivate { <[\xE000..\xF8FF \xF0000..\xFFFFD \x100000..\x10FFFD]> }
        token pct-encoded { '%' <xdigit> <xdigit> }
        token sub-delims { <[!$&'()*+,;=]> }
    }
}
