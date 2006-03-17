%%%-------------------------------------------------------------------
%%% File    : pm_rrd_access.erl
%%% Author  : Anders Nygren <anders.nygren@gmail.com>
%%% Description : 
%%%
%%% Created :  5 Jun 2004 by Anders Nygren <anders.nygren@gmail.com>
%%%-------------------------------------------------------------------
-module(pm_rrd_access).

%%--------------------------------------------------------------------
%% Include files
%%--------------------------------------------------------------------
-include("pm_rec.hrl").
-include("pm_store.hrl").
-include("pm_rrdtool.hrl").

%%--------------------------------------------------------------------
%% External exports
-export([create/3,
	 fetch/7,
	 update/4
	]).

%%====================================================================
%% External functions
%%====================================================================

%% @spec create(Name,MOI,Store_type) -> Result
%% Name        = atom()
%% MOI         = [RDN]
%% RDN         = {Type,Id}
%% Type        = atom()
%% Id          = atom()
%% Store_type  = atom()
%% Result      = {atomic,Reply}
%% Reply       = WHAT
%% @doc Create a measurement store.

create(Name,MOI,Store_type) when is_atom(name),is_list(MOI),is_atom(Store_type)->
    {Step,DSS,RRA}=get_store_type_def(Store_type),
    [ST]=pm_rrd_config:get(pm_store_type,Store_type),
    MO_TYPE=ST#pm_store_type.mo_type,
    File=mk_file_name(Name,MOI,MO_TYPE),
    {ok,nothing}=rrdtool:create(File,[Step],DSS,RRA),
    {atomic,_Reply}=pm_rrd_config:insert(#pm_rrd_inst{name={MOI,MO_TYPE},
						      file=File}).

%% @spec fetch(MOI,MOC,Counters,CF,Res,Start,Stop) -> Result
%% MOI         = [RDN]
%% RDN         = {Type,Id}
%% Type        = atom()
%% Id          = atom()
%% MOC         = atom()
%% Counters    = [Counter]
%% Counter     = atom()
%% CF          = atom
%% Res         = Duration
%% Start       = datetime()
%% Stop        = datetime()
%% Result      = WHAT

fetch(MOI,MOC,Counters,CF,Res,Start,Stop) when is_tuple(Start) ->
    {PCs,DCs}=order_counters(MOI,MOC,Counters),
    DEFs=mk_defs(PCs),
    CDEFs=mk_cdefs(DCs),
    XPORTs=[{Name,Name}||Name <- Counters],
    {DEFs,CDEFs},
    rrdtool:xport({[{step,Res},{start,Start},{'end',Stop}],DEFs,CDEFs,XPORTs}).

%% @spec update(MOI,MOC,Time,Data) -> Result
%% MOI         = [RDN]
%% RDN         = {Type,Id}
%% Type        = atom()
%% Id          = atom()
%% MOC         = atom()
%% Time        = datetime()
%% Result      = {ok,[TimeStamp]}
%% TimeStamp   = integer()

update(MOI,MOC,Time,Data) ->
    {found,File}=pm_rrd_config:id_to_file(MOI,MOC),
    {found,Counters}=pm_rrd_config:get_counters(MOI,MOC,primary),
    TS1=mk_ts(Time),
    {ok,[TS1]}=rrdtool:update(File,Counters,[{TS1,Data}]).

%%====================================================================
%% Internal functions
%%====================================================================

get_store_type_def(Name) ->
    STORE_TYPE=pm_rrd_config:get(pm_store_type,Name),
    [#pm_store_type{name=Name,mo_type=MOC,archive=Arch,step=Step}]=STORE_TYPE,
    MO_TYPE=pm_rrd_config:get(pm_mo_type,MOC),
    [#pm_mo_type{name=MOC,counters=Counters,der_counters=_DC}]=MO_TYPE,
    Cs=lists:map(fun (C) ->
			 [#pm_counter{name={MOC,C},
				      type=T,
				      hb=HB,
				      min=MIN,
				      max=MAX}]=pm_rrd_config:get(pm_counter,{MOC,C}),
			 HB1=pm_config:get_duration(HB),
			 {C,T,HB1,MIN,MAX}
		 end, Counters),
    ARec=pm_rrd_config:get(pm_archive,Arch),
    [#pm_archive{name=Arch,aggregates=AGRS}]=ARec,
    As=lists:map(fun(A) ->
			 [R]=pm_rrd_config:get(pm_aggregate,A),
			 Dur=pm_config:get_duration(R#pm_aggregate.duration),
			 Res=pm_config:get_duration(R#pm_aggregate.resolution),
			 {R#pm_aggregate.cf,R#pm_aggregate.xff,Res,Dur}
		 end, AGRS),
    {{step,pm_config:get_duration(Step)},Cs,As}.

mk_file_name(_Name,MOI,Meas_type) ->
    {ok,Root}={ok,"/home/anders/src/data/pm/"}, %%%application:get_env(root_dir),
    Path=[Root]++lists:foldr(fun ({C,I},Acc) ->
				   [C,I]++Acc
			   end, 
			   [], MOI),
    CList=[to_string(P)||P<-Path],
    Path1=filename:join(CList),
    File=filename:join(Path1,to_string(Meas_type)++".rrd"),
    filelib:ensure_dir(File),
    File.

to_string(X) when is_atom(X) ->
    atom_to_list(X);
to_string(X) when is_integer(X) ->
    integer_to_list(X);
to_string(X) when is_list(X) ->
    X.

mk_ts(TS) ->
    Epoch=calendar:datetime_to_gregorian_seconds({{1970,1,1},{0,0,0}}),
    calendar:datetime_to_gregorian_seconds(TS)-Epoch.

order_counters(MOI,MOC,Counters) ->
    {PCs,DCs}=lists:foldl(fun (Cnt,Acc) ->
			   add_counter(MOI,MOC,[Cnt],Acc)
		   end,{[],[]},Counters),
    {lists:reverse(PCs),lists:reverse(DCs)}.

% add_counter(MOI,MOC,Counters) ->
%     add_counter(MOI,MOC,Counters,{[],[]}).

add_counter(MOI,MOC,Counters,Acc) ->
    lists:foldl(fun (C,Acc1) ->
			add_counter1(MOI,MOC,
				     pm_rrd_config:get_counter_def(MOI,MOC,C),
				     Acc1)
		end,
		Acc,Counters).

add_counter1(_MOI,_MOC,{counter,Cnt,File},{PCs,DCs}=Acc) ->
    case lists:keymember(Cnt,1,PCs) of
	true ->
	    Acc;
	false ->
	    {[{Cnt,File}|PCs],DCs}
    end;
add_counter1(MOI,MOC,{d_counter,Cnt,Expr,Deps,_File},{_PCs,DCs}=Acc) ->
    case lists:keymember(Cnt,1,DCs) of
	true ->
	    Acc;
	false ->
	    {PCs1,DCs1}=add_counter(MOI,MOC,Deps,Acc),
	    {PCs1,[{Cnt,Expr}|DCs1]}
    end.


mk_defs(PCs) ->
    [{Name,File,Name,'AVERAGE'} || {Name,File} <- PCs].
mk_cdefs(DCs) ->
    DCs.

