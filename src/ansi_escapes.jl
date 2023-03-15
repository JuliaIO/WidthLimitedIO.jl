"""
    IncrementalANSIEscape

An `@enum` collection encoding previously-received escape codes.
Their primary purpose is to decide whether we are done rendering
the escape code.


See [`ansi_esc_status`](@ref) for usage details.
"""
@enum IncrementalANSIEscape begin
    NONE
    ESCAPE1
    ESCAPE
    C0
    INTERMEDIATE
    PARAMETER
    FINAL
end

struct ANSIEscapeError <: Exception
    char::Char
    status::Union{Nothing,IncrementalANSIEscape}
end
ANSIEscapeError(char::Char) = ANSIEscapeError(char, nothing)

function Base.showerror(io::IO, e::ANSIEscapeError)
    print(io, "ANSI escape: unsupported character ", e.char)
    status = e.status
    if status !== nothing
        print(io, " from status ", status)
    end
end

"""
    ansi_esc_status(status::IncrementalANSIEscape, c::Char) → status
    ansi_esc_status(c::Char) → status

Return a `status` code indicating our position within an [ANSI terminal escape code](https://en.wikipedia.org/wiki/ANSI_escape_code).

# Examples

```jldoctest; prefix=:(using WidthLimitedIO)
julia> status = ansi_esc_status('m')   # ordinary character with no prior `status`
NONE::IncrementalANSIEscape = 0

julia> status = ansi_esc_status(status, '\e')  # start an escape sequence
ESCAPE1::IncrementalANSIEscape = 1

julia> status = ansi_esc_status(status, '[')   # CSI
ESCAPE::IncrementalANSIEscape = 2

julia> status = ansi_esc_status(status, '3')   # can be multiple digits
PARAMETER::IncrementalANSIEscape = 5

julia> status = ansi_esc_status(status, 'm')   # terminating final character
FINAL::IncrementalANSIEscape = 6

julia> status = ansi_esc_status(status, 'm')   # now 'm' is again an ordinary character
NONE::IncrementalANSIEscape = 0
```
"""
function ansi_esc_status(status::IncrementalANSIEscape, c::Char)
    if status ∈ (NONE, FINAL, C0)
        c ∈ ('\a', '\b', '\t', '\n', '\f', '\r') && return C0
        c == '\e' && return ESCAPE1
        return NONE
    end
    if status == ESCAPE1
        c == '[' && return ESCAPE
        throw(ANSIEscapeError(c))
    end
    newstatus = c ∈ Char(0x20):Char(0x2f) ? INTERMEDIATE :
                c ∈ Char(0x30):Char(0x3f) ? PARAMETER :
                c ∈ Char(0x40):Char(0x7e) ? FINAL : nothing
    status ∈ (ESCAPE, PARAMETER) && newstatus ∈ (PARAMETER, INTERMEDIATE, FINAL) && return newstatus
    status == INTERMEDIATE && newstatus ∈ (INTERMEDIATE, FINAL) && return newstatus
    throw(ANSIEscapeError(c, status))
end
ansi_esc_status(c::Char) = ansi_esc_status(NONE, c)
