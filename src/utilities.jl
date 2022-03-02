"""
    hasdups(guess::NTuple{N,Char}) where {N}

Returns `true` if there are duplicate characters in `guess`.
"""
function hasdups(guess::NTuple{N,Char}) where {N}
    @inbounds for i in 1:(N - 1)
        gi = guess[i]
        for j in (i + 1):N
            gi == guess[j] && return true
        end
    end
    return false
end

"""
    scorecolumn!(col, guess::NTuple{N,Char}, targets::AbstractVector{NTuple{N,Char}})

Return `col` updated with the scores of `guess` on each of the elements of `targets`

If there are no duplicate characters in `guess` a simple algorithm is used, otherwise
the more complex algorithm that accounts for duplicates is used.
"""
function scorecolumn!(
    col::AbstractVector{<:Integer},
    guess::NTuple{N,Char},
    targets::AbstractVector{NTuple{N,Char}},
) where {N}
    if axes(col) ≠ axes(targets)
        throw(DimensionMismatch("axes(col) = $(axes(col)) ≠ $(axes(targets)) = axes(targets)"))
    end
    if hasdups(guess)
        svec = Vector{Int}(undef, N)         # scores for characters in guess
        unused = trues(N)                    # has a character in targets[i] been used
        @inbounds for i in axes(targets, 1)
            sc = 0                           # integer value of score
            targeti = targets[i]
            for j in 1:N                 # first pass checking for target in same position
                if guess[j] == targeti[j]
                    unused[j] = false
                    svec[j] = 2
                else
                    unused[j] = true
                    svec[j] = 0
                end
            end
            for j in 1:N                 # second pass for match in unused position
                sc *= 3
                svj = svec[j]
                if iszero(svj) && guess[j] ∈ targeti[unused]
                    sc += 1
                    unused[j] = false
                else
                    sc += svj
                end
            end
            col[i] = sc
        end
    else                                 # simplified algorithm for guess w/o duplicates
        @inbounds for i in axes(targets, 1)
            sc = 0
            targeti = targets[i]
            for j in 1:N
                sc *= 3
                gj = guess[j]
                sc += (gj == targeti[j] ? 2 : gj ∈ targeti)
            end
            col[i] = sc
        end
    end
    return col
end

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
	tiles(score::Integer, ntiles::Integer)
    tiles(svec::AbstractVector{<:Integer})

Return a length-`ntiles` `String` tile pattern from the numeric score `score`.
"""
function tiles(sc::Integer, ntiles)
    result = sizehint!(Char[], ntiles)    # initialize to an empty array of Char
    for _ in 1:ntiles                     # _ indicates we won't use the value of the iterator
        sc, r = divrem(sc, 3)
        push!(result, iszero(r) ? '🟫' : (isone(r) ? '🟨' : '🟩'))
    end
    return String(reverse(result))
end
