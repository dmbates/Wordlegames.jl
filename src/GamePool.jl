abstract type GuessType end

struct MaximizeEntropy <: GuessType end
struct MinimizeExpected <: GuessType end

"""
    GamePool{N,S,G}

A struct that defines a Wordle-like game with targets of length `N`.
`S <: Unsigned` is the smallest unsigned integer type that can store values in the
range `0:(3 ^ N - 1)`, evaluated as `Wordlegames.scoretype(N)` and `G <: GuessType`
is the guess type, which defaults to `MaximizeEntropy`.

The fields are:

- `targetpool`: the target pool as a `Vector{NTuple{N,Char}}`
- `guesspool`: a `Vector{NTuple{N,Char}}` of potential guesses (can be the same as `targets`)
- `allscores`: a `Matrix{S}` where `allscores[i,j] = score(guesspool[j], targets[i])`
- `active`: a `BitVector`. The active target pool is `targets[active]`.
- `counts`: `Vector{Int}` of length `3 ^ N` in which bin counts are accumulated
- `guesses`: `Vector{NTuple{N,Char}}`
- `guessinds`: `Vector{Int}` where the indexes into `guesspool` of guesses are stored
- `scores`: scores of the guesses as a `Vector{S}`
- `poolsizes`: `Vector{Int}` target pool size for prior to each guess being evaluated
- `expected`: `Vector{Float64}` of expected pool sizes after each guess is scored
- `entropy`: `Vector{Float64}` the (base2) entropy for each guess
- `hardmode`: `Bool` - should the game be played in "Hard Mode"?

Constructor signatures include

    GamePool(targets::Vector{NTuple{N,Char}}, guesses::Vector{NTuple{N,Char}}; guesstype=MaximizeEntropy, hardmode::Bool=true) where {N}
    GamePool(pool::Vector{NTuple{N,Char}}; guesstype=MaximizeEntropy, hardmode::Bool=true) where {N}
    GamePool(pool::AbstractVector{<:AbstractString}; guesstype=MaximizeEntropy, hardmode::Bool=true)
    GamePool(pool::AbstractVector; guesstype=MaximizeEntropy, hardmode::Bool=true)
"""
struct GamePool{N,S,G}
    targetpool::Vector{NTuple{N,Char}}
    guesspool::Vector{NTuple{N,Char}}
    allscores::Matrix{S}
    active::BitVector
    counts::Vector{Int}
    guesses::Vector{NTuple{N,Char}}
    guessinds::Vector{Int}
    scores::Vector{S}
    poolsizes::Vector{Int}
    expected::Vector{Float64}
    entropy::Vector{Float64}
    hardmode::Bool
end

function GamePool(
    targets::Vector{NTuple{N,Char}},
    guesses::Vector{NTuple{N,Char}};
    guesstype=MaximizeEntropy,
    hardmode::Bool=true,
) where {N}
    if !(guesstype <: GuessType)
        throw(ArgumentError("guesstype = $guesstype should be `MaximizeEntropy` or `MinimizeExpected`"))
    end
    if !hardmode
        throw(ArgumentError("!hardmode (easy mode?) not yet implemented"))
    end
    ## enhancements - remove any duplicates in targets and guesses and sort them
    allscores = ThreadsX.map(
        t -> score(last(t), first(t)), Iterators.product(targets, guesses)
    )
    S = eltype(allscores)
    return updateguess!(
        GamePool{N,S,guesstype}(
            targets,
            guesses,
            allscores,
            trues(length(targets)),
            zeros(Int, 3 ^ N),
            sizehint!(NTuple{N,Char}[], 10),
            sizehint!(Int[], 10),
            sizehint!(S[], 10),
            sizehint!(Int[], 10),
            sizehint!(Float64[], 10),
            sizehint!(Float64[], 10),
            hardmode,
        ),
    )
end

function GamePool(
    targets::AbstractVector{<:AbstractString},
    guesses::AbstractVector{<:AbstractString};
    guesstype = MaximizeEntropy,
    hardmode::Bool = true,
)
    N = length(first(targets))
    if any(≠(N) ∘ length, targets) || any(≠(N) ∘ length, guesses)
        throw(ArgumentError("`pool` elements must have the same length"))
    end
    return GamePool(NTuple{N,Char}.(targets), NTuple{N,Char}.(guesses); guesstype, hardmode)
