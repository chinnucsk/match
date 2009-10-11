%% The source of this file is part of leex distribution, as such it
%% has the same Copyright as the other files in the leex
%% distribution. The Copyright is defined in the accompanying file
%% COPYRIGHT. However, the resultant scanner generated by leex is the
%% property of the creator of the scanner and is not covered by that
%% Copyright.

-module(calc_lexer).

-export([string/1,string/2,token/2,token/3,tokens/2,tokens/3]).
-export([format_error/1]).

%% User code. This is placed here to allow extra attributes.


format_error({illegal,S}) -> ["illegal characters ",io_lib:write_string(S)];
format_error({user,S}) -> S.

string(String) -> string(String, 1).

string(String, Line) -> string(String, Line, String, []).

%% string(InChars, Line, TokenChars, Tokens) ->
%%    {ok,Tokens,Line} | {error,ErrorInfo,Line}.
%%  Note the line number going into yystate, L0, is line of token
%%  start while line number returned is line of token end. We want line
%%  of token start.

string([], L, [], Ts) ->			%No partial tokens!
    {ok,yyrev(Ts),L};
string(Ics0, L0, Tcs, Ts) ->
    case yystate(yystate(), Ics0, L0, 0, reject, 0) of
	{A,Alen,Ics1,L1} ->			%Accepting end state
	    string_cont(Ics1, L1, yyaction(A, Alen, Tcs, L0), Ts);
	{A,Alen,Ics1,L1,_S1} ->			%Accepting transistion state
	    string_cont(Ics1, L1, yyaction(A, Alen, Tcs, L0), Ts);
	{reject,_Alen,Tlen,_Ics1,L1,_S1} ->	%After a non-accepting state
	    {error,{L0,?MODULE,{illegal,yypre(Tcs, Tlen+1)}},L1};
	{A,Alen,_Tlen,_Ics1,L1,_S1} ->
	    string_cont(yysuf(Tcs, Alen), L1, yyaction(A, Alen, Tcs, L0), Ts)
    end.

%% string_cont(RestChars, Line, Token, Tokens)
%%  Test for and remove the end token wrapper. Push back characters
%%  are prepended to RestChars.

string_cont(Rest, Line, {token,T}, Ts) ->
    string(Rest, Line, Rest, [T|Ts]);
string_cont(Rest, Line, {token,T,Push}, Ts) ->
    NewRest = Push ++ Rest,
    string(NewRest, Line, NewRest, [T|Ts]);
string_cont(Rest, Line, {end_token,T}, Ts) ->
    string(Rest, Line, Rest, [T|Ts]);
string_cont(Rest, Line, {end_token,T,Push}, Ts) ->
    NewRest = Push ++ Rest,
    string(NewRest, Line, NewRest, [T|Ts]);
string_cont(Rest, Line, skip_token, Ts) ->
    string(Rest, Line, Rest, Ts);
string_cont(Rest, Line, {skip_token,Push}, Ts) ->
    NewRest = Push ++ Rest,
    string(NewRest, Line, NewRest, Ts);
string_cont(_Rest, Line, {error,S}, _Ts) ->
    {error,{Line,?MODULE,{user,S}},Line}.

%% token(Continuation, Chars) ->
%% token(Continuation, Chars, Line) ->
%%    {more,Continuation} | {done,ReturnVal,RestChars}.
%% Must be careful when re-entering to append the latest characters to the
%% after characters in an accept. The continuation is:
%% {token,State,CurrLine,TokenChars,TokenLen,TokenLine,AccAction,AccLen}

token(Cont, Chars) -> token(Cont, Chars, 1).

token([], Chars, Line) ->
    token(yystate(), Chars, Line, Chars, 0, Line, reject, 0);
token({token,State,Line,Tcs,Tlen,Tline,Action,Alen}, Chars, _) ->
    token(State, Chars, Line, Tcs ++ Chars, Tlen, Tline, Action, Alen).

%% token(State, InChars, Line, TokenChars, TokenLen, TokenLine,
%%       AcceptAction, AcceptLen) ->
%%    {more,Continuation} | {done,ReturnVal,RestChars}.
%%  The argument order is chosen to be more efficient.

