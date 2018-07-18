using Structs
using Base.Test

# simple stuff first:
@test Structs.splitkey("/this/is/a/long/key/")==(:this,:is,:a,:long,:key)
@test Structs.splitkey("ilikeike") == (:l,:ke,:ke)
@test Structs.splitkey('_',"specify_the/delimeter")==(:specify,Symbol("the/delimeter"))
@test Structs.splitkey("!shortkey")==(:shortkey,)

mytstruct=Struct{Float64}()
@test Structs.insertkeyval!(mytstruct,"!mynewkey",1.0).value == 1.0
@test mytstruct["/mynewkey"]==1.0
@test mytstruct[:mynewkey]==1.0

mytstruct["_multi_level_key"]=pi
@test Structs.structhaskey(mytstruct,"/multi/level/key")
@test Structs.structhaskey(mytstruct,(:multi,:level,:key))
@test mytstruct[:multi,:level,:key]≈pi
mytstruct[:multi,:level,:key2]=Inf
@test isinf(mytstruct["_multi"][:level]["_key2"])

@test mytstruct["/"]===mytstruct # accessing the "root" of a structure returns *the* structure
