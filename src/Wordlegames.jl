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
    gamesummary,
    playgame!,
    pretty_table,
    reset!,
    score,
    scoreupdate!,
    showgame!,
    tiles,
    updateguess!

end
