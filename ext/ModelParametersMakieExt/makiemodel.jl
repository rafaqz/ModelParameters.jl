const SLIDER_STEPS = 500
const MAX_COLUMNS = 3

function MakieModel(
    f::Base.Callable, parent;
    throttle=0.1,
    figure=Figure(),
    slider_kw=(;),
    ncolumns::Integer=1,
    layout=GridLayout(figure[1, 1]),
    sliderlayout=GridLayout(figure[2, 1]),
)
    model = MakieModel(f, parent, figure)

    # Plot the model
    model_obs = Observable(stripparams(parent))
    f(layout, model_obs)
    # Generate sliders and update the model and output when they change
    sliders = attach_sliders!(figure, model, model_obs; ncolumns, slider_kw, layout=sliderlayout)
    return model
end

Base.display(m::MakieModel) = display(figure(m))

figure(m::MakieModel) = getproperty(m, :figure)


# Widget buliding
function attach_sliders!(fig, model::AbstractModel, parent_obs;
    ncolumns, slider_kw=(;), layout=GridLayout(fig[2, 1]),
)
    length(params(model)) == 0 && return

    sliderlayout, slider_obs = param_sliders!(fig, model; layout, slider_kw, ncolumns)

    isnothing(slider_obs) && return nothing

    # Combine sliders
    combined_obs = lift((s...) -> s, slider_obs...)
    if length(slider_obs) > 0
        on(combined_obs) do values
            try
                model[:val] = stripunits(model, values)
                parent_obs[] = strip(model)
                notify(parent_obs)
            catch e
                println(stdout, e)
            end
        end
    end

    return sliderlayout
end

function param_sliders!(fig, model::AbstractModel; layout=fig, ncolumns, slider_kw=(;))
    length(params(model)) == 0 && return nothing, nothing

    model1 = Model(parent(model))

    labels = if haskey(model1, :label)
        map(model1[:label], model1[:fieldname]) do n, fn
            n === nothing ? fn : n
        end
    else
        model1[:fieldname]
    end
    values = paramswithunits(model1)
    ranges = if haskey(model1, :range)
        paramswithunits(model1, :range)
    elseif haskey(model1, :bounds)
        _makerange.(paramswithunits(model1, :bounds), values)
    else
        _makerange.(Ref(nothing), values)
    end
    descriptions = if haskey(model, :description)
        model[:description]
    else
        map(x -> "", values)
    end
    # TODO Set mouse hover text
    # attributes = map(model[:component], labels, descriptions) do p, n, d
    #     desc = d == "" ? "" : string(": ", d)
    #     Dict(:title => "$p.$n $desc")
    # end
    #
    #ovalues, labels, ranges, descriptions
    slider_vals = (; values, labels, ranges, descriptions)

    if ncolumns > 1
        inner_layout = GridLayout(layout[1, 1])
        nsliders = length(values)
        colsize = ceil(Int, nsliders / ncolumns)
        ranges = map(1:ncolumns) do i
            b = colsize * (i - 1) + 1
            e = min(b + colsize - 1, nsliders)
            b:e
        end
        obs = mapreduce(vcat, enumerate(ranges)) do (i, r)
            col_slider_vals = map(x -> x[r], slider_vals)
            _, col_obs = _param_sliders!(fig, i; layout=inner_layout, slider_kw, col_slider_vals...)
            col_obs
        end
        return inner_layout, obs
    else
        return _param_sliders!(fig, 1; layout, slider_kw, slider_vals...)
    end
end

function _param_sliders!(fig, i;
    layout, slider_kw, values, labels, ranges, descriptions
)

    height = 8
    slider_specs = map(values, labels, ranges) do startvalue, l, range
        (label=string(l), range, startvalue, height)
    end
    sg = SliderGrid(fig, slider_specs...)
    # Manually force label height
    map(sg.labels, sg.valuelabels) do l, vl
        l.height[] = vl.height[] = height
    end
    layout[1, i] = sg

    slider_obs = map(x -> x.value, sg.sliders)

    return sg, slider_obs
end

function _makerange(bounds::Tuple, val::T) where T
    SLIDER_STEPS = 100
    b1, b2 = map(T, bounds)
    step = (b2 - b1) / SLIDER_STEPS
    return b1:step:b2
end
function _makerange(bounds::Tuple, val::T) where T<:Integer
    b1, b2 = map(T, bounds)
    return b1:b2
end
function _makerange(bounds::Nothing, val)
    SLIDER_STEPS = 100
    return if val == zero(val)
        LinRange(-oneunit(val), oneunit(val), SLIDER_STEPS)
    else
        LinRange(zero(val), 2 * val, SLIDER_STEPS)
    end
end
function _makerange(bounds::Nothing, val::Int)
    return if val == zero(val)
        -oneunit(val):oneunit(val)
    else
        zero(val):2val
    end
end
_makerange(bounds, val) = error("Can't make a range from Param bounds of $val")

function _in_columns(layout, objects, ncolumns, objpercol)
    nobjects = length(objects)
    nobjects == 0 && return hbox()

    if ncolumns isa Nothing
        ncolumns = max(1, min(MAX_COLUMNS, (nobjects - 1) ÷ objpercol + 1))
    end
    npercol = (nobjects - 1) ÷ ncolumns + 1
    cols = collect(objects[(npercol * (i - 1) + 1):min(nobjects, npercol * i)] for i in 1:ncolumns)
    for (i, col) in enumerate(cols)
        collayout = GridLayout(layout[i, 1])
        for slider in col

        end
    end
end
