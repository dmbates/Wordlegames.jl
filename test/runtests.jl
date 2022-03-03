using AbstractTrees
using Primes
using Tables
using Test
using Wordlegames

const primes5 = primes(10000, 99999) # vector of 5-digit prime numbers
const primel = GamePool(primes5)
const primelxpc = GamePool(primes5; guesstype=MinimizeExpected)

@testset "GamePool" begin
    @test typeof(primel) == GamePool{5,UInt8,MaximizeEntropy}
    @test isa(propertynames(primel), Tuple)
    @test length(primel.active) == 8363
    @test eltype(primel.allscores) == UInt8
    @test eltype(primel.guesspool) == NTuple{5,Char}
    @test length(first(primel.guesspool)) == 5
    @test primel.targetpool == primel.guesspool
    @test sum(primel.activetargets) == length(primel.active)
    @test length(names(primel.summary)) == 7
    @test all(reset!(primel).active)
    (; poolsz, guess, index, expected, entropy, score, sc) = only(primel.guesses)
    @test guess == "12953"
    @test index == 313
    @test expected ≈ 124.3844314241301
    @test entropy ≈ 6.632274058429609
    @test primel.hardmode
    @test ismissing(score)
    @test ismissing(sc)
    playgame!(primel, index)               # Got it in one!
    (; poolsz, guess, index, expected, entropy, score, sc) = only(primel.guesses)
    @test sc == 0xf2
    @test score == "🟩🟩🟩🟩🟩"
    Random.seed!(1234321)
    (; poolsz, guess, index, expected, entropy, score, sc) = showgame!(primel)
    @test poolsz == [8363, 201, 10]
    @test index == [313, 1141, 3556]
    @test guess == ["12953", "21067", "46271"]
    @test expected ≈ [124.3844314241301, 5.925373134328358, 1.2]
    @test entropy ≈ [6.632274058429609, 5.479367512099353, 3.121928094887362]
    @test sc == [108, 112, 242]
    (; poolsz, guess, index, expected, entropy, score, sc) = showgame!(primel, "43867")
    @test index == [313, 2387, 3273, 3337]
    # size mismatch
    @test_throws ArgumentError playgame!(primel, "4321")
    # errors in constructor arguments
    @test_throws ArgumentError GamePool(["foo", "bar"], trues(4))
    # gp = GamePool(["foo", "bar", "boz"], BitVector([true, true, false]))
    @test_broken isa(gp, GamePool{3,UInt8})
    @test_broken isa(gp.allscores, Matrix{UInt8})
    @test_broken size(gp.allscores) == (2, 3)
    @test_throws ArgumentError GamePool(["foo", "bar", "foobar"])
    @test_throws ArgumentError GamePool(["foo", "bar"]; guesstype=Int)
    @test Tables.isrowtable(playgame!(primel).guesses)  # this also covers the playgame! method for testing
end

@testset "scorecolumn!" begin
    targets = NTuple{5,Char}.(["raise", "super", "adapt", "algae", "abbey"])
    scores = similar(targets, UInt8)
    @test first(scorecolumn!(scores, targets[1], targets)) == 242
    @test_throws DimensionMismatch scorecolumn!(zeros(UInt8,4), targets[1], targets)
    @test scorecolumn!(scores, targets[3], targets)[3] == 242
    targets = NTuple{5,Char}.(["12953", "34513", "51133", "51383"])
    scores = scorecolumn!(similar(targets, UInt8), targets[4], targets)
    @test first(scores) == 0x6e
    @test last(scores) == 0xf2
    scorecolumn!(scores, targets[2], targets)
    @test last(scores) == 0x5f
end

@testset "scoretype" begin
    @test Wordlegames.scoretype(5) == UInt8
    @test_throws ArgumentError Wordlegames.scoretype(0)
    @test Wordlegames.scoretype(6) == UInt16
    @test Wordlegames.scoretype(11) == UInt32
    @test Wordlegames.scoretype(21) == UInt64
    @test Wordlegames.scoretype(80) == UInt128
    @test_throws ArgumentError Wordlegames.scoretype(81)
end

@testset "scoreupdate!" begin
    @test last(scoreupdate!(reset!(primel), [1, 0, 0, 1, 1]).guesses).poolsz == 120
    @test_throws ArgumentError scoreupdate!(primel, [3, 0, 0, 3, 3])
end

@testset "tree" begin
    io = IOBuffer()
    primetree = tree(primel)
    print_tree(io, primetree; maxdepth=8)
    @test length(take!(io)) > 500_000
    rootscore = primetree.score
    @test isa(rootscore, GuessScore)
    @test rootscore.guess == "12953"
    @test ismissing(rootscore.score)
    @test ismissing(rootscore.sc)
    randtree = tree(primel, Random.seed!(1234321), 15)
    @test randtree.score.guess == rootscore.guess
    tree55541 = tree(primel, ["55541"])
    leafnode = only(collect(Leaves(tree55541)))
    @test isempty(leafnode.children)
    @test leafnode.score.guess == "55541"
end