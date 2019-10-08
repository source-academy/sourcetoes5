
/* description: Parses end executes JediScript expressions. */

/* lexical grammar */
%{
  var counter = 0;
  var stack = [{}];
  resetParser = function() {
    counter = 0;
    stack = [{}];
  }
  function getRenamedVarIfPossible(env, id) {
    while (env) {
        if (env.hasOwnProperty(id)) {
            return env[id];
        }
        env = env["#parent"];
  	}
  	return id;
  }
  function currentEnv() {
    return stack[stack.length - 1];
  }
  function getNewName(id) {
    const newName = id + "$" + counter
    currentEnv()[id] = newName;
    counter++;
    return newName;
  }
  function pushStack() {
  	stack.push({"#parent": currentEnv()});
  }
  function popStack() {
  	stack.pop();
  }
  function flatten(array) {
      var result = [];
      var nodes = array;
      var node;

      if (!array.length) {
          return result;
      }

      node = nodes.pop();

      do {
          if (Array.isArray(node)) {
              [].push.apply(nodes, node);
          } else {
            if (typeof node === "string") {
              result.push(node);
            } else {
              result.push(getRenamedVarIfPossible(node.env, node.id));
            }
          }
      } while (nodes.length && (node = nodes.pop()) !== undefined);

      result.reverse(); // we reverse result to restore the original order
      return result.join("");
  }
%}
%lex
%x DoubleQuotedString
%x SingleQuotedString
%x QuotedStringEscape
%%


\/\/([^\n\r]*)              /* skip single-line comments */
\/\*([\u0000-\uffff]*?)\*\/ /* skip multi-line comments */
\s+                         /* skip whitespace */

"function"                                    return 'function'
"return"                                      return 'return'
"if"                                          return 'if'
"else"                                        return 'else'
"while"                                       return 'while'
"for"                                         return 'for'
"break"                                       return 'break'
"continue"                                    return 'continue'
"let"                                         return 'let'
"const"                                       return 'const'
"==="                                         return '==='
"=>"                                          return '=>'
"="                                           return '='
"{"                                           return '{'
"}"                                           return '}'
";"                                           return ';'
","                                           return ','
"true"                                        return 'true'
"false"                                       return 'false'
"NaN"                                         return 'NaN'
"Infinity"                                    return 'Infinity'
"null"                                        return 'emptylist'
"["                                           return '['
"]"                                           return ']'

