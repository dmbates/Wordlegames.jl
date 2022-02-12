module Wordlegames

using PrettyTables
using Random

include("play.jl")

export GamePool,
    Random,
    bincounts!,
    gamesummary,
    playgame!,
    reset!,
    score,
    scoreupdate!,
    showgame!,
    tiles

end
