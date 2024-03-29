module LaunchJobs 
#############################################################################

import myLibs: Utils  
import OrderedCollections: OrderedDict


#===========================================================================#
#
#
#
#---------------------------------------------------------------------------#


#===========================================================================#
#
# Levenshtein distance -- Wagner–Fischer algorithm
# More efficient -- store only two matrix rows 
#
#---------------------------------------------------------------------------# 

function LevenshteinDistance(s::AbstractString, t::AbstractString)::Int 

  # for all i and j, d[i,j] will hold the Levenshtein distance between
  # the first i characters of s and the first j characters of t
#  declare int d[0..m, 0..n]
#  set each element in d to zero

	m = length(s) 
	n = length(t)

	d = zeros(Int, m+1, n+1)
 
  # source prefixes can be transformed into empty string by
  # dropping all characters
 # for i from 1 to m:
 #   d[i, 0] := i

	setindex!(d, 1:m, 2:m+1, 1)

  # target prefixes can be reached from empty source prefix
  # by inserting every character
#  for j from 1 to n:
#    d[0, j] := j

	setindex!(d, 1:n, 1, 2:n+1)


#  for j from 1 to n:
#    for i from 1 to m:
#      if s[i] = t[j]:
#        substitutionCost := 0
#      else:
#        substitutionCost := 1
#
#      d[i, j] := minimum(d[i-1, j] + 1,                   # deletion
#                         d[i, j-1] + 1,                   # insertion
#                         d[i-1, j-1] + substitutionCost)  # substitution

	for j=1:n, i=1:m 

		d[i+1, j+1] = min(d[i, j+1] + 1, d[i+1, j] + 1, d[i, j] + (s[i]!=t[j]))
		
	end 

  return d[m+1,n+1]


end 


#

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


function findtier(tiers::AbstractVector{T},
									hosts::AbstractVector{<:AbstractString}
									)::Tuple{Int,Vector{String}
													 } where T<:AbstractDict{<:AbstractString,Int}
	
	if isempty(hosts) 
		
		length(tiers)==1 && return (1, collect(keys(only(tiers))))
		# only possibility

		# guess
		return findtier(tiers,[gethostname()]) 

	end 


	cands = [i for (i,t)=enumerate(tiers) if any(in(keys(t)),hosts)]

	isempty(cands) && error("No (known) host provided")

	length(cands)>1 && error("Hosts must belong to one single tier at a time")

	hosts_ = intersect(hosts, keys(tiers[only(cands)]))

	for host in setdiff(hosts, hosts_)

		dist = Dict(k=>LevenshteinDistance(host,k) for t=tiers for k=keys(t))

		dmin = minimum(values(dist))

		if dmin<=2 

			@warn string("Host '$host' not found. Did you mean any of: ", 
									 [k for (k,d)=dist if d==dmin]," ?")
	
		else  

			@warn "Host '$host' not known"

		end 
	end 

	return (only(cands),  hosts_)

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

	args_user = hasargval!(options, args_user, "nmin", 1, 
												 Base.Fix1(parse,Int)∘only)

	args_user = hasargval!(options, args_user, "nmax", 1, 
												 Base.Fix1(parse,Int)∘only)

	args_user = hasargval!(options, args_user, "pmin", 1, 
												 Base.Fix1(parse,Int)∘only)

	return (options, unique(args_user))

end 



function foo(
						 options::AbstractDict{<:AbstractString,<:Any},
						 inp_hosts::AbstractVector{<:String},
						 tiers::AbstractVector{<:AbstractDict};
						 )::Tuple{Vector{String},OrderedDict}

#	isempty(args_user) ? [gethostname()] : args_user 


	i, inp_hosts = findtier(tiers, inp_hosts) 

	D = OrderedDict(tiers[i])

	return (options["all"] ? collect(keys(D)) : inp_hosts, D)

#	(tier,run_hosts)

end 

function nr_max_procs(options::AbstractDict{<:AbstractString,<:Any},
											args...)::Int 

	nr_max_procs(options["pmax"], args...)

end  


function nr_min_procs(pmin::Bool)::Int 
	
	6

end   
function nr_min_procs(options::AbstractDict{<:AbstractString,<:Any})::Int 

	nr_min_procs(options["pmin"])

end 



function nr_min_procs(pmin::Int)::Int 

	@assert pmin>0 

	pmin

end   


function nr_max_procs(pmax::Bool, n::Int=1)::Int 
	
	n

end  

function nr_max_procs(pmax::Int, n::Int=1)::Int 

	min(pmax,n)

end 

