using Aqua,
      DataFrames,
      ModelParameters,
      Setfield,
      StaticArrays,
      Test,
      Unitful

@testset "Aqua" begin 
    # Dont check ambiguity on nightly
    Aqua.test_ambiguities([ModelParameters, Base, Core]; exclude=[(==), write])
    Aqua.test_unbound_args(ModelParameters)
    Aqua.test_undefined_exports(ModelParameters)
    Aqua.test_project_extras(ModelParameters)
    Aqua.test_stale_deps(ModelParameters)
    Aqua.test_deps_compat(ModelParameters)
end

if !isdefined(Base, :get_extension) #ensures test compatibility for Julia versions <1.9
    using ConstructionBaseExtras
end

import ModelParameters: component
import BenchmarkTools

@testset "param setproperties" begin
    for P in (Param, RealParam)
        param = Param(1; a=2.0, b="3", c='4')
        @set! param.val = 2
        @test param.val == 2
        @set! param.a = "99"
        @test param.a == "99"
    end
end

@testset "param math" begin
    for P in (Param, RealParam)
        # We don't have to test everything, that is for AbstractNumbers.jl
        @test 2 * P(5.0; bounds=(5.0, 15.0)) == 10.0
        @test P(5.0; bounds=(5.0, 15.0)) + 3 == 8.0
        @test P(5.0; bounds=(5.0, 15.0))^2 === 25.0
        @test P(5; bounds=(5.0, 15.0))^2 === 25
    end
end

struct S1{A,B,C,D,E,F}
    a::A
    b::B
    c::C
    d::D
    e::E 
    f::F
end

struct S2{H,I,J}
    h::H
    i::I
    j::J
end

struct S3{K}
    k::K
end

component(::Type{T}) where {T<:S3} = T

s2_p = S2(
    Param(99), 7,
    Param(100.0; bounds=(50.0, 150.0))
)

s2_rp = S2(
    RealParam(99), 7,
    RealParam(100.0; bounds=(50.0, 150.0))
)

s1_p = S1(
   Param(1.0; bounds=(5.0, 15.0)),
   Param(2.0; bounds=(5.0, 15.0)),
   Param(3.0; bounds=(5.0, 15.0)),
   Param(4.0),
   (Param(5.0; bounds=(5.0, 15.0)), Param(6.0; bounds=(5.0, 15.0))),
   s2_p,
)

s1_rp = S1(
   RealParam(1.0; bounds=(5.0, 15.0)),
   RealParam(2.0; bounds=(5.0, 15.0)),
   RealParam(3.0; bounds=(5.0, 15.0)),
   RealParam(4.0),
   (RealParam(5.0; bounds=(5.0, 15.0)), RealParam(6.0; bounds=(5.0, 15.0))),
   s2_rp,
)

pars_p = ModelParameters.params(s1_p)
pars_rp = ModelParameters.params(s1_rp)

@testset "params are correctly flattened from an object" begin
    @test length(pars_p) == 8
    @test all(map(p -> isa(p, Param), pars_p))
    @test length(pars_rp) == 8
    @test all(map(p -> isa(p, RealParam), pars_rp))
end

@testset "missing fields are added to Model Params" begin
    for s1 in (s1_p, s1_rp)
        m = Model(s1);
        @test all(map(p -> propertynames(p) == (:val, :bounds), params(m)))
    end
end

@testset "getproperties returns column tuples of param fields" begin
    for s1 in (s1_p, s1_rp)
        m = Model(s1)
        @test m[:component] === (S1, S1, S1, S1, Tuple, Tuple, S2, S2)
        @test m[:fieldname] === (:a, :b, :c, :d, 1, 2, :h, :j)
        @test m[:val] === (1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 99, 100.0)
        @test m[:bounds] === ((5.0, 15.0), (5.0, 15.0), (5.0, 15.0), nothing,
                           (5.0, 15.0), (5.0, 15.0), nothing, (50.0, 150.0))
    end
end

