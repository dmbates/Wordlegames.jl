# Wordlegames - play and analyze Wordle and related games

This [Julia](https://julialang.org) package allows for playing and analyzing [Wordle](https://en.wikipedia.org/wiki/Wordle) and related games, such as [Primel](https://cojofra.github.io/primel/).

A game is represented by a `GamePool` of targets, potential guesses, and some game play status information.
By default the game is played as in the "Hard Mode" setting on the Wordle app and web site, which means that the only guesses allowed at each turn are those in the current target pool.
As a consequence, the initial pool of potential guesses is the same as the initial target pool.

Consider a game played on the [Primel site])https://cojofra.github.io/primel/) on 2022-02-11 resulting in the score

```
Primel 237 4/6*

⬜🟨⬜⬜🟨
⬜🟨🟨🟨🟩
🟨🟨🟨⬜🟩
🟩🟩🟩🟩🟩
```

The goal of the game is to guess a 5-digit prime number (i.e. between 10,000 and 99,999) where each guess is scored as a pattern of 5 tiles colored gray, yellow, or green.

Here the scores are entered as 0, 1, or 2 instead of gray, yellow, or green.

```jl
julia> using Primes, Wordlegames

julia> primel = GamePool(primes(10000, 99999));

julia> (string(last(primel.guesses)...), last(primel.poolsizes), last(primel.expected), last(primel.entropy))
("17923", 8363, 121.54167f0, 6.62459f0)

julia> scoreupdate!(primel, [0,1,0,0,1]);

julia> (string(last(primel.guesses)...), last(primel.poolsizes), last(primel.expected), last(primel.entropy))
("56437", 206, 9.495146f0, 4.76909f0)

julia> scoreupdate!(primel, [0,1,1,1,2]);

julia> (string(last(primel.guesses)...), last(primel.poolsizes), last(primel.expected), last(primel.entropy))
("34607", 10, 1.4f0, 2.921928f0)

julia> scoreupdate!(primel, [1,1,1,0,2]);

julia> (string(last(primel.guesses)...), last(primel.poolsizes), last(primel.expected), last(primel.entropy))
("43867", 2, 1.0f0, 1.0f0)

julia> scoreupdate!(primel, [2,2,2,2,2]);

julia> pretty_table(gamesummary(primel))
┌────────┬────────────┬──────────┬──────────┬─────────┐
│  guess │      score │ poolsize │ expected │ entropy │
│ String │     String │    Int64 │  Float32 │ Float32 │
├────────┼────────────┼──────────┼──────────┼─────────┤
│  17923 │ 🟫🟨🟫🟫🟨 │     8363 │  121.542 │ 6.62459 │
│  56437 │ 🟫🟨🟨🟨🟩 │      206 │  9.49515 │ 4.76909 │
│  34607 │ 🟨🟨🟨🟫🟩 │       10 │      1.4 │ 2.92193 │
│  43867 │ 🟩🟩🟩🟩🟩 │        2 │      1.0 │     1.0 │
└────────┴────────────┴──────────┴──────────┴─────────┘
```

The first guess suggested for this game is `17923`.

Initially the size of the target pool, the set of all possible solutions, is 8363.
For this guess, the expected pool size after the guess is scored is 121.542.
As described below, the expected pool size for any guess can be evaluated before the guess is scored.
A guess that minimizes the expected pool size is chosen when the `guesstype` of the `GamePool` is `:expected`, which is the default.
This game is also being played under the "Hard Mode" setting where each guess must be in the current target pool.

```jl
julia> (primel.guesstype, primel.hardmode)
(:expected, true)
```

The actual score from this guess was `[0,1,0,0,1]` which eliminates all but 206 of the targets in the pool.
From this reduced target pool the guess with the lowest expected pool size is `56437` with an expected pool size of 9.5.

Two more guesses produce the solution of `43867`.

## Automatic game play

A game can be played with a pre-specified target.
For example, to play a game of Wordle, which has 2315 possible 5-letter words as targets, with the target `"super"`.

