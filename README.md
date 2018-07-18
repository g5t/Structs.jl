# Structs.jl

A Julia package for structured dictionary-like objects with arbitrary or typed contents.

Basic usage:
```julia
using Structs

# The Struct must be initialized.
any_struct=Struct()
# Keys into the interal dictionary are *always* Symbols
any_struct[:key1]="value1"
# But one can instead access them with structured strings
any_struct["/key2"]=222.2
# For a single level Struct this isn't very helpful, 
# but Struct objects can be nested
any_struct["/level0/level1/key3"] = extrema

show(any_struct)
```
Would result in the output
```julia
Structs.Struct{Any}
 /key1               = "value1"
 /key2               = 222.2
 /level0/level1/key3 = extrema
```


If statically typed structured data is preferred, one can specify it during construction:
```julia
using Structs

user_info_struct=Struct{String}('_')
user_info_struct["_name"] ="Jon Smyth"
user_info_struct["_phone"]="+1 555 123 4567"
user_info_struct["_address_street"]="1 Main St"
user_info_struct["_address_town"]="Anytown"
user_info_struct["_address_postcode"]="00000"

string_struct=Struct{String}('.')
string_struct[:user1]=user_info_struct

user_info_struct["_name"]="Jayne Smyth"
string_struct[:user2]=user_info_struct

show(string_struct)
```
Resulting in:
```julia
Structs.Struct{String}
 .user1.address_postcode = "00000"
 .user1.address_street   = "1 Main St"
 .user1.address_town     = "Anytown"
 .user1.name             = "Jon Smyth"
 .user1.phone            = "+1 555 123 4567"
 .user2.address_postcode = "00000"
 .user2.address_street   = "1 Main St"
 .user2.address_town     = "Anytown"
 .user2.name             = "Jayne Smyth"
 .user2.phone            = "+1 555 123 4567"
```
Note: The separator between Struct levels in the structured string key is defined at creation.
When a Struct is added to a parent Struct the child is added through a copy.
