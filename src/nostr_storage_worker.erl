-module(nostr_storage_worker).
-behaviour(gen_server).
-export([start_link/0, init/1, handle_call/3, handle_cast/2, handle_info/2]).
-export([process_event/1]).


%% API
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).


process_event(Event) ->
    %% Entry point for incoming Nostr events
    gen_server:call(?MODULE, {process_event, Event}).


%% Gen Server Callbacks
init([]) ->
    %% Schedule the first cleanup cycle
    Interval = application:get_env(nostr_relay, cleanup_interval, 60000),
    erlang:send_after(Interval, self(), cleanup_tick),
    {ok, #{status => accept_all}}.


handle_call({process_event, Event}, _From, State) ->
    case check_storage_capacity() of
        full ->
            %% Reject immediately if capacity is reached
            {reply, {error, disk_full}, State#{status => read_only}};
        ok ->
            EventId = maps:get(<<"id">>, Event),
            Expiration = calculate_expiration(Event),
            nostr_db:store_event(EventId, {Event, Expiration}),
            {reply, ok, State#{status => accept_all}}
    end;

handle_call(_Request, _From, State) ->
    {reply, ignored, State}.


handle_cast(_Msg, State) ->
    {noreply, State}.


handle_info(cleanup_tick, State) ->
    %% Execute garbage collection
    Now = erlang:system_time(second),
    nostr_db:delete_expired(Now),

    %% Reschedule next cleanup
    Interval = application:get_env(nostr_relay, cleanup_interval, 60000),
    erlang:send_after(Interval, self(), cleanup_tick),
    {noreply, State}.


%% Internal Functions


check_storage_capacity() ->
    Limit = application:get_env(nostr_relay, storage_limit_pct, 85),
    %% Note: Actual OS disk check logic goes here (e.g., using disksup)
    CurrentUsage = 70,  %% Dummy value
    if CurrentUsage >= Limit -> full; true -> ok end.


calculate_expiration(Event) ->
    Tags = maps:get(<<"tags">>, Event, []),
    case find_expiration_tag(Tags) of
        {ok, ExpStr} ->
            %% Apply NIP-40 expiration tag
            binary_to_integer(ExpStr);
        error ->
            %% Apply default TTL from config
            case application:get_env(nostr_relay, default_ttl) of
                {ok, TTL} -> erlang:system_time(second) + TTL;
                undefined -> infinity  %% Store forever if no config exists
            end
    end.


find_expiration_tag([[<<"expiration">>, Value] | _]) -> {ok, Value};
find_expiration_tag([_ | T]) -> find_expiration_tag(T);
find_expiration_tag([]) -> error.
