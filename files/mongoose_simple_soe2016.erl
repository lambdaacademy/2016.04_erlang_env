%%==============================================================================
%% Copyright 2015 Erlang Solutions Ltd.
%% Licensed under the Apache License, Version 2.0 (see LICENSE file)
%%
%% In this scenarion users are sending message to its neighbours
%% (users wiht lower and grater idea defined by NUMBER_OF_*_NEIGHBOURS values)
%% Messages will be send NUMBER_OF_SEND_MESSAGE_REPEATS to every selected neighbour
%% after every message given the script will wait SLEEP_TIME_AFTER_EVERY_MESSAGE ms
%% Every CHECKER_SESSIONS_INDICATOR is a checker session which just measures message TTD
%%
%%==============================================================================
-module(mongoose_simple_soe2016).

-include_lib("exml/include/exml.hrl").

-define(HOST, <<"localhost">>). %% The virtual host served by the server
-define(SERVER_IPS, {<<"173.16.1.100">>}). %% Tuple of servers, for example {<<"10.100.0.21">>, <<"10.100.0.22">>}
-define(CHECKER_SESSIONS_INDICATOR, 10). %% How often a checker session should be generated
-define(SLEEP_TIME_AFTER_SCENARIO, 10000). %% wait 10s after scenario before disconnecting
-define(NUMBER_OF_PREV_NEIGHBOURS, 4).
-define(NUMBER_OF_NEXT_NEIGHBOURS, 4).
-define(NUMBER_OF_SEND_MESSAGE_REPEATS, 1000000).

-behaviour(amoc_scenario).

-export([start/1]).
-export([init/0]).
-export([log_sent_messages/1]).

-define(MESSAGES_CT, [amoc, counters, messages_sent]).
-define(MESSAGES_CT_USER(Name), [amoc, counters, messages_sent,
                                 list_to_atom(binary_to_list(Name))]).
-define(MESSAGE_TTD_CT, [amoc, times, message_ttd]).

-type binjid() :: binary().

-spec init() -> ok.
init() ->
    lager:info("init some metrics"),
    exometer:new(?MESSAGES_CT, spiral),
    exometer_report:subscribe(exometer_report_graphite, ?MESSAGES_CT, [one, count], 10000),
    exometer:new(?MESSAGE_TTD_CT, histogram),
    exometer_report:subscribe(exometer_report_graphite, ?MESSAGE_TTD_CT, [mean, min, max, median, 95, 99, 999], 10000),
    ok.

-spec user_spec(binary(), binary(), binary()) -> escalus_users:user_spec().
user_spec(ProfileId, Password, Res) ->
    [ {username, ProfileId},
      {server, ?HOST},
      {host, pick_server(?SERVER_IPS)},
      {password, Password},
      {carbons, false},
      {stream_management, false},
      {resource, Res}
    ].

-spec make_user(amoc_scenario:user_id(), binary()) -> escalus_users:user_spec().
make_user(Id, R) ->
    BinId = integer_to_binary(Id),
    ProfileId = <<"user_", BinId/binary>>,
    Password = <<"password_", BinId/binary>>,
    user_spec(ProfileId, Password, R).

-spec start(amoc_scenario:user_id()) -> any().
start(MyId) ->
    my_seed(),
    Cfg = make_user(MyId, <<"res1">>),

    setup_per_user_sent_messages_metric(Cfg),
    
    IsChecker = MyId rem ?CHECKER_SESSIONS_INDICATOR == 0,

    {ConnectionTime, ConnectionResult} = timer:tc(escalus_connection, start, [Cfg]),
    Client = case ConnectionResult of
                 {ok, ConnectedClient, _, _} ->
                     exometer:update([amoc, counters, connections], 1),
                     exometer:update([amoc, times, connection], ConnectionTime),
                     ConnectedClient;
                 Error ->
                     exometer:update([amoc, counters, connection_failures], 1),
                     lager:error("Could not connect user=~p, reason=~p", [Cfg, Error]),
                     exit(connection_failed)
             end,

    do(IsChecker, MyId, Client, Cfg),

    timer:sleep(?SLEEP_TIME_AFTER_SCENARIO),
    send_presence_unavailable(Client),
    escalus_connection:stop(Client).

-spec do(boolean(), amoc_scenario:user_id(), escalus:client(), term()) -> any().
do(false, MyId, Client, Cfg) ->
    escalus_connection:set_filter_predicate(Client, none),

    send_presence_available(Client),
    timer:sleep(5000),

    NeighbourIds = lists:delete(MyId, lists:seq(max(1,MyId-?NUMBER_OF_PREV_NEIGHBOURS),
                                                MyId+?NUMBER_OF_NEXT_NEIGHBOURS)),
    MessageInterval = message_interval(),
    ExometerUpdateFn = exometer_update_fn(Cfg),
    Ref = schedule_logging(Cfg),
    send_messages_many_times(Client, MessageInterval, NeighbourIds, ExometerUpdateFn),
    cancel_logging(Ref);
