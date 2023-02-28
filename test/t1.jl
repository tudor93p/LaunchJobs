

#		tiers::AbstractVector{<:AbstractDict}, 
#		path::AbstractString;


path1 = joinpath(pwd(),"test")
path2 = "/net/horon/scratch/pahomit/SnakeStates/test"

tiers = [Dict("host11"=>10,"host12"=>20), Dict("host21"=>1,"tudor-HP"=>7)]


@show path 

LaunchJobs.qux("all", tiers, [path1, path2]; singlecore=false)

LaunchJobs.qux("all", tiers, [path1, path2]; singlecore=true)