@testset "setindex updates and adds param fields" begin
    for s1 in (s1_p, s1_rp)
        m = Model(s1)
        m[:val] = m[:val] .* 2
        @test m[:val] == (2.0, 4.0, 6.0, 8.0, 10.0, 12.0, 198, 200.0)
        m[:newfield] = ntuple(x -> x, 8)
        @test m[:newfield] == ntuple(x -> x, 8)
    end
end

@testset "show" begin
    for s1 in (s1_p, s1_rp)
        m = Model(s1)
        sh = sprint(show, MIME"text/plain"(), m)
        @test occursin("Model with parent", sh)
        @test occursin("S1", sh)
        @test occursin("Param", sh)
        @test occursin("┌──────", sh)
        @test occursin("component", sh)
        @test occursin("100.0", sh)
    end
end

@testset "strip params from model" begin
    for s1 in (s1_p, s1_rp)
        m = Model(s1);
        stripped = stripparams(m)
        @test params(stripped) == ()
        @test stripped.c == 3.0
        @test stripped.f.j == 100.0
    end
end

@testset "Tables interface" begin
    for s1 in (s1_p, s1_rp)
        m = Model(s1);
        s = Tables.schema(m)
        @test keys(m) == s.names == (:component, :fieldname, :val, :bounds)
        @test s.types == (
            Union{DataType,UnionAll},
            Union{Int64,Symbol},
            Union{Float64,Int64},
            Union{Nothing,Tuple{Float64,Float64}},
        )
        @test Tables.rows(m) isa Tables.RowIterator
        @test Tables.columns(m) isa Model

        df = DataFrame(m)
        @test all(df.component .== m[:component])
        @test all(df.fieldname .== m[:fieldname])
        @test all(df.val .== m[:val])
        @test all(df.bounds .== m[:bounds])

        df.val .*= 3
        ModelParameters.update!(m, df)
        @test m[:val] == (3.0, 6.0, 9.0, 12.0, 15.0, 18.0, 297, 300.0)
        df.val ./= 3
        newm = @inferred ModelParameters.update(m, df)
        @test newm[:val] == (1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 99.0, 100.0)
    end
end

@testset "Unitful extensions" begin
    p = Param(1.0u"m")
    @test hasproperty(p, :units) && p.units == u"m"
    p_cm = uconvert(u"cm", p)
    @test p.units == u"cm" && p.val == 100.0
end

@testset "use Unitful units, with StaticModel" begin
    s1 = S1(
       Param(1.0; bounds=(5.0, 15.0)),
       Param(2.0; bounds=(5.0, 15.0), units=u"s"),
       Param(3.0; bounds=(5.0, 15.0), units=u"K"),
       Param(4.0; units=u"m"),
       Param(5.0; bounds=(5.0, 15.0)),
       Param(6.0),
    )
    s2 = S2( s1,
        Param(7.0; bounds=(50.0, 150.0), units=u"m*s^2"),
        Param(8.0),
    )
    m = StaticModel(s2)
    sh = sprint(show, m)
    @test occursin("bounds", sh)
    @test occursin("units", sh)
    @test m[:units] == (nothing, u"s", u"K", u"m", nothing, nothing, u"m*s^2", nothing)
    # Values have units now
    @test withunits(m) == (1.0, 2.0u"s", 3.0u"K", 4.0u"m", 5.0, 6.0, 7.0u"m*s^2", 8.0)
    @test withunits(m, :bounds) ==
        ((5.0, 15.0), (5.0, 15.0) .* u"s", (5.0, 15.0) .* u"K", nothing,
         (5.0, 15.0), nothing, (50.0, 150.0) .* u"m*s^2", nothing)
    @test stripunits(m, (1.0, 2.0u"s", 3.0u"K", 4.0u"m", 5.0, 6.0, 7.0u"m*s^2", 8.0)) ==
        (1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0)
    @test stripunits(m, ((5.0, 15.0), (5.0, 15.0) .* u"s", (5.0, 15.0) .* u"K", nothing,
                         (5.0, 15.0), nothing, (50.0, 150.0) .* u"m*s^2", nothing)) ==
                        ((5.0, 15.0), (5.0, 15.0), (5.0, 15.0), nothing,
                         (5.0, 15.0), nothing, (50.0, 150.0), nothing)
