-module(server).
-import(maps, []).
-export[start/0].

start() ->
    io:fwrite("\n\n Holaaa!!!, This is Twitter Engine Clone \n\n"),
    Table_set = ets:new(messages, [ordered_set, named_table, public]),
    Clt_Sckt_Mapping = ets:new(clients, [ordered_set, named_table, public]),
    All_Clients = [],
    Map_set = maps:new(),
    {ok, ListenSkt} = gen_tcp:listen(1204, [binary, {keepalive, true}, {reuseaddr, true}, {active, false}]),
    awaiting_connections(ListenSkt, Table_set, Clt_Sckt_Mapping).

awaiting_connections(Listen, Table_set, Clt_Sckt_Mapping) ->
    {ok, Skt} = gen_tcp:accept(Listen),
    ok = gen_tcp:send(Skt, "YIP"),
    spawn(fun() -> awaiting_connections(Listen, Table_set, Clt_Sckt_Mapping) end),
    do_recv_meth(Skt, Table_set, [], Clt_Sckt_Mapping).

do_recv_meth(Skt, Table_set, Bs, Clt_Sckt_Mapping) ->
    io:fwrite("Perform Receive\n\n"),
    case gen_tcp:recv(Skt, 0) of
        {ok, D1} ->
            
            D = re:split(D1, ","),
            Type_var = binary_to_list(lists:nth(1, D)),

            io:format("\n\nDATA: ~p\n\n ", [D]),
            io:format("\n\nTYPE: ~p\n\n ", [Type_var]),

            if 
                Type_var == "register" ->
                    UName = binary_to_list(lists:nth(2, D)),
                    P_ID = binary_to_list(lists:nth(3, D)),
                    io:format("\nPID:~p\n", [P_ID]),
                    io:format("\nSocket:~p\n", [Skt]),
                    io:format("Type: ~p\n", [Type_var]),
                    io:format("\n~p is intrested to register an new account\n", [UName]),
                    
                    Op = ets:lookup(Table_set, UName),
                    io:format("Output: ~p\n", [Op]),
                    if
                        Op == [] ->

                            ets:insert(Table_set, {UName, [{"followers", []}, {"tweets", []}]}),      
                            ets:insert(Clt_Sckt_Mapping, {UName, Skt}),                
                            Temp_Lst = ets:lookup(Table_set, UName),
                            io:format("~p", [lists:nth(1, Temp_Lst)]),

                          
                            ok = gen_tcp:send(Skt, "User has been succesfully registered"), 
                            io:fwrite("You are Good to go, Key is not found in database\n");
                        true ->
                            ok = gen_tcp:send(Skt, "Sorry, Username was already taken! Please run using new username"),
                            io:fwrite("Sorry, Duplicate key!!!\n")
                    end,
                    do_recv_meth(Skt, Table_set, [UName], Clt_Sckt_Mapping);

                Type_var == "tweet" ->
                    UName = binary_to_list(lists:nth(2, D)),
                    Twt = binary_to_list(lists:nth(3, D)),
                    io:format("\n ~p has sent this tweet: ~p", [UName, Twt]),
                    V = ets:lookup(Table_set, UName),
                    io:format("Output: ~p\n", [V]),
                    V3 = lists:nth(1, V),
                    V2 = element(2, V3),
                    V1 = maps:from_list(V2),
                    {ok, Crnt_Followers} = maps:find("followers",V1),                         
                    {ok, CurrentTwts} = maps:find("tweets",V1),

                    NewTwts = CurrentTwts ++ [Twt],
                    io:format("~p~n",[NewTwts]),
                    
                    ets:insert(Table_set, {UName, [{"followers", Crnt_Followers}, {"tweets", NewTwts}]}),

                    Op_After_Twt = ets:lookup(Table_set, UName),
                    io:format("\nOutput got after tweeting: ~p\n", [Op_After_Twt]),
                  
                    sendMsg(Skt, Clt_Sckt_Mapping, Twt, Crnt_Followers, UName),
                    ok = gen_tcp:send(Skt, "Server has processed the tweet succesfully\n"),
                    do_recv_meth(Skt, Table_set, [UName], Clt_Sckt_Mapping);

                Type_var == "retweet" ->
                    Person_UName = binary_to_list(lists:nth(2, D)),
                    UName = binary_to_list(lists:nth(3, D)),
                    S_User = string:strip(Person_UName, right, $\n),
                    io:format("User has to retweet from: ~p\n", [S_User]),
                    Twt = binary_to_list(lists:nth(4, D)),
                    O = ets:lookup(Table_set, S_User),
                    if
                        O == [] ->
                            io:fwrite("Sorry, User you selected does not exist!\n");
                        true ->
                            
                            O1 = ets:lookup(Table_set, UName),
                            V3 = lists:nth(1, O1),
                            V2 = element(2, V3),
                            V1 = maps:from_list(V2),
                            
                            V_3 = lists:nth(1, O),
                            V_2 = element(2, V_3),
                            V_1 = maps:from_list(V_2),
                            
                            {ok, Crnt_Followers} = maps:find("followers",V1),
                            
                            {ok, CurrentTwts} = maps:find("tweets",V_1),
                            io:format("The following Tweet to be re-posted: ~p\n", [Twt]),
                            CheckTwt = lists:member(Twt, CurrentTwts),
                            if
                                CheckTwt == true ->
                                    NewTwt = string:concat(string:concat(string:concat("re:",S_User),"->"),Twt),
                                    sendMsg(Skt, Clt_Sckt_Mapping, NewTwt, Crnt_Followers, UName);
                                true ->
                                    io:fwrite("The Tweet you selected does not exist!\n")
                            end     
                    end,
                    io:format("\n ~p was intrested in retweeting something\n", [UName]),
                    ok = gen_tcp:send(Skt, "Server has processed the retweet succesfully\n"),
                    do_recv_meth(Skt, Table_set, [UName], Clt_Sckt_Mapping);

                Type_var == "subscribe" ->
                    UName = binary_to_list(lists:nth(2, D)),
                    SubscribedUName = binary_to_list(lists:nth(3, D)),
                    S_User = string:strip(SubscribedUName, right, $\n),
                    Op1 = ets:lookup(Table_set, S_User),
                    if
                        Op1 == [] ->
                            io:fwrite("Sorry, The username you have mentioned doesn't exist! Please try again. \n");
                        true ->

                            V = ets:lookup(Table_set, S_User),
                            V3 = lists:nth(1, V),
                            V2 = element(2, V3),

                            V1 = maps:from_list(V2),                            
                            {ok, Crnt_Followers} = maps:find("followers",V1),
                            {ok, CurrentTwts} = maps:find("tweets",V1),

                            N_Followers = Crnt_Followers ++ [UName],
                            io:format("~p~n",[N_Followers]),
                        
                            ets:insert(Table_set, {S_User, [{"followers", N_Followers}, {"tweets", CurrentTwts}]}),

                            Op2 = ets:lookup(Table_set, S_User),
                            io:format("\nThe Output we got after subscribing is: ~p\n", [Op2]),

                            ok = gen_tcp:send(Skt, "Subscription was succesful!!!"),

                            do_recv_meth(Skt, Table_set, [UName], Clt_Sckt_Mapping)
                    end,
                    io:format("\n ~p wants to subscribe to ~p\n", [UName, S_User]),
                    
                    ok = gen_tcp:send(Skt, "Server has processed the subscription succesfully. Subscribed!"),
                    do_recv_meth(Skt, Table_set, [UName], Clt_Sckt_Mapping);

                Type_var == "query" ->
                    Optn = binary_to_list(lists:nth(3, D)),
                    UName = binary_to_list(lists:nth(2, D)),
                    io:format("Query: The current username we are using is -> ~p\n", [UName]),
                    
                    if
                        Optn == "1" ->
                            io:fwrite("My mentions are!!!\n"),
                            MyUName = binary_to_list(lists:nth(4, D)),
                            Sub_UName = ets:first(Table_set),
                            S_User = string:strip(Sub_UName, right, $\n),
                            io:format("Sub_UserName: ~p\n", [S_User]),
                            Twts = searchAllTwts("@", Table_set, S_User, MyUName , []),
                            ok = gen_tcp:send(Skt, Twts);
                        Optn == "2" ->
                            io:fwrite("Hashtag Searches are\n"),
                            Hash_tag = binary_to_list(lists:nth(4, D)),
                            Sub_UName = ets:first(Table_set),
                            S_User = string:strip(Sub_UName, right, $\n),
                            io:format("Sub_UserName: ~p\n", [S_User]),
                            Twts = searchAllTwts("#", Table_set, S_User, Hash_tag , []),
                            ok = gen_tcp:send(Skt, Twts);
                        true ->
                            io:fwrite("Subscribed User Searching\n"),
                            
                            Sub_UName = ets:first(Table_set),
                            S_User = string:strip(Sub_UName, right, $\n),
                            io:format("Sub_UserName: ~p\n", [S_User]),
                            V = ets:lookup(Table_set, S_User),
                            
                            V3 = lists:nth(1, V),
                            V2 = element(2, V3),
                            V1 = maps:from_list(V2),                            
                            {ok, CurrentTwts} = maps:find("tweets",V1),
                            io:format("\n ~p : ", [S_User]),
                            io:format("~p~n",[CurrentTwts]),
                            search_Full_Tab(Table_set, S_User, UName),
                            ok = gen_tcp:send(Skt, CurrentTwts)
                    end,
                    io:format("\n ~p intrested to query", [UName]),
                    
                    do_recv_meth(Skt, Table_set, [UName], Clt_Sckt_Mapping);
                true ->
                    io:fwrite("\n Do you need Anything else!")
            end;

        {error, closed} ->
            {ok, list_to_binary(Bs)};
        {error, Reason} ->
            io:fwrite("error"),
            io:fwrite(Reason)
    end.

