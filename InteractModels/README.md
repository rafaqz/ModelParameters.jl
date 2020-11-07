# InteractModels

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://rafaqz.github.io/ModelParameters.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://rafaqz.github.io/ModelParameters.jl/dev)
[![CI](https://github.com/rafaqz/ModelParameters.jl/workflows/CI/badge.svg)](https://github.com/rafaqz/ModelParameters.jl/actions?query=workflow%3ACI)
[![Coverage](https://codecov.io/gh/rafaqz/ModelParameters.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/rafaqz/ModelParameters.jl)

InteractModels is a subpackage of ModelParameters.jl that provides an interactive
web interface that can run in Atom, Jupyter notebooks, Electron apps or be
served on the web. 

It's separated out to avoid loading the web stack when it isn't needed.
