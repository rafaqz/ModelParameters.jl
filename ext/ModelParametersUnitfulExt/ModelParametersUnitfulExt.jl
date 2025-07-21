module ModelParametersUnitfulExt

using ModelParameters
using Unitful
using Setfield

ModelParameters.Param(val::Unitful.AbstractQuantity{<:Number}; kwargs...) = Param(ustrip(val); units=unit(val), kwargs...)
ModelParameters.RealParam(val::Unitful.AbstractQuantity{<:Real}; kwargs...) = RealParam(ustrip(val); units=unit(val), kwargs...)

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
