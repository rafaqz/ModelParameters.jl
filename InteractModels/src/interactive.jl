const SLIDER_STEPS = 500
const MAX_COLUMNS = 3

"""
    InteractModel(f, model)

An [`AbstractModel`](@ref) that generates its own Interact.jl interface.
Each model [`Param`](@ref) has a slider generated for it to update the model.
After any slider updates the user-defined function `f` is passed the updated
model to generate a new output - anything that will display in a WebIO.jl
node, like a Plots.jl plot

After any slider changes, the parent model is updated, so that `parent(model)`
will return it's latest state.

## Arguments

- `f`: a function that take the model object as an argument, but with
  `Param` fields replaced with their values. Usually a `do` block.
- `model`: any object with [`Param`](@ref)s objects in some fields.

## Param fields

`Param` objects in the model need to include a `range` or `bounds`
field to define the slider range - holding an `AbsractRange` or `NTuple{2}`, respectively.

Optionally, the `Param`s can also include:
- A `label` field to use instead of field names
- A `desciption` field to use in mouse hover text

## Keyword Arguments

- `title`: `""` set a window title, if you need it.
- `submodel`: `Nothing`. `Type` or `Union` that will group sliders into labeled subsections.
- `throttle`: `0.1`. Slider throttle, in seconds. Adjust to improve performance.
- `layout`: `vbox`. This can be any three-argument function that will combine title,
  output, and sliders (all WebIO nodes) into a combined WebIO node. You can use this
  method to do any additional layout you need.

## Example

This is a simple example where the model is a `NamedTuple`, adapted from
an Interact.jl example. It will display in atoms plot pane:

```julia
using InteractModels, Interact, ColorSchemes, Colors

color(i) = Colors.hex(colors[i%length(colors)+1])
colors = ColorSchemes.viridis
width, height = 700, 300
nsamples = 256

model = (;
    sample_step=Param(val=0.05, range=0.01:0.001:0.1, label="Sample step"),
    phase=Param(val=0.0, range=0:0.1:2pi, label="Phase"),
    radii=Param(val=20,range=0:0.1:60, label="Radus")
)

ui = InteractModel(model; submodel=Nothing, throttle=0.1) do m
    cxs_unscaled = [i * m.sample_step + m.phase for i in 1:nsamples]
    cys = sin.(cxs_unscaled) .* height/3 .+ height/2
    cxs = cxs_unscaled .* width/4pi
    c = (dom"svg:circle[cx=\$(cxs[i]), cy=\$(cys[i]), r=\$(m.radii), fill=#\$(color(i))]"()
         for i in 1:nsamples)
    return dom"svg:svg[width=\$width, height=\$height]"(c...)
end
```
"""
mutable struct InteractModel{F,SM,L,Ti,Th} <: AbstractModel
    f::F
    parent::Any
    submodel::SM
    layout::L
    title::Ti
    throttle::Th
    ui::Any
    function InteractModel(
        f::F, parent; layout::L=vbox, ncolumns=nothing, submodel::SM=Nothing, 
        title::Ti="", throttle::Th=0.1
    ) where {F,SM,L,Ti,Th}
        # Partially construct model
        model = new{F,SM,L,Ti,Th}(f, parent, submodel, layout, title, throttle, undef)

        # Initialise an observable output object
        output = Observable(f(parent))

        # Generate sliders and update the model and output when they change
        sliders = attach_sliders!(f, model;
            ncolumns=ncolumns, submodel=submodel, throttle=throttle, obs=output
        )

        # Define the complete user interface
        setfield!(model, :ui, layout(dom"h1"(title), output, sliders))

        return model
    end
end
InteractModel(f, model::Model; kwargs...) = InteractModel(f, parent(model); kwargs...)

ui(m::InteractModel) = getfield(m, :ui)

Base.getproperty(m::InteractModel, key::Symbol) = getindex(m, key::Symbol)
Base.setproperty!(m::InteractModel, key::Symbol, x) = setindex!(m, x, key::Symbol)
Base.display(m::InteractModel) = display(ui(m))

@WebIO.register_renderable(InteractModel) do m
    ui(m)
end


"""
    attach_sliders!(f, model::AbstractModel; submodel=false, throttle=0.1)
    attach_sliders!(model::AbstractModel; submodel=false, throttle=0.1, f=identity)

Internal method that may be useful for creating custom interfaces like `InteractModel`,
without actually using `InteracModel` directly. This interface will be less stable than
`InteractModel`.

Create sliders and attach them to the model so it will be updated when they are moved.

## Arguments

- `f`: a function that accepts the model, stripped of `Param` wrappers, with a return value
  that sets the observable `obs`. Usually this converts it to a plot or other web output.
- `model`: a [`AbstractModel`](@ref)

## Keyword Arguments

- `throttle`: `0.1` - sliders response time, in seconds.
- `submodel`: `Nothing`. `Type` or `Union` that will group sliders into labeled subsections.
- `obs`: An optional observable to be updated when sliders change

Returns a `vbox` holding the slider widgets.
"""
function attach_sliders!(f, model::AbstractModel; kwargs...)
    attach_sliders!(model; kwargs..., f=f)
