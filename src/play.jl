"""
    GamePool

A struct that defines a Wordle-like game.
"""
struct GamePool
    pool::Vector
    allscores::Matrix{<:Unsigned}
    firstguess::Int
    firstexpectedpoolsize::Float64
    active::Vector{Bool}
    counts::Vector{Int}
    guess::Ref{Int}
    expectedpoolsize::Ref{Float64}
    lastscore::Ref{Int}
end

function GamePool(pool::AbstractVector{<:AbstractString})
    nchar = length(first(pool))
    if any(≠(nchar), length.(pool))
        throw(ArgumentError("pool elements are not all the same length"))
    end
        ## Use a Vector{NTuple} representation of pool to evaluate the allscores.
    tpool = NTuple{nchar, typeof(first(first(pool)))}.(pool)
    T = scoretype(nchar)
        ## Can this easily be adapted for multiple threads? `score` is pure.
    allscores = [T(score(g, t)) for t in tpool, g in tpool]
    npool = length(pool)
    active = ones(Bool, npool)
    counts = zeros(Int, 3 ^ nchar)
    sqrsum, guess = findmin(eachcol(allscores)) do col
        sum(abs2, bincounts!(counts, active, col))
    end
    esz = sqrsum / npool   # expected pool size for guess
    GamePool(pool, allscores, guess, esz, active, counts, Ref(guess), Ref(esz), Ref(typemax(Int)))
end

"""
    bincounts!(counts::Vector{<:Integer}, active::AbstractVector{Bool}, scorevec::AbstractVector{<:Integer})

Return `counts` overwritten with the bin counts from `scorevec[active]`
"""
function bincounts!(
    counts::Vector{<:Integer},
    active::AbstractVector{Bool},
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

nextguess(gp::GamePool) = gp.pool[gp.guess[]]

"""
    reset!(gp::GamePool)

Return `gp` with its `active`, `guess`, and `expectedpoolsize` fields reset to initial values.
"""
function reset!(gp::GamePool)
    fill!(gp.active, true)
    gp.guess[] = gp.firstguess
    gp.expectedpoolsize[] = gp.firstexpectedpoolsize
    return gp
end

function playgame(oracle::Function, gp::GamePool)
    reset!(gp)                         # start a new game
    (; pool, active, counts, expectedpoolsize) = gp
    gvec, tvec, svec, evec = String[], String[], Int[], Float64[]
    maxscore = length(counts) - 1
    nchar = length(first(pool))
    for _ in 1:6
        nguess = nextguess(gp)
        sc = oracle(nguess)
        push!(gvec, nguess)
        push!(tvec, tiles(sc, nchar))
        push!(svec, sum(active))
        push!(evec, expectedpoolsize[])
        sc == maxscore && break
		update!(gp, sc)
	end
	return DataFrame(guess = gvec, score = tvec, pool_size = svec, expected = evec)
end

function playgame(rng::AbstractRNG, gp::GamePool)
	playgame(Base.Fix2(score, rand(rng, gp.pool)), gp)
end

playgame(gp::GamePool) = playgame(Random.GLOBAL_RNG, gp)


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

function update!(gp::GamePool, sc::Integer)
    (; pool, allscores, active, counts, guess, expectedpoolsize, lastscore) = gp
    lastscore[] = sc
    active .&= (view(allscores, :, guess[]) .== sc)
    nactive = sum(active)
    toobig = abs2(nactive) + 1
    minsqr, g = findmin(axes(active, 1)) do j
        active[j] ? sum(abs2, bincounts!(counts, active, view(allscores, :, j))) : toobig
    end
    guess[] = g
    expectedpoolsize[] = minsqr / nactive
    return pool[guess[]], nactive, expectedpoolsize[]
end
