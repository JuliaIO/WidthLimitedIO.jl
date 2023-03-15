module WidthLimitedIO

using Unicode

export TextWidthLimiter, ansi_esc_status

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

# Uncomment this to debug display of a TextWidthLimiter (e.g., triggered by `print(limited, args1, args...)`)
# Base.show(io::IO, twl::TextWidthLimiter) = error("do not display")

function Base.print(io::TextWidthLimiter, s::Union{String,SubString{String}})
    for c in s
        print(io, c)
    end
end

function Base.print(limiter::TextWidthLimiter, c::Char)
    @assert limiter.width <= limiter.limit
    if limiter.isclosed
        !limiter.seen_esc && return   # if we've never seen an ANSI escape code, we don't have to look for the "closing" code
        status = limiter.esc_status = ansi_esc_status(limiter.esc_status, c)
        if status != NONE
            print(limiter.io, c)
            limiter.width += textwidth(c)    # these should all be zero, but just in case...
        end
        return
    end
    cwidth = textwidth(c)   # TODO? Add Preferences to allow users to configure broken terminals, see https://discourse.julialang.org/t/graphemes-vs-chars/96118
    if limiter.width + cwidth <= limiter.limit - 1   # -1 saves space for '…'
        status = limiter.esc_status = ansi_esc_status(limiter.esc_status, c)
        if status != NONE
            limiter.seen_esc = true
        end
        print(limiter.io, c)
        limiter.width += cwidth
    else
        # close the output
        print(limiter.io, '…')
        limiter.width += 1
        limiter.isclosed = true
    end
end

## Generic print

Base.print(limiter::TextWidthLimiter, x) = (print(limiter.iotmp, x); print(limiter, String(take!(limiter.iotmp))))

# ambiguity resolution
Base.print(limiter::TextWidthLimiter, s::AbstractString) = invoke(print, Tuple{TextWidthLimiter, Any}, limiter, s)
Base.print(limiter::TextWidthLimiter, s::AbstractChar) = invoke(print, Tuple{TextWidthLimiter, Any}, limiter, s)
Base.print(limiter::TextWidthLimiter, s::Symbol) = invoke(print, Tuple{TextWidthLimiter, Any}, limiter, s)
Base.print(limiter::TextWidthLimiter, f::Core.IntrinsicFunction) = invoke(print, Tuple{TextWidthLimiter, Any}, limiter, f)
Base.print(limiter::TextWidthLimiter, f::Function) = invoke(print, Tuple{TextWidthLimiter, Any}, limiter, f)
Base.print(limiter::TextWidthLimiter, uuid::Base.UUID) = invoke(print, Tuple{TextWidthLimiter, Any}, limiter, uuid)
Base.print(limiter::TextWidthLimiter, uuid::Base.SHA1) = invoke(print, Tuple{TextWidthLimiter, Any}, limiter, uuid)
Base.print(limiter::TextWidthLimiter, x::Union{Float16, Float32}) = invoke(print, Tuple{TextWidthLimiter, Any}, limiter, x)
Base.print(limiter::TextWidthLimiter, x::Unsigned) = invoke(print, Tuple{TextWidthLimiter, Any}, limiter, x)
Base.print(limiter::TextWidthLimiter, v::VersionNumber) = invoke(print, Tuple{TextWidthLimiter, Any}, limiter, v)

## Generic show

Base.show(limiter::TextWidthLimiter, x) = (show(limiter.iotmp, x); print(limiter, String(take!(limiter.iotmp))))

Base.show(limiter::TextWidthLimiter, c::Char) = print(limiter, '\'', c, '\'')
Base.show(limiter::TextWidthLimiter, s::AbstractString) = print(limiter, '\"', s, '\"')

Base.iswritable(limiter::TextWidthLimiter) = !limiter.isclosed || limiter.seen_esc

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

function Base.take!(limiter::TextWidthLimiter)
    @assert limiter.esc_status ∈ (NONE, FINAL)
    limiter.isclosed = iszero(limiter.limit)
    limiter.width = 0
    limiter.esc_status = NONE
    limiter.seen_esc = false
    return take!(limiter.io)
end

end
