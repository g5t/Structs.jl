# The CIF standard is, essentially, a special form of the Struct:
#   It always uses '_' as a delimiter,
#   One CIF file can contain multiple 'data_' blocks, each of which is a Struct
#   Each 'data_' struct is named.

type CIFdata
    name::AbstractString
    dict::Struct{Any}
    CIFdata(n::AbstractString="data",d::Struct{Any}=Struct{Any}('_'))=new(n,d)
end
# We need special versions of show*,get*,set*,has* for CIFdata that push
# everything onto the dict field.
function showCIFdata(io::IO,cif::CIFdata,compact::Bool)
#    compact||println(io,typeof(cif))
    println(io,cif.name)
    pad=compact?"":" "
    showstruct(io,cif.dict,maximumkeylength(cif.dict,pad),pad)
end
Base.show(io::IO,cif::CIFdata)=showCIFdata(io,cif,false)
Base.showcompact(io::IO,cif::CIFdata)=showCIFdata(io,cif,true)
Base.get(s::CIFdata,key,def)=structhaskey(s.dict,key)?getkey(s.dict,key):def
Base.haskey(s::CIFdata,key)=structhaskey(s.dict,key)
Base.getindex(s::CIFdata,key::AbstractString)=structhaskey(s.dict,key)?getkey(s.dict,key):throw(BoundsError())
Base.setindex!(s::CIFdata,val,key::AbstractString)=insertkeyval!(s.dict,key,val)
Base.getindex(s::CIFdata,key::Symbol...)=structhaskey(s.dict,key)?getkey(s.dict,key):throw(BoundsError())
Base.setindex!(s::CIFdata,val,key::Symbol...)=insertkeyval!(s.dict,key,val)

# handle loading from a CIF formatted file:

function splitCIFline(line::AbstractString)
  line=replace(line,"\n"," ")
  # first deal with quoted strings within the line:
  quotedrgx=r"(?<!['\"])(['\"])(.*?)(\1)"
  #quotedrgx=r"(['\"])(.*?)(\1)" # matches pairs of ' or " capturing anything inbetween in captures[2]
  if (hasquotes=ismatch(quotedrgx,line))
    quotes=matchall(quotedrgx,line);
    for i=1:length(quotes)
      quotes[i]=match(quotedrgx,line).captures[2]
      line=replace(line,quotedrgx,"quote#$i",1) # replace at most 1 occurance
    end
  end
  keysvals=split(line) # now with quoted strings replaced by "quote#N"
  keyba=ismatch.(r"^_",keysvals) # likely [true, false ... false]
  keys=keysvals[keyba]
  vals=keysvals[.!keyba]
  if hasquotes
    quoteNrgx=r"^quote#([0-9]+)"
    for i=1:length(vals)
      if ismatch(quoteNrgx,vals[i])
        quoteN=parse(Int,match(quoteNrgx,vals[i]).captures[1])
        vals[i]=quotes[quoteN]
      end
    end
  end
  isempty(keys) && (keys=[""])
  isempty(vals) && (vals=[""])
  return (keys,vals)
end

function loadCIF(ciffile::AbstractString)
  # read in the whole CIF file at once, removing blank lines
  lines=filter(x->!ismatch(r"^\s*$",x) ,readlines(ciffile)) # readlines now cuts endlines and carriage returns by default
  # check if this is a CIF or CIF2 file:
  iscif2= lines[1]=="#\\#CIF_2.0" # === #\#CIF_2.0 in the file, since the \ gets escaped when read
  # strip-out comment lines (those starting with #)
  lines=filter(x->!ismatch(r"^\s*#",x),lines)

  # CIF allows for "save frames" to exist in dictionary files
  # but not in data files. Since, at least for now, we are not
  # using dictionary files, throw an error if passed one:
  @assert all(x->!ismatch(r"^(?i)save_",x),lines) "save_ frames are only allowed in CIF dictionary files"
  @assert all(x->!ismatch(r"(?i)stop_",x),lines) "nested loops are not allowed in CIF files"
  @assert all(x->!ismatch(r"(?i)global_",x),lines) "The STAR global_ keyword is not allowed in CIF files"

  # do multi-line parsing depending on which version of CIF is required
  cif1regex=[r"^;",r"^;$"]
  cif2regex=[r"^(['\"])(\1){2}",r"^(['\"])(\1){2}$"] # match ''' or """ but not mixed cases
  lines=collapsemultilines(lines, iscif2?cif2regex:cif1regex)
  iscif2 && warn("CIF2.0 disallows mid-delimited value delimeters. This code does not check for them.")

  isloop=ismatch.(r"^loop_",lines)

  # CIF allows for multiple data blocks to be present in a single file
  dlocf=find(ismatch.(r"^(i?)data_",lines)) # first line to start each data block parsing
  dlocl=vcat(dlocf[2:end]-1,length(lines)) # last line to include in each data block parsing
  allcif=[handleonedatablock(lines,f,l,isloop) for (f,l) in zip(dlocf,dlocl) ]
  length(allcif)==1 ? allcif[1] : allcif
