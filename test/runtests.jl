using Wordlegames
using Primes
using Tables
using Test

const primes5 = primes(10000, 99999) # vector of 5-digit prime numbers
const primel = GamePool(primes5)
const primelxpc = GamePool(primes5; guesstype=MinimizeExpected)

@testset "GamePool" begin
    @test typeof(primel) == GamePool{5, UInt8, MaximizeEntropy}
    @test length(primel.active) == 8363
    @test eltype(primel.allscores) == UInt8
    @test eltype(primel.targetpool) == eltype(primel.guesspool) == NTuple{5, Char}
    @test length(first(primel.targetpool)) == 5
    @test all(reset!(primel).active)
    @test only(primel.guesses) == ('1', '2', '9', '5', '3')
    @test only(primel.guessinds) == 313
    @test only(primel.expected) ≈ 124.3844314241301
    @test only(primel.entropy) ≈ 6.632274058429609
    @test primel.hardmode
    playgame!(primel, only(primel.guessinds))   # Got it in one!
    @test only(primel.scores) == 0xf2
    gs = gamesummary(primel)
    @test isa(gs, NamedTuple)
    @test Tables.schema(gs) == Tables.Schema(
        (:guess, :score, :poolsize, :expected, :entropy),
        (String, String, Int, Float64, Float64),
    )
    Random.seed!(1234321)
    playgame!(primel)
    @test primel.guessinds == [313, 1141, 3556]
    playgame!(primel, "43867")
    @test primel.guessinds == [313, 2060, 3337]
            # size mismatch
    @test_throws ArgumentError playgame!(primel, "4321")
            # errors in constructor arguments
    gp = GamePool(["foo", "bar"], ["foo", "bar", "baz"])
    @test isa(gp, GamePool{3, UInt8})
    @test isa(gp.allscores, Matrix{UInt8})
    @test size(gp.allscores) == (2,3)
    @test_throws ArgumentError GamePool(["foo", "bar", "foobar"])
    @test_throws ArgumentError GamePool(["foo", "bar"]; guesstype=Int)
    @test_throws ArgumentError GamePool(["foo", "bar"]; hardmode=false)
    @test_throws ArgumentError GamePool(["foo", "bar"], ["foo", "bar", "foobar"])
end 

@testset "showgame!" begin
    @test isnothing(showgame!(primel))   # called for its side-effects
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
    @test last(scoreupdate!(reset!(primel), [1,0,0,1,1]).poolsizes) == 120
    @test_throws ArgumentError scoreupdate!(primel, [3,0,0,3,3])
end