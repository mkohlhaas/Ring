-module(ring).

-export([run/0]).


run() ->
    NumLinks = 100,
    Counter = 100_000,

    % Spawn N processes and connect them as a ring.
    T1 = erlang:system_time(),
    Caller = self(),
    Pids = [spawn(fun() -> proc(Caller) end) || _ <- lists:seq(1, NumLinks)],
    
    io:format("~p processes started in ~p seconds!~n", [
        NumLinks, execTime(T1, erlang:system_time())
    ]),
    
    [HPid | TPids] = Pids,
    RPids = TPids ++ [HPid],
    [Pid ! {next, Next} || {Pid, Next} <- lists:zip(Pids, RPids)],

    io:format("~p processes linked in ~p seconds!~nNow sending ~p messages in a ring!~n", [
        NumLinks, execTime(T1, erlang:system_time()), NumLinks * Counter
    ]),

    % Time sending messages around the ring M times.
    T2 = erlang:system_time(),
    HPid ! NumLinks * Counter,
    receive
        done ->
            ok
    end,

    io:format("All messages sent in ~p seconds.~n", [execTime(T2, erlang:system_time())]),
    io:format("Total time: ~p seconds.~n", [execTime(T1, erlang:system_time())]),

    ok.

proc(Caller) ->
    receive
        {next, Pid} ->
            put(next, Pid),
            proc(Caller);
        0 ->
            Caller ! done,
            proc(Caller);
        J ->
            get(next) ! J - 1,
            proc(Caller)
    end.

execTime(T1, T2) -> (T2 - T1) / 1_000_000_000.