end

function collapsemultilines(lines,rgxs)
  mls=find(ismatch.(rgxs[1],lines)) # contains both starting and ending delims
  mle=find(ismatch.(rgxs[2],lines))# contains only ending delimiters
  mls=setdiff(mls,mle) # returns the elements of mls that are not in mle
  if isempty(mls)
    # all starting lines are also ending lines; e.g. ";" by itself for CIF v1
    # so hope that they indicate [start,stop,start,stop,...]
    mls=mle[1:2:end]
    mle=mle[2:2:end]
  end
  mlr=map(colon,mls,mle)
  nml=collect(1:length(lines))
  for mli in mlr; nml=setdiff(nml,mli); end
  bth=vcat(nml,mlr)
  bth=bth[sortperm( map(minimum,bth) )]
  newlines=similar(lines,length(nml)) # multi-line values always start on the line after their dataname
  j=1;
  for i=1:length(newlines)
    if j+1<=length(bth) && length(bth[j+1])>1 # the next line(s) are a multi-line quoted value
      newlines[i]=lines[bth[j]]*" '"*join(lines[bth[j+1][2:end-1]],"\n")*"'"
      j+=2
    else
      newlines[i]=lines[bth[j]]
      j+=1
    end
  end
  return newlines
end

function handleonedatablock{T<:AbstractString}(lines::Array{T},start_loc::Integer,stop_loc::Integer,isloop)
    thiscif=CIFdata(lines[start_loc]) # create a CIFdata Struct with name given by lines[start_loc]
    i=start_loc+1; lastdelim=""
    while i<=stop_loc
        if isloop[i]
            i+=parseCIFloop!(thiscif.dict,lines[i:stop_loc],1)-1
        else
            (k,v)=splitCIFline(lines[i])
            if length(k)==1 && !isempty(k[1]) && length(v)==1
            insertkeyval!(thiscif.dict,k[1],v[1])
            lastdelim=k[1][1]
            else
                warn("Can not decipher $(lines[i])")
            end
            i+=1
        end
    end
    return thiscif
end

function parseCIFloop!{T<:AbstractString}(c::Struct,lines::AbstractVector{T},i::Integer)
  # i points to an entry in lines that is "loop_"
  j=i+1 # first line of looped keys
  lastkey=false
  while !lastkey && j<=length(lines)
    (k,v)=splitCIFline(lines[j])
    k1e=isempty(k[1]); v1e=isempty(v[1])
    if !k1e && v1e
      j+=1
    elseif k1e && !v1e
      lastkey=true
    else
      throw(error("Expected one key or some value(s) in $j:$(lines[j])"))
    end
  end # j points to the first line *without* a key
  nkeys=j-i-1 # the number of keys, and therefore values per line
  keys=Array{AbstractString}(nkeys)
  for l=1:nkeys
    (k,v)=splitCIFline(lines[i+l])
    keys[l]=k[1]
  end
  # now deal with value line(s). we have no idea how many there are
  lastvals=false
  # j=i+nkeys+1 (no need to set this, as j hasn't be modified from line 86)
  while !lastvals && j<=length(lines)
    (k,v)=splitCIFline(lines[j])
    k1e=isempty(k[1]); v1e=isempty(v[1])||v[1]=="loop_" # a bad hack
    if !k1e || v1e
      lastvals=true
    elseif k1e && !v1e
      j+=1
    else
      throw(error("Expected exactly one key or value in $j:$(lines[j])"))
    end
  end # j points to the first line *without* any value(s)
  nvals=j-nkeys-i-1
  allvals=similar(keys,nvals,nkeys)
  for l=1:nvals
    (k,v)=splitCIFline(lines[i+nkeys+l])
    @assert length(v)==nkeys "Expected $nkeys values but found $(length(v)) in $(lines[i+nkeys+l])"
    for m=1:nkeys
      allvals[l,m]=v[m]
    end
  end
  for m=1:nkeys; insertkeyval!(c,keys[m],allvals[:,m]); end
  return j
end
