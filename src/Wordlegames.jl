module Wordlegames

using Random
using ThreadsX

include("GamePool.jl")

export 
    GamePool,
    MinimizeExpected,
    MaximizeEntropy,
    Random,
    bincounts!,
    entropy2,
    expectedpoolsize,
    optimalguess,
    playgame!,
    reset!,
    score,
    scoreupdate!,
    tiles,
    updateguess!

end
