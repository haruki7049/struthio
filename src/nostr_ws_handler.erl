-module(nostr_ws_handler).
-behaviour(cowboy_websocket).
-export([init/2, websocket_init/1, websocket_handle/2, websocket_info/2]).


init(Req, State) ->
    %% Upgrade the HTTP request to a WebSocket connection
    {cowboy_websocket, Req, State}.


websocket_init(State) ->
    {ok, State}.


%% Handle incoming text messages from the Nostr client
websocket_handle({text, Msg}, State) ->
    try jsx:decode(Msg, [return_maps]) of
        %% NIP-01: Client sends an EVENT
        [~"EVENT", Event] ->
            EventId = maps:get(~"id", Event),
            %% Pass the parsed map to our storage worker
            case nostr_storage_worker:process_event(Event) of
                ok ->
                    %% NIP-20: Send OK response (Success)
                    Reply = jsx:encode([~"OK", EventId, true, ~""]),
                    {reply, {text, Reply}, State};
                {error, Reason} ->
                    %% NIP-20: Send OK response (Failure)
                    ReasonBin = list_to_binary(io_lib:format("~p", [Reason])),
                    Reply = jsx:encode([~"OK", EventId, false, <<"error: ", ReasonBin/binary>>]),
                    {reply, {text, Reply}, State}
            end;

        %% NIP-01: Client requests events
        [~"REQ", SubscriptionId | Filters] ->
            Events = nostr_db:get_events(Filters),

            %% Create EVENT messages for each stored event
            EventReplies = [ {text, jsx:encode([~"EVENT", SubscriptionId, Ev])} || Ev <- Events ],

            %% Create EOSE (End of Stored Events) message
            EoseReply = {text, jsx:encode([~"EOSE", SubscriptionId])},

            %% Send all events followed by EOSE
            {reply, EventReplies ++ [EoseReply], State};

        %% NIP-01: Client closes subscription
        [~"CLOSE", _SubscriptionId] ->
            %% Currently stateless, so just ignore
            {ok, State};

        %% Ignore other message types (REQ, CLOSE) for now
        _Other ->
            {ok, State}
    catch
        _:_ ->
            %% Invalid JSON format
            ErrorReply = jsx:encode([~"NOTICE", ~"invalid: bad JSON"]),
            {reply, {text, ErrorReply}, State}
    end;

websocket_handle(_Data, State) ->
    {ok, State}.


websocket_info(_Info, State) ->
    {ok, State}.
