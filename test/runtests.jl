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
    if isdefined(Base, :closewrite)
        print(limiter, "ab")
        closewrite(limiter)
        @test !iswritable(limiter)
        print(limiter, "cde")
        @test String(take!(limiter)) == "ab"
    end

    # ANSI terminal characters
    limiter = TextWidthLimiter(IOBuffer(), 5)
    printstyled(IOContext(limiter, :color=>true), "abcdef"; color=:red)
    @test iswritable(limiter)    # because seen_esc == true
    @test String(take!(limiter)) == "\e[31mabcd…\e[39m"
    # Placement of escape initiation relative to width is robust
    print(limiter, "1\e[31m23456\e[39m")
    @test String(take!(limiter)) == "1\e[31m234…\e[39m"
    print(limiter, "12\e[31m3456\e[39m")
    @test String(take!(limiter)) == "12\e[31m34…\e[39m"
    print(limiter, "123\e[31m456\e[39m")
    @test String(take!(limiter)) == "123\e[31m4…\e[39m"
    print(limiter, "1234\e[31m56\e[39m")
    @test String(take!(limiter)) == "1234\e[31m…\e[39m"
    print(limiter, "12345\e[31m6\e[39m")
    @test String(take!(limiter)) == "1234…"

    # Malformed ANSI characters
    limiter = TextWidthLimiter(IOBuffer(), 5)
    @test_throws ANSIEscapeError print(limiter, "\e[!3m")
end
