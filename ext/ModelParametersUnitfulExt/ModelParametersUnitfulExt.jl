module ModelParametersUnitfulExt

using ModelParameters
using Unitful
using Setfield

(::Type{PT})(val::Unitful.AbstractQuantity; kwargs...) where {PT<:AbstractParam} = PT(ustrip(val), units=unit(val), kwargs...)

"""
    Unitful.uconvert(u::Unitful.Units, p::Param)

Convert the unit of the `Param` `p` to `u`.
"""
function Unitful.uconvert(u::Unitful.Units, p::Param)
    nt = parent(p)
    @set! nt.val = ustrip(u, stripparams(p))
    @set! nt.units = u
    return Param(nt)
end

end
