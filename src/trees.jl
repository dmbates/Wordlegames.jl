"""
    GameNode

Node type for tree representing game play on a `GamePool{N}`(@ref)

Fields are:

- `score`: a `GameScore`(@ref) for this target based on the score that generated the node
- `children`: `Vector{GameNode}` of children of this node
"""
struct GameNode
    score::GuessScore
    children::Vector{GameNode}
end

AbstractTrees.children(gn::GameNode) = gn.children

function AbstractTrees.printnode(io::IO, gn::GameNode)
    (; poolsz, guess, index, expected, entropy, score) = gn.score
    return join(
        IOContext(io, :compact => true),
        (score, guess, index, poolsz, entropy, expected),
        ", ",
    )
end

"""
    tree(gp::GamePool, inds::AbstractVector{<:Integer})
    tree(gp::GamePool{N}, targets::AbstractVector{NTuple{N,Char}})
    tree(gp::GamePool, targets::AbstractVector{<:AbstractString})
    tree(gp::GamePool)

Return the root `GameNode` of a tree of the result of `playgame!.(Ref(gp), inds)`

A `print_tree` method is available for this tree.
"""
function tree(gp::GamePool{N,S}, targetinds::AbstractVector{<:Integer}) where {N,S}
    (; guesspool) = reset!(gp)
    nguesspool = length(guesspool)
    rootguess = first(gp.guesses)
    rootindex = rootguess.index
    guessmap = Dict{Int,GuessScore}(rootindex => rootguess)
    pathmap = Dict{Int,Vector{Int}}()
    activeinds = sizehint!(BitSet(), nguesspool)
    for t in targetinds
        (; guesses) = playgame!(gp, t)
        inds = getfield.(guesses, :index)
        union!(activeinds, inds)
        for (j, k) in enumerate(inds)
            indviewj = view(inds, 1:j)
            @assert get!(pathmap, k, indviewj) == indviewj  # store or verify
            if j > 1
                (; poolsz, index, guess, expected, entropy) = guesses[j]
                (; score, sc) = guesses[j - 1]
                g = (; poolsz, index, guess, expected, entropy, score, sc)
                @assert get!(guessmap, k, g) == g           # store or verify
            end
        end
    end
    childmap = Dict(i => BitSet() for i in activeinds)
    # If we could do a PreOrderDFS on just the childmap we could add the parent to a GameNode
    # parentmap = Dict{Int, Union{Nothing,Int}}(rootindex => nothing)
    for path in getindex.(Ref(pathmap), activeinds)
        npath = length(path)
        npathm1 = npath - 1
        for i in 1:npathm1
            push!(childmap[path[i]], path[i + 1])
        end
        #=        
        if npath > 1
            parentmap[path[npath]] = path[npathm1]
        end
        =#
    end
    allnodes = [GameNode(guessmap[k], GameNode[]) for k in activeinds]
    inversemap = Dict(k => i for (i, k) in enumerate(activeinds))
    for (i, k) in enumerate(activeinds)
        for j in childmap[k]
            push!(allnodes[i].children, allnodes[inversemap[j]])
        end
    end
    return allnodes[inversemap[rootindex]]
end

function tree(gp::GamePool{N}, targets::AbstractVector{NTuple{N,Char}}) where {N}
    return tree(gp, [findfirst(==(t), gp.guesspool) for t in targets])
end

function tree(gp::GamePool{N}, targets::AbstractVector{<:AbstractString}) where {N}
    any(≠(N), length.(targets)) && throw(ArgumentError("all targets should have length $N"))
    return tree(gp, NTuple{N,Char}.(targets))
end

function tree(gp::GamePool, rng::AbstractRNG, n::Integer)
    vt = gp.validtargets
    return tree(gp, rand(rng, axes(vt, 1)[vt], n))
end

function tree(gp::GamePool)
    (; validtargets) = gp
    return tree(gp, view(axes(validtargets, 1), validtargets))
end
