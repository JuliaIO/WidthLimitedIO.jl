"""
    IncrementalANSIEscape

An `@enum` collection encoding previously-received escape codes. These get ansi_esc_statusd via [`TerminalEscapeCodes.ansi_esc_status`](@ref).
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

"""
# Examples

```jldoctest; prefix=:(using TerminalEscapeCodes)
julia> status = TerminalEscapeCodes.ansi_esc_status('x')   # ordinary character
TerminalEscapeCodes.NONE

julia> status = TerminalEscapeCodes.ansi_esc_status('\e')
TerminalEscapeCodes.ESCAPE1

julia> status = TerminalEscapeCodes.ansi_esc_status(status, '[')
TerminalEscapeCodes.ESCAPE

```
"""
function ansi_esc_status(status::IncrementalANSIEscape, c)
    if status ∈ (NONE, FINAL)
        c ∈ ('\a', '\b', '\t', '\n', '\f', '\r') && return C0
        c == '\e' && return ESCAPE1
        return NONE
    end
    if status == ESCAPE1
        c == '[' && return ESCAPE
        error("unsupported escape character ", c)
    end
    newstatus = c ∈ Char(0x20):Char(0x2f) ? INTERMEDIATE :
                c ∈ Char(0x30):Char(0x3f) ? PARAMETER :
                c ∈ Char(0x40):Char(0x7e) ? FINAL : nothing
    status ∈ (ESCAPE, PARAMETER) && newstatus ∈ (PARAMETER, INTERMEDIATE, FINAL) && return newstatus
    status == INTERMEDIATE && newstatus ∈ (INTERMEDIATE, FINAL) && return newstatus
    error("unsupported escape character ", c, " from status ", status)
end
ansi_esc_status(c) = ansi_esc_status(NONE, c)
