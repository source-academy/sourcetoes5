const tests = [
  `const a = 1;
const b ='b';
if (a === 1) {
  const a = 2;
  a + b;
} else {
  const a = 3;
  b + a;
}`
  , `const f = 1;
function f(a, b, c) {
  return a + b + c + f;
}`
  , `const f = 1;
function g(x) {
  return (x => x)(x);
}`
  , `const x = 1;
function g(y) {
  return f(x)(x);
}`
  , `const x = 1;
function g(y) {
  return f(x=>x)(y=>x)(x=>y(y)(y)(x)(x=>x+1+f()));
}`
];
var x$0 = 1;

function g$1 (y$2) {
  return f$0((function (x$3) { return x$3;}))((function (y$4) { return x$0;}))((function (x$5) { return y$2(y$2)(y$2)(x$5)((function (x$6) { return x$6 + 1 + f$0();}));}));
}