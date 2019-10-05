# sourcetoes5
Transpiles Source to ES5, using jison

Live demo [here](https://s25.openorclo.se/).

Live tests [here](https://s25.openorclo.se/tests.html).

# Why

ev3 doesn't support newer versions of JS that allows `let`, `const`, and arrow functions, but Source demands this. Babel was suggested, but then it took 80+s to transpile from Source to ES5. So instead we decided to use a basic Jison generated parser that can translate Source to valid ES5.

# How it works

Barely. 

The grammar is a hasty port from a previous parser used for the meta circular evaluator, and has a lot of conflicts that we just let jison handle.

It also accepts non-Source languages as a bonus.

## `const` and `let` to `var`

We just replace `const` and `let` with `var`. Yeah. This allows reassignment of constants. 

Bigger issue is scoping, since `var` has function scope but `let` and `const` have block scope. Thus we do a simple renaming of all variables so that they refer to the correct scope. This unfortunately poses debugging issues. Luckily, the renaming only appends a `$xx` where `xx` is some number, so the left part still refers to a correct variable name.

## `=>`

We replace these with anonymoous function expressions: `(function () { ...; return ...; })`. These shouldn't cause any problems.
