# ModelParameters

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://rafaqz.github.io/ModelParameters.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://rafaqz.github.io/ModelParameters.jl/dev)
[![Build Status](https://travis-ci.com/rafaqz/ModelParameters.jl.svg?branch=master)](https://travis-ci.com/rafaqz/ModelParameters.jl)
[![Coverage](https://codecov.io/gh/rafaqz/ModelParameters.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/rafaqz/ModelParameters.jl)

**Work in Progress**

Model parameters simplifies the process of writing and using complex models. 

Once a model grows beyond a certain complexity it often becomes preferable to
organise it in modular way, and to reuse components used in other models,
whether written by yourself of from packages in the Julia package ecosystem.

But how do you run complex, modular models in Optim.jl, or run sensitivity
analysis on them with DiffEqSensitivity.jl, or pass priors to a Bayesian
modelling package? These packages often need parameters, bounds and priors as a
`Vector`. 

ModelParameters.jl can convert any arbitrarily complex model to vectors of
bounds, priors, and anything else you need to add to `Param`s. It can also strip
this information from the model and return it with just the parameter values -
to reduce complexity of the model type when you are seriously running it.

This is achieved by wrapping all parameters in `Param()` objects: 


```julia
compa = ComponentA( 
    α = Param(0.8, bounds=(0.2, 0.9)), 
    β = Param(0.5, bound=(0.7, 0.4)),
end

compb = ComponentB( 
    λ = Param(0.8, bounds=(0.2, 0.9)), 
    δ = Param(0.5, bound=(0.7, 0.4)),
end

model = Model((compa, compb))
```


Here in some modelling tool (like DynamicGrids.jl) that accepts a Tuple
of model components. 


You can also save and import your models to CSV or any other kind of Table or
DataFrame using the Tables.jl interface. You will still need a Julia script to
build the model structure - but the specific parameters can be saved separately
to the structure.

As in the above grid, we still need to define the model structure in plain Julia
code. The utility of Tables.jl interface is viewing, saving and manipulating the
parameters of a model after automated or manual optimisation - and of being able
to load them later into the same default model structure defined in the code.
You only write the structure once. If the components have default values this
should be very simple to do.


An `Interactive` model can be updated from Interact.jl interface, if an
appropriate callback function is included.
