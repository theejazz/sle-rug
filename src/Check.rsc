module Check

import AST;
import Resolve;
import Message; // see standard library
import Set;

data Type
  = tint()
  | tbool()
  | tstr()
  | tunknown()
  ;

// the type environment consisting of defined questions in the form 
alias TEnv = rel[loc def, str name, str label, Type \type];

// To avoid recursively traversing the form, use the `visit` construct
// or deep match (e.g., `for (/question(...) := f) {...}` ) 
TEnv collect(AForm f) {
  return {<i.src, i.name, l, tint()> | /question(str l, AId i, AType _) := f 
  							   || /computed_question(str l, AId i, AType _, _) := f}; 
}

set[Message] check(AForm f, TEnv tenv, UseDef useDef) {
  //lst = for(q <- f.questions){
  //	msgs = check(q, tenv, useDef);
  //	for(msg <- msgs) {
  //	 append(msg);
  //	}
  //}
  //return toSet(lst);
  return union({check(q, tenv, useDef) |  q <- f.questions}); 
}

// - produce an error if there are declared questions with the same name but different types.
// - duplicate labels should trigger a warning 
// - the declared type computed questions should match the type of the expression.
set[Message] check(AQuestion q, TEnv tenv, UseDef useDef) {
  return differentTypes(q, tenv, useDef) +
  		 duplicateLabels(q, tenv, useDef) +  
  		 union({ check(e, tenv, useDef) | /if_then_else(AExpr e, _, _) := q 
  									   || /if_then(AExpr e, _) := q
  									   || /computed_question(_,_,_,AExpr e) := q
  	}	 ); 
}

set[Message] differentTypes(AQuestion q, TEnv tenv, UseDef useDef) {
	return {};
}

set[Message] duplicateLabels(AQuestion q, TEnv tenv, UseDef useDef) {
	return {};
}

// Check operand compatibility with operators.
// E.g. for an addition node add(lhs, rhs), 
//   the requirement is that typeOf(lhs) == typeOf(rhs) == tint()
set[Message] check(AExpr e, TEnv tenv, UseDef useDef) {
  set[Message] msgs = {};
  
  switch (e) {
    case ref(AId x):
      msgs += { error("Undeclared question", x.src) | useDef[x.src] == {} };

    // etc.
  }
  
  return msgs; 
}

Type typeOf(AExpr e, TEnv tenv, UseDef useDef) {
  switch (e) {
    case ref(id(_, src = loc u)):  
      if (<u, loc d> <- useDef, <d, x, _, Type t> <- tenv) {
        return t;
      }
    // etc.
  }
  return tunknown(); 
}

/* 
 * Pattern-based dispatch style:
 * 
 * Type typeOf(ref(id(_, src = loc u)), TEnv tenv, UseDef useDef) = t
 *   when <u, loc d> <- useDef, <d, x, _, Type t> <- tenv
 *
 * ... etc.
 * 
 * default Type typeOf(AExpr _, TEnv _, UseDef _) = tunknown();
 *
 */
 
 

