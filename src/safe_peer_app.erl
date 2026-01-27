-module(safe_peer_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    safe_peer_sup:start_link().

stop(_State) ->
    ok.
