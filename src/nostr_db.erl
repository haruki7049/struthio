-module(nostr_db).
-export([init/0, store_event/2, delete_expired/1, get_events/1]).
-record(nostr_event, {id, event_data, expires_at}).


init() ->
    %% Create schema on local node and start Mnesia
    mnesia:create_schema([node()]),
    mnesia:start(),
    mnesia:create_table(nostr_event,
                        [{attributes, record_info(fields, nostr_event)},
                         {disc_copies, [node()]}]),
    mnesia:wait_for_tables([nostr_event], 5000).


store_event(EventId, {EventData, ExpiresAt}) ->
    %% Write a new event to Mnesia within a transaction
    F = fun() ->
                mnesia:write(#nostr_event{id = EventId, event_data = EventData, expires_at = ExpiresAt})
        end,
    {atomic, ok} = mnesia:transaction(F),
    ok.


delete_expired(Now) ->
    %% Select and delete all events where expires_at is less than Now
    F = fun() ->
                MatchHead = #nostr_event{id = '$1', event_data = '_', expires_at = '$2'},
                Guard = {'<', '$2', Now},
                Result = '$1',
                Keys = mnesia:select(nostr_event, [{MatchHead, [Guard], [Result]}]),
                lists:foreach(fun(Key) -> mnesia:delete({nostr_event, Key}) end, Keys)
        end,
    mnesia:transaction(F).


%% Fetch events with filters and sorting
get_events(Filters) ->
    F = fun() ->
                mnesia:match_object({nostr_event, '_', '_', '_'})
        end,
    {atomic, Records} = mnesia:transaction(F),

    %% Extract event maps
    AllEvents = [ EventData || #nostr_event{event_data = EventData} <- Records ],

    %% Apply filters
    FilteredEvents = lists:filter(fun(Ev) -> nostr_filter:match_filters(Ev, Filters) end, AllEvents),

    %% Sort descending by created_at (Newest first)
    lists:sort(fun(A, B) ->
                       maps:get(~"created_at", A, 0) >= maps:get(~"created_at", B, 0)
               end,
               FilteredEvents).
