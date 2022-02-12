"""
    GamePool{N,S}

A struct that defines a Wordle-like game with targets of length `N`.
`S <: Unsigned` is the smallest type such that `3 ^ N < typemax{S}`. 

The fields are:

- `targetpool`: the target pool as a `Vector{NTuple{N,Char}}`
- `guesspool`: a `Vector{NTuple{N,Char}}` of potential guesses (can be the same as `targets`)
- `allscores`: a `Matrix{S}` where `allscores[i,j] = score(guesspool[j], targets[i])`
- `active`: a `BitVector`. The active target pool is `targets[active]`.
- `counts`: `Vector{Int}` of length `3 ^ N` in which bin counts are accumulated
- `guesses`: `Vector{NTuple{N,Char}}`
- `guessinds`: `Vector{Int}` where the indexes into `pool` of guesses are stored
- `scores`: scores of the guesses as a `Vector{S}`
- `entropy`: `Vector{Float32}` of the entropy after each guess
- `hardmode`: `Bool` - should the game be played in "Hard Mode"?
"""
struct GamePool{N,S}
    targetpool::Vector{NTuple{N,Char}}
    guesspool::Vector{NTuple{N,Char}}
    allscores::Matrix{S}
    active::BitVector
    counts::Vector{Int}
    probs::Vector{Float32}
    guesses::Vector{NTuple{N,Char}}
    guessinds::Vector{Int}
    scores::Vector{S}
    poolsizes::Vector{Int}
    expected::Vector{Float32}
    entropy::Vector{Float32}
    guesstype::Symbol
    hardmode::Bool
end

function GamePool(
    targets::Vector{NTuple{N,Char}},
    guesses::Vector{NTuple{N,Char}};
    guesstype::Symbol = :expected,
    hardmode::Bool=true,
) where {N}
    if guesstype ∉ (:entropy, :expected)
        throw(ArgumentError("guesstype = $guesstype should be `:entropy` or `:expected`"))
    end
    if !hardmode
        throw(ArgumentError("!hardmode (easy mode?) not yet implemented"))
    end
    ## enhancements - remove any duplicates in targets and guesses and sort them
    S = scoretype(N)
    ## Can this easily be adapted for multiple threads? `score` is pure. ThreadsX?
    allscores = [S(score(g, t)) for t in targets, g in guesses]
    ntargets = length(targets)
    return updateguess!(
        GamePool(
            targets,
            guesses,
            allscores,
            trues(ntargets),
            zeros(Int, 3 ^ N),
            zeros(Float32, 3 ^ N),
            sizehint!(NTuple{N,Char}[], 10),
            sizehint!(Int[], 10),
            sizehint!(S[], 10),
            sizehint!(Int[], 10),
            sizehint!(Float32[], 10),
            sizehint!(Float32[], 10),
            guesstype,
            hardmode,
        )
    )
end

function GamePool(
    targets::AbstractVector{<:AbstractString},
    guesses::AbstractVector{<:AbstractString};
    guesstype::Symbol = :expected,
    hardmode::Bool=true,
)
    N = length(first(targets))
    if any(≠(N) ∘ length, targets) || any(≠(N) ∘ length, guesses)
        throw(ArgumentError("`pool` elements must have the same length"))
    end
    return GamePool(NTuple{N,Char}.(targets), NTuple{N,Char}.(guesses); guesstype, hardmode)
end

function GamePool(
    pool::Vector{NTuple{N,Char}};
    guesstype::Symbol = :expected,
    hardmode::Bool=true,
) where {N}
    return GamePool(pool, pool; guesstype, hardmode)
end

function GamePool(pool::AbstractVector{<:AbstractString}; guesstype::Symbol=:expected, hardmode::Bool=true)
    N = length(first(pool))
    if any(≠(N) ∘ length, pool)
        throw(ArgumentError("`pool` elements must have the same length"))
    end
    return GamePool(NTuple{N,Char}.(pool); guesstype, hardmode)
end

function GamePool(
    pool::AbstractVector;
    guesstype::Symbol=:expected,
    hardmode::Bool=true,
)
    return GamePool(string.(pool); guesstype, hardmode)
end

"""
    bincounts!(counts, active, scorevec)

Return `probs` overwritten with bin probabilities from `scorevec[active]`.
`counts` is also overwritten, with the bin counts.
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
    entropybase2(probs::AbstractVector{<:AbstractFloat})
    entropybase2(gp::GamePool)

Return the base-2 entropy of `probs` or `gp.probs`.  This is the entropy measured in bits.

See https://en.wikipedia.org/wiki/Entropy_(information_theory) for the definition
of entropy in information theory.

`probs` is assumed to be a discrete probability distribution.  That is
all(0 .≤ probs .≤ 1) && sum(probs) ≈ 1 are assumed but not checked.
"""
function entropybase2(probs::AbstractVector{<:AbstractFloat})
    return -sum(x -> iszero(x) ? zero(eltype(probs)) : x * log2(x), probs)
end