token(S0, Ics0, L0, Tcs, Tlen0, Tline, A0, Alen0) ->
    case yystate(S0, Ics0, L0, Tlen0, A0, Alen0) of
	%% Accepting end state, we have a token.
	{A1,Alen1,Ics1,L1} ->
	    token_cont(Ics1, L1, yyaction(A1, Alen1, Tcs, Tline));
	%% Accepting transition state, can take more chars.
	{A1,Alen1,[],L1,S1} ->			%Need more chars to check
	    {more,{token,S1,Tcs,L1,Alen1,Tline,A1,Alen1}};
	{A1,Alen1,Ics1,L1,_S1} ->		%Take what we got
	    token_cont(Ics1, L1, yyaction(A1, Alen1, Tcs, Tline));
	%% After a non-accepting state, maybe reach accept state later.
	{A1,Alen1,Tlen1,[],L1,S1} ->		%Need more chars to check
	    {more,{token,S1,Tcs,L1,Tlen1,Tline,A1,Alen1}};
	{reject,_Alen1,Tlen1,eof,L1,_S1} ->	%No token match
	    %% Check for partial token which is error.
	    Ret = if Tlen1 > 0 -> {error,{Tline,?MODULE,
					  %% Skip eof tail in Tcs.
					  {illegal,yypre(Tcs, Tlen1)}},L1};
		     true -> {eof,L1}
		  end,
	    {done,Ret,eof};
	{reject,_Alen1,Tlen1,Ics1,L1,_S1} ->	%No token match
	    Error = {Tline,?MODULE,{illegal,yypre(Tcs, Tlen1+1)}},
	    {done,{error,Error,L1},Ics1};
	{A1,Alen1,_Tlen1,_Ics1,L1,_S1} ->	%Use last accept match
	    token_cont(yysuf(Tcs, Alen1), L1, yyaction(A1, Alen1, Tcs, Tline))
    end.

%% tokens_cont(RestChars, Line, Token)
%%  If we have a token or error then return done, else if we have a
%%  skip_token then continue.

token_cont(Rest, Line, {token,T}) ->
    {done,{ok,T,Line},Rest};
token_cont(Rest, Line, {token,T,Push}) ->
    NewRest = Push ++ Rest,
    {done,{ok,T,Line},NewRest};
token_cont(Rest, Line, {end_token,T}) ->
    {done,{ok,T,Line},Rest};
token_cont(Rest, Line, {end_token,T,Push}) ->
    NewRest = Push ++ Rest,
    {done,{ok,T,Line},NewRest};
token_cont(Rest, Line, skip_token) ->
    token(yystate(), Rest, Line, Rest, 0, Line, reject, 0);
token_cont(Rest, Line, {skip_token,Push}) ->
    NewRest = Push ++ Rest,
    token(yystate(), NewRest, Line, NewRest, 0, Line, reject, 0);
token_cont(Rest, Line, {error,S}) ->
    {done,{error,{Line,?MODULE,{user,S}},Line},Rest}.

%% tokens(Continuation, Chars, Line) ->
%%    {more,Continuation} | {done,ReturnVal,RestChars}.
%% Must be careful when re-entering to append the latest characters to the
%% after characters in an accept. The continuation is:
%% {tokens,State,CurrLine,TokenChars,TokenLen,TokenLine,Tokens,AccAction,AccLen}
%% {skip_tokens,State,CurrLine,TokenChars,TokenLen,TokenLine,Error,AccAction,AccLen}

tokens(Cont, Chars) -> tokens(Cont, Chars, 1).

tokens([], Chars, Line) ->
    tokens(yystate(), Chars, Line, Chars, 0, Line, [], reject, 0);
tokens({tokens,State,Line,Tcs,Tlen,Tline,Ts,Action,Alen}, Chars, _) ->
    tokens(State, Chars, Line, Tcs ++ Chars, Tlen, Tline, Ts, Action, Alen);
tokens({skip_tokens,State,Line,Tcs,Tlen,Tline,Error,Action,Alen}, Chars, _) ->
    skip_tokens(State, Chars, Line, Tcs ++ Chars, Tlen, Tline, Error, Action, Alen).

%% tokens(State, InChars, Line, TokenChars, TokenLen, TokenLine, Tokens,
%%        AcceptAction, AcceptLen) ->
%%    {more,Continuation} | {done,ReturnVal,RestChars}.

