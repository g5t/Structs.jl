thislevelstructkeys(s::AbstractValue)=[]
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
        tlsl[i]=isa(tkv,AbstractValue)?length(fullname):maximumkeylength(tkv,fullname)
    end
    return maximum(tlsl)
end

function showstruct(io::IO,s::AbstractStruct,mkl::Integer,pre="")
    tlsk=thislevelstructkeys(s)
    isempty(tlsk)&&(return nothing)
    for tk in tlsk
        tkv=s.dict[tk]
        #pre*=string(s.d)*"$tk"
        if isa(tkv,AbstractValue)
            name=string(s.d)*"$tk"
            spaces=" "^(mkl-length(pre)-length(name))
            println(io,pre*name*spaces*" = $tkv")
        else
            showstruct(io,tkv,mkl,pre*string(s.d)*"$tk")
        end
    end
end
Base.show(io::IO,s::AbstractValue)=Base.show(io,s.value)
Base.showcompact(io::IO,s::AbstractValue)=Base.showcompact(io,s.value)
Base.show(io::IO,s::AbstractStruct)=(println(io,typeof(s));showstruct(io,s,maximumkeylength(s," ")," "))
Base.showcompact(io::IO,s::AbstractStruct)=showstruct(io,s,maximumkeylength(s))

Base.get(s::AbstractStruct,key,def)=structhaskey(s,key)?getkey(s,key):def
Base.haskey(s::AbstractStruct,key)=structhaskey(s,key)
Base.getindex(s::AbstractStruct,key::AbstractString)=structhaskey(s,key)?getkey(s,key):throw(BoundsError())
Base.setindex!(s::AbstractStruct,val,key::AbstractString)=insertkeyval!(s,key,val)
Base.getindex(s::AbstractStruct,key::Symbol...)=structhaskey(s,key)?getkey(s,key):throw(BoundsError())
Base.setindex!(s::AbstractStruct,val,key::Symbol...)=insertkeyval!(s,key,val)
