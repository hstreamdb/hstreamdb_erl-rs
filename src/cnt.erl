-module(cnt).

-behaviour(gen_server).

-export([start/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).

-record(state, {interval :: integer(), ok_acc :: integer(), err_acc :: integer()}).

start([{interval, Interval}]) ->
    {ok, Pid} = gen_server:start(cnt, [{interval, Interval}], []),
    spawn(fun Loop() ->
        timer:sleep(Interval),
        gen_server:call(Pid, clear),
        Loop()
    end),
    Pid.

-spec init(Args :: proplists:proplist()) -> {ok, #state{}}.
init([{interval, Interval}]) ->
    {ok, #state{
        interval = Interval,
        ok_acc = 0,
        err_acc = 0
    }}.

-spec handle_call(term(), gen_server:from(), #state{}) -> {reply, ok, #state{}}.
handle_call(
    clear,
    _,
    #state{
        interval = Interval,
        ok_acc = OkAcc,
        err_acc = ErrAcc
    } =
        State
) ->
    io:format("~p    ~p~n", [OkAcc / Interval / 1000, ErrAcc / Interval / 1000]),
    {reply, ok, State#state{ok_acc = 0, err_acc = 0}}.

handle_cast(_, State) ->
    {noreply, State}.

handle_info(Info, #state{ok_acc = OkAcc, err_acc = ErrAcc} = State) ->
    case hstreamdb:is_flush_result(Info) of
        true ->
            case hstreamdb:is_ok(Info) of
                true ->
                    {noreply, State#state{ok_acc = OkAcc + hstreamdb:batch_size(Info)}};
                false ->
                    {noreply, State#state{err_acc = ErrAcc + hstreamdb:batch_size(Info)}}
            end;
        false ->
            {noreply, State}
    end.
