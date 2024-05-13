-module(client).
-export[start/0, getparse_input/2, loop/1].

start() ->
    io:fwrite("\n\n Holaaa, This is new client\n\n"),
    PortNum = 1204,
    IPAdd = "localhost",
    {ok, Sock} = gen_tcp:connect(IPAdd, PortNum, [binary, {packet, 0}]),
    io:fwrite("\n\n Please forward my request to server\n\n"),
    spawn(client, getparse_input, [Sock, "_"]),
    loop(Sock).

loop(Sock) ->
    receive
        {tcp, Sock, Data} ->
            io:fwrite("got the message from server\n"),
            io:fwrite(Data),
            loop(Sock);
        {tcp, closed, Sock} ->  
            io:fwrite("Client Cannot be connected anymore as TCP was Closed")
        end.

getparse_input(Sock, UName) ->
    {ok, [CmdType]} = io:fread("\nWrite the command: ", "~s\n"),
    io:fwrite(CmdType),
    if 
        CmdType == "register" ->
            UName1 = reg_acc(Sock);
        CmdType == "tweet" ->
            if
                UName == "_" ->
                    io:fwrite("First register yourself!!!\n"),
                    UName1 = getparse_input(Sock, UName);
                true ->
                    send_twt(Sock,UName),
                    UName1 = UName
            end;
        CmdType == "subscribe" ->
            if
                UName == "_" ->
                    io:fwrite("First register yourself!!!\n"),
                    UName1 = getparse_input(Sock, UName);
                true ->
                    sub_to_user(Sock, UName),
                    UName1 = UName
            end;
        CmdType == "retweet" ->
            if
                UName == "_" ->
                    io:fwrite("First register yourself!!!\n"),
                    UName1 = getparse_input(Sock, UName);
                true ->
                    re_twt(Sock, UName),
                    UName1 = UName
            end;
        CmdType == "query" ->
            if
                UName == "_" ->
                    io:fwrite("First register yourself!!!\n"),
                    UName1 = getparse_input(Sock, UName);
                true ->
                    query_twt(Sock, UName),
                    UName1 = UName
            end;
        
        
        CmdType == "logout" ->
            if
                UName == "_" ->
                    io:fwrite("First register yourself!!!\n"),
                    UName1 = getparse_input(Sock, UName);
                true ->
                    UName1 = "_"
            end;
        CmdType == "login" ->
            UName1 = sign_inacc();
        true ->
            io:fwrite("Sorry Wrong Command, Please Enter another command!\n"),
            UName1 = getparse_input(Sock, UName)
    end,
    getparse_input(Sock, UName1).


reg_acc(Sock) ->
    {ok, [UName]} = io:fread("\nPlease enter your User Name: ", "~s\n"),
    io:format("SELF: ~p\n", [self()]),
    ok = gen_tcp:send(Sock, [["register", ",", UName, ",", pid_to_list(self())]]),
    io:fwrite("\nYour account has been succesfully Registered\n"),
    UName.

sub_to_user(Sock, UName) ->
    SubscribeUName = io:get_line("\nWhich person do you want to subscribe?:"),
    ok = gen_tcp:send(Sock, ["subscribe", "," ,UName, ",", SubscribeUName]),
    io:fwrite("\nSubscription was succesful!\n").

send_twt(Sock,UName) ->
    Tweet = io:get_line("\nHolaa, What do you want to share?:"),
    ok = gen_tcp:send(Sock, ["tweet", "," ,UName, ",", Tweet]),
    io:fwrite("\nTweet was Shared succesfully\n").

re_twt(Socket, UName) ->
    {ok, [Person_UName]} = io:fread("\nPlease enter the User Name of whose tweet you want to share: ", "~s\n"),
    Tweet = io:get_line("\nPlease enter the tweet that you want to share: "),
    ok = gen_tcp:send(Socket, ["retweet", "," ,Person_UName, ",", UName,",",Tweet]),
    io:fwrite("\nRetweet was succesful\n").



sign_inacc() ->
    {ok, [UName]} = io:fread("\nPlease enter your User Name: ", "~s\n"),
    io:format("SELF: ~p\n", [self()]),
    io:fwrite("\nYour account has been Signed in succesfully\n"),
    UName.

query_twt(Sock, UName) ->
    io:fwrite("\n The following are the Querying Options:\n"),
    io:fwrite("\n 1. Mentions\n"),
    io:fwrite("\n 2. Hashtag Search\n"),
    io:fwrite("\n 3. Subscriptions\n"),
    {ok, [Option]} = io:fread("\nMention the querying option you want to perform: ", "~s\n"),
    if
        Option == "1" ->
            ok = gen_tcp:send(Sock, ["query", "," ,UName, ",", "1", ",", UName]);
        Option == "2" ->
            {ok, [Hashtag]} = io:fread("\nPlease enter the hahstag that you want to search: ", "~s\n"),
            ok = gen_tcp:send(Sock, ["query", "," ,UName, ",","2",",", Hashtag]);
        true ->
            {ok, [Sub_UName]} = io:fread("\nWhose tweets do you want to see? ", "~s\n"),
            ok = gen_tcp:send(Sock, ["query", "," ,UName, ",", "3",",",Sub_UName])
    end.

