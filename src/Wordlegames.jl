module Wordlegames

using DataFrames
using Random
using ThreadsX

include("GamePool.jl")

export 
    GamePool,
    MinimizeExpected,
    MaximizeEntropy,
    Random,
    Tables,
    bincounts!,
    entropy2,
    expectedpoolsize,
    optimalguess,
    playgame!,
    reset!,
    rowtable,
    score,
    scoreupdate!,
    showgame!,
    tiles,
    updateguess!

end
