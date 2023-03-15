using WidthLimitedIO
using Test

@testset "Ambiguity" begin
    @test isempty(detect_ambiguities(WidthLimitedIO))
end

@testset "WidthLimitedIO.jl" begin
    limiter = TextWidthLimiter(IOBuffer(), 5)

    print(limiter, 'a')
    @test String(take!(limiter)) == "a"
    print(limiter, "a")
    @test String(take!(limiter)) == "a"
    print(limiter, "abc")
    @test String(take!(limiter)) == "abc"
    print(limiter, "abcd")
    @test String(take!(limiter)) == "abcd"
    print(limiter, "abcde")
    @test String(take!(limiter)) == "abcd…"
    print(limiter, "abcdef")
    @test String(take!(limiter)) == "abcd…"
    for i = 1:10
        print(limiter, 'a')
    end
    @test String(take!(limiter)) == "aaaa…"

    show(limiter, 'a')
    @test String(take!(limiter)) == "'a'"
    show(limiter, "a")
    @test String(take!(limiter)) == "\"a\""
    show(limiter, "ab")
    @test String(take!(limiter)) == "\"ab\""
    show(limiter, "abc")
    @test String(take!(limiter)) == "\"abc…"

    print(limiter, :a)
    @test String(take!(limiter)) == "a"
    show(limiter, :a)
    @test String(take!(limiter)) == ":a"

    iocompare = IOBuffer()
    for len in (5, 50)
        limiter = TextWidthLimiter(IOBuffer(), len)
        for f in (print, show)
            for obj in Any[
                1,
                0x08,
                ('a', 2),
                [1, 2, 3],
                Vector{Int},
                Dict(:a => 1),
                v"1.9",
            ]
                f(limiter, obj)
                f(iocompare, obj)
                strl, strc = String(take!(limiter)), String(take!(iocompare))
                if length(strc) >= len
                    @test strl == strc[1:len-1] * '…'
                else
                    @test strl == strc
                end
            end
        end
    end

    limiter = TextWidthLimiter(IOBuffer(), 1)
    print(limiter, 'a')
    @test String(take!(limiter)) == "…"

    # iswritable & closewrite
    limiter = TextWidthLimiter(IOBuffer(), 5)
    print(limiter, "ab")
    @test iswritable(limiter)
    print(limiter, "cde")
    @test !iswritable(limiter)
    take!(limiter)
    print(limiter, "ab")
    closewrite(limiter)
    @test !iswritable(limiter)
    print(limiter, "cde")
    @test String(take!(limiter)) == "ab"

    # ANSI terminal characters
    limiter = TextWidthLimiter(IOBuffer(), 5)
    printstyled(IOContext(limiter, :color=>true), "abcdef"; color=:red)
    @test iswritable(limiter)    # because seen_esc == true
    @test String(take!(limiter)) == "\e[31mabcd…\e[39m"

    # Malformed ANSI characters
    limiter = TextWidthLimiter(IOBuffer(), 5)
    @test_throws ANSIEscapeError print(limiter, "\e[!3m")
end