```jl
julia> wordle = GamePool(collect(readlines("./data/Wordletargets.txt")));

julia> showgame!(wordle, "super")
┌────────┬────────────┬──────────┬──────────┬──────────┐
│  guess │      score │ poolsize │ expected │  entropy │
│ String │     String │    Int64 │  Float32 │  Float32 │
├────────┼────────────┼──────────┼──────────┼──────────┤
│  raise │ 🟨🟫🟫🟨🟨 │     2315 │  61.0009 │  5.87791 │
│  shrew │ 🟩🟫🟨🟩🟫 │       18 │  2.66667 │  3.03856 │
│  sneer │ 🟩🟫🟨🟩🟩 │        5 │      2.2 │  1.37095 │
│  sever │ 🟩🟨🟫🟩🟩 │        3 │  1.66667 │ 0.918296 │
│  sober │ 🟩🟫🟫🟩🟩 │        2 │      1.0 │      1.0 │
│  super │ 🟩🟩🟩🟩🟩 │        1 │      1.0 │     -0.0 │
└────────┴────────────┴──────────┴──────────┴──────────┘
```

or to play a game with a randomly chosen target

```jl
julia> Random.seed!(1234321);

julia> showgame!(wordle)
┌────────┬────────────┬──────────┬──────────┬─────────┐
│  guess │      score │ poolsize │ expected │ entropy │
│ String │     String │    Int64 │  Float32 │ Float32 │
├────────┼────────────┼──────────┼──────────┼─────────┤
│  raise │ 🟫🟫🟫🟫🟫 │     2315 │  61.0009 │ 5.87791 │
│  could │ 🟫🟩🟫🟫🟫 │      168 │  2.66667 │ 5.16409 │
│  boozy │ 🟨🟩🟨🟫🟩 │       14 │      2.2 │ 3.37878 │
│  hobby │ 🟩🟩🟩🟩🟩 │        1 │  1.66667 │    -0.0 │
└────────┴────────────┴──────────┴──────────┴─────────┘
```

The target can also be specified as an integer between `1` and `length(wordle.targetpool)`.

```
julia> showgame!(wordle, 1234)
┌────────┬────────────┬──────────┬──────────┬─────────┐
│  guess │      score │ poolsize │ expected │ entropy │
│ String │     String │    Int64 │  Float32 │ Float32 │
├────────┼────────────┼──────────┼──────────┼─────────┤
│  raise │ 🟫🟫🟨🟫🟩 │     2315 │  61.0009 │ 5.87791 │
│  binge │ 🟫🟩🟩🟫🟩 │       25 │  2.66667 │ 3.28386 │
│  mince │ 🟩🟩🟩🟩🟩 │        2 │      2.2 │     1.0 │
└────────┴────────────┴──────────┴──────────┴─────────┘
```

This mechanism allows for playing all possible games and accumulating some statistics.

```jl
julia> reset(wordle);

julia> nguesswordle = [length(playgame!(wordle, k).guesses) for k in axes(wordle.active, 1)];

julia> using StatsBase, UnicodePlots

julia> barplot(countmap(nguesswordle))
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
```

