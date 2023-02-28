module LaunchJobs 
#############################################################################

import myLibs: Utils  
import OrderedCollections: OrderedDict

#===========================================================================#
#
#
#
#---------------------------------------------------------------------------#



function hasarg(args_user::AbstractVector{<:AbstractString},
								arg0::AbstractString
								)::Tuple{Bool,AbstractVector{<:AbstractString}}

	i = findfirst(==(arg0), args_user)

	isnothing(i) && return (false,args_user) 

	return (true,
					vcat(view(args_user, 1:i-1), view(args_user, i+1:length(args_user)))
					)

end  

function hasarg!(cmd::AbstractDict{<:AbstractString,<:Bool},
								args_user::AbstractVector{<:AbstractString},
								arg0::AbstractString
								)::AbstractVector{<:AbstractString}

	ha0,au = hasarg(args_user,arg0)

	setindex!(cmd,ha0,arg0)

	return au

end 


function findtiers(tiers::AbstractVector{<:AbstractDict},
									hosts::AbstractVector{<:AbstractString}
									)::Vector{Int}

	[i for (i,t)=enumerate(tiers) if any(in(keys(t)),hosts)]

#
#			for j=i+1:length(tiers)
#
#				if any(in(keys(tiers[j])), hosts)
#
#
#				end 
#
#			end 
#
#		end 
#
#	end 
#

#
#	any(h->haskey(t,h),hosts) 
#
#
#	D = filter(t->any(h->haskey(t,h),hosts),tiers) 
#	@assert length(D)==1 "Hosts must belong to one single tier at a time"

end 

function parse_input_args(args_user::AbstractString,
													)::Tuple{Vector{String},Dict}

	parse_input_args(split(args_user))

end 
function parse_input_args(args_user::AbstractVector{<:AbstractString},
													)::Tuple{Vector{String},Dict}

	options = Dict{String,Bool}()

	args_user = hasarg!(options, args_user, "kill")

	args_user = hasarg!(options, args_user, "all")

	args_user = hasarg!(options, args_user, "print") 

	return (isempty(args_user) ? [gethostname()] : args_user, options)

end 



function foo(
						 inp_hosts::AbstractVector{<:String},
						 options::AbstractDict{<:AbstractString,Bool},
						 tiers::AbstractVector{<:AbstractDict};
						 )::Tuple{Vector{String},OrderedDict}

	i_tiers = findtiers(tiers, inp_hosts)

	@assert length(i_tiers)==1 "Hosts must belong to one single tier at a time"

	D = OrderedDict(tiers[only(i_tiers)])
	
	return (options["all"] ? collect(keys(D)) : inp_hosts, D)

#	(tier,run_hosts)

end 

function jobsargs(run_hosts::AbstractVector{<:AbstractString},
						 tier::OrderedDict;
						 singlecore::Bool=false,
						 min_p::Int=6 
						 )::OrderedDict

	N = collect(values(tier))

	totN::Int = singlecore ? sum(N) : div(sum(N), minimum(N))

	jobranges = Utils.PropDistributeBallsToBoxes_cumulRanges(totN, N)


	ja = OrderedDict{String,Tuple{Int,Vector{NTuple{3,Int}}}}() 


	for host in run_hosts 
	
		R = only(R for (k,R)=zip(keys(tier),jobranges) if k==host)

		if singlecore || (tier[host]<min_p)

			ja[host] = (1,[(totN,i,i) for i=R])

		else 

			ja[host] = (tier[host], [(totN,R[1],R[end])])
			
		end 

	end 

	return ja
	
end  


function sshcmd(host::AbstractString,
								cmd::AbstractString)::String 
	
	"nohup ssh pahomit@$host.ethz.ch '$cmd' &" 

end 
function nohupsshcmd(host::AbstractString,
										 cmd::AbstractString,
										 (path1,path2)::AbstractVector{<:AbstractString},
										 )::String  

	nohupsshcmd(host, cmd, path1, path2)

end 


function nohupsshcmd(host::AbstractString,
										 cmd::AbstractString,
										 path1::AbstractString,
										 path2::AbstractString=path1
										 )::String 


	if host=="tudor-HP"  

		@assert host==gethostname() 

		return "cd $path1; $cmd &"

	end 