tokens(S0, Ics0, L0, Tcs, Tlen0, Tline, Ts, A0, Alen0) ->
    case yystate(S0, Ics0, L0, Tlen0, A0, Alen0) of
	%% Accepting end state, we have a token.
	{A1,Alen1,Ics1,L1} ->
	    tokens_cont(Ics1, L1, yyaction(A1, Alen1, Tcs, Tline), Ts);
	%% Accepting transition state, can take more chars.
	{A1,Alen1,[],L1,S1} ->			%Need more chars to check
	    {more,{tokens,S1,L1,Tcs,Alen1,Tline,Ts,A1,Alen1}};
	{A1,Alen1,Ics1,L1,_S1} ->		%Take what we got
	    tokens_cont(Ics1, L1, yyaction(A1, Alen1, Tcs, Tline), Ts);
	%% After a non-accepting state, maybe reach accept state later.
	{A1,Alen1,Tlen1,[],L1,S1} ->		%Need more chars to check
	    {more,{tokens,S1,L1,Tcs,Tlen1,Tline,Ts,A1,Alen1}};
	{reject,_Alen1,Tlen1,eof,L1,_S1} ->	%No token match
	    %% Check for partial token which is error, no need to skip here.
	    Ret = if Tlen1 > 0 -> {error,{Tline,?MODULE,
					  %% Skip eof tail in Tcs.
					  {illegal,yypre(Tcs, Tlen1)}},L1};
		     Ts == [] -> {eof,L1};
		     true -> {ok,yyrev(Ts),L1}
		  end,
	    {done,Ret,eof};
	{reject,_Alen1,Tlen1,_Ics1,L1,_S1} ->
	    %% Skip rest of tokens.
	    Error = {L1,?MODULE,{illegal,yypre(Tcs, Tlen1+1)}},
	    skip_tokens(yysuf(Tcs, Tlen1+1), L1, Error);
	{A1,Alen1,_Tlen1,_Ics1,L1,_S1} ->
	    Token = yyaction(A1, Alen1, Tcs, Tline),
	    tokens_cont(yysuf(Tcs, Alen1), L1, Token, Ts)
    end.

%% tokens_cont(RestChars, Line, Token, Tokens)
%%  If we have a end_token or error then return done, else if we have
%%  a token then save it and continue, else if we have a skip_token
%%  just continue.

tokens_cont(Rest, Line, {token,T}, Ts) ->
    tokens(yystate(), Rest, Line, Rest, 0, Line, [T|Ts], reject, 0);
tokens_cont(Rest, Line, {token,T,Push}, Ts) ->
    NewRest = Push ++ Rest,
    tokens(yystate(), NewRest, Line, NewRest, 0, Line, [T|Ts], reject, 0);
tokens_cont(Rest, Line, {end_token,T}, Ts) ->
    {done,{ok,yyrev(Ts, [T]),Line},Rest};
tokens_cont(Rest, Line, {end_token,T,Push}, Ts) ->
    NewRest = Push ++ Rest,
    {done,{ok,yyrev(Ts, [T]),Line},NewRest};
tokens_cont(Rest, Line, skip_token, Ts) ->
    tokens(yystate(), Rest, Line, Rest, 0, Line, Ts, reject, 0);
tokens_cont(Rest, Line, {skip_token,Push}, Ts) ->
    NewRest = Push ++ Rest,
    tokens(yystate(), NewRest, Line, NewRest, 0, Line, Ts, reject, 0);
tokens_cont(Rest, Line, {error,S}, _Ts) ->
    skip_tokens(Rest, Line, {Line,?MODULE,{user,S}}).

%%skip_tokens(InChars, Line, Error) -> {done,{error,Error,Line},Ics}.
%%  Skip tokens until an end token, junk everything and return the error.

skip_tokens(Ics, Line, Error)                           ->
    skip_tokens(yystate(), Ics, Line, Ics, 0, Line, Error, reject, 0).

%% skip_tokens(State, InChars, Line, TokenChars, TokenLen, TokenLine, Tokens,
%%             AcceptAction, AcceptLen) ->
%%    {more,Continuation} | {done,ReturnVal,RestChars}.

skip_tokens(S0, Ics0, L0, Tcs, Tlen0, Tline, Error, A0, Alen0) ->
    case yystate(S0, Ics0, L0, Tlen0, A0, Alen0) of
	{A1,Alen1,Ics1,L1} ->			%Accepting end state
	    skip_cont(Ics1, L1, yyaction(A1, Alen1, Tcs, Tline), Error);
	{A1,Alen1,[],L1,S1} ->			%After an accepting state
	    {more,{skip_tokens,S1,L1,Tcs,Alen1,Tline,Error,A1,Alen1}};
	{A1,Alen1,Ics1,L1,_S1} ->
	    skip_cont(Ics1, L1, yyaction(A1, Alen1, Tcs, Tline), Error);
	{A1,Alen1,Tlen1,[],L1,S1} ->		%After a non-accepting state
	    {more,{skip_tokens,S1,L1,Tcs,Tlen1,Tline,Error,A1,Alen1}};
	{reject,_Alen1,_Tlen1,eof,L1,_S1} ->
	    {done,{error,Error,L1},eof};
	{reject,_Alen1,Tlen1,_Ics1,L1,_S1} ->
	    skip_tokens(yysuf(Tcs, Tlen1+1), L1, Error);
	{A1,Alen1,_Tlen1,_Ics1,L1,_S1} ->
	    Token = yyaction(A1, Alen1, Tcs, Tline),
	    skip_cont(yysuf(Tcs, Alen1), L1, Token, Error)
    end.

