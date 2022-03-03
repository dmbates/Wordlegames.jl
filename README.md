# Wordlegames - play and analyze Wordle and related games

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://dmbates.github.io/Wordlegames.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://dmbates.github.io/Wordlegames.jl/dev)
[![Build Status](https://github.com/dmbates/Wordlegames.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/dmbates/Wordlegames.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/dmbates/Wordlegames.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/dmbates/Wordlegames.jl)
[![Code Style: Blue](https://img.shields.io/badge/code%20style-blue-4495d1.svg)](https://github.com/invenia/BlueStyle)
[![PkgEval](https://JuliaCI.github.io/NanosoldierReports/pkgeval_badges/E/Wordlegames.svg)](https://JuliaCI.github.io/NanosoldierReports/pkgeval_badges/report.html)

This [Julia](https://julialang.org) package allows for playing and analyzing [Wordle](https://en.wikipedia.org/wiki/Wordle) and related games, such as [Primel](https://cojofra.github.io/primel/).

A game is represented by a `GamePool` object containing potential guesses, a subset of which are valid targets, and some game play status information.
By default the game is played as in the "Hard Mode" setting on the Wordle app and web site, which means that the only guesses allowed at each turn are those in the current target pool.
As a consequence, the initial pool of potential guesses is the same as the initial target pool.

```jl
julia> using Chain, DataFrames, Primes, Random, StatsBase, UnicodePlots, Wordlegames

julia> datadir = joinpath(dirname(dirname(pathof(Wordlegames))), "data");

julia> wordle = GamePool(collect(readlines(joinpath(datadir, "Wordletargets.txt"))));
```

This creates a `GamePool` from the Wordle targets, a list of 2315 5-letter English words.
The `playgame!` and `showgame!` methods can play a Wordle game, selecting each guess according to a criterion.
By default the guess is chosen to maximize the [entropy](https://en.wikipedia.org/wiki/Entropy_(information_theory)) of the distribution of scores from the current target pool, as explained below.

For example, suppose the target is `"super"`.
It takes 6 guesses to isolate this target using this strategy.

```jl
julia> showgame!(wordle, "super")
4×7 DataFrame
 Row │ poolsz  index  guess   expected  entropy  score       sc    
     │ Int64   Int64  String  Float64   Float64  String      Int64 
─────┼─────────────────────────────────────────────────────────────
   1 │   2315   1535  raise   61.0009   5.87791  🟨🟫🟫🟨🟨     85
   2 │     18   1720  sheer    2.11111  3.28104  🟩🟫🟫🟩🟩    170
   3 │      4   1835  sober    1.5      1.5      🟩🟫🟫🟩🟩    170
   4 │      2   1969  super    1.0      1.0      🟩🟩🟩🟩🟩    242
```

The size of the initial target pool is 2315.
The first guess, `"raise"`, will reduce the size of target pool after it has been scored.
It is not known what the score will be but the set of scores from all possible targets can be calculated.
Assuming the possible targets are equally likely, this gives a distribution of scores, and also a distribution of pool sizes after the guess is scored.
Informally, the entropy of the distribution of scores is a measure of how uniformly they are distributed over the set of the possible scores.
Choosing the guess with the greatest entropy will likely result in a large reduction in the size of the target pool after the guess is scored.

The expected size of the target pool, after this guess is scored, is a little over 61.
The actual score in this game, represented as `🟨🟫🟫🟨🟨` in colored tiles or `[1,0,0,1,1]` as digits, indicates that  `r`, `s` and `e` are in the target but not in the guessed positions and `a` and `i` do not occur in the target.  (The `sc` value in that row, 85, is the decimal value of `10011` in base-3.)

(This package uses the Unicode character `U+F7EB`, the `:large_brown_square:` emoji, `🟫`, instead of a gray square for the "didn't match" tile - a kind of "traffic lights" motif.
But the real reason for this choice is that it is surprisingly difficult to get a consistent-width black or gray square symbol in many fonts.)

There are only 18 of the 2315 possible targets that would have given this score.
Of these 18 targets the guess that will do the best job of spreading out the distribution of scores is `"sheer"`.
The actual score for this guess is `🟩🟫🟫🟩🟩`, meaning that the `s`, the second `e` and the `r` are in the correct positions, the `h` is not in the target and there isn't a second `e`.

(When a character is repeated in a guess, "correct position" takes precedence over "in the target" if there is only one instance of the character in the target.
If none of the guesses are in the correct position then the first one takes precedence.)

The size of the target pool is reduced to 4, which is larger than the expected size of 2.33, and the game continues with other guesses and other scores until the target, `"super"` is matched.

If no target is specified in a call to `showgame!` or `playgame!` one is chosen at random from the set of possible targets.

```jl
julia> Random.seed!(1234321);  # initialize the random number generator

julia> showgame!(wordle)
4×7 DataFrame
 Row │ poolsz  index  guess   expected  entropy   score       sc    
     │ Int64   Int64  String  Float64   Float64   String      Int64 
─────┼──────────────────────────────────────────────────────────────
   1 │   2315   1535  raise   61.0009    5.87791  🟫🟫🟫🟫🟫      0
   2 │    168   1275  mulch    6.85714   5.21165  🟫🟫🟫🟫🟨      1
   3 │      6   2262  whoop    1.0       2.58496  🟫🟨🟫🟫🟫     27
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

This mechanism allows for playing all of the 2315 possible games and accumulating some statistics.

```jl
julia> nguesswordle = [length(playgame!(wordle, k).guesses) for k in axes(wordle.guesspool, 1)];

julia> barplot(countmap(nguesswordle))
     ┌                                        ┐ 
   1 ┤ 1                                        
   2 ┤■■■■■ 131                                 
   3 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 999   
   4 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 919      
   5 ┤■■■■■■■ 207                               
   6 ┤■■ 47                                     
   7 ┤ 9                                        
   8 ┤ 2                                        
     └                                        ┘ 
```

Playing all possible Wordle games in this way takes less than half a second on a not-very-powerful laptop.

```jl
julia> versioninfo()
Julia Version 1.8.0-beta1
Commit 7b711ce699 (2022-02-23 15:09 UTC)
Platform Info:
  OS: Linux (x86_64-pc-linux-gnu)
  CPU: 8 × 11th Gen Intel(R) Core(TM) i5-1135G7 @ 2.40GHz
  WORD_SIZE: 64
  LIBM: libopenlibm
  LLVM: libLLVM-13.0.1 (ORCJIT, tigerlake)
  Threads: 4 on 8 virtual cores
```

The mean and standard deviation of the number of guesses for Wordle using this strategy

```jl
julia> (n̄ = mean(nguesswordle), s = std(nguesswordle))
(n̄ = 3.5991360691144707, s = 0.8490164812102081)
```

are reasonable but not optimal.
Grant Sanderson has a [YouTube video](https://twitter.com/3blue1brown/status/1490351572215283712) describing a strategy the gives a mean of 3.43 guesses.
Later, in a tweet, he referred to a strategy with a mean of 3.42 guesses.

Also, the barplot shows that there are 11 of the 2315 games that are not solved in 6 guesses by this strategy.

The games that require 8 guesses are

```jl
julia> [showgame!(wordle, k) for k in findall(==(8), nguesswordle)]
2-element Vector{DataFrame}:
 8×7 DataFrame
 Row │ poolsz  index  guess   expected  entropy    score       sc    
     │ Int64   Int64  String  Float64   Float64    String      Int64 
─────┼───────────────────────────────────────────────────────────────
   1 │   2315   1535  raise   61.0009    5.87791   🟨🟫🟫🟫🟨     82
   2 │    102    546  deter    9.23529   4.37007   🟫🟫🟫🟩🟩      8
   3 │     26    454  cower    5.23077   2.74682   🟫🟩🟫🟩🟩     62
   4 │      9    999  hover    3.44444   1.65774   🟫🟩🟫🟩🟩     62
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
   5 │      4    959  hatch    2.5       0.811278  🟫🟩🟩🟩🟩     80
   6 │      3   1102  latch    1.66667   0.918296  🟫🟩🟩🟩🟩     80
   7 │      2   1206  match    1.0       1.0       🟫🟩🟩🟩🟩     80
   8 │      1   2233  watch    1.0      -0.0       🟩🟩🟩🟩🟩    242
```

## Related games

Wordle has spawned a huge number of [related games](https://rwmpelstilzchen.gitlab.io/wordles/).

One such game is [Primel](https://converged.yt/primel/) where the targets are 5-digit prime numbers.
The Primel game from 2022-02-15 can be played by entering the scores after each guess is copied onto the game-play page.
The `summary` property of a `GamePool` shows the guesses and scores to this point, and the next guess to use.

```jl
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

Playing all possible Primel games produces statistics of

```jl
julia> nguessprimel = [length(playgame!(primel, k).guesses) for k in axes(primel.active, 1)];

julia> barplot(countmap(nguessprimel))
     ┌                                        ┐ 
   1 ┤ 1                                        
   2 ┤■■ 215                                    
   3 ┤■■■■■■■■■■■■■■■■■■■■■■■■ 3173             
   4 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 4477   
   5 ┤■■■■ 482                                  
   6 ┤ 15                                       
     └                                        ┘ 

julia> (n̄ = mean(nguessprimel), s = std(nguessprimel))
(n̄ = 3.6300370680377854, s = 0.6413308603862167)
```

Because there are more targets initially in Primel than in Wordle, the mean number of guesses is greater.
However, the standard deviation of the length of Primel games played this way is smaller than that for Wordle, perhaps because the number of possible characters at each position (10) is smaller than for Wordle (26).

## Strategy

Each turn in a Wordle-like game can be regarded as submitting a guess to an "oracle" which returns a score that is used to update the information on the play.
Initially the target can be any element of the target pool.
Each guess/score combination reduces the size of the target pool, as shown in the game summaries above.

In a `GamePool` object the actual pool of potential targets and guesses is not modified.
Instead there is a `BitVector` field, `active`, that is used to keep track of the active target pool.
The size of the current target pool is the sum of `active`.

The score for a particular guess is known to the oracle but not to the player.
However, the scores for any potential guess and a member of the target pool can be evaluated.
The number of possible scores is finite (`3^N` where `N` is the number of tiles in the score).

For example the first guess chosen in the Wordle games shown about is `"raise"`, which is at position 1535 in `wordle.targetpool`. 

```jl
julia> reset!(wordle);  # reset the `GamePool` to its initial state

julia> only(wordle.guesses).index  # check there is exactly one guess and return its indexl
1535

julia> bincounts!(wordle, 1535);   # evaluate the bin counts for that guess

julia> @chain DataFrame(score = tiles.(0:242, 5), counts = wordle.counts) begin
           subset(:counts => x -> x .> 0)
           sort(:counts; rev=true)
       end
132×2 DataFrame
 Row │ score       counts 
     │ String      Int64  
─────┼────────────────────
   1 │ 🟫🟫🟫🟫🟫     168
   2 │ 🟫🟫🟫🟫🟨     121
   3 │ 🟫🟫🟨🟫🟫     107
   4 │ 🟨🟫🟫🟫🟫     103
   5 │ 🟨🟫🟫🟫🟨     102
   6 │ 🟫🟨🟫🟫🟫      92
   7 │ 🟫🟩🟫🟫🟫      91
   8 │ 🟫🟫🟫🟨🟫      80
   9 │ 🟨🟨🟫🟫🟫      78
  10 │ 🟫🟨🟫🟫🟨      69
  11 │ 🟫🟫🟫🟫🟩      61
  12 │ 🟫🟫🟩🟫🟫      51
  13 │ 🟫🟨🟫🟨🟫      43
  14 │ 🟫🟫🟫🟨🟨      41
  15 │ 🟫🟨🟫🟫🟩      41
  ⋮  │     ⋮         ⋮
 118 │ 🟨🟨🟩🟫🟩       1
 119 │ 🟨🟨🟩🟩🟩       1
 120 │ 🟨🟩🟫🟩🟩       1
 121 │ 🟩🟫🟫🟨🟫       1
 122 │ 🟩🟫🟫🟩🟫       1
 123 │ 🟩🟫🟨🟨🟫       1
 124 │ 🟩🟫🟨🟩🟩       1
 125 │ 🟩🟫🟩🟫🟫       1
 126 │ 🟩🟫🟩🟫🟨       1
 127 │ 🟩🟨🟫🟩🟫       1
 128 │ 🟩🟨🟨🟫🟫       1
 129 │ 🟩🟩🟫🟫🟩       1
 130 │ 🟩🟩🟫🟨🟫       1
 131 │ 🟩🟩🟩🟫🟫       1
 132 │ 🟩🟩🟩🟩🟩       1
          102 rows omitted

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
The best case is for each of the `n` possible scores to have probability `1/n` of occurring.
In that case, whichever score is returned, there will only be a small number of targets with that score.
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
   3 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 957   
   4 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 946   
   5 ┤■■■■■■■■ 224                              
   6 ┤■■ 42                                     
   7 ┤ 11                                       
   8 ┤ 3                                        
     └                                        ┘ 

julia> (n̄ = mean(ngwrdle2), s = std(ngwrdle2))
(n̄ = 3.624622030237581, s = 0.8578269827640186)
```

## Game play as a tree

For a deterministic strategy and a fixed `guesspool` and set of `validtargets` the possible games can be represented as a [tree](https://en.wikipedia.org/wiki/Tree_(data_structure)).

For illustration, consider just a portion of the tree of Wordle games using the MaximumEntropy strategy.
Games with targets `["super", "hobby", "mince", "goner", "watch"]` are shown above.
They can be combined into a tree as

```jl
julia> print_tree(tree(wordle, ["super", "hobby", "mince", "goner", "watch"]), maxdepth=8)
missing, raise, 1535, 2315, 5.87791, 61.0009
├─ 🟫🟫🟨🟫🟩, binge, 198, 25, 3.28386, 3.64
│  └─ 🟫🟩🟩🟫🟩, mince, 1234, 2, 1.0, 1.0
├─ 🟨🟫🟫🟫🟨, deter, 546, 102, 4.37007, 9.23529
│  └─ 🟫🟫🟫🟩🟩, cower, 454, 26, 2.74682, 5.23077
│     └─ 🟫🟩🟫🟩🟩, hover, 999, 9, 1.65774, 3.44444
│        └─ 🟫🟩🟫🟩🟩, joker, 1059, 5, 1.37095, 2.2
│           └─ 🟫🟩🟫🟩🟩, boxer, 258, 3, 0.918296, 1.66667
│              └─ 🟫🟩🟫🟩🟩, foyer, 800, 2, 1.0, 1.0
│                 └─ 🟫🟩🟫🟩🟩, goner, 884, 1, -0.0, 1.0
├─ 🟫🟫🟫🟫🟫, mulch, 1275, 168, 5.21165, 6.85714
│  └─ 🟫🟫🟫🟫🟨, whoop, 2262, 6, 2.58496, 1.0
│     └─ 🟫🟨🟨🟫🟫, hobby, 985, 1, -0.0, 1.0
├─ 🟨🟫🟫🟨🟨, sheer, 1720, 18, 3.28104, 2.11111
│  └─ 🟩🟫🟫🟩🟩, sober, 1835, 4, 1.5, 1.5
│     └─ 🟩🟫🟫🟩🟩, super, 1969, 2, 1.0, 1.0
└─ 🟫🟩🟫🟫🟫, tangy, 2012, 91, 4.03061, 7.48352
   └─ 🟨🟩🟫🟫🟫, caput, 334, 13, 2.4997, 2.84615
      └─ 🟨🟩🟫🟫🟨, batch, 160, 5, 0.721928, 3.4
         └─ 🟫🟩🟩🟩🟩, hatch, 959, 4, 0.811278, 2.5
            └─ 🟫🟩🟩🟩🟩, latch, 1102, 3, 0.918296, 1.66667
               └─ 🟫🟩🟩🟩🟩, match, 1206, 2, 1.0, 1.0
                  └─ 🟫🟩🟩🟩🟩, watch, 2233, 1, -0.0, 1.0
```

Although this is not a particularly interesting tree, it serves to illustrate some of the properties.
The first node, called the "root" node, is the first guess in all the games.
The guess is "raise" at index 1535 with pool size 2315, an entropy of 5.88 and an expected pool size of 61.00 after scoring.

If the score for "raise" is `🟫🟫🟨🟫🟩`, the next guess will be "binge", with the characteristics shown.
If the score is `🟫🟫🟫🟫🟫`, which is the most likely score for the first guess, the next guess is "mulch", and so on.

Note that in the tree the score is associated with the guess that it will produce next, whereas in the summary of the game the score is associated with the guess that produced it.

The reason that this tree is not very interesting is that it simply reproduces the game summaries, with the minor changes that the root node is common to all the games and the score tiles refer to the score that has been observed, not the score that will be observed.

It is more interesting to play a random selection of games

```jl
julia> print_tree(tree(wordle, Random.seed!(1234321), 12))
missing, raise, 1535, 2315, 5.87791, 61.0009
├─ 🟫🟫🟫🟫🟨, betel, 189, 121, 5.06266, 4.95041
│  └─ 🟫🟩🟫🟫🟨, cello, 349, 9, 2.9477, 1.22222
│     └─ 🟫🟩🟩🟫🟨, felon, 714, 2, 1.0, 1.0
│        └─ 🟫🟩🟩🟩🟩, melon, 1220, 1, -0.0, 1.0
├─ 🟨🟩🟩🟫🟫, dairy, 515, 4, 1.5, 1.5
│  └─ 🟫🟩🟩🟩🟩, fairy, 699, 2, 1.0, 1.0
│     └─ 🟫🟩🟩🟩🟩, hairy, 948, 1, -0.0, 1.0
├─ 🟨🟫🟫🟫🟨, deter, 546, 102, 4.37007, 9.23529
│  └─ 🟩🟩🟫🟫🟩, decor, 530, 2, 1.0, 1.0
│     └─ 🟩🟩🟫🟫🟩, demur, 540, 1, -0.0, 1.0
├─ 🟫🟫🟫🟫🟫, mulch, 1275, 168, 5.21165, 6.85714
│  ├─ 🟫🟩🟩🟫🟫, bully, 302, 6, 1.79248, 2.0
│  │  └─ 🟫🟩🟩🟫🟩, pulpy, 1492, 1, -0.0, 1.0
│  ├─ 🟫🟨🟨🟨🟫, cloud, 419, 4, 2.0, 1.0
│  │  └─ 🟩🟩🟩🟩🟫, clout, 420, 1, -0.0, 1.0
│  └─ 🟫🟫🟫🟫🟨, whoop, 2262, 6, 2.58496, 1.0
│     └─ 🟫🟨🟨🟫🟫, hobby, 985, 1, -0.0, 1.0
├─ 🟨🟩🟫🟫🟫, party, 1377, 26, 3.12276, 3.84615
│  └─ 🟫🟩🟩🟫🟩, carry, 338, 4, 1.5, 1.5
│     └─ 🟫🟩🟩🟩🟩, harry, 955, 2, 1.0, 1.0
├─ 🟫🟫🟨🟫🟫, pilot, 1413, 107, 4.69342, 6.38318
│  ├─ 🟫🟨🟫🟨🟫, comic, 435, 4, 2.0, 1.0
│  │  └─ 🟩🟩🟫🟩🟩, conic, 439, 1, -0.0, 1.0
│  ├─ 🟫🟩🟫🟫🟨, width, 2267, 13, 2.93121, 2.07692
│  │  └─ 🟫🟩🟫🟩🟫, bitty, 204, 4, 1.5, 1.5
│  │     └─ 🟫🟩🟫🟩🟩, fifty, 733, 2, 1.0, 1.0
│  └─ 🟫🟩🟫🟫🟫, windy, 2274, 16, 3.20282, 1.875
│     └─ 🟫🟩🟫🟫🟩, fizzy, 746, 2, 1.0, 1.0
│        └─ 🟨🟩🟫🟫🟩, jiffy, 1056, 1, -0.0, 1.0
├─ 🟨🟩🟫🟨🟫, satyr, 1648, 2, 1.0, 1.0
└─ 🟨🟫🟫🟨🟫, short, 1739, 24, 3.60539, 2.25
   └─ 🟨🟫🟨🟨🟨, torus, 2085, 1, -0.0, 1.0
```

Again, the root is "raise", which is the first guess in any game using the `MaximumEntropy` strategy, and if the first score is `🟫🟫🟫🟫🟫` then the second guess will be "mulch".
But now in this selection of games the guess after "mulch" was "bully", "cloud" or "whoop" in different games.

In other words some of the games from the 12 randomly selected targets overlapped in both the first and second guesses.
Also, one of the games, for the target "satyr", got the target on the second guess.

A tree representation of all possible games can be written to a file as

```jl
julia> open("wordle_tree.txt", "w") do io
           print_tree(io, tree(wordle); maxdepth=9)
       end
```

but it may be more interesting to use some of the tools in [AbstractTrees.jl](https://github.com/JuliaCollections/AbstractTrees.jl) to explore the tree itself.
