
# A Tables.jl interface for AbstractModel

Tables.istable(::AbstractModel) = true
Tables.columnnames(m::AbstractModel) = keys(m)
Tables.schema(m::AbstractModel) = Tables.Schema(Tables.columnnames(m), _columntypes(m))

_columntypes(m) = map(k -> Union{map(typeof, getindex(m, k))...}, keys(m)) 

# As Columns
Tables.columnaccess(::Type{<:AbstractModel}) = true
Tables.columns(m::AbstractModel) = m
Tables.getcolumn(m::AbstractModel, nm::Symbol; kw...) = collect(getindex(m, nm; kw...))
Tables.getcolumn(m::AbstractModel, i::Int; kw...) = collect(getindex(m, i; kw...))
Tables.getcolumn(m::AbstractModel, ::Type{T}, col::Int, nm::Symbol; kw...) where T = 
    collect(getindex(m, nm; kw...))
