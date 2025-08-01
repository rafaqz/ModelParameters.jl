"""
    params(object)
    params(model::AbstractModel)

Returns a tuple of all `AbstractParam`s or `AbstractRealParam`s in the model, or arbitrary object.
"""
function params end

"""
    constants(object)
    constants(model::AbstractModel)

Returns a tuple of all `Const`s in the model or arbitrary object.
"""
function constants end

"""
    printparams(object)
    printparams(io::IO, object)

Prints a table of all `AbstractParam`s or `AbstractRealParam`s in the object, 
similar to what is printed in the repl for `AbstractModel`.
"""
function printparams end

"""
    strip(object)

Strips all `AbstractParam`, `AbstractConst` from an object, replacing them with 
the `val` field, or a combination of `val` and `units` if a `units` field exists.
"""
function strip end

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
