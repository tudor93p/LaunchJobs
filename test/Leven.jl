
@testset "LevenshteinDistance" begin 

	for (a,b,n) in [("sitting","kitten",3),
									("Saturday","Sunday",3),
									("flaw","lawn",2),
									]

		@test LaunchJobs.LevenshteinDistance(a,b)==n

	end 

end 
