Definitions.
STRING     = "[^'"]+"
WORD       = [a-zA-Z_][a-zA-Z0-9_-]*
DATE       = [0-9]+-[0-9]+-[0-9]+
OP         = (<|<=|=|==|>=|>|~)
INT        = [0-9]+
FLOAT      = [0-9]+\.[0-9]+
DOT        = \.
WHITESPACE = [\s\t\n\r]

Rules.
{STRING}      : {token, {string, TokenLine, string:strip(TokenChars, both, $")}}.
{WORD}        : {token, {string, TokenLine, TokenChars}}.
{DATE}        : {token, {string, TokenLine, TokenChars}}.
{DOT}         : {token, {'.', TokenLine}}.
{OP}          : {token, {op,  TokenLine, TokenChars}}.
{INT}         : {token, {int,  TokenLine, list_to_integer(TokenChars)}}.
{FLOAT}       : {token, {int,  TokenLine, list_to_float(TokenChars)}}.
{WHITESPACE}+ : skip_token.

Erlang code.
