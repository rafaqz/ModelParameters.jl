
# Tables.jl interface
Tables.istable(::AbstractModel) = true
Tables.columnnames(m::AbstractModel) = keys(first(params(m)))
Tables.schema(m::AbstractModel) =
    Tables.Schema(Tables.columnnames(m), map(typeof, first(params(m))...))

# As Columns
Tables.columnaccess(::Type{<:AbstractModel}) = true
Tables.columns(m::AbstractModel) = m
Tables.getcolumn(m::AbstractModel, nm::Symbol) = map(p -> getproperty(p, nm), params(m))
Tables.getcolumn(m::AbstractModel, i::Int) = map(p -> getindex(p, i), params(m))
Tables.getcolumn(m::AbstractModel, ::Type{T}, col::Int, nm::Symbol) where {T} = param(m, nm)

# As rows
Tables.rowaccess(::Type{<:AbstractModel}) = true
# Vector of NamedTuple already has a row interface defined,
# so we take a shortcut and return that.
Tables.rows(m::AbstractModel) = [nt for nt in map(fields, params(m))]
