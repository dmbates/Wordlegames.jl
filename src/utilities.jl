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
