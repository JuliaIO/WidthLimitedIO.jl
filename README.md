# WidthLimitedIO

[![Build Status](https://github.com/JuliaIO/WidthLimitedIO.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/JuliaIO/WidthLimitedIO.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/JuliaIO/WidthLimitedIO.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/JuliaIO/WidthLimitedIO.jl)

This Julia package exports a type, `TextWidthLimiter <: IO`, which can be used to limit output to no more than a specified number of characters.
Demo:

```julia
julia> using WidthLimitedIO

julia> limitio = TextWidthLimiter(IOBuffer(), 15);     # generous limit

julia> println(limitio, "Hello, world!"); String(take!(limitio))
"Hello, world!\n"

julia> limitio = TextWidthLimiter(IOBuffer(), 5);      # restrictive limit

julia> println(limitio, "Hello, world!"); String(take!(limitio))
"Hell…"

julia> print(limitio, collect(1:15)); String(take!(limitio))
"[1, …"
```

A particular feature of the package is that it takes care to ensure that font-color changes and other
features implemented via [ANSI escape codes](https://en.wikipedia.org/wiki/ANSI_escape_code) work
properly:

```julia
julia> limitio = TextWidthLimiter(IOBuffer(), 5);

julia> printstyled(IOContext(limitio, :color=>true), "abcdef"; color=:red); String(take!(limitio))
"\e[31mabcd…\e[39m"
```

Thus the text-color was properly reset despite having exceeded the width of the buffer (as evidenced by the `…` character).
When the string above is printed, it displays

```
abcd…
```

in red, while avoiding any corruption of any other on-screen display.

`TextWidthLimiter` was initially in [Cthulhu.jl](https://github.com/JuliaDebug/Cthulhu.jl),
but was redesigned and moved here to allow others to take advantage of it.
It may be particularly useful for terminal programs where you may want to limit options to a single line.