%% skip_cont(RestChars, Line, Token, Error)
%%  Skip tokens until we have an end_token or error then return done
%%  with the original rror.

skip_cont(Rest, Line, {token,_T}, Error) ->
    skip_tokens(yystate(), Rest, Line, Rest, 0, Line, Error, reject, 0);
skip_cont(Rest, Line, {token,_T,Push}, Error) ->
    NewRest = Push ++ Rest,
    skip_tokens(yystate(), NewRest, Line, NewRest, 0, Line, Error, reject, 0);
skip_cont(Rest, Line, {end_token,_T}, Error) ->
    {done,{error,Error,Line},Rest};
skip_cont(Rest, Line, {end_token,_T,Push}, Error) ->
    NewRest = Push ++ Rest,
    {done,{error,Error,Line},NewRest};
skip_cont(Rest, Line, skip_token, Error) ->
    skip_tokens(yystate(), Rest, Line, Rest, 0, Line, Error, reject, 0);
skip_cont(Rest, Line, {skip_token,Push}, Error) ->
    NewRest = Push ++ Rest,
    skip_tokens(yystate(), NewRest, Line, NewRest, 0, Line, Error, reject, 0);
skip_cont(Rest, Line, {error,_S}, Error) ->
    skip_tokens(yystate(), Rest, Line, Rest, 0, Line, Error, reject, 0).

yyrev(List) -> lists:reverse(List).
yyrev(List, Tail) -> lists:reverse(List, Tail).
yypre(List, N) -> lists:sublist(List, N).
yysuf(List, N) -> lists:nthtail(N, List).

%% yystate() -> InitialState.
%% yystate(State, InChars, Line, CurrTokLen, AcceptAction, AcceptLen) ->
%%      {Action, AcceptLen, RestChars, Line} |
%%      {Action, AcceptLen, RestChars, Line, State} |
%%      {reject, AcceptLen, CurrTokLen, RestChars, Line, State} |
%%      {Action, AcceptLen, CurrTokLen, RestChars, Line, State}.
%% Generated state transition functions. The non-accepting end state
%% return signal either an unrecognised character or end of current
%% input.

yystate() -> 22.

yystate(29, [114|Ics], Line, Tlen, _, _) ->
    yystate(23, Ics, Line, Tlen+1, 14, Tlen);
yystate(29, [95|Ics], Line, Tlen, _, _) ->
    yystate(24, Ics, Line, Tlen+1, 14, Tlen);
yystate(29, [C|Ics], Line, Tlen, _, _) when C >= 97, C =< 113 ->
    yystate(24, Ics, Line, Tlen+1, 14, Tlen);
yystate(29, [C|Ics], Line, Tlen, _, _) when C >= 115, C =< 122 ->
    yystate(24, Ics, Line, Tlen+1, 14, Tlen);
yystate(29, Ics, Line, Tlen, _, _) ->
    {14,Tlen,Ics,Line,29};
yystate(28, [100|Ics], Line, Tlen, _, _) ->
    yystate(23, Ics, Line, Tlen+1, 14, Tlen);
yystate(28, [95|Ics], Line, Tlen, _, _) ->
    yystate(24, Ics, Line, Tlen+1, 14, Tlen);
yystate(28, [C|Ics], Line, Tlen, _, _) when C >= 97, C =< 99 ->
    yystate(24, Ics, Line, Tlen+1, 14, Tlen);
yystate(28, [C|Ics], Line, Tlen, _, _) when C >= 101, C =< 122 ->
    yystate(24, Ics, Line, Tlen+1, 14, Tlen);
yystate(28, Ics, Line, Tlen, _, _) ->
    {14,Tlen,Ics,Line,28};
yystate(27, Ics, Line, Tlen, _, _) ->
    {12,Tlen,Ics,Line};
yystate(26, [35|Ics], Line, Tlen, _, _) ->
    yystate(2, Ics, Line, Tlen+1, 15, Tlen);
yystate(26, [10|Ics], Line, Tlen, _, _) ->
    yystate(26, Ics, Line+1, Tlen+1, 15, Tlen);
yystate(26, [C|Ics], Line, Tlen, _, _) when C >= 0, C =< 9 ->
    yystate(26, Ics, Line, Tlen+1, 15, Tlen);
yystate(26, [C|Ics], Line, Tlen, _, _) when C >= 11, C =< 32 ->
    yystate(26, Ics, Line, Tlen+1, 15, Tlen);
yystate(26, Ics, Line, Tlen, _, _) ->
    {15,Tlen,Ics,Line,26};
