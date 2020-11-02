"""
    InteractModel(f, model)

An [`AbstractModel`](@ref) that generates its own Interact.jl interface. 
Each model `Param` has a slider generated for it to update the model. 
After any slider updates the user-defined function `f` is passed the updated 
model to generate a new output - anything that will display in a WebIO.jl
node, like a Plots.jl plot

After all updates, the parent model is updated, so that `parent(interactmodel)`
will return it's latest state.

## Arguments

- `f`: a function that take the model object as an argument, but with 
  `Param` fields replaced with their values. Usually a `do` block.
- `model`: any object with `Param`s objects in some fields. 
  Params objects need to include:
  - `range` field to define the slider ranges
  - `label` field to replace field names as labels (optional)
  - `desciption` field for mouse-hover text (optional)

## Keyword Arguments

- `title`: `""` set a window title, if you need it.
- `grouped`: `true`. Wether to show sliders grouped and labeled by their parent object.
- `throttle`: `0.1`. Slider throttle, in seconds. Adjust to improve performance.
- `layout`: `vbox`. This can be any three-argument function that will combine title, 
  output, and sliders (all webio nodes) into a combined WebIO node. You can use this 
  method to add any additional layout you need.
- `stripped`: `true`. Wether to strip Params objects from the model and replace them 
  with their values.

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

ui = InteractModel(model; grouped=false, throttle=0.1) do m
    cxs_unscaled = [i * m.sample_step + m.phase for i in 1:nsamples]
    cys = sin.(cxs_unscaled) .* height/3 .+ height/2
    cxs = cxs_unscaled .* width/4pi
    c = (dom"svg:circle[cx=\$(cxs[i]), cy=\$(cys[i]), r=\$(m.radii), fill=#\$(color(i))]"()
         for i in 1:nsamples)
    return dom"svg:svg[width=\$width, height=\$height]"(c...)
end
```
"""
mutable struct InteractModel{F,Ti,G,Th} <: MutableModel
    f::F
    parent::Any
    grouped::Bool
    layout::Ti
    title::Ti
    throttle::Th
    ui::Any
    function InteractModel(
        f::F, parent; layout::L=vbox, grouped::Bool=true, title::Ti="", throttle::Th=0.1
    ) where {F,Ti,L,Th}
        # Partially construct model
        model = new{F,Ti,L,Th}(f, parent, grouped, layout, title, throttle, undef)

        # Initialise an observable output object
        output = Observable(f(simplify(parent)))
        # And an observable that is passed the updated model
        update = Observable(simplify(parent))
        on(update) do stripped_model
            output[] = f(stripped_model)
        end

        # Generate sliders and update the model and output when they change
        sliders = attach_sliders!(model; 
            grouped=grouped, throttle=throttle, obs=update
        )

        # Define the complete user interface
        model.ui = layout(dom"h1"(title), output, sliders)

        return model
    end
end
InteractModel(f, model::Model; kwargs...) = InteractModel(f, parent(model); kwargs...)

ui(m::InteractModel) = getfield(m, :ui)

Base.display(m::InteractModel) = display(ui(m))

@WebIO.register_renderable(InteractModel) do m
    ui(m)
end


"""
    attach_sliders!(model::AbstractModel; grouped=false, throttle=0.1)

Create sliders and attach them to the model so it will be updated 
when they are moved.

## Keyword Arguments
- `throttle`: `0.1` - sliders response time, in seconds. 
- `grouped`: `false` - group sliders by parent object.
- `updateobs`: An optional observable to be updated when sliders change

"""
function attach_sliders!(f, model::AbstractModel; kwargs...) 
    attach_sliders!(model; kwargs..., f=f)
end
function attach_sliders!(model::AbstractModel; 
    grouped=false, throttle=0.1, obs=nothing, f=simplify
)
    # Generte observable sliders
    sliders, slider_obs = param_sliders(StaticModel(model); throttle=throttle)

    if length(sliders) > 0
        on(slider_obs) do values
            setparent!(interactive, Flatten.reconstruct(model, values, Param))
            if obs isa Observable
                obs[] = f(interactive)
            end
        end
    end

    sliders = if grouped
        slider_groups = group_sliders(model, sliders)
        vbox(slider_groups...)
    else
        vbox(sliders...)
    end

    return sliders
end

function param_sliders(model::AbstractModel; throttle=0.1)
    fields = model.field
    values = model.val
    ranges = if hasproperty(model, :range)
        model.range
    elseif hasproperty(model, :bounds)
        _makerange.(model.bounds, values)
    else
        error("Params must include a `range` or `bounds` field to generate interactive sliders")
    end

    if hasproperty(model, :units) 
        ranges = map(ModelParameters.withunits, ranges, model.units)
        values = map(ModelParameters.withunits, values, model.units)
    end
    println(ranges)

    labels = hasproperty(model, :label) ? model.label : fields
    descriptions = if hasproperty(model, :description) 
        model.description 
    else
        map(x -> "", values)
    end

    # Set mouse hover text
    parents = Flatten.parentnameflatten(model, Param)
    attributes = map(parents, fields, descriptions) do p, n, d 
        Dict(:title => "$p.$n: $d")
    end

    sliders = map(values, fields, ranges, attributes) do v, l, r, a 
        slider(r; label=string(l), value=v, attributes=a)
    end
    # `map` on Observables is a little odd, *all* sliders here are splatted to `s`
    slider_obs = map((s...) -> s, Interact.throttle.(throttle, observe.(sliders))...)

    return sliders, slider_obs
end

function group_sliders(model::AbstractModel, sliders)
    parents = Flatten.parentnameflatten(model, Param)
    # Group slider observations into a single observable
    group_title = nothing
    slider_groups = []
    group_items = []
    for i in 1:length(sliders)
        parent = parents[i]
        if group_title != parent
            group_title == nothing || push!(slider_groups, dom"div"(group_items...))
            group_items = Any[dom"h2"(string(parent))]
            group_title = parent
        end
        push!(group_items, sliders[i])
    end
    push!(slider_groups, dom"h2"(group_items...))
    return slider_groups
end


function _makerange(bounds::Tuple, val::T) where T
    nsteps = 1000
    b1, b2 = map(T, bounds)
    step = (b2 - b1) / nsteps
    return b1:step:b2
end