searchAllTwts(Sym, Table_set, K, Wrd, Found_var) ->
    Search_var = string:concat(Sym, Wrd),
    io:format("The Word we need to search is: ~p~n", [Search_var]),
    if
        K == '$end_of_table' ->
            io:fwrite("Found the following tweets: ~p~n", [Found_var]),
            Found_var;
        true ->
            io:fwrite("Current Row key: ~p~n", [K]),
            V = ets:lookup(Table_set, K),
            V3 = lists:nth(1, V),
            V2 = element(2, V3),
            V1 = maps:from_list(V2),                              
            {ok, CurrentTwts} = maps:find("tweets",V1),
            io:fwrite("CurrentTweets: ~p~n", [CurrentTwts]),
            FilteredTwts = [S || S <- CurrentTwts, string:str(S, Search_var) > 0],
            io:fwrite("FilteredTweets: ~p~n", [FilteredTwts]),
            Found_var1 = Found_var ++ FilteredTwts,
            CrntRow_Key = ets:next(Table_set, K),
            searchAllTwts(Sym, Table_set, CrntRow_Key, Wrd, Found_var1)
    end.


search_Full_Tab(Table_set, K, UName) ->
    CrntRow_Key = ets:next(Table_set, K),
    V = ets:lookup(Table_set, CrntRow_Key),
    V3 = lists:nth(1, V),
    V2 = element(2, V3),
    V1 = maps:from_list(V2),                            
    {ok, Crnt_Followers} = maps:find("followers",V1),
    IsMem = lists:member(UName, Crnt_Followers),
    if
        IsMem == true ->
            {ok, CurrentTwts} = maps:find("tweets",V1),
            io:format("\n ~p : ", [CrntRow_Key]),
            io:format("~p~n",[CurrentTwts]),
            search_Full_Tab(Table_set, CrntRow_Key, UName);
        true ->
            io:fwrite("\n No more tweets are there!\n")
    end,
    io:fwrite("\n Searching the whole table for the tweets!\n").