yystate(25, Ics, Line, Tlen, _, _) ->
    {0,Tlen,Ics,Line};
yystate(24, [95|Ics], Line, Tlen, _, _) ->
    yystate(24, Ics, Line, Tlen+1, 14, Tlen);
yystate(24, [C|Ics], Line, Tlen, _, _) when C >= 97, C =< 122 ->
    yystate(24, Ics, Line, Tlen+1, 14, Tlen);
yystate(24, Ics, Line, Tlen, _, _) ->
    {14,Tlen,Ics,Line,24};
yystate(23, [95|Ics], Line, Tlen, _, _) ->
    yystate(24, Ics, Line, Tlen+1, 5, Tlen);
yystate(23, [C|Ics], Line, Tlen, _, _) when C >= 97, C =< 122 ->
    yystate(24, Ics, Line, Tlen+1, 5, Tlen);
yystate(23, Ics, Line, Tlen, _, _) ->
    {5,Tlen,Ics,Line,23};
yystate(22, [125|Ics], Line, Tlen, Action, Alen) ->
    yystate(14, Ics, Line, Tlen+1, Action, Alen);
yystate(22, [123|Ics], Line, Tlen, Action, Alen) ->
    yystate(6, Ics, Line, Tlen+1, Action, Alen);
yystate(22, [116|Ics], Line, Tlen, Action, Alen) ->
    yystate(1, Ics, Line, Tlen+1, Action, Alen);
yystate(22, [111|Ics], Line, Tlen, Action, Alen) ->
    yystate(29, Ics, Line, Tlen+1, Action, Alen);
yystate(22, [102|Ics], Line, Tlen, Action, Alen) ->
    yystate(15, Ics, Line, Tlen+1, Action, Alen);
yystate(22, [97|Ics], Line, Tlen, Action, Alen) ->
    yystate(20, Ics, Line, Tlen+1, Action, Alen);
yystate(22, [95|Ics], Line, Tlen, Action, Alen) ->
    yystate(24, Ics, Line, Tlen+1, Action, Alen);
yystate(22, [62|Ics], Line, Tlen, Action, Alen) ->
    yystate(16, Ics, Line, Tlen+1, Action, Alen);
yystate(22, [61|Ics], Line, Tlen, Action, Alen) ->
    yystate(8, Ics, Line, Tlen+1, Action, Alen);
yystate(22, [60|Ics], Line, Tlen, Action, Alen) ->
    yystate(16, Ics, Line, Tlen+1, Action, Alen);
yystate(22, [47|Ics], Line, Tlen, Action, Alen) ->
    yystate(5, Ics, Line, Tlen+1, Action, Alen);
yystate(22, [45|Ics], Line, Tlen, Action, Alen) ->
    yystate(25, Ics, Line, Tlen+1, Action, Alen);
yystate(22, [44|Ics], Line, Tlen, Action, Alen) ->
    yystate(27, Ics, Line, Tlen+1, Action, Alen);
yystate(22, [43|Ics], Line, Tlen, Action, Alen) ->
    yystate(25, Ics, Line, Tlen+1, Action, Alen);
yystate(22, [42|Ics], Line, Tlen, Action, Alen) ->
    yystate(5, Ics, Line, Tlen+1, Action, Alen);
yystate(22, [41|Ics], Line, Tlen, Action, Alen) ->
    yystate(17, Ics, Line, Tlen+1, Action, Alen);
yystate(22, [40|Ics], Line, Tlen, Action, Alen) ->
    yystate(13, Ics, Line, Tlen+1, Action, Alen);
yystate(22, [37|Ics], Line, Tlen, Action, Alen) ->
    yystate(5, Ics, Line, Tlen+1, Action, Alen);
yystate(22, [35|Ics], Line, Tlen, Action, Alen) ->
    yystate(2, Ics, Line, Tlen+1, Action, Alen);
yystate(22, [33|Ics], Line, Tlen, Action, Alen) ->
    yystate(10, Ics, Line, Tlen+1, Action, Alen);
yystate(22, [10|Ics], Line, Tlen, Action, Alen) ->
    yystate(26, Ics, Line+1, Tlen+1, Action, Alen);
yystate(22, [C|Ics], Line, Tlen, Action, Alen) when C >= 0, C =< 9 ->
    yystate(26, Ics, Line, Tlen+1, Action, Alen);
yystate(22, [C|Ics], Line, Tlen, Action, Alen) when C >= 11, C =< 32 ->
    yystate(26, Ics, Line, Tlen+1, Action, Alen);
yystate(22, [C|Ics], Line, Tlen, Action, Alen) when C >= 48, C =< 57 ->
    yystate(3, Ics, Line, Tlen+1, Action, Alen);
