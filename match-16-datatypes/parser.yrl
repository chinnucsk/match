Nonterminals 
expr_list grammar literal expressions expression function_def argument_def
arguments block fun_expression function_call call_arguments call_argument
call_params bool_expr comp_expr add_expr mul_expr unary_expr or_expr xor_expr
and_expr patterns pattern atom_expr list list_items tuple tuple_items atoms.

Terminals 
bool_op comp_op add_op mul_op unary_op match var open close fn sep open_list close_list
open_block close_block integer float boolean endl atom string and_op xor_op or_op dot.

Rootsymbol grammar.

grammar -> expr_list: '$1'.

expr_list -> fun_expression: ['$1'].
expr_list -> fun_expression expr_list: ['$1'|'$2'].

fun_expression -> var match function_def endl: {fun_def, line('$1'), unwrap('$1'), '$3'}.

expressions -> expression: ['$1'].
expressions -> expression expressions: ['$1'|'$2'].

expression -> bool_expr match bool_expr endl: {unwrap('$2'), line('$2'), '$1', '$3'}.
expression -> bool_expr endl : '$1'.

bool_expr -> comp_expr bool_op bool_expr : {unwrap('$2'), line('$2'), '$1', '$3'}.
bool_expr -> comp_expr : '$1'.

comp_expr -> or_expr comp_op comp_expr : {unwrap('$2'), line('$2'), '$1', '$3'}.
comp_expr -> or_expr : '$1'.

or_expr -> xor_expr or_op or_expr : {unwrap('$2'), line('$2'), '$1', '$3'}.
or_expr -> xor_expr : '$1'.

xor_expr -> and_expr xor_op xor_expr : {unwrap('$2'), line('$2'), '$1', '$3'}.
xor_expr -> and_expr : '$1'.

and_expr -> add_expr and_op and_expr : {unwrap('$2'), line('$2'), '$1', '$3'}.
and_expr -> add_expr : '$1'.

add_expr -> mul_expr add_op add_expr : {unwrap('$2'), line('$2'), '$1', '$3'}.
add_expr -> mul_expr : '$1'.

mul_expr -> unary_expr mul_op mul_expr : {unwrap('$2'), line('$2'), '$1', '$3'}.
mul_expr -> unary_expr: '$1'.

function_call -> var call_params: {call, line('$1'), '$1', '$2'}.
function_call -> atoms call_params: {callatom, line_on_atoms('$1'), '$1', '$2'}.
%% function_call -> function_call call_params: {call, line('$1'), '$1', '$2'}.

atoms -> dot var atoms : [{atom, line('$1'), unwrap('$2')} | '$3'].
atoms -> dot var : [{atom, line('$2'), unwrap('$2')}].

call_params -> open call_arguments close: lists:flatten('$2').
call_params -> open close: [].

call_arguments -> call_argument: ['$1'].
call_arguments -> call_argument sep call_arguments:  ['$1'|'$3'].
call_arguments -> atom_expr call_arguments:  [['$1']|'$2'].
call_arguments -> call_argument atom_expr call_arguments:  ['$1'|['$2', '$3']].
call_argument -> bool_expr: '$1'.

function_def 	-> fn patterns: {unwrap('$1'), line('$1'), '$2'}.
patterns	-> pattern patterns: ['$1'|'$2'].
patterns	-> pattern: ['$1'].
pattern		-> argument_def block: {pattern, '$1', '$2'}.
argument_def	-> open arguments close : {unwrap('$1'), line('$1'), lists:flatten('$2')}.
argument_def	-> open close : {'(', line('$1'), []}.

arguments	-> unary_expr: ['$1'].
arguments	-> unary_expr sep arguments : ['$1'|'$3'].
arguments	-> atom_expr arguments: [['$1']|'$2'].
arguments	-> unary_expr atom_expr arguments : ['$1'|['$2', '$3']].

block		-> bool_expr:  {'{', line('$1'), ['$1']}.
block		-> open_block expressions close_block : {unwrap('$1'), line('$1'), '$2'}.

unary_expr -> unary_op literal: {unwrap('$1'), line('$1'), '$2'}.
unary_expr -> add_op literal: {unwrap('$1'), line('$1'), '$2'}.
unary_expr -> literal: '$1'.

literal -> integer : {integer, line('$1'), unwrap('$1')}.
literal -> float : {float, line('$1'), unwrap('$1')}.
literal -> boolean : {atom, line('$1'), unwrap('$1')}.
literal -> string : {string, line('$1'), unwrap('$1')}.
literal -> list: '$1'.
literal -> tuple: '$1'.
literal -> var : {var, line('$1'), unwrap('$1')}.
literal -> atom_expr : '$1'.
literal -> open bool_expr close : '$2'.
literal -> function_call : '$1'.
literal -> function_def : '$1'.

list -> open_list close_list: {nil, line('$1')}.
list -> open_list list_items close_list: '$2'.

list_items -> bool_expr sep list_items : {cons, line('$1'), '$1', '$3'}.
list_items -> bool_expr : {cons, line('$1'), '$1', {nil, line('$1')}}.
list_items -> bool_expr sep : {cons, line('$1'), '$1', {nil, line('$1')}}.

tuple -> open close: {tuple, line('$1'), []}.
tuple -> open bool_expr sep close: {tuple, line('$1'), ['$2']}.
tuple -> open tuple_items close: {tuple, line('$1'), '$2'}.

tuple_items -> bool_expr sep tuple_items : ['$1'|'$3'].
tuple_items -> bool_expr : ['$1'].

atom_expr -> atom : {atom, line('$1'), get_atom(unwrap('$1'))}.

Erlang code.

unwrap({_,V}) -> V;
unwrap({_,_,V}) -> V.

line({_, Line}) -> Line;
line({_, Line, _}) -> Line;
line({_, Line, _, _}) -> Line.

get_atom([_ | T]) -> list_to_atom(T).

line_on_atoms([{atom, Line, _}|_]) -> Line.
