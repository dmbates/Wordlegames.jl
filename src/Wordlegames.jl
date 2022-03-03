module Wordlegames

using AbstractTrees
using DataFrames
using Random
using Tables

using AbstractTrees: print_tree

include("utilities.jl")
include("GamePool.jl")
include("trees.jl")

export GameNode,
    GamePool,
    GuessScore,
    GuessType,
    MinimizeExpected,
    MaximizeEntropy,
    Random,
    Tables,
    bincounts!,
    entropy2,
    expectedpoolsize,
    optimalguess,
    playgame!,
    print_tree,
    reset!,
    rowtable,
    scorecolumn!,
    scoreupdate!,
    showgame!,
    tiles,
    tree,
    updateguess!

end
