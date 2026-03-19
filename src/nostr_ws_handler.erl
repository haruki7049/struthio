-module(nostr_ws_handler).
-behaviour(cowboy_websocket).
-export([init/2, websocket_init/1, websocket_handle/2, websocket_info/2]).


init(Req, _State) ->
    %% Initialize state with an empty subscriptions map
    {cowboy_websocket, Req, #{subs => #{}}}.


websocket_init(State) ->
    %% Join the process group for broadcasting
    pg:join(nostr_clients, self()),
    {ok, State}.


websocket_handle({text, Msg}, State) ->
    try jsx:decode(Msg, [return_maps]) of
        [~"EVENT", Event] ->
            EventId = maps:get(~"id", Event),
            case nostr_storage_worker:process_event(Event) of
                ok ->
                    Reply = jsx:encode([~"OK", EventId, true, ~""]),
                    {reply, {text, Reply}, State};
                {error, Reason} ->
                    ReasonBin = list_to_binary(io_lib:format("~p", [Reason])),
                    Reply = jsx:encode([~"OK", EventId, false, <<"error: ", ReasonBin/binary>>]),
                    {reply, {text, Reply}, State}
            end;

        [~"REQ", SubId | Filters] ->
            %% Add subscription to state
            Subs = maps:get(subs, State),
            NewState = State#{subs => Subs#{SubId => Filters}},

            %% Fetch and send past events
            Events = nostr_db:get_events(Filters),
            EventReplies = [ {text, jsx:encode([~"EVENT", SubId, Ev])} || Ev <- Events ],
            EoseReply = {text, jsx:encode([~"EOSE", SubId])},

            {reply, EventReplies ++ [EoseReply], NewState};

        [~"CLOSE", SubId] ->
            %% Remove subscription from state
            Subs = maps:get(subs, State),
            NewState = State#{subs => maps:remove(SubId, Subs)},
            {ok, NewState};

        _Other ->
            {ok, State}
    catch
        _:_ ->
            ErrorReply = jsx:encode([~"NOTICE", ~"invalid: bad JSON"]),
            {reply, {text, ErrorReply}, State}
    end;

websocket_handle(_Data, State) ->
    {ok, State}.


%% Handle internal Erlang messages (Pub/Sub broadcasts)
websocket_info({new_event, Event}, State) ->
    Subs = maps:get(subs, State),
    %% Push the event to all active subscriptions (ignoring filters for now)
    Replies = [ {text, jsx:encode([~"EVENT", SubId, Event])} || SubId <- maps:keys(Subs) ],
    {reply, Replies, State};

websocket_info(_Info, State) ->
    {ok, State}.
