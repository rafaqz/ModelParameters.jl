"""
    flatparams(object)
    flatparams(model::AbstractModel)

Returns a tuple of all `Param`s in the model or arbitrary object.
"""
function flatparams end

"""
    printparams(object)
    printparams(io::IO, object)

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

Note: the parent object can be immutable, it will be completely rebuilt. 
But the wrapper `AbstractModel` is mutable, such as `Model` or `InteractModel`.
"""
function update! end

"""
    update(m::AbstractModel, table)

Update the model from an object that implements the Tables.jl interface,
returning a new, updated object.
"""
function update end

"""
    withunits(object, [fieldname])
    withunits(model::AbstractModel, [fieldname])
    withunits(param::AbstractParam, [fieldname])

Returns the field specifed by `fieldname` (by default `:val`) for a single `Param`, 
or a tuple of the `Param`s in a `Model` or arbitrary object. 

If there is a `units` field the returned value will be a combination of the specied field 
and the `units` fields. 

If there is no units field or a specific `Param`s `units` fields contains `nothing`, 
the field value is returned unchanged.
"""
function withunits end

"""
    stripunits(model::AbstractModel, xs)
    stripunits(param::AbstractParam, x)

Returns the `x` or `xs` divided by their corresponding units field, if it exists.

It there is no units field, and x has units, it will be returned with units! It
you want to simply remove all units, using Unitful.ustrip.
"""
function stripunits end


# Low-level, non-exported interface

"""
    setparent!(model::MutableModel, x)

Internal interface method to define for custom `AbstractModel` with a different field
for `parent`.

Set the parent object. Must be defined if the parent field of an `AbstractModel`
is not `:parent`.
"""
function setparent! end

"""
    setparent(model::AbstractModel, x)

Internal interface method to define for custom `AbstractModel` with a different field
for `parent`.

Set the parent object and return the rebuilt model. Must be defined 
if the parent field of an `AbstractModel` is not `:parent`.
"""
function setparent end
