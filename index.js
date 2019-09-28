var parser = require("./hard.js").parser;

console.log(parser.parse(`x => x; const x = 1; if (true) {const x = 2; x + 2;} else { x = 3; x + y + pi;}
function sum(xs) {
  if (is_null(xs)) {
    return 0;
  } else {
    return head(xs) + sum(tail(xs));
  }
}

function sum() {}

`));