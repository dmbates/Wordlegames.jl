# Wordlegames

A Julia package to play and analyze [Wordle](https://en.wikipedia.org/wiki/Wordle) and related games, such as [Primel](https://cojofra.github.io/primel/).

A game is represented by a `GamePool` constructed from the list of possible targets

```jl
julia> using Wordlegames

julia> wordle = GamePool(collect(eachline("./data/Wordletargets.txt")))
GamePool(["aback", "abase", "abate", "abbey", "abbot", "abhor", "abide", "abled", "abode", "abort"  …  "wryly", "yacht", "yearn", "yeast", "yield", "young", "youth", "zebra", "zesty", "zonal"], UInt8[0xf2 0xea … 0x00 0x03; 0xea 0xf2 … 0x24 0x03; … ; 0x00 0x04 … 0xf2 0xa2; 0x5a 0x5a … 0xa2 0xf2], 1535, 61.00086393088553, Bool[1, 1, 1, 1, 1, 1, 1, 1, 1, 1  …  1, 1, 1, 1, 1, 1, 1, 1, 1, 1], [446, 169, 43, 329, 123, 25, 58, 19, 28, 125  …  0, 0, 0, 0, 0, 0, 0, 0, 0, 1], Base.RefValue{Int64}(1535), Base.RefValue{Float64}(61.00086393088553), Base.RefValue{Int64}(0))
```

The first field in this object is the pool of targets.
The other fields are described in the documentation.

In Wordle a target is chosen from the possible targets and, at each turn, the player submits a guess and receives a score that reduces the pool of possible targets.
In the sample game on the [Wikipedia page](https://en.wikipedia.org/wiki/Wordle) for Wordle the target is "rebus".
To play this game we define an "oracle" function the produces the score for an arbitrary guess with this target.
Two ways of defining an oracle are shown below.

```jl
julia> playgame(guess -> score(guess, "rebus"), wordle) # oracle as an anonymous function
2×4 DataFrame
 Row │ guess   score       pool_size  expected 
     │ String  String      Int64      Float64  
─────┼─────────────────────────────────────────
   1 │ raise   🟩🟫🟫🟨🟨       2315   61.0009
   2 │ rebus   🟩🟩🟩🟩🟩          2    1.0
```

This game ends suspiciously quickly but that doesn't always happen.
Suppose the target was "wryly".

```jl
julia> playgame(Base.Fix2(score, "wryly"), wordle) # oracle as a partially applied function
4×4 DataFrame
 Row │ guess   score       pool_size  expected 
     │ String  String      Int64      Float64  
─────┼─────────────────────────────────────────
   1 │ raise   🟨🟫🟫🟫🟫       2315  61.0009
   2 │ truly   🟫🟩🟫🟩🟩        103   6.14563
   3 │ dryly   🟫🟩🟩🟩🟩          2   1.0
   4 │ wryly   🟩🟩🟩🟩🟩          1   1.0
```

The game can also be played with a randomly chosen target from the pool of possible targets.

```jl
julia> playgame(wordle)
3×4 DataFrame
 Row │ guess   score       pool_size  expected 
     │ String  String      Int64      Float64  
─────┼─────────────────────────────────────────
   1 │ raise   🟨🟫🟨🟫🟫       2315  61.0009
   2 │ droit   🟫🟨🟫🟨🟨         23   1.86957
   3 │ birth   🟩🟩🟩🟩🟩          3   1.66667
```

For the game of Primel the target pool is the 5-digit prime numbers between 10,000 and 99,999.

```jl
julia> using Primes

julia> primel = GamePool(string.(primes(10000, 99999)))
GamePool(["10007", "10009", "10037", "10039", "10061", "10067", "10069", "10079", "10091", "10093"  …  "99877", "99881", "99901", "99907", "99923", "99929", "99961", "99971", "99989", "99991"], UInt8[0xf2 0xf0 … 0x00 0x01; 0xf0 0xf2 … 0x77 0x79; … ; 0x00 0x02 … 0xf2 0xed; 0x51 0x52 … 0xeb 0xf2], 826, 121.5416716489298, Bool[1, 1, 1, 1, 1, 1, 1, 1, 1, 1  …  1, 1, 1, 1, 1, 1, 1, 1, 1, 1], [1631, 1087, 1361, 0, 0, 0, 0, 0, 0, 0  …  2, 0, 0, 0, 4, 0, 3, 0, 0, 1], Base.RefValue{Int64}(826), Base.RefValue{Float64}(121.5416716489298), Base.RefValue{Int64}(0))

julia> playgame(primel)
3×4 DataFrame
 Row │ guess   score       pool_size  expected  
     │ String  String      Int64      Float64   
─────┼──────────────────────────────────────────
   1 │ 17923   🟨🟫🟨🟨🟨       8363  121.542
   2 │ 95231   🟨🟩🟨🟨🟩         45    3.48889
   3 │ 25391   🟩🟩🟩🟩🟩          1    1.0
```

## Strategy

Each guess produced by a `GamePool` object must be in the current target pool, which is what the "Hard Mode" setting on the web sites or apps for such games require.
Updating the `GamePool` with the score from the guess reduces the size of the target pool, as can be seen in the sample games.

In the Primel game with target 25391 the initial target pool size is 8363.
The first guess, 17923, produces a score of 🟨🟫🟨🟨🟨, which could be written as the base-3 integer 10111, or 94 as a decimal number.

```jl
julia> evalpoly(3, reverse([1,0,1,1,1])) # evalpoly uses little-endian order of coefficients
94
```

The expected pool size from this guess is 121.542, before we record the score.
The actual pool size after updating is 45.

We can do this step-by-step

```jl
julia> nextguess(reset!(primel))   # Reset the game to its initial state.
"17923"

julia> update!(primel, evalpoly(3, reverse([1,0,1,1,1]))) # enter score shown as 🟨🟫🟨🟨🟨
("95231", 45, 3.488888888888889)

julia> update!(primel, evalpoly(3, reverse([1,2,1,1,2]))) # enter score shown as 🟨🟩🟨🟨🟩
("25391", 1, 1.0)
```

For this guess the score is 🟩🟩🟩🟩🟩 or 242 in decimal so we are done.

Within the `update!` method, the expected pool size for each guess left in the current target pool is evaluated.

The next guess is chosen as the element of the current target pool with the minimum expected pool size.

Several aspects of the implementation are chosen to make the updating operation very fast.

On a modest laptop

```jl
julia> versioninfo()
Julia Version 1.8.0-DEV.1455
Commit e0a4b7727c (2022-02-06 12:55 UTC)
Platform Info:
  OS: Linux (x86_64-linux-gnu)
  CPU: 11th Gen Intel(R) Core(TM) i5-1135G7 @ 2.40GHz
  WORD_SIZE: 64
  LIBM: libopenlibm
  LLVM: libLLVM-13.0.0 (ORCJIT, tigerlake)
```

benchmarking play of a random Wordle game produces

```jl
julia> @benchmark playgame($wordle)
BenchmarkTools.Trial: 10000 samples with 1 evaluation.
 Range (min … max):   3.410 μs …  7.382 ms  ┊ GC (min … max): 0.00% … 98.92%
 Time  (median):     70.059 μs              ┊ GC (median):    0.00%
 Time  (mean ± σ):   85.787 μs ± 89.935 μs  ┊ GC (mean ± σ):  0.85% ±  0.99%

      ▂▁▂▃▄▇▇▇▃█▂▆ ▁        ▁      ▂▂▂▁                        
  ▁▅▆▅████████████▇█▆▄▄▄▄▆▅▇█▆▇▇▇▆▇████▇▇▇▆▆▅▄▂▂▁▁▁▂▁▃▃▃▄▄▄▃▃ ▄
  3.41 μs         Histogram: frequency by time         211 μs <

 Memory estimate: 3.07 KiB, allocs estimate: 50.
 ```
