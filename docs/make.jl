using Documenter
using Wordlegames

DocMeta.setdocmeta!(Wordlegames, :DocTestSetup, :(using Wordlegames); recursive=true)

makedocs(
    sitename = "Wordlegames.jl",
    authors="Douglas Bates <dmbates@gmail.com> and contributors",
    repo="https://github.com/dmbates/Wordlegames.jl/blob/{commit}{path}#{line}",
    doctest = true,
    format = Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://dmbates.github.io/Wordlegames.jl",
        assets=String[],
    ),
    modules = [Wordlegames],
    pages=[
        "Home" => "index.md",
    ]
)

# Documenter can also automatically deploy documentation to gh-pages.
# See "Hosting Documentation" and deploydocs() in the Documenter manual
# for more information.
deploydocs(;
    repo = "github.com/dmbates/Wordlegame.jl.git",
    devbranch="main",
    push_preview=true,
)
