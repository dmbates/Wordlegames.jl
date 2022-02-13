using Wordlegames
using Test

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
end
