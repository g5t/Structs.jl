abstract type Entry{T} <: AbstractStruct{T} end
type Struct{T} <: Entry{T}
    d::Char
    dict::Dict{Symbol,Entry{T}}
    Struct{R}(p::Char='/',pict::Dict{Symbol,Entry{R}}=Dict{Symbol,Entry{R}}()) where R = new(p,pict)
    function Struct{R}(p::AbstractString,pict::Dict{Symbol,Entry{R}}=Dict{Symbol,Entry{R}}()) where R
        @assert length(p)==1 "A Struct delimiter must be one character; got $(length(p)): "*join(p,",")
        new(p[1],pict)
    end
end
Struct(o...)=Struct{Any}(o...)
type Value{T} <: Entry{T}; value::T; end
Value(o...)=Value{Any}(o...)

""" splitkey(key::AbstractString)
Convert a delimited `String` key into its parts as `Vector{Symbol}`.
The delimiter is taken as the first character in `key`,
and repeated and trailing `delimiter`s in `key` are ignored.
"""
function splitkey(k::AbstractString)
    @assert ~isempty(k) "A key must start with its delimeter. (The key can not be empty.)"
    splitkey(k[1],k)
end
""" splitkey(delimiter::Char,key::AbstractString)
Convert a delimited `String` key into its parts as `Vector{Symbol}`.
If present, repeated and trailing `delimiter`s in `key` are ignored.
Typically a key should start with its delimeter, but this is not enforced.
"""
splitkey(d::Char,k::AbstractString)=Tuple(Symbol.(split(k,d,keep=false)))

""" insertkeyval!(struct::Struct,key,val)
Follows the path of the provided `key` to insert `val` into `struct`.
If `key` is an `AbstractString` it is first converted to a `Vector{Symbol}` via `splitkey(key)`.
"""
insertkeyval!(s::AbstractStruct,k::AbstractString,v)=insertkeyval!(s,splitkey(k),v)
function insertkeyval!{T,N,S<:Symbol}(s::Struct{T},keys::NTuple{N,S},subs::Struct{T})
    if N==1
        csubs = deepcopy(subs)
        csubs.d=s.d # copy the top-level delimiter :/ (doesn't help sub-sub-delimiters)
        s.dict[keys[1]]=csubs 
    else
        haskey(s.dict,keys[1])||(s.dict[keys[1]]=Struct{T}(s.d))
        insertkeyval!(s.dict[keys[1]],keys[2:N],subs)
    end
end
function insertkeyval!{T,N,S<:Symbol}(s::Struct{T},keys::NTuple{N,S},val::T)
    if N==1
        s.dict[keys[1]]=Value{T}(val)
    else
        haskey(s.dict,keys[1])||(s.dict[keys[1]]=Struct{T}(s.d))
        insertkeyval!(s.dict[keys[1]],keys[2:N],val)
    end
end
function insertkeyval!{T,N,S<:Symbol,R}(s::Struct{T},keys::NTuple{N,S},val::R)
  try insertkeyval!(s,keys,convert(T,val))
  catch
    throw(TypeError(:insertkeyval!,"Structs.jl, typed structures require same (or convertable) typed input",T,val))
  end
end

""" getkey(struct::AbstractStruct,key,default)
Returns the entry of `struct` described by `key` or `default` if it is not found.
If `key` is an `AbstractString` it is first converted to a `Vector{Symbol}` via `splitkey(key)`.
"""
getkey(s::Value,o...)=throw(error("getkey does not work on $(typeof(s)) objects"))
getkey(s::AbstractStruct,k::AbstractString,def=nothing)=getkey(s,splitkey(k),def)
function getkey{N,S<:Symbol}(s::AbstractStruct,k::NTuple{N,S},def=nothing)
    kval=getkey(s,k[1],def)
    N>1 && isa(kval,AbstractStruct) && (kval=getkey(kval,k[2:N],def))
    isa(kval,Value) && (kval=kval.value) # strip off the type wrapper if it is a Value object
    return kval
end
function getkey(s::AbstractStruct,k::Symbol,def=nothing)
  kval=get(s.dict,k,def)
  isa(kval,Value) && (kval=kval.value)
  return kval
end
getkey(s::AbstractStruct,k::Tuple{},def=nothing)=s # asking for the whole struct, s["/"] === s

""" structhaskey(struct,key)
Checks for the presence of an entry defined by `key` in `struct`.
If `key` is an `AbstractString` it is first converted to a `Vector{Symbol}` via `splitkey(key)`.
"""
structhaskey(s::Value,o...)=false # The Value type has no "keys"
structhaskey(s::AbstractStruct,k::AbstractString)=structhaskey(s,splitkey(k))
function structhaskey{N,S<:Symbol}(s::AbstractStruct,k::NTuple{N,S})
    flag=haskey(s.dict,k[1])
    if flag && N>1
        kval=getkey(s,k[1])
        flag=isa(kval,AbstractStruct)?structhaskey(kval,k[2:N]):false
    end
    return flag
end
structhaskey(s::AbstractStruct,k::Symbol)=haskey(s.dict,k)
structhaskey(s::AbstractStruct,k::Tuple{})=true # all structs have themselves, the empty Tuple key