end

@testset "parameters in StaticArrays" begin
    s2 = S2(
        SA[Param(99)],
        7,
        SA[Param(100.0) Param(200.0)]
    ) |> Model
    @test params(s2) === (Param(99), Param(100.0), Param(200.0))
    s2[:val] = s2[:val] .+ 1.0
    @test params(s2) === (Param(100.0), Param(101.0), Param(201.0))
end

@testset "type stable update" begin
    s1 = S1(
       Param(1.0; bounds=(5.0, 15.0)),
       Param(2.0; bounds=(5.0, 15.0), units=u"s"),
       Param(3.0; bounds=(5.0, 15.0), units=u"K"),
       Param(4.0; units=u"m"),
       Param(5.0; bounds=(5.0, 15.0)),
       Param(6.0),
    )
    s2 = S2(
        s1,
        Param(7.0; bounds=(50.0, 150.0), units=u"m*s^2"),
        Param(8.0),
    )
    m = Model(s2)
    ps = collect(m[:val]).*2.0
    new_s2 = @inferred update(s2, ps)
    @test all(Model(new_s2)[:val] .== ps)
    b = BenchmarkTools.@benchmark update($s2, $ps)
    # @test b.allocs == 0
end

@testset "parameter grouping" begin
    s1 = S1(
       Param(1.0; bounds=(5.0, 15.0), group=:A),
       Param(2.0; bounds=(5.0, 15.0), units=u"s", group=:A),
       Param(3.0; bounds=(5.0, 15.0), units=u"K", group=:A),
       Param(4.0; units=u"m", group=:B),
       Param(5.0; bounds=(5.0, 15.0), group=:B),
       Param(6.0, group=:B),
    )
    s2 = S2(
        s1,
        Param(7.0; bounds=(50.0, 150.0), units=u"m*s^2", group=:A),
        Param(8.0, group=:B),
    )
    m = Model(s2)
    # groupparams
    groupedparams = groupparams(m, :group)
    @test haskey(groupedparams, :A)
    @test length(groupedparams.A) == 4
    @test haskey(groupedparams, :B)
    @test length(groupedparams.B) == 4
    groupedparams = groupparams(m, :group, :fieldname)
    @test haskey(groupedparams, :A)
    @test haskey(groupedparams, :B)
    @test groupedparams.A.a == [s1.a]
    @test groupedparams.A.b == [s1.b]
    @test groupedparams.A.c == [s1.c]
    @test groupedparams.B.d == [s1.d]
    @test groupedparams.B.e == [s1.e]
    @test groupedparams.B.f == [s1.f]
    @test groupedparams.A.i == [s2.i]
    @test groupedparams.B.j == [s2.j]
    # flat
    groupedvals = mapflat(p -> p.val, groupedparams)
    @test groupedvals.A.a == [s1.a.val]
    @test groupedvals.A.b == [s1.b.val]
    @test groupedvals.A.c == [s1.c.val]
    @test groupedvals.B.d == [s1.d.val]
    @test groupedvals.B.e == [s1.e.val]
    @test groupedvals.B.f == [s1.f.val]
    @test groupedvals.A.i == [s2.i.val]
    @test groupedvals.B.j == [s2.j.val]
    # convert to tuples; uses maptype kwarg to recurse exclusively on NamedTuples, not arrays
    tuplegroups = mapflat(Tuple, groupedparams; maptype=NamedTuple)
    @test isa(tuplegroups.A.a, Tuple)
    @test isa(tuplegroups.A.b, Tuple)
    @test isa(tuplegroups.A.c, Tuple)
    @test isa(tuplegroups.B.d, Tuple)
    @test isa(tuplegroups.B.e, Tuple)
    @test isa(tuplegroups.B.f, Tuple)
    @test isa(tuplegroups.A.i, Tuple)
    @test isa(tuplegroups.B.j, Tuple)
end

@testset "custom component" begin
    obj = S3(Param(1.0))
    m = Model(obj)
    @test m[:component] == (typeof(obj),)
end
