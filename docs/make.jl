using Documenter
using Wordlegames

makedocs(
    sitename = "Wordlegames",
    doctest = true,
    format = Documenter.HTML(),
    modules = [Wordlegames]
)

# Documenter can also automatically deploy documentation to gh-pages.
# See "Hosting Documentation" and deploydocs() in the Documenter manual
# for more information.
deploydocs(;
    repo = "github.com/dmbates/Wordlegame.jl.git",
)
