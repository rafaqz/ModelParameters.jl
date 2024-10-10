"""
    MakieModel(f, model)

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
- `throttle`: `0.1`. Slider throttle, in seconds. Adjust to improve performance.
- `figure`: An optional Makie `Figure`.
- `axis`: An optional Makie `Axis`.
- `layout`: `vbox`. This can be any three-argument function that will combine title,
  output, and sliders (all WebIO nodes) into a combined WebIO node. You can use this
  method to do any additional layout you need.

## Example

This is a simple example where the model is a `NamedTuple`, adapted from
an Interact.jl example. It will display in atoms plot pane:

```julia
using ModelParameters, GLMakie, CSV

# Define some parameters
p = (; 
    noise=Param(0.5, bounds=(0.0, 1.0), label="Noise"),
    color=Param(0.5, bounds=(0.0, 1.0), label="Color"),
)

# Make an interactive model 
m = MakieModel(p) do layout, model
    A = lift(model) do m
        max.(min.((rand(10, 10) .- 0.5) .* m.noise .+ m.color, 1.0), 0.0)
    end
    ax = Axis(layout[1, 1])
    heatmap!(ax, A; colorrange=(0, 1))
end

# We can save the parameters set in the interface
# to anything Tables.jl compatible, like csv
CSV.write("modelparams.csv", m)
```
"""
mutable struct MakieModel{F} <: AbstractModel
    f::F
    parent::Any
    figure::Any
end
MakieModel(f, model::AbstractModel; kw...) = MakieModel(f, parent(model); kw...)
function MakieModel(f, model; kw...)
    # Error if a non function is passed
    f isa Base.Callable || throw(ArgumentError("first argument `f` must be a `Function` or `Type`"))
    # Error because we cant reach here if Makie is not loaded
    throw(ArgumentError("Please run `using GLMakie` or `using WGLMakie` to make an interactive Makie instance avaialble."))
end