Playing all possible Wordle games in this way takes less than half a second on my not-very-powerful laptop.

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
julia> (mean(nguesswordle), std(nguesswordle))
(3.634989200863931, 0.8622912420643568)
```

are reasonable but not optimal.
Grant Sanderson (@3brown1blue) has a [YouTube video](https://twitter.com/3blue1brown/status/1490351572215283712) describing a strategy the gives a mean of 3.43 guesses.
Later, in a tweet, he referred to a strategy with a mean of 3.42 guesses.

Also, the barplot shows that there are 14 of the 2315 games that are not solved in 6 guesses by this strategy.

The games that require 8 guesses are

```jl
julia> [showgame!(wordle, k) for k in findall(==(8), nguesswordle)];
┌────────┬────────────┬──────────┬──────────┬──────────┐
│  guess │      score │ poolsize │ expected │  entropy │
│ String │     String │    Int64 │  Float32 │  Float32 │
├────────┼────────────┼──────────┼──────────┼──────────┤
│  raise │ 🟨🟫🟫🟫🟨 │     2315 │  61.0009 │  5.87791 │
│  outer │ 🟨🟫🟫🟩🟩 │      102 │  2.66667 │  4.09399 │
│  mower │ 🟫🟩🟫🟩🟩 │       16 │      2.2 │  1.91974 │
│  cover │ 🟫🟩🟫🟩🟩 │        9 │  1.66667 │  1.65774 │
│  joker │ 🟫🟩🟫🟩🟩 │        5 │      1.0 │  1.37095 │
│  boxer │ 🟫🟩🟫🟩🟩 │        3 │      1.0 │ 0.918296 │
│  foyer │ 🟫🟩🟫🟩🟩 │        2 │  6.27381 │      1.0 │
│  goner │ 🟩🟩🟩🟩🟩 │        1 │  1.42857 │     -0.0 │
└────────┴────────────┴──────────┴──────────┴──────────┘
┌────────┬────────────┬──────────┬──────────┬──────────┐
│  guess │      score │ poolsize │ expected │  entropy │
│ String │     String │    Int64 │  Float32 │  Float32 │
├────────┼────────────┼──────────┼──────────┼──────────┤
│  raise │ 🟫🟩🟫🟫🟫 │     2315 │  61.0009 │  5.87791 │
│  tangy │ 🟨🟩🟫🟫🟫 │       91 │  2.66667 │  4.03061 │
│  caput │ 🟨🟩🟫🟫🟨 │       13 │      2.2 │   2.4997 │
│  batch │ 🟫🟩🟩🟩🟩 │        5 │  1.66667 │ 0.721928 │
│  hatch │ 🟨🟩🟩🟩🟩 │        4 │      1.0 │ 0.811278 │
│  latch │ 🟫🟩🟩🟩🟩 │        3 │      1.0 │ 0.918296 │
│  match │ 🟫🟩🟩🟩🟩 │        2 │  6.27381 │      1.0 │
│  watch │ 🟩🟩🟩🟩🟩 │        1 │  1.42857 │     -0.0 │
└────────┴────────────┴──────────┴──────────┴──────────┘
┌────────┬────────────┬──────────┬──────────┬──────────┐
│  guess │      score │ poolsize │ expected │  entropy │
│ String │     String │    Int64 │  Float32 │  Float32 │
├────────┼────────────┼──────────┼──────────┼──────────┤
│  raise │ 🟫🟫🟫🟫🟫 │     2315 │  61.0009 │  5.87791 │
│  could │ 🟫🟩🟩🟫🟩 │      168 │  2.66667 │  5.16409 │
│  bound │ 🟫🟩🟩🟩🟩 │        6 │      2.2 │ 0.650022 │
│  found │ 🟫🟩🟩🟩🟩 │        5 │  1.66667 │ 0.721928 │
│  hound │ 🟫🟩🟩🟩🟩 │        4 │      1.0 │ 0.811278 │
│  mound │ 🟫🟩🟩🟩🟩 │        3 │      1.0 │ 0.918296 │
│  pound │ 🟫🟩🟩🟩🟩 │        2 │  6.27381 │      1.0 │
│  wound │ 🟩🟩🟩🟩🟩 │        1 │  1.42857 │     -0.0 │
└────────┴────────────┴──────────┴──────────┴──────────┘
```

In the last game, after 2 guesses there are 6 targets for which the last four characters are correct but the first is unknown, other than not being `r`, `a`, `i`, `s`, `e`, `c`, or `l`.

All 6 such targets produce the same score and it becomes a matter of trying each one in turn until the solution is found.

As can be seen here resolving ties is done by choosing the first target in the collection of tied guesses.
(The target pool was sorted lexicographically.)

As might be expected, the mean number of guesses when playing Primel is larger, because the initial target pool is larger, but the standard deviation is smaller.

```jl
julia> nguessprimel = [length(playgame!(primel, k).guesses) for k in axes(primel.targetpool, 1)];

julia> barplot(countmap(nguessprimel))
     ┌                                        ┐ 
   1 ┤ 1                                        
   2 ┤■■ 209                                    
   3 ┤■■■■■■■■■■■■■■■■■■■ 2642                  
   4 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 4612   
   5 ┤■■■■■■ 854                                
   6 ┤ 44                                       
   7 ┤ 1                                        
     └                                        ┘ 

julia> (mean(nguessprimel), std(nguessprimel))
(3.7467415999043405, 0.6907319195032124)

