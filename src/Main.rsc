module Main

import Syntax;
import AST;
import CST2AST;
import Resolve;
import ParseTree;
import IO;
import Check;
import Message;
import Eval;


// e.g. main(|project://QL/examples/tax.myql|);
void main(loc l) {
  fm = l;
  Form p = parse(#Form, fm);
  AForm a = cst2ast(p);
  TEnv env = collect(a);
  UseDef usedef = resolve(a)[2];
  set[Message] c = check(a, env, usedef);
  if (c == {}) {
    VEnv venv = initialEnv(a);
    println("Initial environment computed");
  }
  println(c);
}

void main(str tax) {
  if (tax != "tax") {
    println("sorry! -- not a valid option; try \"tax\"");
    return;
  }
  loc fm = |project://QL/examples/tax.myql|;
  Form p = parse(#Form, fm);
  AForm a = cst2ast(p);
  TEnv env = collect(a);
  UseDef usedef = resolve(a)[2];
  set[Message] c = check(a, env, usedef);
  if (c != {}) {
    println(c);
    return;
  }
  VEnv venv = initialEnv(a);
  println("Initial environment:");
  println(venv);
  venv = eval(a, input("\"Did you buy a house in 2010?\"", vbool(true)), venv);
  venv = eval(a, input("\"Did you enter a loan?\"", vbool(false)), venv);
  venv = eval(a, input("\"Did you sell a house in 2010?\"", vbool(true)), venv);
  venv = eval(a, input("\"What was the selling price?\"", vint(100000)), venv);
  venv = eval(a, input("\"Private debts for the sold house:\"", vint(4083)), venv);
  println("Final environment:");
  println(venv);
}

