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

This is a simple example where the model is a NamedTuple, adapted from 
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

ui = InteractModel(model; grouped=false) do m
    cxs_unscaled = [i * m.sample_step + m.phase for i in 1:nsamples]
    cys = sin.(cxs_unscaled) .* height/3 .+ height/2
    cxs = cxs_unscaled .* width/4pi
    dom"svg:svg[width=\$width, height=\$height]"(
    (dom"svg:circle[cx=\$(cxs[i]), cy=\$(cys[i]), r=\$(m.radii), fill=#\$(color(i))]"()
            for i in 1:nsamples)...
    )
end
```
"""
mutable struct InteractModel <: MutableModel
    parent
    ui
    InteractModel(f, model; title="", layout=vbox, grouped=true, throttle=0.1, stripped=true) = begin
       
        init = f(simplify(model))
        # Make an observable output object
        output = Observable(init)
        # Generte observable sliders
        sliders, slider_obs, slider_groups = makesliders(StaticModel(model), throttle)
        sliderbox = vbox((grouped ? slider_groups : sliders)...)
        # Define the complete ui
        ui = layout(dom"h1"(title), output, sliderbox)
        # Construct the InteractModel object
        interactive = new(model, ui)
        # Update the model and output when sliders change
        on(slider_obs) do values
            setfield!(interactive, :parent, Flatten.reconstruct(model, values, Param))
            output[] = f(parent(interactive))
        end
        return interactive
    end
end
InteractModel(f, model::Model; kwargs...) = InteractModel(f, parent(model); kwargs...)

ui(m::InteractModel) = getfield(m, :ui)

Base.display(m::InteractModel) = display(ui(m))

@WebIO.register_renderable(InteractModel) do m
    ui(m)
end

function makesliders(model::StaticModel, throttle)
    values = paramval(model)
    fields = model.field
    ranges = model.range
    labels = hasproperty(model, :label) ? model.label : fields
    descriptions = if hasproperty(model, :description) 
        model.description 
    else
        map(x -> "", values)
    end

    # Set mouse hove text
    parents = Flatten.parentnameflatten(model, Param)
    attributes = map(parents, fields, descriptions) do p, n, d 
        Dict(:title => "$p.$n: $d")
    end

    sliders = _makeslider.(values, fields, ranges, attributes)
    # `map` on Observables is a little odd, *all* sliders here are splatted to `s`
    slider_obs = map((s...) -> s, Interact.throttle.(throttle, observe.(sliders))...)

    # Group slider observations into a single observable
    group_title = nothing
    slider_groups = []
    group_items = []
    for i in 1:length(values)
        parent = parents[i]
        if group_title != parent
            group_title == nothing || push!(slider_groups, dom"div"(group_items...))
            group_items = Any[dom"h2"(string(parent))]
            group_title = parent
        end
        push!(group_items, sliders[i])
    end
    push!(slider_groups, dom"h2"(group_items...))

    return sliders, slider_obs, slider_groups
end

_makeslider(val, lab, rng, attr) =
    slider(rng; label=string(lab), value=val, attributes=attr)

_makerange(bounds::Tuple, val::T) where T =
    T(bounds[1]):(T(bounds[2])-T(bounds[1]))/1000:T(bounds[2])
