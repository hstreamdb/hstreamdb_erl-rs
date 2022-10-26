-module(bench).

-include("bench.hrl").

-export([start/0]).

start() ->
    observer:start(),
    CntPid = cnt:start([{interval, 5000}]),
    Url = <<"http://127.0.0.1:6570">>,
    Producers =
        lists:map(
            fun(_) ->
                Stream =
                    base64:encode(
                        crypto:strong_rand_bytes(10)
                    ),
                ok = hstreamdb:create_stream(Url, Stream, 1, 10 * 60, 1),
                timer:sleep(50),
                {ok, Producer} =
                    hstreamdb:start_producer(
                        Url,
                        Stream,
                        [
                            {on_flush, CntPid},
                            {max_batch_len, 180}
                        ]
                    ),
                Producer
            end,
            lists:seq(1, 5)
        ),

    Payload = ?PAYLOAD_4K,
    LoopFun =
        fun Loop(Producer) ->
            timer:sleep(1),
            Rand =
                base64:encode(
                    crypto:strong_rand_bytes(30)
                ),
            _ = hstreamdb:append(Producer, Rand, Payload),
            _ = hstreamdb:append(Producer, Rand, Payload),
            Loop(Producer)
        end,
    lists:foreach(fun(Producer) -> spawn(fun() -> LoopFun(Producer) end) end, Producers),
    timer:sleep(100 * 1000),
    lists:foreach(fun hstreamdb:stop_producer/1, Producers),
    ok.
