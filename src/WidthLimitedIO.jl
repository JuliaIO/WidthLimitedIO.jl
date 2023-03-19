module WidthLimitedIO

using Unicode

export TextWidthLimiter, ansi_esc_status, ANSIEscapeError

include("ansi_escapes.jl")

mutable struct TextWidthLimiter <: IO
    io::IO
    isclosed::Bool
    width::Int
    limit::Int
    esc_status::IncrementalANSIEscape
    seen_esc::Bool
    iotmp::IOBuffer
end
TextWidthLimiter(io::IO, limit) = TextWidthLimiter(io, iszero(limit), 0, limit, NONE, false, IOBuffer())
Base.get(limiter::TextWidthLimiter, key, default) = get(limiter.io, key, default)

getiotmp(io::TextWidthLimiter) = io.iotmp
getiotmp(ioctx::IOContext{TextWidthLimiter}) = getiotmp(ioctx.io)
gettwl(io::TextWidthLimiter) = io
gettwl(io::IOContext{TextWidthLimiter}) = io.io

# Uncomment this to debug display of a TextWidthLimiter (e.g., triggered by `print(limited, args1, args...)`)
# Base.show(io::IO, twl::TextWidthLimiter) = error("do not display")

function Base.write(limiter::TextWidthLimiter, c::Char)
    @assert limiter.width <= limiter.limit
    n = 0
    if limiter.isclosed
        !limiter.seen_esc && return n  # if we've never seen an ANSI escape code, we don't have to look for the "closing" code
        status = limiter.esc_status = ansi_esc_status(limiter.esc_status, c)
        if status != NONE
            print(limiter.io, c)
            n = ncodeunits(c)
        end
        return n
    end
    cwidth = textwidth(c)   # TODO? Add Preferences to allow users to configure broken terminals, see https://discourse.julialang.org/t/graphemes-vs-chars/96118
    in_esc = limiter.esc_status ∈ (ESCAPE1, ESCAPE, INTERMEDIATE, PARAMETER)
    if limiter.width + cwidth < limiter.limit || in_esc    # < saves space for '…'
        status = limiter.esc_status = ansi_esc_status(limiter.esc_status, c)
        if status != NONE
            limiter.seen_esc = true
        else
            limiter.width += cwidth
        end
        print(limiter.io, c)
        n = ncodeunits(c)
    else
        # close the output
        print(limiter.io, '…')
        limiter.width += 1
        limiter.isclosed = true
        n = ncodeunits('…')
    end
    return n
end

function Base.write(limiter::TextWidthLimiter, s::Union{String,SubString{String}})
    n = 0
    for c in s
        n += write(limiter, c)
    end
    return n
end

writegeneric(limiter, x) = (write(getiotmp(limiter), x); write(gettwl(limiter), String(take!(getiotmp(limiter)))))
printgeneric(limiter, x) = (print(getiotmp(limiter), x); print(gettwl(limiter), String(take!(getiotmp(limiter)))))
 showgeneric(limiter, x) = (show(getiotmp(limiter), x); print(gettwl(limiter), String(take!(getiotmp(limiter)))))

Base.write(limiter::IOContext{TextWidthLimiter}, c::Char) = writegeneric(limiter, c)
Base.write(limiter::IOContext{TextWidthLimiter}, s::Union{String,SubString{String}}) = writegeneric(limiter, s)

for IOT in (TextWidthLimiter, IOContext{TextWidthLimiter})
    @eval Base.write(limiter::$IOT, s::Symbol) = writegeneric(limiter, s)
    @eval Base.show(limiter::$IOT, c::AbstractChar) = showgeneric(limiter, c)
    @eval Base.show(limiter::$IOT, n::BigInt) = showgeneric(limiter, n)
    @eval Base.show(limiter::$IOT, n::Signed) = showgeneric(limiter, n)
end


Base.iswritable(limiter::TextWidthLimiter) = !limiter.isclosed || limiter.seen_esc

if isdefined(Base, :closewrite)
    """
        closewrite(limiter::TextWidthLimiter)

    Turn off further writing to `limiter`. In many cases, `iswritable(limiter)` will now return `false`,
    but it is not an error to attempt to write further values to `limiter`.

    One exception is if ANSI terminal escape codes (e.g., to change text color) had been previously
    written to `limiter`; in that case `iswritable(limiter)` will still return `true`, but henceforth
    the only characters written to `limiter` will be further escape codes. This will ensure, e.g., that
    text color gets reset to its original state.

    Thus, it's acceptable to check `iswritable(limiter)` and skip further writing if the return value is `false`.
    """
    Base.closewrite(limiter::TextWidthLimiter) = limiter.isclosed = true
end

function Base.take!(limiter::TextWidthLimiter)
    @assert limiter.esc_status ∈ (NONE, FINAL, C0)
    limiter.isclosed = iszero(limiter.limit)
    limiter.width = 0
    limiter.esc_status = NONE
    limiter.seen_esc = false
    return take!(limiter.io)
end

end
