module Structs
"""
It is occasionally nice to arrange information in a hierarchy, not unlike a file structure.
The `AbstractStruct` has been created to enable this in `julia`, where the main element of
each `AbstractStruct` is a `julia` `Dict` that (possibly) contains additional `Dicts` depending
on the structure of its keys.
"""
abstract type AbstractStruct{T} end
include("defineStruct.jl")
include("defineCIF.jl")
include("evalStruct.jl")
include("showStruct.jl")

export Struct,TStruct,CIFdata,loadCIF,evalstructkeystuple
end # module