#						 options::AbstractDict{<:AbstractString,<:Any},
#						n::Int; PMIN::Int=5, kwargs...
#						)::Int 
#
#	N = isa(options["pmax"],Int) ? min(options["pmax"], n) : n 
#
#	return N<PMIN ? 1 : N
#
#end  

function split_jobs_one(available_cores::Int, pmax::Int, 
												pmin_::Union{Int,Bool},
												)::Vector{Int}

	pmin = nr_min_procs(pmin_)

	pmax<pmin && return ones(Int,available_cores)

	boxes = Utils.FillBoxesWithBalls(available_cores, pmax)

	boxes[end]>=pmin && return boxes 

	return vcat(view(boxes, 1:length(boxes)-1),
							ones(Int, boxes[end])
							)

end 
function tot_nr_jobs(N::Int, nmin::Bool, nmax::Int)::Int 

	min(N,nmax)

end 

function tot_nr_jobs(N::Int, nmin::Int, nmax::Bool)::Int 

	max(N,nmin)

end 
function tot_nr_jobs(N::Int, nmin::Bool, nmax::Bool)::Int 

	N

end 


function tot_nr_jobs(N::Int, nmin::Int, nmax::Int)::Int 

	min(max(N,nmin),nmax)

end 



function jobsargs(run_hosts::AbstractVector{<:AbstractString},
						 tier::OrderedDict,
						 options::AbstractDict{<:AbstractString,<:Any};
						 kwargs...
						 )::OrderedDict

	N = collect(values(tier))

	totN = div(sum(N), nr_max_procs(options, minimum(N))) 

	totN = tot_nr_jobs(totN, options["nmin"], options["nmax"])

	jobranges = Utils.PropDistributeBallsToBoxes_cumulRanges(totN, N) 
####
# distribution used again below. Combine in a single operation 
#
#	for v in values(tier)
# 	split_jobs_one(v, nr_max_procs(options, v), options["pmin"])
# end 
#
# N = vcat(...) :
#
###


	ja = OrderedDict{String,Vector{NTuple{4,Int}}}() 


	for host in run_hosts 
			
		R = only(R for (k,R)=zip(keys(tier),jobranges) if k==host) 

		if isempty(R) 

			ja[host] = NTuple{4,Int}[]

			continue

		end 

		nr_procs = split_jobs_one(tier[host], #min(length(R),tier[host]), 
															nr_max_procs(options, tier[host]),
														 options["pmin"])
		
		rs = Utils.PropDistributeBallsToBoxes_cumulRanges(length(R), nr_procs)

		ja[host] = [(n,totN,R[r[1]],R[r[end]]) for (n,r)=zip(nr_procs,rs) if !isempty(r)]

	end 

	return ja
	
end  


function cmdsmain(ja::OrderedDict, args...
									)::Vector{Vector{String}}

	[[cmdmain(host,a,args...) for a=A] for (host,A)=ja]

end 

function cmdmain(host::AbstractString, 
								 (n,N,s,e)::NTuple{4,Int},
						 		options::AbstractDict{<:AbstractString,<:Any},
								 path::Union{AbstractString,AbstractVector{<:AbstractString}},
								 fname::AbstractString="main")::String 

	cmd = n<nr_min_procs(options) ? "" : "-p $n -L ~/.julia/config/startup.jl"

#	length(fname)>3 && fname[end-2:end]=="jl"

	@assert !occursin("/",fname)

	return nohupsshcmd(host, 
									join(["julia", cmd, 
												splitext(fname)[1]*".jl", N, s, e]," "),
									path)

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

function sshcmd(host::AbstractString,
								cmd::AbstractString)::String 
	
	# also without 'nohup' ? 
	
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

#	nice = in(host, ["rick","morty"]) ? "nice -n 12 " : ""
	nice = in(host, ["rick","morty", "yoshi", "toad", "spaceml4"]) ? "nice -n 15 " : ""

	return sshcmd(host, "bash; cd $path2; nohup $nice $cmd &")

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


	return (run_hosts,
					cmdsmain(jobsargs(run_hosts, tier, options; kwargs...), 
									 options,
									 args...))

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
						 safe=nothing,#::Bool=true,
						 kwargs...)


	rh,rc = get_commands(options, args...; kwargs...) 

	if !options["print"] 

		if (safe isa Bool && safe) || !options["kill"] 

			@info "Commands prepared. First on $(rh[1]): |$(rc[1][1])|\ny: launch\nn: print "

			if occursin("y",lowercase(readline(stdin)))   

				run_commands(rh, rc, options)

			end 

			options["print"] = true 

		end 
	
	end 

	run_commands(rh, rc, options)


end  
































































































#############################################################################
end # module LaunchJobs


