module Check

import AST;
import Resolve;
import Message; // see standard library
import Set;
import IO;

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
  return {<i.src, i.name, l.label, tint()> | /question(ALabel l, AId i, AType _) := f 
  							   || /computed_question(ALabel l, AId i, AType _, _) := f}; 
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
  set[Message] msgs = {};
  
  switch (q) {
    case if_then_else(AExpr e, list[AQuestion] if_qs, list[AQuestion] else_qs):
      msgs +=  	check(e, tenv, useDef) +
      			union({check(q, tenv, useDef) | q <- if_qs}) + 
      			union({check(q, tenv, useDef) | q <- else_qs});
    case if_then(AExpr e, list[AQuestion] if_qs):
      msgs += 	check(e, tenv, useDef) + 
      			union({check(q, tenv, useDef) | q <- if_qs});
    case computed_question(ALabel lbl, AId id, AType t, AExpr e):
      msgs += 	differentTypes(q, tenv, useDef) +
      			duplicateLabels(lbl, tenv) +
      			declaredType(q, e, tenv, useDef) +
      			check(e, tenv, useDef);
    case question(ALabel lbl, AId id, AType t):
      msgs += 	differentTypes(q, tenv, useDef) +
      			duplicateLabels(lbl, tenv);
    case block(list[AQuestion] qs):
      msgs += union({check(q, tenv, useDef) | q <- qs});
  }
  
  return msgs; 
}

set[Message] differentTypes(AQuestion q, TEnv tenv, UseDef useDef) {
	return {};
}

set[Message] duplicateLabels(ALabel lbl, TEnv tenv) {
	int count = 0;
	for (<_,_,label,_> <- tenv){
				print(label + ":" + lbl.label + "\n");
		if(label == lbl.label){
			if(count == 1){
				return {warning("Duplicate label", lbl.src)};
			}
			count += 1;
		}
	}
	return {};
}

set[Message] declaredType(AQuestion q, AExpr e, TEnv tenv, UseDef useDef) {
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
 
 

