module Wordlegames

using LogExpFunctions: xlogx
using PrettyTables: pretty_table
using Random
using ThreadsX

include("play.jl")

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
