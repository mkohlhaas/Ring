-module(ring).

-export([run/0]).

run() ->
    NumLinks = 100,
    Counter = 100_000,

    T1 = erlang:system_time(),
    Caller = self(),
    Pids = [spawn(fun() -> proc(Caller) end) || _ <- lists:seq(1, NumLinks)],
    
    io:format("~p processes started in ~p seconds!~n", [
        NumLinks, execTime(T1, erlang:system_time())
    ]),
    
    T2 = erlang:system_time(),
    [HPid | TPids] = Pids,
    RPids = TPids ++ [HPid],
    [Pid ! {next, Next} || {Pid, Next} <- lists:zip(Pids, RPids)],

    io:format("~p processes linked in ~p seconds!~n", [
        NumLinks, execTime(T2, erlang:system_time())
    ]),

    T3 = erlang:system_time(),
    HPid ! NumLinks * Counter,
    receive
        done ->
            ok
    end,
    io:format("All messages sent in ~p seconds.~n", [execTime(T3, erlang:system_time())]).

proc(Caller) ->
    receive
        {next, Pid} ->
            put(next, Pid),
            proc(Caller);
        0 ->
            Caller ! done,
            proc(Caller);
        N ->
            get(next) ! N - 1,
            proc(Caller)
    end.

execTime(T1, T2) -> (T2 - T1) / 1_000_000_000.
