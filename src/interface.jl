"""
    params(object)
    params(model::AbstractModel)

Returns a tuple of all `Param`s in the model or arbitrary object.
"""
function params end

"""
    printparams(object)
    printparams(io, object)

Prints a table of all `Param`s in the object, similar to what
is printed in the repl for `AbstractModel`.
"""
function printparams end

"""
    stripparams(object)

Strips all `AbstractParam` from an object, replacing them with the `val` 
field, or a combination of `val` and `units` if a `units` field exists.
"""
function stripparams end

"""
    update!(m::MutableModel, table)

Update the model in-place from an object that implements the Tables.jl interface.

Note: the parent object can absolutely be immutable, it will be completely rebuild. 
But the wrapper `AbstractModel` must be mutable, such as `Model` or `InteractModel`.
"""
function update! end

"""
    update(m::StaticModel, table)

Update the model from an object that implements the Tables.jl interface,
returning a new, updated object.
"""
function update end

"""
    uval(object)
    uval(model::AbstractModel)

Returns a tuple of the values of all `Param`s in the model or object. If there is a 
`units` field the model value will be a combination of of `val` and `units` fields
, otherwise just the `val` field.

`units` fields contianing `nothing` are ignored, and the `val` alone is returned.
"""
function uval end
