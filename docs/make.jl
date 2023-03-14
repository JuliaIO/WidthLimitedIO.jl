using WidthLimitedIO
using Documenter

DocMeta.setdocmeta!(WidthLimitedIO, :DocTestSetup, :(using WidthLimitedIO); recursive=true)

makedocs(;
    modules=[WidthLimitedIO],
    authors="Tim Holy <tim.holy@gmail.com> and contributors",
    repo="https://github.com/JuliaIO/WidthLimitedIO.jl/blob/{commit}{path}#{line}",
    sitename="WidthLimitedIO.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://JuliaIO.github.io/WidthLimitedIO.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/JuliaIO/WidthLimitedIO.jl",
    devbranch="main",
)
