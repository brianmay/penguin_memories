Nonterminals elems word_elems word_elem op_elems op_elem name value.
Terminals int float date op string '.'.
Rootsymbol elems.

elems -> int            : {id, extract_token('$1')}.

elems -> word_elems     : {words, '$1'}.
elems -> op_elems       : {ops, '$1'}.

word_elems -> word_elem           : ['$1'].
word_elems -> word_elem word_elems     : ['$1'|'$2'].

word_elem -> string       : extract_token('$1').

op_elems -> op_elem           : ['$1'].
op_elems -> op_elem op_elems     : ['$1'|'$2'].

op_elem -> name op value  : {'$1', extract_token('$2'), '$3'}.

value -> string         : extract_token('$1').
value -> date           : extract_token('$1').
value -> int            : extract_token('$1').
value -> float          : extract_token('$1').

name -> string          : {extract_token('$1')}.
name -> string '.' string   : {extract_token('$1'), extract_token('$3')}.


Erlang code.

extract_token({_Token, _Line, Value}) -> Value.

