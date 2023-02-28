module LaunchJobs 
#############################################################################

import myLibs: Utils  
import OrderedCollections: OrderedDict

#===========================================================================#
#
#
#
#---------------------------------------------------------------------------#


function hasargval(args_user::AbstractVector{<:AbstractString}, 
									 arg0::AbstractString,
									 nvals::Int=0,
									 farg::Function=copy,
								)::Tuple{<:Any,AbstractVector{<:AbstractString}}

	i = findfirst(==(arg0), args_user)

	isnothing(i) && return (false,args_user) 

	@assert length(args_user)>=i+nvals "Not enough args for '$arg0' ($nvals required)"

	return (nvals==0 ? true : farg(view(args_user, i+1:i+nvals)),
					vcat(view(args_user, 1:i-1), 
							 view(args_user, i+nvals+1:length(args_user)))
					)

end  

#function hasarg(args_user::AbstractVector{<:AbstractString},
#								arg0::AbstractString
#								)::Tuple{Bool,AbstractVector{<:AbstractString}}
#
#	i = findfirst(==(arg0), args_user)
#
#	isnothing(i) && return (false,args_user) 
#
#	return (true,
#					vcat(view(args_user, 1:i-1), view(args_user, i+1:length(args_user)))
#					)
#
#end  

function hasargval!(cmd::AbstractDict{<:AbstractString,<:Any},
								args_user::AbstractVector{<:AbstractString},
								k::AbstractString,
								args...
								)::AbstractVector{<:AbstractString}

	v,rest = hasargval(args_user,k,args...)

	setindex!(cmd,v,k)

	return rest

end 


function findtiers(tiers::AbstractVector{<:AbstractDict},
									hosts::AbstractVector{<:AbstractString}
									)::Vector{Int}

	[i for (i,t)=enumerate(tiers) if any(in(keys(t)),hosts)]

end 

function parse_input_args(args_user::AbstractString,
													)::Tuple{Dict,Vector{String}}

	parse_input_args(split(args_user))

end 
function parse_input_args(args_user::AbstractVector{<:AbstractString},
													)::Tuple{Dict,Vector{String}}

	options = Dict{String,Any}()

	args_user = hasargval!(options, args_user, "kill")

	args_user = hasargval!(options, args_user, "all")

	args_user = hasargval!(options, args_user, "print") 

	args_user = hasargval!(options, args_user, "pmax", 1, 
												 Base.Fix1(parse,Int)∘only)

	return (options,
					isempty(args_user) ? [gethostname()] : args_user)

end 



function foo(
						 options::AbstractDict{<:AbstractString,<:Any},
						 inp_hosts::AbstractVector{<:String},
						 tiers::AbstractVector{<:AbstractDict};
						 )::Tuple{Vector{String},OrderedDict}

	i_tiers = findtiers(tiers, inp_hosts)

	@assert length(i_tiers)==1 "Hosts must belong to one single tier at a time"

	D = OrderedDict(tiers[only(i_tiers)])
	
	return (options["all"] ? collect(keys(D)) : inp_hosts, D)

#	(tier,run_hosts)

end 

function jobsargs(run_hosts::AbstractVector{<:AbstractString},
						 tier::OrderedDict,
						 options::AbstractDict{<:AbstractString,<:Any};
						 pmin::Int=6,
#						 singlecore::Bool=false,
						 )::OrderedDict


	singlecore = options["pmax"] isa Int  

	if singlecore

		@assert options["pmax"]==1 "Only all-/singlecore supported"

	end 


	N = collect(values(tier))

	totN = singlecore ? sum(N) : div(sum(N), minimum(N))

	jobranges = Utils.PropDistributeBallsToBoxes_cumulRanges(totN, N)


	ja = OrderedDict{String,Tuple{Int,Vector{NTuple{3,Int}}}}() 


	for host in run_hosts 
	
		R = only(R for (k,R)=zip(keys(tier),jobranges) if k==host)

		if singlecore || (tier[host]<pmin)

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
						 options::AbstractDict{<:AbstractString,<:Any},
						 inp_hosts::AbstractVector{<:String},
						 tiers::AbstractVector{<:AbstractDict},
							args...;
						 kwargs...
						 )::Tuple{Vector{String},Vector{Vector{String}}}

	run_hosts,tier = foo(options, inp_hosts, tiers)

	options["kill"] && return (run_hosts,cmdkill.(run_hosts))


	return (run_hosts,cmdsmain(jobsargs(run_hosts, tier, options; kwargs...), args...))

end 


function get_commands(
							args_user::Union{AbstractString,
															 <:AbstractVector{<:AbstractString}},
							args...;
						 kwargs...
						 )::Tuple{Vector{String},Vector{Vector{String}}}

	get_commands(parse_input_args(args_user)..., args...; kwargs...)

end 


function run_commands(run_hosts::AbstractVector{<:AbstractString},
							 run_cmds::AbstractVector{<:AbstractVector{<:AbstractString}},
						 options::AbstractDict{<:AbstractString,<:Any},
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

function getrun_commands(
							args_user::Union{AbstractString,
															 <:AbstractVector{<:AbstractString}},
						 args...;
						 kwargs...
						 )

	getrun_commands(parse_input_args(args_user)..., args...; kwargs...)

end 

function getrun_commands(
						 options::AbstractDict{<:AbstractString,<:Any},
						 args...; 
#						 safe=nothing,#::Bool=true,
						 kwargs...)



	rhc  = get_commands(options, args...; kwargs...) 

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


