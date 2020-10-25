
# A Tables.jl interface for AbstractModel

Tables.istable(::AbstractModel) = true
Tables.columnnames(m::AbstractModel) = keys(m)
Tables.schema(m::AbstractModel) =
    Tables.Schema(Tables.columnnames(m), _columntypes(m))

_columntypes(m) = map(keys(m)) do key
        Union{map(typeof, getproperty(m, key))...}
    end

# As Columns
Tables.columnaccess(::Type{<:AbstractModel}) = true
Tables.columns(m::AbstractModel) = m
Tables.getcolumn(m::AbstractModel, nm::Symbol) = getproperty(m, nm)
Tables.getcolumn(m::AbstractModel, i::Int) = map(p -> getindex(p, i), params(m))
Tables.getcolumn(m::AbstractModel, ::Type{T}, col::Int, nm::Symbol) where {T} = param(m, nm)

# As rows
Tables.rowaccess(::Type{<:AbstractModel}) = true
# Vector of NamedTuple already has a row interface defined,
# so we take a shortcut and return that.
Tables.rows(m::AbstractModel) = [nt for nt in map(fields, params(m))]