sendMsg(Skt, Clt_Sckt_Mapping, Twt, Subscribers, UName) ->
    if
        Subscribers == [] ->
            io:fwrite("\nYou have No followers!\n");
        
        true ->
            
            [Client_To_Send | Remaining_List ] = Subscribers,
            io:format("Client to send: ~p\n", [Client_To_Send]),
            io:format("\nRemaining List: ~p~n",[Remaining_List]),
            Client_Skt_Row = ets:lookup(Clt_Sckt_Mapping,Client_To_Send),
            V3 = lists:nth(1, Client_Skt_Row),
            Client_Skt = element(2, V3),
            io:format("\nClient Socket: ~p~n",[Client_Skt]),
            
            ok = gen_tcp:send(Client_Skt, ["You have received New tweet!\n",UName,":",Twt]),
            ok = gen_tcp:send(Skt, "Your tweet has been shared succesfully\n"),
            
            sendMsg(Skt, Clt_Sckt_Mapping, Twt, Remaining_List, UName)
    end,
    io:fwrite("Send message!\n").


printMap(Map) ->
    io:fwrite("----**************----\n"),
    List1 = maps:to_list(Map),
    io:format("~s~n",[tuplelist_to_string(List1)]),
    io:fwrite("----**************----\n").

tuplelist_to_string(L) ->
    tuplelist_to_string(L,[]).

tuplelist_to_string([],Acc) ->
    lists:flatten(["[",
           string:join(lists:reverse(Acc),","),
           "]"]);
tuplelist_to_string([{X,Y}|Rest],Acc) ->
    S = ["{\"x\":\"",X,"\", \"y\":\"",Y,"\"}"],
    tuplelist_to_string(Rest,[S|Acc]).

conn_loop(Skt) ->
    io:fwrite("I think someone is trying to connect to me!\n\n"),
    receive
        {tcp, Skt, D} ->
            io:fwrite("........"),
            io:fwrite("\n ~p \n", [D]),
            if 
                D == <<"register_account">> ->
                    io:fwrite("Client was intrested in registering a new account"),
                    ok = gen_tcp:send(Skt, "username"), 
                    io:fwrite("It is now registered succesfully");
                true -> 
                    io:fwrite("TRUTH")
            end,
            conn_loop(Skt);
            
        {tcp_closed, Skt} ->
            io:fwrite("I promise I am not here!"),
            closed
    end.