'""'                                          return 'EmptyString'
"''"                                          return 'EmptyString'
'"'                                           this.begin('DoubleQuotedString');
"'"                                           this.begin('SingleQuotedString');
<DoubleQuotedString,SingleQuotedString>\\     this.begin('QuotedStringEscape');
<DoubleQuotedString>'"'                       this.popState();
<SingleQuotedString>"'"                       this.popState();
<QuotedStringEscape>(.|\r\n|\n)               { this.popState(); return 'QuotedStringEscape'; } /* The newlines are there because we can span strings across lines using \ */
<DoubleQuotedString>[^"\\]*                   return 'QuotedString';
<SingleQuotedString>[^'\\]*                   return 'QuotedString';


[A-Za-z_][A-Za-z0-9_]*                        return 'Identifier' /* TODO: non-ASCII identifiers */

[0-9]+("."[0-9]+)?([eE][\-+]?[0-9]+)?\b       return 'FLOAT_NUMBER' /* 3.1, 3.1e-7 */
[0-9]+\b                                      return 'INT_NUMBER'

"+"                                           return '+'
"-"                                           return '-'
"*"                                           return '*'
"/"                                           return '/'
"%"                                           return '%'
"!=="                                         return '!=='
"<="                                          return '<='
">="                                          return '>='
"<"                                           return '<'
">"                                           return '>'
"!"                                           return '!'
"&&"                                          return '&&'
"||"                                          return '||'
"("                                           return '('
")"                                           return ')'
"?"                                           return '?'
":"                                           return ':'

<<EOF>>                                       return 'EOF'
.                                             return 'INVALID'

/lex

/* operator associations and precedence */

%left  ';'
%right '='
%left  '=>' ARROW
%right '?' ':'
%left  '||'
%left  '&&'
%left  '===' '!=='
%left  '<' '>' '<=' '>='
%left  '+' '-'
%left  '*' '/' '%'
%right '!' UMINUS UPLUS
%left  '[' ']'
%left  '.'

%% /* language grammar */

program
  : statements EOF
    {{ return flatten($1); }}
  ;

statements
  :
    { $$ = ""; }
  | statement statements
    { $$ = [$1 , "\n" , $2]; }
  ;

functionid
  :
  'function' identifier
  {{
  	$$ = getNewName($2[0]);
  }}
  ;

statement
  :
  ifstatement

  | whilestatement

  | forstatement

  | functionid wrappedparams leftbrace statements rightbrace
    {{
      popStack();
      $$ = ["function " , $1 , "(" , $2 , ") {" , $4 , "}"] ;
    }}
  | declaration
  | leftbrace statements rightbrace
        {{
      $$ = ["{" , $2 , "}"];
        }}

  | assignment ';'
      {{
      $$ = [$1 , ";"];
        }}

  | expression ';'
    {{
      $$ = [$1 , ";"];
        }}
  | 'return' expression ';'
    {{
      $$ = ["return " , $2 , ";"];
        }}


  | break ';'
    {{
      $$ = "break;";
    }}
  | continue ';'
    {{
      $$ = "continue;";
    }}

  ;

declaration
  :
  declarator identifier '=' expression ';'
    {{
      var newName = getNewName($2[0]);
      $$ = ["var " , newName , "=" , $4 , ";"];
    }}
  ;

declarator: 'const' | 'let';


assignment
  :
  expression '=' expression
    {{
      $$ = [$1 , "=" , $3];
    }}
  ;

ifstatement
  :
  'if' '(' expression ')' leftbrace statements rightbrace 'else' leftbrace statements rightbrace
    {{
      $$ = ["if (" , $3 , ") {" , $6 , "} else {" , $10 , "}"];
    }}
  | 'if' '(' expression ')' leftbrace statements rightbrace 'else' ifstatement
    {{
      $$ = ["if (" , $3 , ") {" , $6 , "} else " , $9];
    }}
  ;


whilestatement
  :
  'while' '(' expression ')' leftbrace statements rightbrace
    {{
      $$ = ["while (" , $3 , ") {" , $6 , "}"];
    }}
  ;

forstatement
  :
    'for' '(' forinitialiser expression ';' forfinaliser ')' leftbrace statements rightbrace
    {{
      $$ = ["for (" , $3 , $4 , ";" , $6 , ") {" , $9 , "}"];
    }}
  ;

forinitialiser
  :
  declaration
  | assignment ';'
  {{
      $$ = [$1 , ";"];
    }}
  ;

forfinaliser
  :
  assignment
  ;


expression
  :
  expression '+' expression
    {{
      $$ = [$1 , "+" , $3];
    }}
  | expression '-' expression
    {{
      $$ = [$1 , "-" , $3];
    }}
  | expression '*' expression
    {{
      $$ = [$1 , "*" , $3];
    }}
  | expression '/' expression
    {{
      $$ = [$1 , "/" , $3];
    }}
  | expression '%' expression
    {{
      $$ = [$1 , "%" , $3];
    }}
  | '-' expression %prec UMINUS
    {{
      $$ = ["-" , $2];
    }}
  | '+' expression %prec UPLUS
    {{
      $$ = ["," , $2];
    }}
  | '!' expression
    {{
      $$ = ["!" , $2];
    }}
  | expression '&&' expression
    {{
      $$ = [$1 , "&&" , $3];
    }}
  | expression '||' expression
    {{
      $$ = [$1 , "||" , $3];
    }}
  | expression '===' expression
    {{
      $$ = [$1 , "===" , $3];
    }}
  | expression '!==' expression
    {{
      $$ = [$1 , "!==" , $3];
    }}
  | expression '>' expression
    {{
      $$ = [$1 , ">" , $3];
    }}
  | expression '<' expression
    {{
      $$ = [$1 , "<" , $3];
    }}
  | expression '>=' expression
    {{
      $$ = [$1 , ">=" , $3];
    }}
  | expression '<=' expression
    {{
      $$ = [$1 , "<=" , $3];
    }}
  | wrappedparams '=>' expression    %prec ARROW
    {{
      popStack();
      $$ = ["(function(" , $1 , "){ return " , $3 , ";})"];
    }}
  | wrappedparams '=>' leftbrace statements rightbrace    %prec ARROW
    {{
      popStack();
      $$ = ["(function(" , $1 , "){ " , $4 , "})"];
    }}
  | idarrow expression
    {{
      popStack();
      $$ = ["(function(" , $1 , "){ return " , $2 , ";})"];
    }}
  | idarrow leftbrace statements rightbrace
	{{
	  popStack();
	  $$ = ["(function(" , $1 , "){ " , $3 , "})"];
	}}

  | constants
    { $$ = $1; }

  | wrappedexpressions

  | identifier wrappedexpressions
    {{ $$ = [$1[1] , $2]}}

  | expression '?' expression ':' expression
    {{
      $$ = [$1 , "?" , $3 , ":" , $5];
    }}

  | identifier
    { $$ = $1[1]; }
  ;

wrappedexpressions
  :'(' expressions ')'
  { $$ = ["(" , $2 , ")"]; }
  |'[' expressions ']'
  { $$ = ["[" , $2 , "]"]; }
  | '(' expressions ')' wrappedexpressions
  { $$ = ["(" , $2 , ")" , $4]; }
  | '[' expressions ']' wrappedexpressions
  { $$ = ["[", $2, "]", $4]; }
  ;

constants
  :
  'FLOAT_NUMBER'
    { $$ = String(parseFloat(yytext)); }

  | 'INT_NUMBER'
    { $$ = String(parseInt(yytext, 10)); }

  | 'true'
    { $$ = 'true'; }

  | 'false'
    { $$ = 'false'; }

  | 'NaN'
    { $$ = 'NaN'; }

  | 'Infinity'
    { $$ = 'Infinity'; }

  | quotedstring
    { $$ = '"' + $1.replace(/\"/g,'\\\"') + '"'; }

  | 'emptylist'
    { $$ = 'null'; }
  ;

quotedstring
  :
    'EmptyString'
  {
    $$ = '';
  }
  | 'QuotedString'
  | 'QuotedStringEscape'
  {
    switch (yytext)
    {
      case 'b':   $$ = '\\b'; break;
      case 'n':   $$ = '\\n'; break;
      case 'r':   $$ = '\\r'; break;
      case 't':   $$ = '\\t'; break;
      case "'":   $$ = "\\'"; break;
      case '"':   $$ = '\"'; break;
      case '\\':    $$ = '\\\\'; break;
      case '\n':
      case '\r\n':  $$ = ''; break;
      default:    $$ = '\\\\' + $1; break;
    }
  }
  | 'QuotedStringEscape' quotedstring
  {
    switch ($1)
    {
      case 'b':   $$ = '\\b'; break;
      case 'n':   $$ = '\\n'; break;
      case 'r':   $$ = '\\r'; break;
      case 't':   $$ = '\\t'; break;
      case "'":   $$ = "\\'"; break;
      case '"':   $$ = '\"'; break;
      case '\\':    $$ = '\\\\'; break;
      case '\n':
      case '\r\n':  $$ = ''; break;
      default:    $$ = '\\\\' + $1; break;
    }
    $$ += $2;
  }
  | 'QuotedString' quotedstring
  {
    $$ = $1 + $2;
  }
  ;

expressions
  :
  nonemptyexpressions
    { $$ = $1; }
  | /* NOTHING */
    { $$ = ""; }
  ;

nonemptyexpressions
  :
  expression ',' nonemptyexpressions
    { $$ = [$1, ",", $3]; }
  | expression
    { $$ = $1; }
  ;

idarrow
  :
  identifier '=>'
  {{
  	pushStack();
  	$$ = getNewName($1[0]);
  }}
  ;

wrappedparams
  :
  '(' identifiers ')'
  {{
  	pushStack();
  	var renamed = [];
  	for (var i = 0; i < $2.length; i++) {
  		renamed.push(getNewName($2[i]));
  	}
  	$$ = renamed.join(", ");
  }}
  ;


identifiers
  :
  nonemptyidentifiers
    { $$ = $1; }
  | /* NOTHING */
    { $$ = []; }
  ;

nonemptyidentifiers
  :
  identifier ',' nonemptyidentifiers
    { $$ = [$1[0]].concat($3); }
  | identifier
    { $$ = [$1[0]]; }
  ;

identifier
  :
  'Identifier'
    {{
      var id = yytext;
      $$ = [id, {env:currentEnv(), id:id}];
    }}
  ;

leftbrace
  :
  '{'
  {{
  	pushStack();
  }}
  ;
rightbrace
  :
  '}'
  {{
  	popStack();
  }}
  ;
