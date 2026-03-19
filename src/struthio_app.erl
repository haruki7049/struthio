-module(struthio_app).
-behaviour(application).
-export([start/2, stop/1]).


start(_StartType, _StartArgs) ->
    %% Initialize database
    nostr_db:init(),

    %% Setup Cowboy routing (Route "/" to nostr_ws_handler)
    Dispatch = cowboy_router:compile([{'_', [{"/", nostr_ws_handler, []}]}]),

    %% Start Cowboy listener on port 8080
    {ok, _} = cowboy:start_clear(http_listener,
                                 [{port, 8080}],
                                 #{env => #{dispatch => Dispatch}}),

    %% Start main supervisor
    struthio_sup:start_link().


stop(_State) ->
    cowboy:stop_listener(http_listener),
    ok.
