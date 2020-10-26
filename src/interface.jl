"""
    params(object)
    params(model::AbstractModel)

Returns a tuple of all `Param`s in the model or object.
"""
params

"""
    paramvals(object)
    paramvals(model::AbstractModel)

Returns a tuple of the values of all `Param`s in the model
or object. If there is a `units` field the model value will a 
combination of `val` and `units` fields.
"""
paramval

"""
    simplify(object)
    simplify(model::AbstractModel)

Strips all `AbstractParam` from the object, and for `AbstractModel` 
also removes the model wrapper.
"""
raw

"""
    update!(m::AbstractModel, table)
"""
update!


"""
    fields(p::Param)

Returns a `NamedTuple` of the parameter fields.
"""
fields
