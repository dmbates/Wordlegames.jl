module Wordlegames

using DataFrames
using Primes
using Random

include("utilities.jl")
include("play.jl")

export
    GamePool,
    bincounts!,
    nextguess,
    playgame,
    reset!,
    score,
    tiles,
    update!

end
