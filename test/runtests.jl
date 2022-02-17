using Primes
using Tables
using Test
using Wordlegames

const primes5 = primes(10000, 99999) # vector of 5-digit prime numbers
const primel = GamePool(primes5)
const primelxpc = GamePool(primes5; guesstype=MinimizeExpected)

@testset "GamePool" begin
    @test typeof(primel) == GamePool{5, UInt8, MaximizeEntropy}
    @test isa(propertynames(primel), Tuple)
    @test length(primel.active) == 8363
    @test eltype(primel.allscores) == UInt8
    @test eltype(primel.guesspool) == NTuple{5, Char}
    @test length(first(primel.guesspool)) == 5
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
    @test entropy ≈ [6.632274058429609,  5.479367512099353, 3.121928094887362]
    @test sc == [108, 112, 242]
    (; poolsz, guess, index, expected, entropy, score, sc) = showgame!(primel, "43867")
    @test index == [313, 2060, 3337]
            # size mismatch
    @test_throws ArgumentError playgame!(primel, "4321")
            # errors in constructor arguments
    @test_throws ArgumentError GamePool(["foo", "bar"], trues(4))
    # gp = GamePool(["foo", "bar", "boz"], BitVector([true, true, false]))
    @test_broken isa(gp, GamePool{3, UInt8})
    @test_broken isa(gp.allscores, Matrix{UInt8})
    @test_broken size(gp.allscores) == (2,3)
    @test_throws ArgumentError GamePool(["foo", "bar", "foobar"])
    @test_throws ArgumentError GamePool(["foo", "bar"]; guesstype=Int)
    @test Tables.isrowtable(playgame!(primel).guesses)  # this also covers the playgame! method for testing
end 

@testset "score" begin
    raiseS = "raise"
    raiseN = NTuple{5,Char}(raiseS)
    superS = "super"
    superN = NTuple{5,Char}(superS)


    @test score(raiseS, raiseS) == 242
    @test score(raiseN, raiseN) == 242
    @test score(raiseS, superS) == 85
    @test score(raiseN, superS) == 85
    @test score(raiseS, superN) == 85
    @test score(raiseN, superN) == 85
    reset!(primel)
    @test score(primel, 1) == 0xa2
    @test score(primel, 3426) == 0x09
    @test_throws BoundsError score(primel, -1)
    @test_throws BoundsError score(primel, 8364)
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
    @test last(scoreupdate!(reset!(primel), [1,0,0,1,1]).guesses).poolsz == 120
    @test_throws ArgumentError scoreupdate!(primel, [3,0,0,3,3])
end