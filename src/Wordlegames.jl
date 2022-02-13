module Wordlegames

using PrettyTables: pretty_table
using Random
using ThreadsX

include("play.jl")

export GamePool,
    Random,
    bincounts!,
    entropybase2,
    expectedpoolsize!,
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