#	host!=gethostname()=="tudor-HP" || return cmd*" &"

	nice = in(host, ["rick","morty"]) ? "nice -n 12 " : ""

	return sshcmd(host, "bash; cd $path2; nohup $nice $cmd &")

end 


function cmdmain(host::AbstractString, n::Int,
								 args::NTuple{3,Int},
								 path::Union{AbstractString,AbstractVector{<:AbstractString}},
								 fname::AbstractString="main")::String 

	cmd = n<6 ? "" : "-p $n -L ~/.julia/config/startup.jl"

#	length(fname)>3 && fname[end-2:end]=="jl"

	@assert !occursin("/",fname)

	return nohupsshcmd(host, 
									join(["julia", cmd, 
												splitext(fname)[1]*".jl", args...]," "),
									path)

end 

function cmdsmain(ja::OrderedDict, args...
									)::Vector{Vector{String}}

	[[cmdmain(host,n,nse,args...) for nse=NSE] for (host,(n,NSE))=ja]

end 




function cmdkill(host::AbstractString, args...
								 )::Vector{String}

	if host!=gethostname()=="tudor-HP"

		return [sshcmd(host, "pkill -9 julia -u pahomit &")]

	end 

	return ["pkill -9 julia"]
#	@warn "kill command ignored when the target is the host"

	return String[]

end 



function get_commands(
						 inp_hosts::AbstractVector{<:String},
						 options::AbstractDict{<:AbstractString,Bool},
							tiers::AbstractVector{<:AbstractDict},
							args...;
						 kwargs...
						 )::Tuple{Vector{String},Vector{Vector{String}}}

	run_hosts,tier = foo(inp_hosts, options, tiers) 

	options["kill"] && return (run_hosts,cmdkill.(run_hosts))
	
	return (run_hosts,cmdsmain(jobsargs(run_hosts, tier; kwargs...), args...))

end 


function get_commands(
							args_user::AbstractString,
							tiers::AbstractVector{<:AbstractDict},
							args...;
						 kwargs...
						 )::Tuple{Vector{String},Vector{Vector{String}}}

	inp_hosts,options = parse_input_args(args_user)   

	run_hosts,tier = foo(inp_hosts, options, tiers) 

	options["kill"] && return (run_hosts,cmdkill.(run_hosts))
	
	return (run_hosts,cmdsmain(jobsargs(run_hosts, tier; kwargs...), args...))

end 


function run_commands(run_hosts::AbstractVector{<:AbstractString},
							 run_cmds::AbstractVector{<:AbstractVector{<:AbstractString}},
						 options::AbstractDict{<:AbstractString,Bool},
							 )

	run_ns = length.(run_cmds) 

	run_maxn = maximum(run_ns) 

	for i=1:run_maxn 
		
		println() 
	
		js = findall(>=(i), run_ns) 
	
		s = string("\nRound $i/$run_maxn, hosts ",
							 length(js),"/",length(run_hosts),
							 " (", join(view(run_hosts,js),", "),")\n ")
	
		@info s

		for j in js 

			cmd = run_cmds[j][i]
	
			println(cmd)

			options["print"] && continue 
	
			run(`sh -c $cmd`) 
	
		end 
	
		options["print"] && continue 
	
		sleep(0.3)
	
	end 
	
end 


function getrun_commands(args_user::AbstractString,
						 args...;
						 safe=nothing,#::Bool=true,
						 kwargs...
						 )

	inp_hosts,options = parse_input_args(args_user)  

	rhc  = get_commands(inp_hosts, options, args...; kwargs...) 


	if !options["print"] 

		if (safe isa Bool && safe) || !options["kill"] 

			@info "Commands prepared. First: |$(rhc[2][1][1])|\ny: launch\nn: print "

			if occursin("y",lowercase(readline(stdin)))   

				run_commands(rhc..., options)

			end 

			options["print"] = true 

		end 
	
	end 

	run_commands(rhc..., options)


end  
































































































#############################################################################
end # module LaunchJobs