yystate(22, [C|Ics], Line, Tlen, Action, Alen) when C >= 98, C =< 101 ->
    yystate(24, Ics, Line, Tlen+1, Action, Alen);
yystate(22, [C|Ics], Line, Tlen, Action, Alen) when C >= 103, C =< 110 ->
    yystate(24, Ics, Line, Tlen+1, Action, Alen);
yystate(22, [C|Ics], Line, Tlen, Action, Alen) when C >= 112, C =< 115 ->
    yystate(24, Ics, Line, Tlen+1, Action, Alen);
yystate(22, [C|Ics], Line, Tlen, Action, Alen) when C >= 117, C =< 122 ->
    yystate(24, Ics, Line, Tlen+1, Action, Alen);
yystate(22, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,22};
yystate(21, [95|Ics], Line, Tlen, _, _) ->
    yystate(24, Ics, Line, Tlen+1, 4, Tlen);
yystate(21, [C|Ics], Line, Tlen, _, _) when C >= 97, C =< 122 ->
    yystate(24, Ics, Line, Tlen+1, 4, Tlen);
yystate(21, Ics, Line, Tlen, _, _) ->
    {4,Tlen,Ics,Line,21};
yystate(20, [110|Ics], Line, Tlen, _, _) ->
    yystate(28, Ics, Line, Tlen+1, 14, Tlen);
yystate(20, [95|Ics], Line, Tlen, _, _) ->
    yystate(24, Ics, Line, Tlen+1, 14, Tlen);
yystate(20, [C|Ics], Line, Tlen, _, _) when C >= 97, C =< 109 ->
    yystate(24, Ics, Line, Tlen+1, 14, Tlen);
yystate(20, [C|Ics], Line, Tlen, _, _) when C >= 111, C =< 122 ->
    yystate(24, Ics, Line, Tlen+1, 14, Tlen);
yystate(20, Ics, Line, Tlen, _, _) ->
    {14,Tlen,Ics,Line,20};
yystate(19, [C|Ics], Line, Tlen, _, _) when C >= 48, C =< 57 ->
    yystate(19, Ics, Line, Tlen+1, 3, Tlen);
yystate(19, Ics, Line, Tlen, _, _) ->
    {3,Tlen,Ics,Line,19};
yystate(18, Ics, Line, Tlen, _, _) ->
    {6,Tlen,Ics,Line};
yystate(17, Ics, Line, Tlen, _, _) ->
    {8,Tlen,Ics,Line};
yystate(16, [61|Ics], Line, Tlen, _, _) ->
    yystate(18, Ics, Line, Tlen+1, 6, Tlen);
yystate(16, Ics, Line, Tlen, _, _) ->
    {6,Tlen,Ics,Line,16};
yystate(15, [110|Ics], Line, Tlen, _, _) ->
    yystate(7, Ics, Line, Tlen+1, 14, Tlen);
yystate(15, [97|Ics], Line, Tlen, _, _) ->
    yystate(0, Ics, Line, Tlen+1, 14, Tlen);
yystate(15, [95|Ics], Line, Tlen, _, _) ->
    yystate(24, Ics, Line, Tlen+1, 14, Tlen);
yystate(15, [C|Ics], Line, Tlen, _, _) when C >= 98, C =< 109 ->
    yystate(24, Ics, Line, Tlen+1, 14, Tlen);
yystate(15, [C|Ics], Line, Tlen, _, _) when C >= 111, C =< 122 ->
    yystate(24, Ics, Line, Tlen+1, 14, Tlen);
yystate(15, Ics, Line, Tlen, _, _) ->
    {14,Tlen,Ics,Line,15};
yystate(14, Ics, Line, Tlen, _, _) ->
    {10,Tlen,Ics,Line};
yystate(13, Ics, Line, Tlen, _, _) ->
    {7,Tlen,Ics,Line};
yystate(12, [101|Ics], Line, Tlen, _, _) ->
    yystate(21, Ics, Line, Tlen+1, 14, Tlen);
yystate(12, [95|Ics], Line, Tlen, _, _) ->
    yystate(24, Ics, Line, Tlen+1, 14, Tlen);
yystate(12, [C|Ics], Line, Tlen, _, _) when C >= 97, C =< 100 ->
    yystate(24, Ics, Line, Tlen+1, 14, Tlen);
yystate(12, [C|Ics], Line, Tlen, _, _) when C >= 102, C =< 122 ->
    yystate(24, Ics, Line, Tlen+1, 14, Tlen);
yystate(12, Ics, Line, Tlen, _, _) ->
    {14,Tlen,Ics,Line,12};
