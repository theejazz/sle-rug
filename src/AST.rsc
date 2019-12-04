module AST

data AForm(loc src = |tmp:///|)
  = form(AId id, list[AQuestion] questions)
  ;

data AQuestion(loc src = |tmp:///|)
  = if_then_else(AExpr e, list[AQuestion] if_qs, list[AQuestion] else_qs)
  | if_then(AExpr e, list[AQuestion] if_qs)
  | computed_question(str s, AId id, AType t, AExpr e)
  | question(str s, AId id, AType t)
  | block(list[AQuestion] qs)
  ;

data AExpr(loc src = |tmp:///|)
  = ref(AId id)
  | string(str s)
  | integer(int i)
  | boolean(bool b)
  | brackets(AExpr expr)
  | not(AExpr expr)
  | mul(AExpr lhs, AExpr rhs)
  | div(AExpr lhs, AExpr rhs)
  | sum(AExpr lhs, AExpr rhs)
  | min(AExpr lhs, AExpr rhs)
  | less(AExpr lhs, AExpr rhs)
  | leq(AExpr lhs, AExpr rhs)
  | greater(AExpr lhs, AExpr rhs)
  | geq(AExpr lhs, AExpr rhs)
  | eq(AExpr lhs, AExpr rhs)
  | neq(AExpr lhs, AExpr rhs)
  | and(AExpr lhs, AExpr rhs)
  | or(AExpr lhs, AExpr rhs)
  ;

data AId(loc src = |tmp:///|)
  = id(str name);

data AType(loc src = |tmp:///|)
  = string()
  | integer()
  | boolean()
  ;
