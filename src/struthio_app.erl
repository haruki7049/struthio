-module(struthio_app).
-behaviour(application).
-export([start/2, stop/1]).


start(_StartType, _StartArgs) ->
    %% Initialize database before starting supervisor
    nostr_db:init(),
    nostr_relay_sup:start_link().


stop(_State) ->
    ok.