yystate(11, [C|Ics], Line, Tlen, Action, Alen) when C >= 48, C =< 57 ->
    yystate(19, Ics, Line, Tlen+1, Action, Alen);
yystate(11, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,11};
yystate(10, [61|Ics], Line, Tlen, Action, Alen) ->
    yystate(18, Ics, Line, Tlen+1, Action, Alen);
yystate(10, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,10};
yystate(9, [117|Ics], Line, Tlen, _, _) ->
    yystate(12, Ics, Line, Tlen+1, 14, Tlen);
yystate(9, [95|Ics], Line, Tlen, _, _) ->
    yystate(24, Ics, Line, Tlen+1, 14, Tlen);
yystate(9, [C|Ics], Line, Tlen, _, _) when C >= 97, C =< 116 ->
    yystate(24, Ics, Line, Tlen+1, 14, Tlen);
yystate(9, [C|Ics], Line, Tlen, _, _) when C >= 118, C =< 122 ->
    yystate(24, Ics, Line, Tlen+1, 14, Tlen);
yystate(9, Ics, Line, Tlen, _, _) ->
    {14,Tlen,Ics,Line,9};
yystate(8, [61|Ics], Line, Tlen, _, _) ->
    yystate(18, Ics, Line, Tlen+1, 13, Tlen);
yystate(8, Ics, Line, Tlen, _, _) ->
    {13,Tlen,Ics,Line,8};
yystate(7, [95|Ics], Line, Tlen, _, _) ->
    yystate(24, Ics, Line, Tlen+1, 11, Tlen);
yystate(7, [C|Ics], Line, Tlen, _, _) when C >= 97, C =< 122 ->
    yystate(24, Ics, Line, Tlen+1, 11, Tlen);
yystate(7, Ics, Line, Tlen, _, _) ->
    {11,Tlen,Ics,Line,7};
yystate(6, Ics, Line, Tlen, _, _) ->
    {9,Tlen,Ics,Line};
yystate(5, Ics, Line, Tlen, _, _) ->
    {1,Tlen,Ics,Line};
yystate(4, [115|Ics], Line, Tlen, _, _) ->
    yystate(12, Ics, Line, Tlen+1, 14, Tlen);
yystate(4, [95|Ics], Line, Tlen, _, _) ->
    yystate(24, Ics, Line, Tlen+1, 14, Tlen);
yystate(4, [C|Ics], Line, Tlen, _, _) when C >= 97, C =< 114 ->
    yystate(24, Ics, Line, Tlen+1, 14, Tlen);
yystate(4, [C|Ics], Line, Tlen, _, _) when C >= 116, C =< 122 ->
    yystate(24, Ics, Line, Tlen+1, 14, Tlen);
yystate(4, Ics, Line, Tlen, _, _) ->
    {14,Tlen,Ics,Line,4};
yystate(3, [46|Ics], Line, Tlen, _, _) ->
    yystate(11, Ics, Line, Tlen+1, 2, Tlen);
yystate(3, [C|Ics], Line, Tlen, _, _) when C >= 48, C =< 57 ->
    yystate(3, Ics, Line, Tlen+1, 2, Tlen);
yystate(3, Ics, Line, Tlen, _, _) ->
    {2,Tlen,Ics,Line,3};
yystate(2, [35|Ics], Line, Tlen, _, _) ->
    yystate(2, Ics, Line, Tlen+1, 15, Tlen);
yystate(2, [33|Ics], Line, Tlen, _, _) ->
    yystate(2, Ics, Line, Tlen+1, 15, Tlen);
yystate(2, [34|Ics], Line, Tlen, _, _) ->
    yystate(2, Ics, Line, Tlen+1, 15, Tlen);
yystate(2, [10|Ics], Line, Tlen, _, _) ->
    yystate(26, Ics, Line+1, Tlen+1, 15, Tlen);
yystate(2, [C|Ics], Line, Tlen, _, _) when C >= 0, C =< 9 ->
    yystate(2, Ics, Line, Tlen+1, 15, Tlen);
yystate(2, [C|Ics], Line, Tlen, _, _) when C >= 11, C =< 32 ->
    yystate(2, Ics, Line, Tlen+1, 15, Tlen);
yystate(2, [C|Ics], Line, Tlen, _, _) when C >= 36 ->
    yystate(2, Ics, Line, Tlen+1, 15, Tlen);
yystate(2, Ics, Line, Tlen, _, _) ->
    {15,Tlen,Ics,Line,2};
yystate(1, [114|Ics], Line, Tlen, _, _) ->
    yystate(9, Ics, Line, Tlen+1, 14, Tlen);
yystate(1, [95|Ics], Line, Tlen, _, _) ->
    yystate(24, Ics, Line, Tlen+1, 14, Tlen);
