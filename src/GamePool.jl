abstract type GuessType end

struct MaximizeEntropy <: GuessType end
struct MinimizeExpected <: GuessType end

"""
    GuessScore

A `NamedTuple` for recording a guess and its score, when available.
"""
const GuessScore = NamedTuple{
    (:poolsz, :index, :guess, :expected, :entropy, :score, :sc),
    Tuple{Int,Int,String,Float64,Float64,Union{Missing,String},Union{Missing,Int}},
}

"""
    GamePool{N,S,G}

A struct that defines a Wordle-like game with targets of length `N`.
`S <: Unsigned` is the smallest unsigned integer type that can store values in the
range `0:(3 ^ N - 1)` (obtained as `Wordlegames.scoretype(N)`) and `G <: GuessType`
is the guess type, which defaults to `MaximizeEntropy`.

The fields are:

- `guesspool`: a `Vector{NTuple{N,Char}}` of potential guesses
- `validtargets`: a `BitVector` of valid targets in the `guesspool`
- `allscores`: a cache of pre-computed scores as a `Matrix{S}` of size `(sum(validtargets), length(guesspool))`
- `active`: a `BitVector`. The active pool of guesses is `guesspool[active]`.
- `counts`: `Vector{Int}` of length `3 ^ N` in which bin counts are accumulated
- `guesses`: `Vector{GuessScore}` recording game play
- `hardmode`: `Bool` - should the game be played in "Hard Mode"?

Constructor signatures include

    GamePool(guesspool::Vector{NTuple{N,Char}}, validtargets::BitVector; guesstype=MaximizeEntropy, hardmode::Bool=true) where {N}
    GamePool(guesspool::Vector{NTuple{N,Char}}; guesstype=MaximizeEntropy, hardmode::Bool=true) where {N}
    GamePool(guesspool::AbstractVector{<:AbstractString}; guesstype=MaximizeEntropy, hardmode::Bool=true)
    GamePool(guesspool::AbstractVector; guesstype=MaximizeEntropy, hardmode::Bool=true)
"""
struct GamePool{N,S,G}
    guesspool::Vector{NTuple{N,Char}}
    validtargets::BitVector
    allscores::Matrix{S}
    active::BitVector
    counts::Vector{Int}
    guesses::Vector{GuessScore}
    hardmode::Bool
end

function GamePool(
    guesspool::Vector{NTuple{N,Char}},
    validtargets::BitVector;
    guesstype=MaximizeEntropy,
    hardmode::Bool=true,
) where {N}
    if !(guesstype <: GuessType)
        throw(ArgumentError("guesstype = $guesstype is not `<: GuessType`"))
    end
    if length(validtargets) ≠ length(guesspool)
        throw(ArgumentError("lengths of `guesspool` and `validtargets` must match"))
    end
    ## enhancements - remove any duplicates in guesspool
    allscores = ThreadsX.map(
        t -> score(last(t), first(t)),
        Iterators.product(view(guesspool, validtargets), guesspool),
    )
    S = eltype(allscores)
    return updateguess!(
        GamePool{N,S,guesstype}(
            guesspool,
            validtargets,
            allscores,
            trues(length(guesspool)),
            zeros(Int, 3^N),
            sizehint!(GuessScore[], 10),
            hardmode,
        ),
    )
end

function GamePool(
    guesspool::Vector{NTuple{N,Char}};
    guesstype=MaximizeEntropy,
    hardmode::Bool=true,
) where {N}
    return GamePool(guesspool, trues(length(guesspool)); guesstype, hardmode)
end

function GamePool(
    guesspool::AbstractVector{<:AbstractString},
    validtargets::BitVector;
    guesstype=MaximizeEntropy,
    hardmode::Bool=true,
)
    N = length(first(guesspool))
    if any(≠(N) ∘ length, guesspool)
        throw(ArgumentError("`guesspool` elements must have the same length"))
    end
    return GamePool(NTuple{N,Char}.(guesspool), validtargets; guesstype, hardmode)
end

function GamePool(
    guesspool::AbstractVector{<:AbstractString};
    guesstype=MaximizeEntropy,
    hardmode::Bool=true,
)
    return GamePool(guesspool, trues(length(guesspool)); guesstype, hardmode)
end

function GamePool(
    guesspool::AbstractVector,
    validtargets::BitVector;
    guesstype=MaximizeEntropy,
    hardmode::Bool=true,
)
    return GamePool(string.(guesspool), validtargets; guesstype, hardmode)
end

function GamePool(
    guesspool::AbstractVector;
    guesstype=MaximizeEntropy,
    hardmode::Bool=true,
)
    gps = string.(guesspool)
    return GamePool(gps, trues(length(gps)); guesstype, hardmode)
end