end
function attach_sliders!(model::AbstractModel;
    ncolumns=nothing, submodel=Nothing, throttle=0.1, obs=nothing, f=identity
)
    length(params(model)) == 0 && return hbox()

    sliderbox = if submodel === Nothing
        objpercol = 3
        sliders, slider_obs = param_sliders(model; throttle=throttle)
        _in_columns(sliders, ncolumns, objpercol)
    else
        objpercol = 1
        sliders, slider_obs = group_sliders(f, model, submodel, obs, throttle)
        _in_columns(sliders, ncolumns, objpercol)
    end

    length(slider_obs) == 0 && return hbox()

    # `map` combining Observables is a little odd, *all* sliders here are splatted to `s`
    combined_obs = map((s...) -> s, slider_obs...)
    if length(sliders) > 0
        on(combined_obs) do values
            try
                model[:val] = stripunits(model, values)
                if obs isa Observable
                    obs[] = f(model)
                end
            catch e
                println(stdout, e)
            end
        end
    end

    return sliderbox
end

function _in_columns(objects, ncolumns, objpercol)
    nobjects = length(objects)
    nobjects == 0 && return hbox() 

    if ncolumns isa Nothing
        ncolumns = max(1, min(MAX_COLUMNS, (nobjects - 1) ÷ objpercol + 1))
    end
    npercol = (nobjects - 1) ÷ ncolumns + 1
    cols = collect(objects[(npercol * (i - 1) + 1):min(nobjects, npercol * i)] for i in 1:ncolumns)
    return hbox(map(col -> vbox(col...), cols)...)
end

function param_sliders(model::AbstractModel; throttle=0.1)
    length(params(model)) == 0 && return [], []

    labels = if haskey(model, :label)
        map(model[:label], model[:fieldname]) do n, fn
            n === nothing ? fn : n
        end
    else
        model[:fieldname]
    end
    values = withunits(model)
    ranges = if haskey(model, :range)
        withunits(model, :range)
    elseif haskey(model, :bounds)
        _makerange.(withunits(model, :bounds), values)
    else
        _makerange.(Ref(nothing), values)
    end

    descriptions = if haskey(model, :description)
        model[:description]
    else
        map(x -> "", values)
    end

    # Set mouse hover text
    attributes = map(model[:component], labels, descriptions) do p, n, d
        desc = d == "" ? "" : string(": ", d)
        Dict(:title => "$p.$n $desc")
    end

    sliders = map(values, labels, ranges, attributes) do v, l, r, a
        slider(r; label=string(l), value=v, attributes=a)
    end
    # `map` combining Observables is a little odd, *all* sliders here are splatted to `s`
    slider_obs = Interact.throttle.(throttle, observe.(sliders))

    return sliders, slider_obs
end

function group_sliders(f, model::AbstractModel, submodel::Type, obs, throttle)
    # Group slider observations into a single observable
    submodels = [sm for sm in Flatten.flatten(parent(model), submodel) if length(Flatten.flatten(sm, Param)) > 0]
    length(submodels) == 0 && return [], []

    submodel_sliders = map(sm -> param_sliders(Model(sm); throttle=throttle), submodels)
    slider_groups = map(first, submodel_sliders)
    slider_obs = collect(Iterators.flatten(map(last, submodel_sliders)))

    group_doms = map(submodels, slider_groups) do sm, sl
        dom"div"(dom"h2"(string(nameof(typeof(sm)))), sl...)
    end

    return group_doms, slider_obs
end

function _makerange(bounds::Tuple, val::T) where T
    b1, b2 = map(T, bounds)
    step = (b2 - b1) / SLIDER_STEPS
    return b1:step:b2
end
function _makerange(bounds::Tuple, val::T) where T<:Integer
    b1, b2 = map(T, bounds)
    return b1:b2
end
function _makerange(bounds::Nothing, val)
    return if val == zero(val)
        LinRange(-oneunit(val), onunit(val), SLIDER_STEPS)
    else
        LinRange(zero(val), 2 * val, SLIDER_STEPS)
    end
end
function _makerange(bounds::Nothing, val::Int)
    return if val == zero(val) 
        -oneunit(val):onunit(val)
    else 
        zero(val):2val
    end
end
_makerange(bounds, val) = error("Can't make a range from Param bounds of $val")
