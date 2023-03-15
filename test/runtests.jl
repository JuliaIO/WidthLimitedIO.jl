using WidthLimitedIO
using Test

@testset "WidthLimitedIO.jl" begin
    limiter = TextWidthLimiter(IOBuffer(), 5)
    @test_throws Exception write(limiter, UInt8('a'))   # byte I/O unsupported
    @test_throws Exception write(limiter, 'a')          # byte I/O unsupported
    @test_throws Exception write(limiter, "abc")        # byte I/O unsupported

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

    limiter = TextWidthLimiter(IOBuffer(), 50)
    iocompare = IOBuffer()
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
            @test String(take!(limiter)) == String(take!(iocompare))
        end
    end

end
