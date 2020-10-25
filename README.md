# ModelParameters

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://rafaqz.github.io/ModelParameters.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://rafaqz.github.io/ModelParameters.jl/dev)
[![Build Status](https://travis-ci.com/rafaqz/ModelParameters.jl.svg?branch=master)](https://travis-ci.com/rafaqz/ModelParameters.jl)
[![Coverage](https://codecov.io/gh/rafaqz/ModelParameters.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/rafaqz/ModelParameters.jl)

**Work in Progress**

Model parameters simplifies the process of writing and using complex models. 

It provides linear indexing, a Tables.jl interface, and controllable Interact.jl
Interfaces vie InteractModels.jl, for any object of arbitrary complexity but
fixed size.

# Use case

Once a model grows beyond a certain complexity it often becomes preferable to
organise it in modular way, and to reuse components used in other models. This
is seen in climate models and land models related to CLIMA project, and
ecological models like DynamicGrids.jl and GrowthMaps.jl.

Model structure may be structured as a composed nested hierarchy of structs,
tuple chains of objects, NameTuples, or some combination of the above.

The problem comes when trying to use these models in Optim.jl, or run
sensitivity analysis on them with DiffEqSensitivity.jl, or pass priors to a
Bayesian modelling package. These packages often need parameters, bounds and
priors as a `Vector`. Writing these out for every model combination is error
prone and inefficient.

ModelParameters.jl can convert any arbitrarily complex model to vectors of
bounds, priors, and anything else you need - by wrapping you parameters in
`Param` objects that hold the value and metadata. You can also strip this
information from the model and return it with just the parameter values - to
reduce complexity of the model type when you are seriously running it.

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

# Using with Optim.jl


# Swapping number types

ModelParameters makes it very easy to make modifications to all of your model
parameters. You can simply do: 

```julia
model.val = map(Float32, model.val)
```

To update all model values to be `Float32`. Or whatever you like.

You can also add new columns to all model parameters directly from the model:

```julia
model.bounds = ((1, 4), (0.0, 1.0), 0.0, 0.1) 
```


# Tables.jl interface

You can also save and import your model parameters to/from CSV or any other kind
of Table or `DataFrame` using the Tables.jl interface.

```julia

```


# Live Interact.jl models

Any model can have an Interact.jl web interface defined for it automatically, by
providing a function to turn you model into a plot or other visualisation. The
interface, slider controllers and model updates are all taken care of for you.

# What are Params?

`Param` is a wrapper for your parameter value and any metadata you need to track
about it. Essentially it's a struct that holds a `NamedTuple`. The struct simply
marks it so we don't get mixed up with other `NamedTuple`s in a model. It
expects to always have a `:val` field - which is the default if you don't used
a keyword argument:

```julia
par = Param(99.0)
@assert par.val == 99.0
```

We use a `NamedTuple` so that using parameters is more flexible for scripting -
if you have an idea for tracking a new thing about you model - you can just add
it!. When paramters are built into a model, they are standardised so that they
all have the same fields, filling the gaps with `nothing`. 

There are a few other "priveleged" fields that have specific behaviour, if you
use them. A `units` field will be combined with a `val` field in `paramvals`,
and when using `simplify` on the models. The `InteractModel` may also combine
`range`, `bounds` or fields with `units` and use them to construct sliders.


# What is a Model?

A model is another wrapper type, this time for you whole model - whatever it is.
It gives you a Tables.jl interface for you model, provides a table of parameters
in the REPL, and give you some powerful tools for makeing changes to your model.