do(_Other, _MyId, Client, _) ->
    lager:info("checker"),
    send_presence_available(Client),
    receive_forever(Client).

-spec receive_forever(escalus:client()) -> no_return().
receive_forever(Client) ->
    Stanza = escalus_connection:get_stanza(Client, message, infinity),
    Now = usec:from_now(os:timestamp()),
    case Stanza of
        #xmlel{name = <<"message">>, attrs=Attrs} ->
            case lists:keyfind(<<"timestamp">>, 1, Attrs) of
                {_, Sent} ->
                    TTD = (Now - binary_to_integer(Sent)),
                    exometer:update(?MESSAGE_TTD_CT, TTD);
                _ ->
                    ok
            end;
        _ ->
            ok
    end,
    receive_forever(Client).


-spec send_presence_available(escalus:client()) -> ok.
send_presence_available(Client) ->
    Pres = escalus_stanza:presence(<<"available">>),
    escalus_connection:send(Client, Pres).

-spec send_presence_unavailable(escalus:client()) -> ok.
send_presence_unavailable(Client) ->
    Pres = escalus_stanza:presence(<<"unavailable">>),
    escalus_connection:send(Client, Pres).

-spec send_messages_many_times(escalus:client(), timeout(), [binjid()], term()) -> ok.
send_messages_many_times(Client, MessageInterval, NeighbourIds, ExometerUpdateFn) ->
    S = fun(_) ->
                send_messages_to_neighbors(Client, NeighbourIds, MessageInterval, ExometerUpdateFn)
        end,
    lists:foreach(S, lists:seq(1, ?NUMBER_OF_SEND_MESSAGE_REPEATS)).


-spec send_messages_to_neighbors(escalus:client(), [binjid()], timeout(), term()) -> list().
send_messages_to_neighbors(Client, TargetIds, SleepTime, ExometerUpdateFn) ->
    [send_message(Client, make_jid(TargetId), SleepTime, ExometerUpdateFn)
     || TargetId <- TargetIds].

-spec send_message(escalus:client(), binjid(), timeout(), term()) -> ok.
send_message(Client, ToId, SleepTime, ExometerUpdateFn) ->
    MsgIn = make_message(ToId),
    TimeStamp = integer_to_binary(usec:from_now(os:timestamp())),
    escalus_connection:send(Client, escalus_stanza:setattr(MsgIn, <<"timestamp">>, TimeStamp)),
    ExometerUpdateFn(),
    timer:sleep(SleepTime).

-spec make_message(binjid()) -> exml:element().
make_message(ToId) ->
    Body = <<"hello sir, you are a gentelman and a scholar.">>,
    Id = escalus_stanza:id(),
    escalus_stanza:set_id(escalus_stanza:chat_to(ToId, Body), Id).

-spec make_jid(amoc_scenario:user_id()) -> binjid().
make_jid(Id) ->
    BinInt = integer_to_binary(Id),
    ProfileId = <<"user_", BinInt/binary>>,
    Host = ?HOST,
    << ProfileId/binary, "@", Host/binary >>.

-spec pick_server({binary()}) -> binary().
pick_server(Servers) ->
    S = size(Servers),
    N = erlang:phash2(self(), S) + 1,
    element(N, Servers).

my_seed() ->
    random:seed(erlang:phash2([node()]),
                erlang:monotonic_time(),
                erlang:unique_integer()).

setup_per_user_sent_messages_metric(Cfg) ->
    Username = proplists:get_value(username, Cfg),
    exometer:new(?MESSAGES_CT_USER(Username), spiral),
    exometer_report:subscribe(exometer_report_graphite,
                              ?MESSAGES_CT_USER(Username),
                              [one, count],
                              5000).

message_interval() ->
    1000 + random:uniform(5000).

exometer_update_fn(Cfg) ->
    Username = proplists:get_value(username, Cfg),
    fun() ->
            exometer:update(?MESSAGES_CT, 1),
            exometer:update(?MESSAGES_CT_USER(Username), 1)
    end.

schedule_logging(Cfg) ->
    Username = proplists:get_value(username, Cfg),
    {ok, TRef} = timer:apply_interval(5000, ?MODULE, log_sent_messages, [Username]),
    TRef.

cancel_logging(Ref) ->
    {ok, cancel} = timer:cancel(Ref).

-spec log_sent_messages(binary()) -> ok.
log_sent_messages(Username) ->
    {ok, [{count, N}]} = exometer:get_value(?MESSAGES_CT_USER(Username), [count]), 
    lager:info("Client ~p has sent ~p messages so far", [Username, N]).
