# ModelParameters

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://rafaqz.github.io/ModelParameters.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://rafaqz.github.io/ModelParameters.jl/dev)
[![CI](https://github.com/rafaqz/ModelParameters.jl/workflows/CI/badge.svg)](https://github.com/rafaqz/ModelParameters.jl/actions?query=workflow%3ACI)
[![Coverage](https://codecov.io/gh/rafaqz/ModelParameters.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/rafaqz/ModelParameters.jl)

**Work in Progress**

To dev ModelParameters and InteractModels locally, do:

```julia
] dev "https://github.com/rafaqz/ModelParameters.jl"
dev "/your/dev/folder/ModelParameters/InteractModels
```

ModelParameters simplifies the process of writing and using complex, high
performance models, decoupling technical decisions about model structure and
composition from usability concerns. 

It provides linear indexing of parameters, a Tables.jl interface, and
controllable Interact.jl Interfaces (via InteractModels.jl) -- for any object,
of any complexity. Parameters of immutable objects can be updated from a vector,
tuple or table using a single command, rebuilding the object with the new values.

# Use case

Once a model grows beyond a certain complexity it becomes preferable to organise
it in modular way, and to reuse components in variants of the model. For example
this is seen in climate models and land models related to CLIMA project, and
in ecological modelling tools like DynamicGrids.jl and GrowthMaps.jl.

Models may be structured as a composed nested hierarchy of structs, `Tuple`
chains of objects, `NameTuple`s, or some combination of the above. For
performance, or running on GPUs, immutability is often necessary.

The problem comes when trying to use these models in Optim.jl, or run
sensitivity analysis on them with DiffEqSensitivity.jl, or pass priors to a
Bayesian modelling package. These packages often need starting values, bounds
and priors as `Vector`s. The also need to update the model with new parameters
as required. Writing out these conversions for every model combination is error
prone and inefficient.

ModelParameters.jl can convert any arbitrarily complex model of structs,
`Tuple`s and `NamedTuple`s into vectors of values, bounds, priors, and anything
else you need to attach. This is facilitated by wrapping your parameters,
wherever they are in the model, in a `Param`:

```julia
using ModelParameters

Base.@kwdef struct Submodel1{A,B}
    α::A = Param(0.8, bounds=(0.2, 0.9))
    β::B = Param(0.5, bounds=(0.7, 0.4))
end

Base.@kwdef struct Submodel2{Γ}
    γ::Γ = Param(1e-3, bounds=(1e-4, 1e-2))
end

Base.@kwdef struct SubModel3{Λ,X}
    λ::Λ = Param(0.8, bounds=(0.2, 0.9))
    x::X = Submodel2()
end

julia> model = Model((Submodel1(), SubModel3()))
Model with parent object of type: 

Tuple{Submodel1{Param{Float64,NamedTuple{(:val, :bounds),Tuple{Float64,Tuple{Float64,Float64}}}},Param{Float64,NamedTuple{(:val, :bounds),Tuple{Float64,Tuple{Float64,Float64}}}}},SubModel3{Param{Float64,NamedTuple{(:val, :bounds),Tuple{Float64,Tuple{Float64,Float64}}}},Submodel2{Param{Float64,NamedTuple{(:val, :bounds)
,Tuple{Float64,Tuple{Float64,Float64}}}}}}}

And parameters:
┌───────────┬───────┬───────┬────────────────┐
│ component │ field │   val │         bounds │
├───────────┼───────┼───────┼────────────────┤
│ Submodel1 │     α │   0.8 │     (0.2, 0.9) │
│ Submodel1 │     β │   0.5 │     (0.7, 0.4) │
│ SubModel3 │     λ │   0.8 │     (0.2, 0.9) │
│ Submodel2 │     γ │ 0.001 │ (0.0001, 0.01) │
└───────────┴───────┴───────┴────────────────┘

julia> model.val
(0.8, 0.5, 0.8, 0.001)
```

# What are Params?

`Param` is a wrapper for your parameter value and any metadata you need to track
about it. `Param` has flexible fields, but expects to always have a `:val` field
- which is the default if you don't used a keyword argument:

```julia
par = Param(99.0)
@assert par.val == 99.0
```

Internally `Param` uses a `NamedTuple` so to be flexible for scripting, you can
just add anything you need. When parameters are built into a model, they are
standardised so that they all have the same fields, filling the gaps with
`nothing`. 

There are a few other "privileged" fields that have specific behaviour, if you
use them. A `units` field will be combined with a `val` field in `paramvals`,
and when using `simplify` on the models. The `InteractModel` may also combine
`range`, `bounds` or fields with `units` and use them to construct sliders.

`Param` is also a `Number`, and should work as-is in a lot of models for
convenience. It can easily be stripped from objects using `stripparams`.


# What is a Model?

A model is another wrapper type, this time for a whole model - whatever it may
be. Its a mutable and untyped containers for you typed, immutable models, so the
model can be updated in a user interface or using `setproperties!` and you keep
a handle to the updated version. `Model` gives you a Tables.jl interface,
provides a table of parameters in the REPL, and give you some powerful tools for
making changes to your model. There is a more limited `StaticModel` variant
where you need maximum performance and don't need a handle to the model object.

An `InteractModel` from InteractModels.jl (also in this repository) is
identical, with the addition of an Interact.jl interface. It accepts a function
that generates anything that can go into a web page (like a plot) in response to
model parameter changes you make with the generated sliders.

# Setting model values 

### Setting new values

You can also add new columns to all model parameters directly from the model:

```julia
model.bounds = ((1.0, 4.0), (0.0, 1.0), (0.0, 0.1), (0.0, 100.0))
```

### Swapping number types

ModelParameters makes it very easy to make modifications to your model
parameters. To update all model values to be `Float32`, you can simply do: 

```julia
model.val = map(Float32, model.val)
```

# Using with Optim.jl

TODO


# Tables.jl interface

You can also save and import your model parameters to/from CSV or any other kind
of Table or `DataFrame` using the Tables.jl interface:

```julia
update!(model, table)
```

# Live Interact.jl models

Any model can have an Interact.jl web interface defined for it automatically, by
providing a function that plots or displays your model in some way that can show
in a web page. The interface, slider controllers and model updates are all taken
care of.


# Potential Problems

If you define structs with type parameters that are not connected to fields,
ModelParameters.jl will not be able to use Flatten.jl to reconstruct them.
Defining `ConstructionBase.constructorof` from
[ConstructionBase.jl](https://github.com/JuliaObjects/ConstructionBase.jl)  the
solution to this, and will also mean your objects can be used with other
packages for immutable manipulation like Setfield.jl, Accessors.jl and
BangBang.jl.
