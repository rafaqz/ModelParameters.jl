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
analysis on them with DiffEqSensitivity.jl? These packages need model parameters
as a vector. Other packages may also need parameter bounds or bayesian priors
for every parameter as a vector.

ModelParameters makes organising these things very easy. It can convert any
arbitrarily complex model to vectors of bounds, priors, and anything else you
need. It can also strip this information from the model and return it with just
the parameter values - for minimum size and complexity.

This is acheived by wrapping all parameters in `Param()` objects, and using
Flatten.jl to strip them out and rebuild the models.

Using ModelParameters.jl you can also save and import your models to CSV or any
other kind of Table or DataFrame using the Tables.jl interface. You will still
need a Julia script to build the model structure - but the specific parameters
can be saved separately to the structure.
