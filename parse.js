var envs = [{}];
var counter = 0;
function parse(code) {
  envs = [{}];
  counter = 0;
  return transpile(acorn.parse(code));
}

function transpile(ast) {
  if (walkers.hasOwnProperty(ast.type)) {
    return walkers[ast.type](ast);
  } else {
    throw Error("Unknown syntax: " + ast.type);
  }
}
function makeUnique(name) {
  return name + "$" + counter++;
}
function currentEnv() {
  return envs[envs.length - 1];
}
function pushEnv() {
  envs.push({"#parent": currentEnv()});
}
function popEnv() {
  envs.pop();
}

function getIdentifier(name) {
  var env = currentEnv();
  while (env) {
    if (env.hasOwnProperty(name)) {
      return env[name];
    }
    env = env["#parent"];
  }
  return name;
}

function hoistIdentifier(name) {
  var env = currentEnv();
  if (env.hasOwnProperty(name)) {
    return env[name];
  }
  return env[name] = makeUnique(name);
}

function hoistVariableDeclarations(node) {
  for (var i = 0; i < node.declarations.length; i++) {
    hoistIdentifier(node.declarations[i].id.name);
  }
}

function hoistFunctionsAndVariableDeclarationsIdentifiers(node) {
  var statement;
  for (var i = 0; i < node.body.length; i++) {
    statement = node.body[i];
    switch (statement.type) {
      case 'VariableDeclaration':
        hoistVariableDeclarations(statement);
        break;
      case 'FunctionDeclaration':
        hoistIdentifier(statement.id.name);
        break
    }
  }
}

function evaluateBlockSatement(node) {
  pushEnv();
  hoistFunctionsAndVariableDeclarationsIdentifiers(node);
  var result = "";
  for (var i = 0; i < node.body.length; i++) {
    result += transpile(node.body[i]);
  }
  popEnv();
  return result
}

function parseParams(params) {
  var ret = [];
  for (var i = 0; i < params.length; i++) {
    ret.push(hoistIdentifier(params[i].name));
  }
  return ret.join(", ");
}

var walkers = {
  Program: evaluateBlockSatement,
  BlockStatement: function (block) {
    return "{\n" + evaluateBlockSatement(block) + "}\n";
  },
  ExpressionStatement: function (expr) {
    return transpile(expr.expression) + ";\n";
  },
  IfStatement: function (cond) {
    console.log(cond.alternate);
    return "if (" + transpile(cond.test) + ")\n" + transpile(cond.consequent) + "else\n" +
      transpile(cond.alternate) + "\n";
  },
  ReturnStatement: function (ret) {
    return "return " + transpile(ret.argument) + ";\n";
  },
  FunctionDeclaration: function (fDecl) {
    var name = hoistIdentifier(fDecl.id.name);
    pushEnv();
    var result = "function " + name + "(" + parseParams(fDecl.params) + ")\n" + transpile(fDecl.body) + "\n";
    popEnv();
    return result;
  },
  VariableDeclaration: function (vDecl) {
    return "var " + hoistIdentifier(vDecl.declarations[0].id.name) + " = " + transpile(vDecl.declarations[0].init) + ";\n";
  },
  ArrowFunctionExpression: function (fn) {
    pushEnv();
    var ret =  "(function(" + parseParams(fn.params) + ") {" + (fn.expression ? "return " : "") + transpile(fn.body) + "})";
    popEnv();
    return ret;
  },
  UnaryExpression: function (u) {
    return u.operator + "(" + transpile(u.argument) + ")";
  },
  BinaryExpression: function (b) {
    return "(" + transpile(b.left) + b.operator + transpile(b.right) + ")";
  },
  LogicalExpression: function (b) {
    return "(" + transpile(b.left) + b.operator + transpile(b.right) + ")";
  },
  ConditionalExpression: function (cond) {
    return "((" + transpile(cond.test) + ") ?" + transpile(cond.consequent) + ":" + transpile(cond.alternate) + ")";
  },
  CallExpression: function (call) {
    return "(" + transpile(call.callee) + ")(" + call.arguments.map(transpile).join(", ") + ")";
  } ,
  Identifier: function (id) {
    return getIdentifier(id.name);
  },
  Literal: function (lit) {
    if (typeof lit.value === "string") {
      return '"' + lit.value.replace(/"/g, "\\\"").replace(/\n/g, "\\n") + '"';
    }
    return String(lit.value);
  },
  BreakStatement: function () {
    return "break;\n";
  },
  ContinueStatement: function () {
    return "continue;\n";
  },
  WhileStatement: function (w) {
    return "while (" + transpile(w.test) + ")\n" + transpile(w.body) + "\n";
  },
  ForStatement: function (f) {
    pushEnv();
    return "for (" + transpile(f.init) + (f.init.type === 'AssignmentExpression' ? ";" : "") + transpile(f.test) + ";" + transpile(f.update) + ")\n" + transpile(f.body) + "\n";
  },
  ArrayExpression: function (arr) {
    return "[" + arr.elements.map(transpile).join(", ") + "]";
  },
  AssignmentExpression: function (ass) {
    return transpile(ass.left) + "=" + transpile(ass.right);
  },
  MemberExpression: function (me) {
    return "" + transpile(me.object) + "[" + transpile(me.property) + "]";
  }
};