julia> showgame!(primel, only(findall(==(7), nguessprimel)))
┌────────┬────────────┬──────────┬──────────┬──────────┐
│  guess │      score │ poolsize │ expected │  entropy │
│ String │     String │    Int64 │  Float32 │  Float32 │
├────────┼────────────┼──────────┼──────────┼──────────┤
│  17923 │ 🟨🟫🟫🟨🟫 │     8363 │  121.542 │  6.62459 │
│  20681 │ 🟨🟫🟫🟩🟩 │      140 │  9.49515 │  4.76711 │
│  41281 │ 🟩🟨🟩🟩🟩 │        8 │      1.4 │      2.0 │
│  42281 │ 🟩🟨🟩🟩🟩 │        4 │      1.0 │ 0.811278 │
│  44281 │ 🟩🟨🟩🟩🟩 │        3 │  5.46809 │ 0.918296 │
│  45281 │ 🟩🟫🟩🟩🟩 │        2 │      1.0 │      1.0 │
│  48281 │ 🟩🟩🟩🟩🟩 │        1 │      1.0 │     -0.0 │
└────────┴────────────┴──────────┴──────────┴──────────┘
```

I suspect the smaller standard deviation in `primel` is because the number of characters that can occur in each position is smaller (9 in the first position, 10 for the others) than for `wordle` (26).


## Strategy

Each turn in a Wordle-like game can be regarded as submitting a guess to an "oracle" which returns a score that is used to update the information on the play.
Initially the target can be any element of the target pool.
Each guess/score combination reduces the size of the target pool, as shown in the game summaries above.
In a `GamePool` object the `targetpool` field remains constant and the `active` field, a `BitVector` of the same length as the `targetpool`, is used to keep track of which targets are in the current target pool

The size of the current target pool is the sum of `active`.

The score for a particular guess is known to the oracle but not to the player.
However, the scores for any potential guess and a member of the target pool can be evaluated.
The number of possible scores is finite (`3^N` where `N` is the number of tiles in the score).

For example the first guess chosen in the `wordle` games shown about is `"raise"`, which is at position 1535 in `wordle.targetpool`. 

```jl
julia> reset!(wordle)  # reset the `GamePool` to its initial state
1535

julia> only(wordle.guessinds)  # check that there is exactly one guessind and return it
1535

julia> bincounts!(wordle, 1535);   # evaluate the bin counts

julia> expectedpoolsize!(wordle)  # also evaluates the probabilities
61.00086393088553

julia> pretty_table((;score = tiles.(0:242, 5), counts = wordle.counts, probs = wordle.probs))
┌────────────┬────────┬─────────────┐
│      score │ counts │       probs │
│     String │  Int64 │     Float32 │
├────────────┼────────┼─────────────┤
│ 🟫🟫🟫🟫🟫 │    168 │   0.0725702 │
│ 🟫🟫🟫🟫🟨 │    121 │   0.0522678 │
│ 🟫🟫🟫🟫🟩 │     61 │   0.0263499 │
│ 🟫🟫🟫🟨🟫 │     80 │   0.0345572 │
│ 🟫🟫🟫🟨🟨 │     41 │   0.0177106 │
│ 🟫🟫🟫🟨🟩 │     17 │  0.00734341 │
│ 🟫🟫🟫🟩🟫 │     17 │  0.00734341 │
│ 🟫🟫🟫🟩🟨 │      9 │  0.00388769 │
│ 🟫🟫🟫🟩🟩 │     20 │  0.00863931 │
│ 🟫🟫🟨🟫🟫 │    107 │   0.0462203 │
│ 🟫🟫🟨🟫🟨 │     35 │   0.0151188 │
│ 🟫🟫🟨🟫🟩 │     25 │   0.0107991 │
│ 🟫🟫🟨🟨🟫 │     21 │  0.00907127 │
│ 🟫🟫🟨🟨🟨 │      4 │  0.00172786 │
│ 🟫🟫🟨🟨🟩 │      5 │  0.00215983 │
│ 🟫🟫🟨🟩🟫 │      6 │  0.00259179 │
│ 🟫🟫🟨🟩🟨 │      0 │         0.0 │
│ 🟫🟫🟨🟩🟩 │      0 │         0.0 │
│ 🟫🟫🟩🟫🟫 │     51 │   0.0220302 │
│ 🟫🟫🟩🟫🟨 │     15 │  0.00647948 │
│ 🟫🟫🟩🟫🟩 │     23 │   0.0099352 │
│ 🟫🟫🟩🟨🟫 │     29 │    0.012527 │
│ 🟫🟫🟩🟨🟨 │      3 │   0.0012959 │
│     ⋮      │   ⋮    │      ⋮      │
└────────────┴────────┴─────────────┘
                     220 rows omitted
```

Assuming the targets are equally likely, which apparently is the case in the online games, the probability of each score is the count for that score divided by size of the active target pool.
The expected pool size is the sum of the `counts` multiplied by the `probs` or, equivalently, the sum of the squared counts divided by the sum of the counts.

```jl
julia> sum(abs2, wordle.counts) / sum(wordle.counts)  # abs2(x) returns x * x
61.00086393088553
```

The next guess is chosen to minimize the expected pool size.

### MAximizing entropy

An alternative criterion is to maximize the [entropy](https://en.wikipedia.org/wiki/Entropy_(information_theory)) of the probabilities associated with the possible scores, i.e. the `probs` field.

Measured in bits, the entropy of the `n` probabilities is $-\sum_{i=1}^n p_i\,log_2(p_i)$

It measures how the probability is among the possible scores.
The best case is for each of the `n` possible scores to have probability `1/n` of occurring so that, whichever score is returned, there will only be a small number of targets with that score.
It is not possible to get that from a starting guess but, sometimes when the target pool is small, a particular guess may be able to split the remaining `k` targets into `k` distinct scores.

In particular, this always occurs when there are only two targets left.

Chosing a guess so as to maximize the entropy provides slightly better performance, on average.

```jl
julia> wordle2 = GamePool(collect(readlines("./data/Wordletargets.txt")); guesstype=:entropy);

