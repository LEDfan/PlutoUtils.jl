using PlutoUtils.Export
using Test
using Logging

flatmap(args...) = vcat(map(args...)...)

list_files_recursive(dir=".") = let
    paths = flatmap(walkdir(dir)) do (root, dirs, files)
        joinpath.([root], files)
    end
    relpath.(paths, [dir])
end

original_dir1 = joinpath(@__DIR__, "dir1")
make_test_dir() = let
    new = tempname(cleanup=false)
    cp(original_dir1, new)
    new
end


@testset "Basic github action" begin
    test_dir = make_test_dir()
    cache_dir = tempname(cleanup=false)

    @show test_dir cache_dir
    cd(test_dir)
    @test sort(list_files_recursive()) == sort([
        "a.jl",
        "b.pluto.jl",
        "notanotebook.jl",
        "subdir/c.plutojl",
    ])

    github_action(
        cache_dir=cache_dir,
    )

    @test sort(list_files_recursive()) == sort([ 
        "index.md",
        "a.jl",
        "a.html",
        "b.pluto.jl",
        "b.html",
        "notanotebook.jl",
        "subdir/c.plutojl",
        "subdir/c.html",
    ])

    # Test whether the notebook file did not get changed
    @test read(joinpath(original_dir1, "a.jl")) == read(joinpath(test_dir, "a.jl"))

    # Test cache
    @show list_files_recursive(cache_dir)
    @test length(list_files_recursive(cache_dir)) >= 2

    # Test runtime to check that the cache works
    second_runtime = with_logger(NullLogger()) do
        .1 * @elapsed for i in 1:10
            github_action(
                cache_dir=cache_dir,
            )
        end
    end
    @show second_runtime
    @test second_runtime < 1.0
end


@testset "Separate state files" begin
    test_dir = make_test_dir()
    @show test_dir
    cd(test_dir)
    @test sort(list_files_recursive()) == sort([
        "a.jl",
        "b.pluto.jl",
        "notanotebook.jl",
        "subdir/c.plutojl",
    ])

    github_action(
        offer_binder=true,
        baked_state=false,
    )

    @test sort(list_files_recursive()) == sort([
        "index.md",

        "a.jl",
        "a.html",
        "a.plutostate",

        "b.pluto.jl",
        "b.html",
        "b.plutostate",

        "notanotebook.jl",

        "subdir/c.plutojl",
        "subdir/c.html",
        "subdir/c.plutostate",
    ])

    @test occursin("a.jl", read("a.html", String))
    @test occursin("a.plutostate", read("a.html", String))
end

