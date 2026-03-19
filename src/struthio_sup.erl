-module(struthio_sup).
-behaviour(supervisor).
-export([start_link/0, init/1]).


start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).


init([]) ->
    SupFlags = #{strategy => one_for_all, intensity => 3, period => 5},
    ChildSpecs = [#{
                    id => pg,
                    start => {pg, start_link, []},
                    restart => permanent,
                    shutdown => 5000,
                    type => worker,
                    modules => [pg]
                   },
                  #{
                    id => nostr_storage_worker,
                    start => {nostr_storage_worker, start_link, []},
                    restart => permanent,
                    shutdown => 5000,
                    type => worker,
                    modules => [nostr_storage_worker]
                   }],
    {ok, {SupFlags, ChildSpecs}}.
