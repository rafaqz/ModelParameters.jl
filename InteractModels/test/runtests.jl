using InteractModels, DataFrames, Interact, Test

# Test stoled from Interact.jl docs
@testset "interactive model" begin
    color(i) = colors[i%length(colors)+1]
    colors = [
        "black", "gray", "silver", "maroon", "red", "olive", "yellow", 
        "green", "lime", "teal", "aqua", "navy", "blue", "purple", "fuchsia"
    ]
    width, height = 700, 300
    nsamples = 256
    pars = (;
        sample_step=Param(val=0.05, range=0.01:0.001:0.1, label="Sample step", description="The step size between samples"),
        phase=Param(val=0.0, range=0:0.1:2pi, label="Phase", description="Phase of the starting point"),
        radii=Param(val=20,range=0:0.1:60, label="Radus", description="Radius of the circles")
    )

    interface = InteractModel(pars; ncolumns=2, grouped=false, title="slinky") do m
        m = stripparams(m)
        println(m)
        cxs_unscaled = [i * m.sample_step + m.phase for i in 1:nsamples]
        cys = sin.(cxs_unscaled) .* height/3 .+ height/2
        cxs = cxs_unscaled .* width/4pi
        # dom"div"()
        dom"svg:svg[width=$width, height=$height]"(
             (dom"svg:circle[cx=$(cxs[i]), cy=$(cys[i]), r=$(m.radii), fill=$(color(i))]"()
              for i in 1:nsamples)...
        )
    end

    ui_ = ui(interface)
    # Title node matches.
    @test first(ui_.children).children == dom"h1"("slinky").children
    # TODO how to test this more?
    
    # To test manually
    # using Blink
    # w = Blink.Window()
    # body!(w, interface)

    @testset "Test the tables interface and getproperty work on InteractModel too" begin
        df = DataFrame(interface)
        @test Tuple(df.val) == interface.val == interface[:val] == (0.05, 0.0, 20)
        @test Tuple(df.range) == interface.range == interface[:range] == (0.01:0.001:0.1, 0.0:0.1:6.2, 0.0:0.1:60.0)
        @test Tuple(df.label) == interface.label == interface[:label] == ("Sample step", "Phase", "Radus")
    end

end
