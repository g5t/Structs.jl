
function replacestructkeysintuple{T<:AbstractString}(s::AbstractStruct,et::Tuple{Vararg{T}})
    # we know the delimiter that s expects. should we only check values that start with it?
    possiblekey=[map(x->length(x)>1?x[1]==s.d:false,et)...] # the minimum key length is 2 (delim,name), s.d is a char, x[1] is a char
    foreach(x->possiblekey[x]=haskey(s,et[x]),find(possiblekey)) # now possiblekey == iskey
    for i in find(possiblekey) # iterate over valid keys
        et=(et[1:i-1]...,string(s[et[i]]),et[i+1:end]...) # and replace them by their string values
    end
    return et::Tuple{Vararg{T}}
end
evalstructkeystuple{T<:AbstractString}(s::AbstractStruct,et::Tuple{Vararg{T}})=eval(parse(prod(replacestructkeysintuple(s,et))))