end

function GamePool(
    pool::Vector{NTuple{N,Char}}; guesstype=MaximizeEntropy, hardmode::Bool=true
) where {N}
    return GamePool(pool, pool; guesstype, hardmode)
end

function GamePool(
    pool::AbstractVector{<:AbstractString}; guesstype=MaximizeEntropy, hardmode::Bool=true
)
    N = length(first(pool))
    if any(≠(N) ∘ length, pool)
        throw(ArgumentError("`pool` elements must have the same length"))
    end
    return GamePool(NTuple{N,Char}.(pool); guesstype, hardmode)
end

function GamePool(pool::AbstractVector; guesstype=MaximizeEntropy, hardmode::Bool=true)
    return GamePool(string.(pool); guesstype, hardmode)
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
        xlgx = x * log(x)
        iszero(x) ? zero(xlgx) : xlgx
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
    gamesummary(gp::GamePool)

Return a summary of a game as a columntable (i.e. a `NamedTuple` of `Vector`s of the same length).

The table contains columns `guess` (as `String`s), `score`, `poolsize`, `expected`, and `entropy`.
"""
function gamesummary(gp::GamePool{N}) where {N}
    (; guessinds, scores) = gp
    length(scores) == length(guessinds) || throw(ArgumentError("Game gp is not finished."))
    return (;                      # columntable as a NamedTuple
        poolsize=gp.poolsizes,
        guess=[string(g...) for g in gp.guesses],
        expected=gp.expected,
        entropy=gp.entropy,
        score=tiles.(scores, N),
    )
end

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
    psz = length(gp.targetpool)
    0 < ind ≤ psz || throw(ArgumentError("condition 1 ≤ ind ≤ $psz not satisfied"))
    reset!(gp)
    maxscore = (3^N) - 1
    while true
        sc = score(gp, ind)
        sc == maxscore && break
        scoreupdate!(gp, sc)
    end
    push!(gp.scores, maxscore)
    return gp
end

playgame!(gp::GamePool, rng::AbstractRNG) = playgame!(gp, rand(rng, axes(gp.targetpool, 1)))

playgame!(gp::GamePool) = playgame!(gp, Random.GLOBAL_RNG)

function playgame!(gp::GamePool{N}, target::NTuple{N,Char}) where {N}
    targetind = findfirst(==(target), gp.targetpool)
    isnothing(targetind) && throw(ArgumentError("`target` is not in `gp.targetpool`"))
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
    fill!(gp.active, true)
    trailing = 2:length(gp.guesses)
    if !isempty(trailing)
        deleteat!(gp.guesses, trailing)
        deleteat!(gp.guessinds, trailing)
        deleteat!(gp.poolsizes, trailing)
        deleteat!(gp.expected, trailing)
        deleteat!(gp.entropy, trailing)
    end
    empty!(gp.scores)
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

score(gp::GamePool, targetind::Integer) = gp.allscores[targetind, last(gp.guessinds)]

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
function scoreupdate!(gp::GamePool, sc::Integer)
    (; allscores, active, counts, guessinds) = gp
    sc = eltype(allscores)(sc)
    push!(gp.scores, sc)
    sc == length(counts) - 1 && return gp
    active .&= (view(allscores, :, last(guessinds)) .== sc)
    return updateguess!(gp)
end

function scoreupdate!(gp::GamePool{N}, score::Vector{<:Integer}) where {N}
    sclen = length(score)
    sclen == N || throw(ArgumentError("length(score) = $sclen should be $N"))
    all(∈((0, 1, 2)), score) || throw(ArgumentError("score elements must be in [0, 1, 2]"))
    return scoreupdate!(gp, evalpoly(3, reverse(score)))
end

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
    push!(gp.guesses, gp.guesspool[gind])
    push!(gp.guessinds, gind)
    push!(gp.poolsizes, sum(gp.active))
    push!(gp.expected, xpctedpoolsize)
    push!(gp.entropy, entropy)
    return gp
end