entropybase2(gp::GamePool) = entropybase2(gp.probs)

"""
    expectedpoolsize!(gp::GamePool)

Update `gp.probs` from `gp.counts` and return the expected pool size.
"""
function expectedpoolsize!(gp::GamePool)
    (; counts, probs) = gp
    nactive = sum(counts)
    probs .= counts ./ nactive
    return sum(abs2, counts) / nactive
end

"""
    gamesummary(gp::GamePool)

Return a summary of a game as a columntable (i.e. a `NamedTuple` of `Vector`s of the same length).
"""
function gamesummary(gp::GamePool{N}) where {N}
    (; guessinds, scores) = gp
    length(scores) == length(guessinds) || throw(ArgumentError("Game gp is not finished."))
    return (;                      # columntable as a NamedTuple
        guess=[string(g...) for g in gp.guesses],
        score=tiles.(scores, N),
        poolsize=gp.poolsizes,
        expected=gp.expected,
        entropy=gp.entropy,
    )
end

"""
    playgame!(gp::GamePool, ind::Integer)
    playgame!(gp::GamePool[, rng::AbstractRNG])

Return `gp` after playing a game with target `gp.targetpool[ind]`, or a randomly chosen target
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
        deleteat!(gp.entropy, trailing)
    end
    empty!(gp.scores)
    return gp
end

"""
    score(guess, target)

Return a generalized Wordle score for `guess` at `target`, as an `Int` in `0:((3^length(zip(guess,target))) - 1)`.

In Wordle both `guess` and `target` would be length-5 character strings and each position
in `guess` is scored as green if it matches `target` in the same position, yellow if it
matches `target` in another position, and gray if there is no match. This function returns
such a score as a number whose base-3 representation is 0 for no match, 1 for a match in
another position and 2 for a match in the same position.  See `tiles` for converting this
numeric score to colored tiles.
"""
function score(guess, target)
    s = 0
    for (g, t) in zip(guess, target)
        s *= 3
        s += (g == t ? 2 : Int(g ∈ target))
    end
    return s
end

score(gp::GamePool, targetind::Integer) = gp.allscores[targetind, last(gp.guessinds)]

"""
	scoretype(nchar)

Return the smallest type `T<:Unsigned` for storing the scores from a pool of items of length `nchar`
"""
function scoretype(nchar)
    if nchar > 80
        error("pool element length = $nchar must be < 80")
    end
    unsignedtypes = [UInt8, UInt16, UInt32, UInt64, UInt128]
    return unsignedtypes[findfirst(>(nchar), log.(3, typemax.(unsignedtypes)))]
end

"""
    scoreupdate!(gp::GamePool, sc::Integer)

Update `gp` with the score `sc`
"""
function scoreupdate!(gp::GamePool, sc::Integer)
    (; allscores, active, counts, probs, guessinds) = gp
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
    showgame!(gp::GamePool[, target])

Return a `pretty_table` of the summary of `playgame!(gp, target)))`.
"""
function showgame!(gp::GamePool, target)
    return pretty_table(gamesummary(playgame!(gp, target)))
end

showgame!(gp::GamePool) = showgame!(gp, rand(gp.targetpool))

"""
	tiles(score, ntiles)

Return a length-`ntiles` `String` tile pattern from the numeric score `score`.
"""
function tiles(sc, ntiles)
    result = Char[]    # initialize to an empty array of Char
    for _ in 1:ntiles  # _ indicates we won't use the counter
        sc, r = divrem(sc, 3)
        push!(result, iszero(r) ? '🟫' : (isone(r) ? '🟨' : '🟩'))
    end
    return String(reverse(result))
end

"""
    updateguess!(gp::GamePool)

Choose the optimal guess according to `gp.guesstype` and push! new values onto `gp.guesses`,
`gp.guessinds`, `gp.expected` and `gp.entropy`
"""
function updateguess!(gp::GamePool)
    (; guesspool, active, counts, probs, guesses, guessinds, poolsizes, expected, entropy, guesstype) = gp
    gind, xpctd, entrpy = 0, Inf, -Inf
    if guesstype == :expected
        for (k, a) in enumerate(active)
            if a
                thisexpected = expectedpoolsize!(bincounts!(gp, k))
                if thisexpected < xpctd
                    gind, xpctd, entrpy = k, thisexpected, entropybase2(gp)
                end
            end
        end
    elseif guesstype == :entropy
        for (k, a) in enumerate(active)
            if a
                expectedpoolsize!(bincounts!(gp, k))  # updates probs
                thisentropy = entropybase2(gp)
                if thisentropy > entrpy
                    gind, xpctd, entrpy = k, sum(counts .* probs), thisentropy
                end
            end
        end
    else
        throw(error("gp.guesstype = $(gp.guesstype) should be `:expected` or `:entropy`"))
    end
    push!(guesses, guesspool[gind])
    push!(guessinds, gind)
    push!(poolsizes, sum(active))
    push!(expected, xpctd)
    push!(entropy, entrpy)
    return gp
end