yystate(1, [C|Ics], Line, Tlen, _, _) when C >= 97, C =< 113 ->
    yystate(24, Ics, Line, Tlen+1, 14, Tlen);
yystate(1, [C|Ics], Line, Tlen, _, _) when C >= 115, C =< 122 ->
    yystate(24, Ics, Line, Tlen+1, 14, Tlen);
yystate(1, Ics, Line, Tlen, _, _) ->
    {14,Tlen,Ics,Line,1};
yystate(0, [108|Ics], Line, Tlen, _, _) ->
    yystate(4, Ics, Line, Tlen+1, 14, Tlen);
yystate(0, [95|Ics], Line, Tlen, _, _) ->
    yystate(24, Ics, Line, Tlen+1, 14, Tlen);
yystate(0, [C|Ics], Line, Tlen, _, _) when C >= 97, C =< 107 ->
    yystate(24, Ics, Line, Tlen+1, 14, Tlen);
yystate(0, [C|Ics], Line, Tlen, _, _) when C >= 109, C =< 122 ->
    yystate(24, Ics, Line, Tlen+1, 14, Tlen);
yystate(0, Ics, Line, Tlen, _, _) ->
    {14,Tlen,Ics,Line,0};
yystate(S, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,S}.

%% yyaction(Action, TokenLength, TokenChars, TokenLine) ->
%%        {token,Token} | {end_token, Token} | skip_token | {error,String}.
%% Generated action function.

yyaction(0, TokenLen, YYtcs, TokenLine) ->
    TokenChars = yypre(YYtcs, TokenLen),
    {token,{add_operator,TokenLine,list_to_atom(TokenChars)}};
yyaction(1, TokenLen, YYtcs, TokenLine) ->
    TokenChars = yypre(YYtcs, TokenLen),
    {token,{mul_operator,TokenLine,list_to_atom(TokenChars)}};
yyaction(2, TokenLen, YYtcs, TokenLine) ->
    TokenChars = yypre(YYtcs, TokenLen),
    {token,{integer,TokenLine,list_to_integer(TokenChars)}};
yyaction(3, TokenLen, YYtcs, TokenLine) ->
    TokenChars = yypre(YYtcs, TokenLen),
    {token,{float,TokenLine,list_to_float(TokenChars)}};
yyaction(4, TokenLen, YYtcs, TokenLine) ->
    TokenChars = yypre(YYtcs, TokenLen),
    {token,{boolean,TokenLine,list_to_atom(TokenChars)}};
yyaction(5, TokenLen, YYtcs, TokenLine) ->
    TokenChars = yypre(YYtcs, TokenLen),
    {token,{logic,TokenLine,list_to_atom(TokenChars)}};
yyaction(6, TokenLen, YYtcs, TokenLine) ->
    TokenChars = yypre(YYtcs, TokenLen),
    {token,{comparation,TokenLine,list_to_atom(TokenChars)}};
yyaction(7, TokenLen, YYtcs, TokenLine) ->
    TokenChars = yypre(YYtcs, TokenLen),
    {token,{open,TokenLine,list_to_atom(TokenChars)}};
yyaction(8, TokenLen, YYtcs, TokenLine) ->
    TokenChars = yypre(YYtcs, TokenLen),
    {token,{close,TokenLine,list_to_atom(TokenChars)}};
yyaction(9, TokenLen, YYtcs, TokenLine) ->
    TokenChars = yypre(YYtcs, TokenLen),
    {token,{open_block,TokenLine,list_to_atom(TokenChars)}};
yyaction(10, TokenLen, YYtcs, TokenLine) ->
    TokenChars = yypre(YYtcs, TokenLen),
    {token,{close_block,TokenLine,list_to_atom(TokenChars)}};
yyaction(11, TokenLen, YYtcs, TokenLine) ->
    TokenChars = yypre(YYtcs, TokenLen),
    {token,{fn,TokenLine,list_to_atom(TokenChars)}};
yyaction(12, TokenLen, YYtcs, TokenLine) ->
    TokenChars = yypre(YYtcs, TokenLen),
    {token,{sep,TokenLine,list_to_atom(TokenChars)}};
yyaction(13, TokenLen, YYtcs, TokenLine) ->
    TokenChars = yypre(YYtcs, TokenLen),
    {token,{match,TokenLine,list_to_atom(TokenChars)}};
yyaction(14, TokenLen, YYtcs, TokenLine) ->
    TokenChars = yypre(YYtcs, TokenLen),
    {token,{var,TokenLine,list_to_atom(TokenChars)}};
yyaction(15, _, _, _) ->
    skip_token;
yyaction(_, _, _, _) -> error.
