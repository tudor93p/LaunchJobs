

#		tiers::AbstractVector{<:AbstractDict}, 
#		path::AbstractString;


path1 = joinpath(pwd(),"test")
path2 = "/net/horon/scratch/pahomit/SnakeStates/test"

tiers = [Dict("host11"=>10,"host12"=>20), Dict("host21"=>1,"tudor-HP"=>7)]


#
#LaunchJobs.getrun_commands("print all", tiers, [path1, path2]; singlecore=false)
#LaunchJobs.getrun_commands("print all", tiers, [path1, path2]; singlecore=true)

LaunchJobs.getrun_commands("pmax 1 print all host11", tiers, [path1, path2])
LaunchJobs.getrun_commands("print all host11", tiers, [path1, path2])
#LaunchJobs.getrun_commands("print host11 all", tiers, [path1, path2]; singlecore=true)
