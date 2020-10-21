
# Tables.jl interface

Tables.istable(::AbstractModel) = true
Tables.rowaccess(::Type{<:AbstractModel}) = true
Tables.columnaccess(::Type{<:AbstractModel}) = true
# Vector of NamedTuple already has a row interface defined,
# so we take a shortcut and just return that.
Tables.rows(m::AbstractModel) = [x for x in map(fields, flatparams(m))]
Tables.columns(m::AbstractModel) = m
Tables.getcolumn(m::Tuple{<:AbstractParam,Vararg{<:AbstractParam}}, nm::Symbol) = param(m, nm)
Tables.getcolumn(m::AbstractModel, i::Int) = param(m, i)
Tables.getcolumn(m::AbstractModel, ::Type{T}, col::Int, nm::Symbol) where {T} = param(m, nm)

Tables.columnnames(m::AbstractModel) = keys(firstparams(m))
Tables.schema(m::AbstractModel) =
    Tables.Schema(Tables.columnnames(m), map(typeof, firstparam(m)...))
