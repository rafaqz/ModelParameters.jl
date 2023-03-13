# ModelParameters

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://rafaqz.github.io/ModelParameters.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://rafaqz.github.io/ModelParameters.jl/dev)
[![CI](https://github.com/rafaqz/ModelParameters.jl/workflows/CI/badge.svg)](https://github.com/rafaqz/ModelParameters.jl/actions?query=workflow%3ACI)
[![Coverage](https://codecov.io/gh/rafaqz/ModelParameters.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/rafaqz/ModelParameters.jl)

ModelParameters simplifies the process of writing and using complex, high
performance models, decoupling technical decisions about model structure and
composition from usability concerns. 

It provides linear indexing of parameters, a Tables.jl interface, and
controllable Interact.jl Interfaces (via InteractModels.jl) -- for any object,
of any complexity. Parameters of immutable objects can be updated from a vector,
tuple or table using a single command, rebuilding the object with the new values.

## Use case

ModelParameters.jl is designed to help writing physics/environmental/ecological
models with heterogeneous structure and multiple formulation options. 

Once these models grow beyond a certain complexity it becomes preferable to
organise them in modular way, and to reuse components in variants in other
models. This pattern is seen in climate models and land models related to CLIMA
project, and in ecological modelling tools like DynamicGrids.jl and
GrowthMaps.jl that this package was built for.

Models may be structured as a composed nested hierarchy of structs, `Tuple`
chains of objects, `NameTuple`s, or some combination of the above. For
performance, or running on GPUs, immutability is often necessary.

The problem comes when trying to use these models in Optim.jl, or run
sensitivity analysis on them with DiffEqSensitivity.jl, or pass priors to a
Bayesian modelling package. These packages often need parameter values, bounds
and priors as `Vector`s. They may also need to update the model with new
parameters as required. Writing out these conversions for every model
combination is error prone and inefficient - especially with nested immutable
models, that need to be rebuilt to change the parameters.

ModelParameters.jl can convert any arbitrarily complex model built with structs,
`Tuple`s and `NamedTuple`s into vectors of values, bounds, priors, and anything
else you need to attach, and easily reconstruct the whole model when they are
updated. This is facilitated by wrapping your parameters, wherever they are in
the model, in a `Param`:

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

julia> model[:val]
(0.8, 0.5, 0.8, 0.001)
```

To get the model values as a vector for Optim.jl, simply:

```julia
collect(model[:val])
```

## What are Params?

`Param` is a wrapper for your parameter value and any metadata you need to track
about it. `Param` has flexible fields, but expects to always have a `:val` field
-- which is the default if you don't used a keyword argument:

```julia
par = Param(99.0)
@assert par.val == 99.0
```

Internally `Param` uses a `NamedTuple` to be flexible for scripting. You can
just add any fields you need. When parameters are built into a `Model`, they are
standardised so that they all have the same fields, filling the gaps with
`nothing`. 

There are a few other "privileged" fields that have specific behaviour, if you
use them. A `units` field will be combined other fields using `withunits`, and
this is done by default for `val` when you run `stripparams` on the models - if
there is actually a `units` field. The `InteractModel` in the sub-package
InteractModels.jl may also combine `range` or `bounds` fields with `units` and
use them to construct sliders.

`Param` is also a `Number`, and should work as-is in a lot of models for
convenience. But it can easily be stripped from objects using `stripparams`.


## What is a Model?

A model is another wrapper type, this time for a whole model - whatever it may
be. Its a mutable and untyped containers for you typed, immutable models, so
they can be updated in a user interface or by using `setproperties!`. Letting
you keep a handle to the updated version. `Model` gives you a Tables.jl
interface, provides a table of parameters in the REPL, and give you some
powerful tools for making changes to your model. 

There is a more limited `StaticModel` variant where you need maximum performance
and don't need a handle to the model object.

An `InteractModel` from the InteractModels.jl subpackage is identical to
`Model`, with the addition of an Interact.jl interface. It accepts a function
that generates anything that can go into a web page (like a plot) in response to
model parameter changes you make with the generated sliders.


## Setting model values 

### Setting new values

You can also add new columns to all model parameters directly from the model:

```julia
model[:bounds] = ((1.0, 4.0), (0.0, 1.0), (0.0, 0.1), (0.0, 100.0))
```

### Swapping number types

ModelParameters makes it very easy to make modifications to your model
parameters. To update all model values to be `Float32`, you can simply do: 

```julia
model[:val] = map(Float32, model[:val])
```

## Tables.jl interface

You can also save and import your model parameters to/from CSV or any other kind
of Table or `DataFrame` using the Tables.jl interface:

```julia
update!(model, table)
```

## Live Interact.jl models

InteractModels.jl is a subpackage of ModelParameters.jl, but needs to be
installed separately. This avoids loading the heavy web-stack dependencies of
Interact.jl when you don't need them.

Using InteractModels, any model can have an Interact.jl web interface defined
for it automatically, by providing a function that plots or displays your model
in some way that can show in a web page. The interface, slider controllers and
model updates are all taken care of.


## Potential Problems

If you define structs with type parameters that are not connected to fields,
ModelParameters.jl will not be able to reconstruct them with new `Param` values,
or use `stripparams` to remove the `Param` wrappers.

Defining `ConstructionBase.constructorof` from
[ConstructionBase.jl](https://github.com/JuliaObjects/ConstructionBase.jl) is
the solution to this, and will also mean your objects can be used with other
packages for immutable manipulation like Flatten.jl, Setfield.jl, Accessors.jl
and BangBang.jl.

[ConstructionBaseExtras.jl](https://github.com/JuliaObjects/ConstructionBaseExtras.jl) also
exists to add support to common packages, such as StaticArrays.jl arrays. Import it if you 
need StaticArrays support, or open an issue to add support to additional packages.

**Note: Breaking change in 0.4.0**
With the introduction of weak extensions in Julia 1.9, ConstructionBase.jl and ConstructionBaseExtras.jl
should not be loaded at the same time (see [this issue](https://github.com/rafaqz/ModelParameters.jl/issues/52)). 
ModelParameters.jl has dropped the direct dependency on ConstructionBase.jl in version 0.4.0.
Users that employ Julia versions <1.9 are advised to load ConstructionBaseExtras.jl themselves if StaticArrays.jl 
support is needed.