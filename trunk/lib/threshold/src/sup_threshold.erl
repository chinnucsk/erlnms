%%%-------------------------------------------------------------------
%%% File    : sup_threshold.erl
%%% Author  : Anders <anders@local>
%%% Description : 
%%%
%%% Created :  18 Jun 2004 by Anders <anders@local>
%%%-------------------------------------------------------------------
-module(sup_threshold).

-behaviour(supervisor).
%%--------------------------------------------------------------------
%% Include files
%%--------------------------------------------------------------------

%%--------------------------------------------------------------------
%% External exports
%%--------------------------------------------------------------------
-export([start_link/0]).

%%--------------------------------------------------------------------
%% Internal exports
%%--------------------------------------------------------------------
-export([init/1]).

%%--------------------------------------------------------------------
%% Macros
%%--------------------------------------------------------------------
-define(SERVER, ?MODULE).

%%--------------------------------------------------------------------
%% Records
%%--------------------------------------------------------------------

%%====================================================================
%% External functions
%%====================================================================
%%--------------------------------------------------------------------
%% Function: start_link/0
%% Description: Starts the supervisor
%%--------------------------------------------------------------------
start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

%%====================================================================
%% Server functions
%%====================================================================
%%--------------------------------------------------------------------
%% Func: init/1
%% Returns: {ok,  {SupFlags,  [ChildSpec]}} |
%%          ignore                          |
%%          {error, Reason}   
%%--------------------------------------------------------------------
init([]) ->
    {ok,{{one_for_one, 5, 30},
	 [{threshold, {threshold, start_link, []},
	   permanent, 5000, worker, [threshold]}
	  ,{threshold_conf, {threshold_conf, start_link, []},
	    permanent, 5000, worker, [threshold_conf]}
	 ]}}.

%%====================================================================
%% Internal functions
%%====================================================================

