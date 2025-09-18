# params method interface
"""
    $SIGNATURES

Returns the parameters of the given `obj` as (possibly nested) named tuple of `Param`s or the given
`PT<:AbstractParam` type.

!!! caution
    `params` is not type stable on deeply nested structures and thus should not be used in performance-critical code.
    For these cases, it is recommended to either (a) call `params` outside of the performance-critical code and pass it in
    or (b) to use `flatparams` instead.
"""
params(::NamedTuple{()}; kwargs...) = (;) # base case
params(obj; kwargs...) = params(Param, obj; kwargs...)
params(xs::Tuple; kwargs...) = map(x -> params(Param, x; kwargs...), xs)
params(param::Union{Number,AbstractArray}; kwargs...) = params(Param, param; kwargs...)
params(param::PT; kwargs...) where {PT<:AbstractParam} = params(PT, param; kwargs...)
params(::Type{PT}, ::NamedTuple{()}; kwargs...) where {PT<:AbstractParam} = (;) # base case
params(::Type{PT}, xs::Tuple; kwargs...) where {PT<:AbstractParam} = map(x -> params(PT, x; kwargs...), xs)
params(::Type{PT}, obj; kwargs...) where {PT<:AbstractParam} = selectrecursive(x -> isa(x, AbstractParam), map(val -> params(PT, val; kwargs...), ConstructionBase.getproperties(obj)))
params(::Type{PT}, param::AbstractParam; kwargs...) where {PT<:AbstractParam} = PT(merge(parent(param), kwargs))
params(::Type{PT}, x::Union{Number,AbstractArray}; kwargs...) where {PT<:AbstractParam} = PT(x; kwargs...)
# params for specific properties
params(::Type{PT}, obj::T, ::Val{propname}; kwargs...) where {PT<:AbstractParam,T,propname} = params(PT, getproperty(obj, propname); merge((; kwargs...), (type=T,),)...)

# setrecursive

"""
    $SIGNATURES

Recurisvely sets the properties of the given (possibly nested) object `obj` to `values`. If `values` is a `NamedTuple`,
the nested structure must match that of `obj`.
"""
setrecursive(obj, value) = value
setrecursive(obj::AbstractParam, value) = update(obj, Tuple(value))
setrecursive(obj::AbstractParam, values::NamedTuple{keys,V}) where {keys,V<:Tuple} = update(obj, values)
setrecursive(obj::NamedTuple{keys,V}, values::NamedTuple{keys,V}) where {keys,V<:Tuple} = values
@generated function setrecursive(obj, values::NamedTuple{keys}) where {keys}
    recursive_calls = map(k -> :(setrecursive(obj.$k, values.$k)), keys)
    quote
        # recursively call reconstruct for all keys specified in values
        patchvals = tuple($(recursive_calls...))
        # construct a named tuple with the reconstructed values and apply with setproperties
        patch = NamedTuple{keys}(patchvals)
        return ConstructionBase.setproperties(obj, patch)
    end
end

"""
    $SIGNATURES

Recursively filters out all values from a (possibly nested) named tuple `nt` for which `selector` returns true.
"""
selectrecursive(selector, x) = selector(x) ? x : nothing
selectrecursive(selector, xs::Tuple) = map(x -> selectrecursive(selector, x), xs)
function selectrecursive(selector, nt::NamedTuple)
    # recursively apply selector
    new_nt = map(x -> selectrecursive(selector, x), nt)
    # filter out all nothing values
    selected_keys = filter(k -> !isnothing(new_nt[k]), keys(new_nt))
    # construct named tuple from filtered keys or return nothing if no keys were selected
    return length(selected_keys) > 0 ? NamedTuple{selected_keys}(map(k -> new_nt[k], selected_keys)) : nothing
end
