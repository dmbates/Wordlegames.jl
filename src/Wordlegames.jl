module Wordlegames

using AbstractTrees
using DataFrames
using Random
using Tables
using ThreadsX

using AbstractTrees: print_tree

include("GamePool.jl")
include("trees.jl")

export GameNode,
    GamePool,
    GuessScore,
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
    score,
    scoreupdate!,
    showgame!,
    tiles,
    tree,
    updateguess!

end
