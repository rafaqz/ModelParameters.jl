
# A Tables.jl interface for AbstractModel

Tables.istable(::AbstractModel) = true
Tables.columnnames(m::AbstractModel) = keys(m)
Tables.schema(m::AbstractModel) = Tables.Schema(Tables.columnnames(m), _columntypes(m))

_columntypes(m) = map(k -> Union{map(typeof, getindex(m, k))...}, keys(m)) 

# As Columns
Tables.columnaccess(::Type{<:AbstractModel}) = true
Tables.columns(m::AbstractModel) = m
Tables.getcolumn(m::AbstractModel, nm::Symbol) = collect(getindex(m, nm))
Tables.getcolumn(m::AbstractModel, i::Int) = collect(getindex(m, i))
Tables.getcolumn(m::AbstractModel, ::Type{T}, col::Int, nm::Symbol) where T = 
    collect(getindex(m, nm))

# As rows
Tables.rowaccess(::Type{<:AbstractModel}) = true
# Vector of NamedTuple already has a row interface defined,
# so we take a shortcut and return that.
Tables.rows(m::AbstractModel) = [nt for nt in map(fields, params(m))]
