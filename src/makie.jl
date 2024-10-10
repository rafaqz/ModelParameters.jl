"""
    MakieModel(f, model)

An [`AbstractModel`](@ref) that generates its own Makie.jl interface.
Each model [`Param`](@ref) has a slider generated for it to update the model.
Function `f` is passed a `Makie.GridLayout` to plot into and an `Observables.Observable`
that holds the model object stripped of `Param`s, with the values of the sliders in 
the interface. After any slider updates the `Observable` is updated.

Function `f` only runs once, on initialisation. In it `Makie.lift` should be used on the model
to create an `Observable` which can be plotted into one or many `Makie.Axis` created in
the `GridLayout`.

## Arguments

- `f`: a function that take a `GridLayout` and model object wrapped as an `Observable` as arguments.
- `model`: any object with [`Param`](@ref)s objects in some fields.

## Keyword Arguments

- `title`: `""` set a window title, if you need it.
- `slider_kw`: An optional `NamedTuple` of keywords to pass to all sliders.
- `ncolumns`: Group sliders in `n` columns, `1` by default.
- `figure`: An optional Makie `Figure`.
- `layout`: An optional Makie `GridLayout` that gets passed to `f`

## Param fields

`Param` objects in the model can include keywords:

- `label`: field to use instead of field names
- `range`: an `AbsractRange` of slider positions
- `bounds`: an `NTuple{2}` for min and max of slider ranges, 
    if `range` is not available.

Withouth `range` or `bounds` the range will be guessed from `val`.

## Example

This is a simple example where the model is a `NamedTuple` that changes
the color patterns of 

```julia
using ModelParameters, GLMakie, CSV

# Define some parameters
model = (; 
    noise=Param(0.5, bounds=(0.0, 1.0), label="Noise"),
    color=Param(0.5, bounds=(0.0, 1.0), label="Color"),
)

# Define a function that generates a random array from our model `m`
randarray(m) = max.(min.((rand(10, 10) .- 0.5) .* m.noise .+ m.color, 1.0), 0.0)

# Make an interactive model 
mm = MakieModel(model; ncolumns=2) do layout, model_obs
    # `model_obs` is our model with `Params` stripped and wrapped as an `Observable`.
    # We can `lift` it to run `f` and update a new 
    x = lift(randarray, model_obs)
    # Define an axis to plot into
    ax = Axis(layout[1, 1])
    # And plot a heatmap of the output of `f`
    heatmap!(ax, x; colorrange=(0, 1))
end

# We can save the parameters set in the interface
# to anything Tables.jl compatible, like csv
CSV.write("modelparams.csv", mm)
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
