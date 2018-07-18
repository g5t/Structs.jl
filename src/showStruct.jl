thislevelstructkeys(s::Value)=[]
thislevelstructkeys(s::AbstractStruct)=(tlsk=collect(Base.keys(s.dict));tlsk[sortperm(tlsk)])


#maximumkeylength(s::Value)=0
function maximumkeylength(s::AbstractStruct,pre="")
    tlsk=thislevelstructkeys(s)
    isempty(tlsk)&&(return 0)
    tlsl=Vector{Int64}(length(tlsk))
    for i=1:length(tlsk)
        tk=tlsk[i]
        fullname=pre*string(s.d)*"$tk"
        tkv=s.dict[tk]
        tlsl[i]=isa(tkv,Value)?length(fullname):maximumkeylength(tkv,fullname)
    end
    return maximum(tlsl)
end

function showstruct(io::IO,s::AbstractStruct,mkl::Integer,pre="")
    tlsk=thislevelstructkeys(s)
    isempty(tlsk)&&(return nothing)
    for tk in tlsk
        tkv=s.dict[tk]
        #pre*=string(s.d)*"$tk"
        if isa(tkv,Value)
            name=string(s.d)*"$tk"
            spaces=" "^(mkl-length(pre)-length(name))
            println(io,pre*name*spaces*" = $tkv")
        else
            showstruct(io,tkv,mkl,pre*string(s.d)*"$tk")
        end
    end
end
Base.show(io::IO,s::Value)=Base.show(io,s.value)
Base.showcompact(io::IO,s::Value)=Base.showcompact(io,s.value)
Base.show(io::IO,s::AbstractStruct)=(println(io,typeof(s));showstruct(io,s,maximumkeylength(s," ")," "))
Base.showcompact(io::IO,s::AbstractStruct)=showstruct(io,s,maximumkeylength(s))

Base.get(s::AbstractStruct,key,def)=structhaskey(s,key)?getkey(s,key):def
Base.haskey(s::AbstractStruct,key)=structhaskey(s,key)
Base.getindex(s::AbstractStruct,key::AbstractString)=structhaskey(s,key)?getkey(s,key):throw(BoundsError())
Base.setindex!(s::AbstractStruct,val,key::AbstractString)=insertkeyval!(s,key,val)
Base.getindex(s::AbstractStruct,key::Symbol...)=structhaskey(s,key)?getkey(s,key):throw(BoundsError())
Base.setindex!(s::AbstractStruct,val,key::Symbol...)=insertkeyval!(s,key,val)
Base.getindex(s::AbstractStruct,i::Integer)=s[collectstructkeys(s)[i]]
Base.setindex!(s::AbstractStruct,val,i::Integer)=Base.setindex!(s,val,collectstructkeys(s)[i])

function collectstructkeys(s::AbstractStruct,pre="")
    tlsk=thislevelstructkeys(s)
    out=Array{String}(0)
    isempty(tlsk) && (return out)
    for tk in tlsk
        tkv=s.dict[tk]
        fullname=pre*string(s.d)*"$tk"
        if isa(tkv,Value)
            push!(out,fullname)
        else
            out=vcat(out,collectstructkeys(tkv,fullname))
        end
    end
    return out
end
function countstructelements(s::AbstractStruct)
    count=0
    for (k,v) in s.dict
        count+= isa(v,Value)? 1 : countstructelements(v)
    end
    return count
end


Base.length(s::Struct)=countstructelements(s)
Base.start(s::Struct)=1
Base.done(s::Struct,i) =i>countstructelements(s)
Base.next(s::Struct{T},i) where T =(k=collectstructkeys(s)[i]; (Pair{String,T}(k,s[k]),i+1) )
