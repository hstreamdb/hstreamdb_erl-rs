-module(hstreamdb_SUITE).

-include_lib("eunit/include/eunit.hrl").

-define(SERVER_URL, <<"hstream://127.0.0.1:6570">>).

-export([all/0]).
-export([
    t_start_client/1,
    t_create_stream/1,
    t_create_subscription/1,
    t_start_producer/1,
    t_append/1,
    t_await_append_result/1,
    t_start_streaming_fetch/1
]).

all() ->
    [
        t_start_client,
        t_create_stream,
        t_create_subscription,
        t_start_producer,
        t_append,
        t_await_append_result,
        t_start_streaming_fetch
    ].

-spec rand_bin(N :: non_neg_integer()) -> binary().
rand_bin(N) ->
    Rand = crypto:strong_rand_bytes(N),
    base64:encode(Rand).

rand_stream_name() ->
    StreamName =
        io_lib:format("stream_name-~B-~B", [erlang:system_time(), rand:uniform(1000)]),
    list_to_binary(StreamName).

rand_subscription_id() ->
    SubscriptionId =
        io_lib:format("subscription_id-~B-~B", [erlang:system_time(), rand:uniform(1000)]),
    list_to_binary(SubscriptionId).

rand_consumer_name() ->
    ConsumerName =
        io_lib:format("consumer_name-~B-~B", [erlang:system_time(), rand:uniform(1000)]),
    list_to_binary(ConsumerName).

start_client() ->
    {ok, Client} = hstreamdb:start_client(?SERVER_URL, []),
    Client.

t_start_client(_Cfg) ->
    Client = start_client(),
    ?assert(is_reference(Client)),
    {ok, _} = hstreamdb:echo(Client, <<"alive">>),
    {ok, _} = hstreamdb:echo(Client, <<"alive">>),
    try
        hstreamdb:start_client(<<"hstream://example.com:6570">>, [])
    catch
        exit:{timeout, {start_client, 3}} ->
            ok
    end.

t_create_stream(_Cfg) ->
    Client = start_client(),
    StreamName = rand_stream_name(),
    ok = hstreamdb:create_stream(Client, StreamName, 1, 30 * 60, 8),
    StreamName.

t_create_subscription(Cfg) ->
    Client = start_client(),
    StreamName = t_create_stream(Cfg),
    SubscriptionId = rand_subscription_id(),
    ok =
        hstreamdb:create_subscription(
            Client,
            SubscriptionId,
            StreamName,
            30 * 60 * 60,
            1000,
            earliest
        ),
    SubscriptionId.

t_start_producer(Cfg) ->
    Client = start_client(),
    StreamName = t_create_stream(Cfg),
    {ok, Producer} =
        hstreamdb:start_producer(
            Client,
            StreamName,
            [{max_batch_len, 10}, {batch_deadline, 5000 * 2}]
        ),
    Producer.

t_append(Cfg) ->
    Producer = t_start_producer(Cfg),
    F = fun(_) ->
        {ok, Result} = hstreamdb:append(Producer, rand_bin(10), rand_bin(200), 5000 * 2),
        Result
    end,
    lists:map(F, lists:seq(1, 120)).

t_await_append_result(Cfg) ->
    Results = t_append(Cfg),
    lists:foreach(fun(Result) -> hstreamdb:await_append_result(Result) end, Results).

t_start_streaming_fetch(_Cfg) ->
    Client = start_client(),
    StreamName = rand_stream_name(),
    ok = hstreamdb:create_stream(Client, StreamName, 1, 30 * 60, 8),
    SubscriptionId = rand_subscription_id(),
    ok =
        hstreamdb:create_subscription(
            Client,
            SubscriptionId,
            StreamName,
            30 * 60 * 60,
            1000,
            earliest
        ),
    {ok, Producer} =
        hstreamdb:start_producer(
            Client,
            StreamName,
            [{max_batch_len, 10}, {batch_deadline, 5000 * 2}]
        ),
    F = fun(_) ->
        {ok, Result} = hstreamdb:append(Producer, rand_bin(10), rand_bin(200), 5000 * 2),
        Result
    end,
    Results = lists:map(F, lists:seq(1, 120)),
    ok = lists:foreach(fun(Result) -> hstreamdb:await_append_result(Result) end, Results),
    ok =
        hstreamdb:start_streaming_fetch(Client, self(), rand_consumer_name(), SubscriptionId),
    lists:foreach(
        fun(_) ->
            receive
                _ -> ok
            after 15000 -> exit(timeout)
            end
        end,
        lists:seq(1, 120)
    ).

t_bad_receive_timeout_value(_Cfg) ->
    Client = start_client(),
    {ok, _} = hstreamdb:echo(Client, <<"alive">>),
    {ok, _} = hstreamdb:echo(Client, <<"alive">>, 10 * 1000),
    {ok, _} = hstreamdb:echo(Client, <<"alive">>, infinity),
    {error, _} = hstreamdb:echo(Client, <<"alive">>, -1),
    {error, _} = hstreamdb:echo(Client, <<"alive">>, finity).