"""
    bincounts!(counts, active, scorevec)
    bincounts!(gp::GamePool, k)

Return `counts` overwritten with bin probabilities from `scorevec[active]` or
update `gp.counts` from `gp.active` and `gp.allscores[:,k]`.
"""
function bincounts!(
    counts::AbstractVector{<:Integer},
    active::BitVector,
    scorevec::AbstractVector{<:Integer},
)
    fill!(counts, 0)
    for (i, a) in enumerate(active)
        if a
            counts[scorevec[i] + 1] += 1
        end
    end
    return counts
end

function bincounts!(gp::GamePool, k)
    bincounts!(gp.counts, gp.active, view(gp.allscores, :, k))
    return gp
end

"""
    entropy2(counts::AbstractVector{<:Real})
    entropy2(gp::GamePool)

Return the base-2 entropy of `counts` or `gp.counts`, converted to probabilities.

The result is the entropy measured in bits.
See the [Wikipedia entry](https://en.wikipedia.org/wiki/Entropy_(information_theory))
for the definition of entropy in information theory.
"""
function entropy2(counts::AbstractVector{<:Real})
    countsum = sum(counts)
    return -sum(counts) do k
        x = k / countsum
        xlogx = x * log(x)
        iszero(x) ? zero(xlogx) : xlogx
    end / log(2)
end

entropy2(gp::GamePool) = entropy2(gp.counts)

"""
    expectedpoolsize(gp::GamePool)

Return the expected pool size from `gp.counts`.
"""
function expectedpoolsize(gp::GamePool)
    return sum(abs2, gp.counts) / sum(gp.counts)
end
    
"""
    optimalguess(gp::GamePool{N,S,G}) where {N,S,G}

Return the optimal guess as a `Tuple{Int,Float64,Float64}` from
`view(gp.guesspool, gp.active)` according to strategy `G`
"""
function optimalguess(gp::GamePool{N,S,MaximizeEntropy}) where {N,S}
    gind, xpctd, entrpy = 0, Inf, -Inf
    poolsize = sum(gp.active)
    for (k, a) in enumerate(gp.active)
        if a
            thisentropy = entropy2(bincounts!(gp, k))
            if thisentropy > entrpy
                gind, xpctd, entrpy = k, expectedpoolsize(gp), thisentropy
            end
        end
    end
    return gind, xpctd, entrpy
end

function optimalguess(gp::GamePool{N,S,MinimizeExpected}) where {N,S}
    gind, xpctd, entrpy = 0, Inf, -Inf
    for (k, a) in enumerate(gp.active)
        if a
            thisexpected = expectedpoolsize(bincounts!(gp, k))
            if thisexpected < xpctd
                gind, xpctd, entrpy = k, thisexpected, entropy2(gp)
            end
        end
    end
    return gind, xpctd, entrpy
end

"""
    playgame!(gp::GamePool, ind::Integer)
    playgame!(gp::GamePool[, rng::AbstractRNG])
    playgame!(gp::GamePool{N}, target::NTuple{N,Char}) where {N}
    playgame!(gp::GamePool{N}, target::AbstractString) where {N}

Return `gp` after playing a game with target `gp.targetpool[ind]`, or a randomly chosen target
or `target` given as an `AbstractString` or `NTuple{N,Char}`.

A `target` as a string must have `length(target) == N`.

See also: [`showgame!`](@ref)
"""
function playgame!(gp::GamePool{N}, ind::Integer) where {N}
    gp.validtargets[ind] || throw(ArgumentError("ind = $ind is not a valid target index"))
    reset!(gp)
    maxscore = (3^N) - 1
    while true     # FIXME: there should be a better way of writing this loop
        sc = score(gp, ind)
        scoreupdate!(gp, sc)
        sc == maxscore && break
    end
    return gp
end

playgame!(gp::GamePool, rng::AbstractRNG) = playgame!(gp, rand(rng, axes(gp.guesspool, 1)))

playgame!(gp::GamePool) = playgame!(gp, Random.GLOBAL_RNG)

function playgame!(gp::GamePool{N}, target::NTuple{N,Char}) where {N}
    targetind = findfirst(==(target), gp.guesspool)
    isnothing(targetind) && throw(ArgumentError("`target` is not in `gp.guesspool`"))
    return playgame!(gp, targetind)
end

function playgame!(gp::GamePool{N}, target::AbstractString) where {N}
    tlen = length(target)
    if length(target) ≠ N
        throw(ArgumentError("`length(target) = $tlen` must be $N for this `GamePool`"))
    end
    return playgame!(gp, NTuple{N,Char}(target))
end

"""
    reset!(gp::GamePool)

Return `gp` with its `active`, `guess`, and `entropy` fields reset to initial values.
"""
function reset!(gp::GamePool)
    (; active, guesses) = gp
    fill!(active, true)
    deleteat!(guesses, 2:length(guesses))
    return gp
