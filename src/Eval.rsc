module Eval

import AST;
import Resolve;
import IO; //debug
import List;

/*
 * Implement big-step semantics for QL
 */
 
// NB: Eval may assume the form is type- and name-correct.


// Semantic domain for expressions (values)
data Value
  = vint(int n)
  | vbool(bool b)
  | vstr(str s)
  ;

// The value environment
alias VEnv = map[str name, Value \value];

// Modeling user input
data Input
  = input(str question, Value \value);
  
// produce an environment which for each question has a default value
// (e.g. 0 for int, "" for str etc.)
VEnv initialEnv(AForm f) {
  return initialEnv(f.questions);
}

VEnv initialEnv(list[AQuestion] qs) {
  VEnv venv = ();
  for (q <- qs) {
    switch(q) { 
      case if_then_else(AExpr e, list[AQuestion] if_qs, list[AQuestion] else_qs):
        venv += initialEnv(if_qs) + initialEnv(else_qs);
      case if_then(AExpr e, list[AQuestion] if_qs):
        venv += initialEnv(if_qs);
      case computed_question(ALabel lbl, AId id, AType t, AExpr e):
        venv[id.name] = initialEnv(t);
      case question(ALabel lbl, AId id, AType t):
        venv[id.name] = initialEnv(t);
      case block(list[AQuestion] qs):
        venv += initialEnv(qs);
     }
  }
  return venv;
}

Value initialEnv(AType \type) {
  switch(\type) {
    case string():
      return vstring("");
    case integer():
      return vint(0);
    case boolean():
      return vbool(false);
  }
}


// Because of out-of-order use and declaration of questions
// we use the solve primitive in Rascal to find the fixpoint of venv.
VEnv eval(AForm f, Input inp, VEnv venv) {
  return solve (venv) {
    venv = evalOnce(f, inp, venv);
  }
  //return (); // shutup eclipse.
}

VEnv evalOnce(AForm f, Input inp, VEnv venv) {
  for (q <- f.questions) {
    venv = eval(q, inp, venv);
  }
  return venv; 
}

VEnv eval(AQuestion q, Input inp, VEnv venv) {
  // evaluate conditions for branching,
  // evaluate inp and computed questions to return updated VEnv
  switch (q) {
    case if_then_else(AExpr e, list[AQuestion] if_qs, list[AQuestion] else_qs):
      {
        qs = (eval(e, venv) == vbool(true)) ? if_qs : else_qs;
        for (question <- qs) {
          venv = eval(question, inp, venv);
        }
      }
    case if_then(AExpr e, list[AQuestion] if_qs):
      if (eval(e, venv) == vbool(true)) {
        for (question <- if_qs) {
          venv = eval(question, inp, venv);
        }
      }
    case computed_question(ALabel lbl, AId id, AType t, AExpr e):
      venv[id.name] = eval(e, venv);
    case question(ALabel lbl, AId id, AType t):
      if (lbl.label == inp[0]) {
        venv[id.name] = inp[1];
      }
    case block(list[AQuestion] qs):
      for (question <- qs) {
        venv = eval(question, inp, venv);
      }
  }
  return venv;
}

Value eval(AExpr e, VEnv venv) {
  switch (e) {
    case ref(AId x): { return venv[x.name]; }
    case string(str s): return vstr(s);
    case integer(int i): return vint(i);
    case boolean(bool b): return vbool(b);
  	case brackets(AExpr expr): return eval(e, venv);
    case not(AExpr expr): return vbool(!eval(expr, venv).b);
    case mul(AExpr lhs, AExpr rhs): return vint(eval(lhs, venv).n * eval(rhs, venv).n);
    case div(AExpr lhs, AExpr rhs): return vint(eval(lhs, venv).n / eval(rhs, venv).n);
    case sum(AExpr lhs, AExpr rhs): return vint(eval(lhs, venv).n + eval(rhs, venv).n);
    case min(AExpr lhs, AExpr rhs): return vint(eval(lhs, venv).n - eval(rhs, venv).n);
    case less(AExpr lhs, AExpr rhs): return vbool(eval(lhs, venv).n < eval(rhs, venv).n);
    case leq(AExpr lhs, AExpr rhs): return vbool(eval(lhs, venv).n <= eval(rhs, venv).n);
    case greater(AExpr lhs, AExpr rhs): return vbool(eval(lhs, venv).n > eval(rhs, venv).n);
    case geq(AExpr lhs, AExpr rhs): return vbool(eval(lhs, venv).n >= eval(rhs, venv).n);
    case eql(AExpr lhs, AExpr rhs): return vbool(eval(lhs, venv) == eval(rhs, venv)); 
    case neq(AExpr lhs, AExpr rhs): return vbool(eval(lhs, venv) != eval(rhs, venv));
    case and(AExpr lhs, AExpr rhs): return vbool(eval(lhs, venv).b && eval(rhs, venv).b);
    case or(AExpr lhs, AExpr rhs): return vbool(eval(lhs, venv).b || eval(rhs, venv).b);
    default: throw "Unsupported expression <e>";
  }
}