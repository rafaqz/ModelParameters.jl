
# Test stoled from Interact.jl docs
@testset "interactive model" begin
    color(i) = colors[i%length(colors)+1]
    colors = [
        "black", "gray", "silver", "maroon", "red", "olive", "yellow", 
        "green", "lime", "teal", "aqua", "navy", "blue", "purple", "fuchsia"
    ]
    width, height = 700, 300
    nsamples = 256
    model = (;
        sample_step=Param(val=0.05, range=0.01:0.001:0.1, label="Sample step"),
        phase=Param(val=0.0, range=0:0.1:2pi, label="Phase"),
        radii=Param(val=20,range=0:0.1:60, label="Radus")
    )
    interface = InteractModel(model; grouped=false) do m
        cxs_unscaled = [i * m.sample_step + m.phase for i in 1:nsamples]
        cys = sin.(cxs_unscaled) .* height/3 .+ height/2
        cxs = cxs_unscaled .* width/4pi
        dom"svg:svg[width=$width, height=$height]"(
        (dom"svg:circle[cx=$(cxs[i]), cy=$(cys[i]), r=$(m.radii), fill=$(color(i))]"()
                for i in 1:nsamples)...
        )
    end
    display(interface)

    @testset "Test the tables interface and getproperty work on InteractModel too" begin
        df = DataFrame(interface)
        @test Tuple(df.val) == interface.val == (0.05, 0.0, 20)
        @test Tuple(df.range) == interface.range == (0.01:0.001:0.1, 0.0:0.1:6.2, 0.0:0.1:60.0)
        @test Tuple(df.label) == interface.label == ("Sample step", "Phase", "Radus")
    end
end
