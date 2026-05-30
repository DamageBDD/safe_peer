-module(safe_peer).

-author("Steven Joseph <steven@stevenjoseph.in>").

-copyright("Steven Joseph <steven@stevenjoseph.in>").

-license("Apache-2.0").

-include_lib("kernel/include/logger.hrl").

-export([wrap/1, wrap/2, wrap/3]).

-define(DEFAULT_TIMEOUT_MS, 5000).

%% @doc Run MFA on an isolated peer node with default timeout.
wrap({M, F, A} = MFA) when is_atom(M), is_atom(F), is_list(A) ->
    wrap(MFA, default_timeout_ms()).

%% @doc Run MFA on an isolated peer node with TimeoutMs.
wrap({M, F, A} = MFA, TimeoutMs)
  when is_atom(M), is_atom(F), is_list(A),
       is_integer(TimeoutMs), TimeoutMs > 0 ->
    wrap(MFA, TimeoutMs, #{}).

%% @doc Run MFA on an isolated peer node with TimeoutMs and Options map.
%% Options:
%%  - peer_args => [string()]
%%  - peer_name_prefix => string()
wrap({M, F, A} = MFA, TimeoutMs, Opts)
  when is_atom(M), is_atom(F), is_list(A),
       is_integer(TimeoutMs), TimeoutMs > 0,
       is_map(Opts) ->
    case is_distributed_alive() of
        false -> {error, not_alive};
        true  -> do_wrap(MFA, TimeoutMs, Opts)
    end.

%% -------------------------
%% Internals
%% -------------------------

default_timeout_ms() ->
    application:get_env(safe_peer, default_timeout_ms, ?DEFAULT_TIMEOUT_MS).

is_distributed_alive() ->
    %% Node must be alive for peer/rpc to work
    node() =/= nonode@nohost.

do_wrap(MFA, TimeoutMs, Opts) ->
    PeerArgs = maps:get(peer_args, Opts,
                        application:get_env(safe_peer, peer_args, ["-hidden"])),
    Prefix   = maps:get(peer_name_prefix, Opts,
                        application:get_env(safe_peer, peer_name_prefix, "safepeer")),
    UniqueName = unique_peer_name(Prefix),

    %% Start peer as hidden. We keep it explicit.
    %% peer:start_link/1 signature varies slightly across OTP versions,
    %% but the map form is stable in modern OTP.
    case peer:start_link(#{
            name => list_to_atom(UniqueName),
            args => PeerArgs
         }) of
        {ok, PeerPid, PeerNode} ->
            try
                call_on_peer(PeerPid, PeerNode, MFA, TimeoutMs)
            after
                %% Always try to stop peer; it's fine if already dead.
                safe_peer_stop(PeerPid)
            end;
        {error, Reason} ->
            {error, {peer_start_failed, Reason}}
    end.

unique_peer_name(Prefix) ->
    %% Make a shortname-ish identifier; OTP will place it on same host.
    %% Example: "safepeer_1700000000_12345"
    T = integer_to_list(erlang:system_time(second)),
    U = integer_to_list(erlang:unique_integer([positive])),
    Prefix ++ "_" ++ T ++ "_" ++ U.

call_on_peer(PeerPid, PeerNode, {M,F,A}, TimeoutMs) ->
    Ref = make_ref(),
    Parent = self(),

    %% Monitor node so we can detect peer crashes (NIF crash, halt, etc.)
    monitor_node(PeerNode, true),

    %% Run rpc in a worker so we can enforce timeout cleanly.
    Worker = spawn_link(fun() ->
        Res = rpc:call(PeerNode, M, F, A),
        Parent ! {Ref, {rpc_result, Res}}
    end),

    receive
        {Ref, {rpc_result, Res}} ->
            %% rpc:call can return {'badrpc', Reason}
            monitor_node(PeerNode, false),
            unlink(Worker),
            normalize_rpc_result(Res);

        {nodedown, PeerNode} ->
            %% Peer died: treat as NIF crash / halt / hard failure.
            monitor_node(PeerNode, false),
            safe_worker_kill(Worker),
            {error, noconnection}
    after TimeoutMs ->
            %% Timeout: kill worker and peer.
            monitor_node(PeerNode, false),
            safe_worker_kill(Worker),
            safe_peer_stop(PeerPid),
            {error, timeout}
    end.

normalize_rpc_result({'badrpc', nodedown}) ->
    {error, noconnection};
normalize_rpc_result({'badrpc', timeout}) ->
    {error, timeout};
normalize_rpc_result({'badrpc', Reason}) ->
    {error, {badrpc, Reason}};
normalize_rpc_result(Res) ->
    {ok, Res}.

safe_peer_stop(PeerPid) ->
    try
        peer:stop(PeerPid)
    catch
        _:_ ->
            ok
    end.

safe_worker_kill(Worker) ->
    try
        exit(Worker, kill)
    catch
        _:_ ->
            ok
    end.