end

"""
    score(guess, target)
    score(gp::GamePool, targetind::Integer)

Return a generalized Wordle score for `guess` at `target`, as an `Int` in `0:((3^length(zip(guess,target))) - 1)`.

The second method returns a precomputed score at `gp.allscores[targetind, last(gp.guessinds)]`.

In Wordle both `guess` and `target` would be length-5 character strings and each position
in `guess` is scored as green if it matches `target` in the same position, yellow if it
matches `target` in another position, and gray if there is no match. This function returns
such a score as a number whose base-3 representation is 0 for no match, 1 for a match in
another position and 2 for a match in the same position.
    
See also: [`tiles`](@ref) for converting this numeric score to colored tiles.
"""
function score(guess, target)
    s = 0
    for (g, t) in zip(guess, target)
        s *= 3
        s += (g == t ? 2 : Int(g ∈ target))
    end
    return s
end

function score(guess::NTuple{N}, target::NTuple{N}) where {N}
    S = scoretype(N)
    s = zero(S)
    for i in 1:N
        s *= S(3)
        g = guess[i]
        s += (g == target[i] ? S(2) : S(g ∈ target))
    end
    return s
end

score(gp::GamePool, targetind::Integer) = gp.allscores[targetind, last(gp.guesses).index]

"""
	scoretype(nchar)

Return the smallest type `T<:Unsigned` for storing the scores from a pool of items of length `nchar`
"""
@inline function scoretype(nchar)
    if nchar ≤ 0 || nchar > 80
        throw(ArgumentError("nchar = $nchar is not in `1:80`"))
    end
    return if nchar ≤ 5
        UInt8
    elseif nchar ≤ 10
        UInt16
    elseif nchar ≤ 20
        UInt32
    elseif nchar ≤ 40
        UInt64
    else
        UInt128
    end
end

"""
    scoreupdate!(gp::GamePool, sc::Integer)
    scoreupdate!(gp::GamePool{N}, scv::Vector{<:Integer}) where {N}

Update `gp` with the score `sc`, or a vector `scv` of length `N` whose elements are `0`, `1`, or `2` for `last(gp.guesses)`

Always `push!(gp.scores, sc)`.  If `sc` is the maximum possible score, `3 ^ N - 1`, the game is over and return `gp`.
Otherwise, update `gp.active` and call `updateguess!(gp)`.
"""
function scoreupdate!(gp::GamePool{N}, scr::Integer) where {N}
    (; active, allscores, counts, guesses) = gp
    (; poolsz, index, guess, expected, entropy, score, sc) = last(guesses)
    score = tiles(scr, N)
    sc = Int(scr)
    guesses[length(guesses)] = (; poolsz, index, guess, expected, entropy, score, sc)
    sc == length(counts) - 1 && return gp
    active .&= (view(allscores, :, index) .== sc)
    return updateguess!(gp)
end

function scoreupdate!(gp::GamePool{N}, score::Vector{<:Integer}) where {N}
    sclen = length(score)
    sclen == N || throw(ArgumentError("length(score) = $sclen should be $N"))
    all(∈((0, 1, 2)), score) || throw(ArgumentError("score elements must be in [0, 1, 2]"))
    return scoreupdate!(gp, evalpoly(3, reverse(score)))
end

"""
    showgame!(gp::GamePool[, target])

Return a `Tables.ColumnTable` of `playgame!(gp, target)))`.
"""
function showgame!(gp::GamePool, target)
    return columntable(playgame!(gp, target).guesses)
end

showgame!(gp::GamePool) = showgame!(gp, rand(axes(gp.active, 1)))

"""
	tiles(score, ntiles)

Return a length-`ntiles` `String` tile pattern from the numeric score `score`.
"""
function tiles(sc, ntiles)
    result = sizehint!(Char[], ntiles)    # initialize to an empty array of Char
    for _ in 1:ntiles                     # _ indicates we won't use the value of the iterator
        sc, r = divrem(sc, 3)
        push!(result, iszero(r) ? '🟫' : (isone(r) ? '🟨' : '🟩'))
    end
    return String(reverse(result))
end

"""
    updateguess!(gp::GamePool)

Choose the optimal guess the `GuessType` of `gp` and push! new values onto `gp.guesses`,
`gp.guessinds`, `gp.expected` and `gp.entropy`
"""
function updateguess!(gp::GamePool)
    gind, xpctedpoolsize, entropy = optimalguess(gp)
    push!(
        gp.guesses,
        (;
            poolsz=sum(gp.active),
            index=gind,
            guess=string(gp.guesspool[gind]...),
            expected=xpctedpoolsize,
            entropy=entropy,
            score=missing,
            sc=missing,
        ),
    )
    return gp
end
