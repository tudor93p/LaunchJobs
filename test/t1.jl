

#		tiers::AbstractVector{<:AbstractDict}, 
#		path::AbstractString;


path1 = joinpath(pwd(),"test")
path2 = "/net/horon/scratch/pahomit/SnakeStates/test"

tiers = [Dict("host11"=>10,"host12"=>21,"host13"=>1), Dict("host21"=>1,"tudor-HP"=>7)]


#
#LaunchJobs.getrun_commands("print all", tiers, [path1, path2]; singlecore=false)
#LaunchJobs.getrun_commands("print all", tiers, [path1, path2]; singlecore=true)
path = [path1,path2]

#LaunchJobs.getrun_commands("pmax 6 print all host11", tiers, [path1, path2])
#LaunchJobs.getrun_commands("pmax 5 print all host11", tiers, [path1, path2])
#LaunchJobs.getrun_commands(["print","all","host11"], tiers, [path1, path2])
#LaunchJobs.getrun_commands("print host11 all", tiers, [path1, path2]; singlecore=true) 
#

tiers = [Dict("spaceml4"=>28, 
              #"yoshi"=>12, 
              "nut"=>23, "toad"=>38,
              "taranis"=>16)
         ]

tiers = [Dict("spaceml4"=>28,
              #"yoshi"=>12, 
              "nut"=>23, 
              "toad"=>38,
              "taranis"=>16,
              "horon"=>8,
              "sia"=>8,
              "re"=>12,
              "neper"=>8,
              "kis"=>8,
              )
         ]
#####
tiers = [Dict("spaceml4"=>29, 
							"yoshi"=>40, 
							"nut"=>23, 
							"toad"=>38,
							"taranis"=>15,
							"horon"=>7,
							"sia"=>7,
							"re"=>11,
							"neper"=>7,
							"kis"=>7,
							)
				 ]



LaunchJobs.getrun_commands(#"all nmin 1000 pmax 2 print",
"kill all print",
#													 "nut all print pmax 1 nmax 2000 nmin 1000", 
													 tiers, path)

tiers = [Dict(
							"spaceml4"=>29, 
							"yoshi"=>38, 
#
							),
				 Dict(

														"toad"=>38,
#							"re"=>11,
#							"taranis"=>15,
#							"sia"=>7,
#							"neper"=>7,
#"toad"=>7,
#				"horon"=>7,
							),
				 Dict(
							"nut"=>7,#23, 
							"kis"=>7,
				)
				] 


LaunchJobs.getrun_commands("toad pmax 4 pmin 4", tiers,path)

tiers = [Dict(
							 "neper" => 2, 
							 "sia" => 2, 
							 "shu" => 2, 
							 "re" => 2, 
							 )
				 ]

LaunchJobs.getrun_commands("re all pmax 1 nmax 3",tiers, path)





