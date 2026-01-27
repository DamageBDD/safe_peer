-module(safe_peer_sup).
-behaviour(supervisor).

-export([start_link/0]).
-export([init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    %% For now, we don't keep a pool. This supervisor exists so
    %% the app is OTP-clean and you can later add pooling workers.
    SupFlags = #{
        strategy => one_for_one,
        intensity => 5,
        period => 10
    },
    ChildSpecs = [],
    {ok, {SupFlags, ChildSpecs}}.
