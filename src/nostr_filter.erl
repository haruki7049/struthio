-module(nostr_filter).
-export([match_filters/2]).


%% A list of filters acts as an OR condition. Matches if any filter matches.
match_filters(_Event, []) -> true;
match_filters(Event, Filters) when is_list(Filters) ->
    lists:any(fun(Filter) -> match_filter(Event, Filter) end, Filters).


%% Guard: Ignore invalid filters that are not maps
match_filter(_Event, Filter) when not is_map(Filter) -> false;

%% A single filter object acts as an AND condition for its fields.
match_filter(Event, Filter) ->
    check_ids(Event, maps:get(~"ids", Filter, undefined)) andalso
    check_authors(Event, maps:get(~"authors", Filter, undefined)) andalso
    check_kinds(Event, maps:get(~"kinds", Filter, undefined)) andalso
    check_since(Event, maps:get(~"since", Filter, undefined)) andalso
    check_until(Event, maps:get(~"until", Filter, undefined)).


check_ids(_Event, undefined) -> true;
check_ids(Event, Ids) -> lists:member(maps:get(~"id", Event), Ids).


check_authors(_Event, undefined) -> true;
check_authors(Event, Authors) -> lists:member(maps:get(~"pubkey", Event), Authors).


check_kinds(_Event, undefined) -> true;
check_kinds(Event, Kinds) -> lists:member(maps:get(~"kind", Event), Kinds).


check_since(_Event, undefined) -> true;
check_since(Event, Since) -> maps:get(~"created_at", Event, 0) >= Since.


check_until(_Event, undefined) -> true;
check_until(Event, Until) -> maps:get(~"created_at", Event, 0) =< Until.
