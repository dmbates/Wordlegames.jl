# Wordlegames - play and analyze Wordle and related games

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://dmbates.github.io/Wordlegames.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://dmbates.github.io/Wordlegames.jl/dev)
[![Build Status](https://github.com/dmbates/Wordlegames.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/dmbates/Wordlegames.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/dmbates/Wordlegames.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/dmbates/Wordlegames.jl)
[![Code Style: Blue](https://img.shields.io/badge/code%20style-blue-4495d1.svg)](https://github.com/invenia/BlueStyle)
[![PkgEval](https://JuliaCI.github.io/NanosoldierReports/pkgeval_badges/E/Wordlegames.svg)](https://JuliaCI.github.io/NanosoldierReports/pkgeval_badges/report.html)

This [Julia](https://julialang.org) package allows for playing and analyzing [Wordle](https://en.wikipedia.org/wiki/Wordle) and related games, such as [Primel](https://cojofra.github.io/primel/).

A game is represented by a `GamePool` of targets, potential guesses, and some game play status information.
By default the game is played as in the "Hard Mode" setting on the Wordle app and web site, which means that the only guesses allowed at each turn are those in the current target pool.
As a consequence, the initial pool of potential guesses is the same as the initial target pool.

```jl
julia> using Wordlegames

julia> wordle = GamePool(collect(readlines("./data/Wordletargets.txt")));
```

This creates a `GamePool` from the Wordle targets, a list of 2315 5-letter English words.
The `playgame!` and `showgame!` methods can play a Wordle game, selecting each guess according to a criterion.
By default the guess is chosen to maximize the [entropy](https://en.wikipedia.org/wiki/Entropy_(information_theory)) of the distribution of scores from the current target pool, as explained below.

For example, suppose the target is `"super"`.
It takes 6 guesses to isolate this target using this strategy.

```jl
julia> showgame!(wordle, "super")
6×7 DataFrame
 Row │ poolsz  index  guess   expected  entropy    score       sc    
     │ Int64   Int64  String  Float64   Float64    String      Int64 
─────┼───────────────────────────────────────────────────────────────
   1 │   2315   1535  raise   61.0009    5.87791   🟨🟫🟫🟨🟨     85
   2 │     18   1744  shrew    2.66667   3.03856   🟩🟫🟨🟩🟫    177
   3 │      5   1823  sneer    2.2       1.37095   🟩🟫🟨🟩🟩    179
   4 │      3   1697  sever    1.66667   0.918296  🟩🟨🟫🟩🟩    197
   5 │      2   1835  sober    1.0       1.0       🟩🟫🟫🟩🟩    170
   6 │      1   1969  super    1.0      -0.0       🟩🟩🟩🟩🟩    242
```

The size of the initial target pool is 2315.
The first guess, `"raise"`, will reduce the size of target pool after it has been scored.
It is not known what the score will be but the set of scores from each target can be calculated.
Informally, the entropy of the distribution of scores is a measure of how uniformly they are distributed over set of the possible scores.
Choosing the guess with the greatest entropy will likely result in a large reduction in the size of the target pool after the guess is scored.

The expected size of the target pool, after this guess is scored, is a little over 61.
The actual score in this game, represented as 🟨🟫🟫🟨🟨 in colored tiles or `[1,0,0,1,1]` as digits, indicates that  `r`, `s` and `e` are in the target but not in the guessed positions and `a` and `i` do not occur in the target.

(This package uses the Unicode character `U+F7EB`, the `:large_brown_square:` emoji, 🟫, instead of a gray square for the "didn't match" tile - a kind of "traffic lights" motif.
Also, it is surprisingly difficult to get a consistent-width black or gray square symbol in many fonts.)

There are only 18 of the 2315 possible targets that would have given this score.
Of these 18 targets the guess that will do the best job of spreading out the distribution of scores is `"shrew"`.
The actual score for this guess is 🟩🟫🟨🟩🟫, meaning that the `s` and `e` are in the correct positions, the `r` is in the target but not in the third position, and neither `h` nor `w` are in the target.

The size of the target pool is reduced to 5, which is larger than the expected size of 2.67 and the game continues with other guesses and other scores until the target, `"super"` is matched.

The target can be chosen at random

```jl
julia> Random.seed!(1234321);  # initialize the random number generator

julia> showgame!(wordle)
4×7 DataFrame
 Row │ poolsz  index  guess   expected  entropy   score       sc    
     │ Int64   Int64  String  Float64   Float64   String      Int64 
─────┼──────────────────────────────────────────────────────────────
   1 │   2315   1535  raise   61.0009    5.87791  🟫🟫🟫🟫🟫      0
   2 │    168   1275  mulch    6.85714   5.21165  🟫🟫🟫🟫🟨      1
   3 │      6   1000  howdy    1.33333   2.25163  🟩🟩🟫🟫🟩    218
   4 │      1    985  hobby    1.0      -0.0      🟩🟩🟩🟩🟩    242
```

The target can also be specified as an integer between `1` and `length(wordle.targetpool)`.

```jl
julia> showgame!(wordle, 1234)
3×7 DataFrame
 Row │ poolsz  index  guess   expected  entropy  score       sc    
     │ Int64   Int64  String  Float64   Float64  String      Int64 
─────┼─────────────────────────────────────────────────────────────
   1 │   2315   1535  raise    61.0009  5.87791  🟫🟫🟨🟫🟩     11
   2 │     25    198  binge     3.64    3.28386  🟫🟩🟩🟫🟩     74
   3 │      2   1234  mince     1.0     1.0      🟩🟩🟩🟩🟩    242
```

This mechanism allows for playing all possible games and accumulating some statistics.

```jl
julia> nguesswordle = [length(playgame!(wordle, k).guesses) for k in axes(wordle.guesspool, 1)];

julia> using StatsBase, UnicodePlots

julia> barplot(countmap(nguesswordle))
     ┌                                        ┐ 
   1 ┤ 1                                        
   2 ┤■■■■■ 131                                 
   3 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 978   
   4 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 928     
   5 ┤■■■■■■■■ 217                              
   6 ┤■■ 49                                     
   7 ┤ 9                                        
   8 ┤ 2                                        
     └                                        ┘ 
```

Playing all possible Wordle games in this way takes less than half a second on a not-very-powerful laptop.

```jl
julia> versioninfo()
Julia Version 1.8.0-DEV.1526
Commit 635449dabe (2022-02-13 12:15 UTC)
Platform Info:
  OS: Linux (x86_64-linux-gnu)
  CPU: 8 × 11th Gen Intel(R) Core(TM) i5-1135G7 @ 2.40GHz
  WORD_SIZE: 64
  LIBM: libopenlibm
  LLVM: libLLVM-13.0.1 (ORCJIT, tigerlake)
  Threads: 4 on 8 virtual cores
```

The mean and standard deviation of the number of guesses for Wordle using this strategy

```jl
julia> (n̄ = mean(nguesswordle), s = std(nguesswordle)) 
(n̄ = 3.614254859611231, s = 0.8552369532287724)
```

are reasonable but not optimal.
Grant Sanderson has a [YouTube video](https://twitter.com/3blue1brown/status/1490351572215283712) describing a strategy the gives a mean of 3.43 guesses.
Later, in a tweet, he referred to a strategy with a mean of 3.42 guesses.

Also, the barplot shows that there are 11 of the 2315 games that are not solved in 6 guesses by this strategy.

The games that require 8 guesses are

```jl
julia> [showgame!(wordle, k) for k in findall(==(8), nguesswordle)]
2-element Vector{DataFrames.DataFrame}:
 8×7 DataFrame
 Row │ poolsz  index  guess   expected  entropy    score       sc    
     │ Int64   Int64  String  Float64   Float64    String      Int64 
─────┼───────────────────────────────────────────────────────────────
   1 │   2315   1535  raise   61.0009    5.87791   🟨🟫🟫🟫🟨     82
   2 │    102   1352  outer    8.68627   4.09399   🟨🟫🟫🟩🟩     89
   3 │     16   1271  mower    5.875     1.91974   🟫🟩🟫🟩🟩     62
   4 │      9    451  cover    3.44444   1.65774   🟫🟩🟫🟩🟩     62
   5 │      5   1059  joker    2.2       1.37095   🟫🟩🟫🟩🟩     62
   6 │      3    258  boxer    1.66667   0.918296  🟫🟩🟫🟩🟩     62
   7 │      2    800  foyer    1.0       1.0       🟫🟩🟫🟩🟩     62
   8 │      1    884  goner    1.0      -0.0       🟩🟩🟩🟩🟩    242
 8×7 DataFrame
 Row │ poolsz  index  guess   expected  entropy    score       sc    
     │ Int64   Int64  String  Float64   Float64    String      Int64 
─────┼───────────────────────────────────────────────────────────────
   1 │   2315   1535  raise   61.0009    5.87791   🟫🟩🟫🟫🟫     54
   2 │     91   2012  tangy    7.48352   4.03061   🟨🟩🟫🟫🟫    135
   3 │     13    334  caput    2.84615   2.4997    🟨🟩🟫🟫🟨    136
   4 │      5    160  batch    3.4       0.721928  🟫🟩🟩🟩🟩     80
   5 │      4    959  hatch    2.5       0.811278  🟨🟩🟩🟩🟩    161
   6 │      3   1102  latch    1.66667   0.918296  🟫🟩🟩🟩🟩     80
   7 │      2   1206  match    1.0       1.0       🟫🟩🟩🟩🟩     80
   8 │      1   2233  watch    1.0      -0.0       🟩🟩🟩🟩🟩    242
```

## Related games

Wordle has spawned a huge number of [related games](https://rwmpelstilzchen.gitlab.io/wordles/).

One such game is [Primel](https://converged.yt/primel/) where the targets are 5-digit prime numbers.
The Primel game from 2022-02-15 can be played by entering the scores after each guess is copied onto the game-play page.
The `summary` property of a `GamePool` shows the guesses and scores to this point and the next guess to use.

```jl
julia> using Primes

julia> primel = GamePool(primes(10000, 99999));

julia> primel.summary
1×7 DataFrame
 Row │ poolsz  index  guess   expected  entropy  score    sc      
     │ Int64   Int64  String  Float64   Float64  String?  Int64?  
─────┼────────────────────────────────────────────────────────────
   1 │   8363    313  12953    124.384  6.63227  missing  missing 

julia> scoreupdate!(primel, [1,0,0,0,1]).summary
2×7 DataFrame
 Row │ poolsz  index  guess   expected   entropy  score       sc      
     │ Int64   Int64  String  Float64    Float64  String?     Int64?  
─────┼────────────────────────────────────────────────────────────────
   1 │   8363    313  12953   124.384    6.63227  🟨🟫🟫🟫🟨       82
   2 │    236   2612  36187     6.30508  5.57465  missing     missing 

julia> scoreupdate!(primel, [2,2,1,0,0]).summary
3×7 DataFrame
 Row │ poolsz  index  guess   expected   entropy  score       sc      
     │ Int64   Int64  String  Float64    Float64  String?     Int64?  
─────┼────────────────────────────────────────────────────────────────
   1 │   8363    313  12953   124.384    6.63227  🟨🟫🟫🟫🟨       82
   2 │    236   2612  36187     6.30508  5.57465  🟩🟩🟨🟫🟫      225
   3 │      3   2597  36011     1.0      1.58496  missing     missing 

julia> scoreupdate!(primel, [2,2,2,2,2]).summary
3×7 DataFrame
 Row │ poolsz  index  guess   expected   entropy  score       sc    
     │ Int64   Int64  String  Float64    Float64  String      Int64 
─────┼──────────────────────────────────────────────────────────────
   1 │   8363    313  12953   124.384    6.63227  🟨🟫🟫🟫🟨     82
   2 │    236   2612  36187     6.30508  5.57465  🟩🟩🟨🟫🟫    225
   3 │      3   2597  36011     1.0      1.58496  🟩🟩🟩🟩🟩    242
```

Because there are more targets initially in Primel than in Wordle, the mean number of guesses is greater but the standard deviation is smaller, perhaps because the number of possible characters at each position (10) is smaller than for Wordle (26).

```jl
julia> nguessprimel = [length(playgame!(primel, k).guesses) for k in axes(primel.active, 1)];

julia> barplot(countmap(nguessprimel))
     ┌                                        ┐ 
   1 ┤ 1                                        
   2 ┤■■ 215                                    
   3 ┤■■■■■■■■■■■■■■■■■■■■■■■■ 3070             
   4 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 4363   
   5 ┤■■■■■ 684                                 
   6 ┤ 30                                       
     └                                        ┘ 

julia> (n̄ = mean(nguessprimel), s = std(nguessprimel))
(n̄ = 3.6700944637091952, s = 0.6770215085958287)
```

## Strategy

Each turn in a Wordle-like game can be regarded as submitting a guess to an "oracle" which returns a score that is used to update the information on the play.
Initially the target can be any element of the target pool.
Each guess/score combination reduces the size of the target pool, as shown in the game summaries above.
(In a `GamePool` object the `targetpool` field remains constant and the `active` field, a `BitVector` of the same length as the `targetpool`, is used to keep track of which targets are in the current target pool.)

The size of the current target pool is the sum of `active`.

The score for a particular guess is known to the oracle but not to the player.
However, the scores for any potential guess and a member of the target pool can be evaluated.
The number of possible scores is finite (`3^N` where `N` is the number of tiles in the score).

For example the first guess chosen in the Wordle games shown about is `"raise"`, which is at position 1535 in `wordle.targetpool`. 

```jl
julia> reset!(wordle);  # reset the `GamePool` to its initial state

julia> only(wordle.guesses).index  # check that there is exactly one guess and return its index
1535

julia> bincounts!(wordle, 1535);   # evaluate the bin counts for that guess

julia> DataFrame(score = tiles.(0:242, 5), counts = wordle.counts)
243×2 DataFrame
 Row │ score       counts 
     │ String      Int64  
─────┼────────────────────
   1 │ 🟫🟫🟫🟫🟫     168
   2 │ 🟫🟫🟫🟫🟨     121
   3 │ 🟫🟫🟫🟫🟩      61
   4 │ 🟫🟫🟫🟨🟫      80
   5 │ 🟫🟫🟫🟨🟨      41
   6 │ 🟫🟫🟫🟨🟩      17
   7 │ 🟫🟫🟫🟩🟫      17
   8 │ 🟫🟫🟫🟩🟨       9
   9 │ 🟫🟫🟫🟩🟩      20
  10 │ 🟫🟫🟨🟫🟫     107
  11 │ 🟫🟫🟨🟫🟨      35
  12 │ 🟫🟫🟨🟫🟩      25
  13 │ 🟫🟫🟨🟨🟫      21
  14 │ 🟫🟫🟨🟨🟨       4
  15 │ 🟫🟫🟨🟨🟩       5
  ⋮  │     ⋮         ⋮
 229 │ 🟩🟩🟨🟨🟫       0
 230 │ 🟩🟩🟨🟨🟨       0
 231 │ 🟩🟩🟨🟨🟩       0
 232 │ 🟩🟩🟨🟩🟫       0
 233 │ 🟩🟩🟨🟩🟨       0
 234 │ 🟩🟩🟨🟩🟩       0
 235 │ 🟩🟩🟩🟫🟫       1
 236 │ 🟩🟩🟩🟫🟨       0
 237 │ 🟩🟩🟩🟫🟩       0
 238 │ 🟩🟩🟩🟨🟫       0
 239 │ 🟩🟩🟩🟨🟨       0
 240 │ 🟩🟩🟩🟨🟩       0
 241 │ 🟩🟩🟩🟩🟫       0
 242 │ 🟩🟩🟩🟩🟨       0
 243 │ 🟩🟩🟩🟩🟩       1
          213 rows omitted

julia> (expectedpoolsize(wordle), entropy2(wordle))
(61.00086393088553, 5.877909690821478)
```

Assuming the targets are equally likely, which apparently is the case in the online games, the probability of each score is the count for that score divided by the size of the active target pool.
The expected pool size is the sum of the `counts` multiplied by the probabilities or, equivalently, the sum of the squared counts divided by the sum of the counts.

```jl
julia> sum(abs2, wordle.counts) / sum(wordle.counts)  # abs2(x) returns x * x
61.00086393088553
```

Measured in bits, the entropy of the probabilities is `- Σᵢ pᵢ log₂(pᵢ)`.
Entropy measures how the probability is dispersed among the possible scores.
The best case is for each of the `n` possible scores to have probability `1/n` of occurring.In that case, whichever score is returned, there will only be a small number of targets with that score.
It is not possible to get uniform pool sizes from a starting guess but, sometimes when the target pool is small, a particular guess may be able to split the remaining `k` targets into `k` distinct scores.

In particular, this always occurs when there are only two targets left.

The guesses can be chosen to minimize the expected pool size but this strategy is not as effective as is maximizing the entropy.

```jl
julia> wrdle2 = GamePool(collect(readlines("./data/Wordletargets.txt")); guesstype=MinimizeExpected);

julia> ngwrdle2 = [length(playgame!(wrdle2, k).guesses) for k in axes(wrdle2.active, 1)];

julia> barplot(countmap(ngwrdle2))
     ┌                                        ┐ 
   1 ┤ 1                                        
   2 ┤■■■■■ 131                                 
   3 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 944   
   4 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 949   
   5 ┤■■■■■■■■■ 233                             
   6 ┤■■ 43                                     
   7 ┤ 11                                       
   8 ┤ 3                                        
     └                                        ┘ 

julia> (n̄ = mean(ngwrdle2), s = std(ngwrdle2))
(n̄ = 3.634989200863931, s = 0.8622912420643568)
```