julia> ngwrdl2 = [length(playgame!(wordle2, k).guesses) for k in axes(wordle2.active, 1)];

julia> barplot(countmap(ngwrdl2))
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

julia> (mean(ngwrdl2), std(ngwrdl2))
(3.614254859611231, 0.8552369532287724)
```

Two of the games that took 8 guesses under the expected pool size strategy also take 8 guesses under the maximum entropy strategy

```jl
julia> showgame!.(Ref(wordle2), findall(==(8), ngwrdl2));
┌────────┬────────────┬──────────┬──────────┬──────────┐
│  guess │      score │ poolsize │ expected │  entropy │
│ String │     String │    Int64 │  Float32 │  Float32 │
├────────┼────────────┼──────────┼──────────┼──────────┤
│  raise │ 🟨🟫🟫🟫🟨 │     2315 │  61.0009 │  5.87791 │
│  outer │ 🟨🟫🟫🟩🟩 │      102 │  4.54348 │  4.09399 │
│  mower │ 🟫🟩🟫🟩🟩 │       16 │      2.0 │  1.91974 │
│  cover │ 🟫🟩🟫🟩🟩 │        9 │     1.75 │  1.65774 │
│  joker │ 🟫🟩🟫🟩🟩 │        5 │      1.0 │  1.37095 │
│  boxer │ 🟫🟩🟫🟩🟩 │        3 │  5.29268 │ 0.918296 │
│  foyer │ 🟫🟩🟫🟩🟩 │        2 │      1.0 │      1.0 │
│  goner │ 🟩🟩🟩🟩🟩 │        1 │  3.34783 │     -0.0 │
└────────┴────────────┴──────────┴──────────┴──────────┘
┌────────┬────────────┬──────────┬──────────┬──────────┐
│  guess │      score │ poolsize │ expected │  entropy │
│ String │     String │    Int64 │  Float32 │  Float32 │
├────────┼────────────┼──────────┼──────────┼──────────┤
│  raise │ 🟫🟩🟫🟫🟫 │     2315 │  61.0009 │  5.87791 │
│  tangy │ 🟨🟩🟫🟫🟫 │       91 │  4.54348 │  4.03061 │
│  caput │ 🟨🟩🟫🟫🟨 │       13 │      2.0 │   2.4997 │
│  batch │ 🟫🟩🟩🟩🟩 │        5 │     1.75 │ 0.721928 │
│  hatch │ 🟨🟩🟩🟩🟩 │        4 │      1.0 │ 0.811278 │
│  latch │ 🟫🟩🟩🟩🟩 │        3 │  5.29268 │ 0.918296 │
│  match │ 🟫🟩🟩🟩🟩 │        2 │      1.0 │      1.0 │
│  watch │ 🟩🟩🟩🟩🟩 │        1 │  3.34783 │     -0.0 │
└────────┴────────────┴──────────┴──────────┴──────────┘
```

but this strategy can find `"wound"` in six guesses.

```jl
julia> showgame!(wordle2, "wound")
┌────────┬────────────┬──────────┬──────────┬──────────┐
│  guess │      score │ poolsize │ expected │  entropy │
│ String │     String │    Int64 │  Float32 │  Float32 │
├────────┼────────────┼──────────┼──────────┼──────────┤
│  raise │ 🟫🟫🟫🟫🟫 │     2315 │  61.0009 │  5.87791 │
│  mulch │ 🟫🟨🟫🟫🟫 │      168 │  4.54348 │  5.21165 │
│  bound │ 🟫🟩🟩🟩🟩 │        8 │      2.0 │  2.40564 │
│  found │ 🟫🟩🟩🟩🟩 │        3 │     1.75 │ 0.918296 │
│  pound │ 🟫🟩🟩🟩🟩 │        2 │      1.0 │      1.0 │
│  wound │ 🟩🟩🟩🟩🟩 │        1 │  5.29268 │     -0.0 │
└────────┴────────────┴──────────┴──────────┴──────────┘
```
