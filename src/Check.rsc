module Check

import AST;
import Resolve;
import Message; // see standard library
import Set;
import List;
import IO;
import Math;

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
  return {<i.src, i.name, l.label, typeOf(t)> | /question(ALabel l, AId i, AType t) := f 
  							   || /computed_question(ALabel l, AId i, AType t, _) := f}; 
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
      			checkType(e, tbool(), tenv, useDef) + 
      			union({check(if_q, tenv, useDef) | if_q <- if_qs}) + 
      			union({check(else_q, tenv, useDef) | else_q <- else_qs});
    case if_then(AExpr e, list[AQuestion] if_qs):
      msgs += 	check(e, tenv, useDef) +
      			checkType(e, tbool(), tenv, useDef) + 
      			union({check(if_q, tenv, useDef) | if_q <- if_qs});
    case computed_question(ALabel lbl, AId id, AType t, AExpr e):
      msgs += 	differentTypes(id, t, tenv) +
      			duplicateLabels(lbl, tenv) +
      			declaredType(t,id.src, e, tenv, useDef) +
      			check(e, tenv, useDef);
    case question(ALabel lbl, AId id, AType t):
      msgs += 	differentTypes(id, t, tenv) +
      			duplicateLabels(lbl, tenv);
    case block(list[AQuestion] qs):
      msgs += union({check(q, tenv, useDef) | q <- qs});
  }
  return msgs; 
}

set[Message] differentTypes(AId id, AType typ, TEnv tenv) {
	for (<_,name,_,t> <- tenv){
		if (name == id.name && t != typeOf(typ)){
			return {error("Multiple declared questions of different types", id.src)};
		} 
	}
	return {};	
}

set[Message] duplicateLabels(ALabel lbl, TEnv tenv) {
	int count = 0;
	for (<_,_,label,_> <- tenv){
		if(label == lbl.label){
			if(count == 1){
				return {warning("Duplicate label", lbl.src)};
			}
			count += 1;
		}
	}
	return {};
}

set[Message] declaredType(AType atyp, loc src, AExpr aexp, TEnv tenv, UseDef useDef) {
	if(typeOf(atyp) != typeOf(aexp, tenv, useDef)){
		return {error("Expression not of declared type", aexp.src)}; 
	}
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
	case brackets(AExpr e):
	  msgs += check(e, tenv, useDef);
	case not(AExpr e):
	  msgs += check(e, tenv, useDef);
	}  
  if(	mul(AExpr lhs, AExpr rhs) := e ||
		div(AExpr lhs, AExpr rhs) := e ||  		
		sum(AExpr lhs, AExpr rhs) := e ||  		
		min(AExpr lhs, AExpr rhs) := e ||  		
		less(AExpr lhs, AExpr rhs) := e ||  		
		leq(AExpr lhs, AExpr rhs) := e ||  		
		greater(AExpr lhs, AExpr rhs) := e ||  		
		geq(AExpr lhs, AExpr rhs) := e	
  	){
    msgs +=	check(lhs, tenv, useDef) +
    		check(rhs, tenv, useDef) +
    		checkType(lhs, tint(), tenv, useDef) +
	  		checkType(rhs, tint(), tenv, useDef);
  }
  if(	eq(AExpr lhs, AExpr rhs) := e ||
		neq(AExpr lhs, AExpr rhs) := e	
  	){
    msgs +=	check(lhs, tenv, useDef) +
    		check(rhs, tenv, useDef) +
    		checkType(lhs, typeOf(rhs, tenv, useDef), tenv, useDef) +
	  		checkType(rhs, typeOf(lhs, tenv, useDef), tenv, useDef);
  }
  if(	and(AExpr lhs, AExpr rhs) := e ||
  		or(AExpr lhs, AExpr rhs) := e
  	){
    msgs +=	check(lhs, tenv, useDef) +
    		check(rhs, tenv, useDef) +
  			checkType(lhs, tbool(), tenv, useDef) +
	  		checkType(rhs, tbool(), tenv, useDef);
  }
  
  return msgs; 
}

set[Message] checkType(AExpr e, Type t, TEnv tenv, UseDef useDef){
  return {error("Operator requires type: [" + type2str(t) + "]", e.src) | typeOf(e, tenv, useDef) != t};
}

Type typeOfInteger(AExpr lhs, AExpr rhs, TEnv tenv, UseDef useDef){
	tlhs = typeOf(lhs, tenv, useDef);
	trhs = typeOf(rhs, tenv, useDef);
	if(tlhs == tint() && trhs == tint()){
		return tint();
	}
	
	return tunknown();
}

Type typeOfBoolean(AExpr lhs, AExpr rhs, TEnv tenv, UseDef useDef){
	tlhs = typeOf(lhs, tenv, useDef);
	trhs = typeOf(rhs, tenv, useDef);
	if(tlhs == tbool() && trhs == tbool()){
		return tbool();
	}
	
	return tunknown();
}

Type typeOfComp(AExpr lhs, AExpr rhs, TEnv tenv, UseDef useDef){
	tlhs = typeOf(lhs, tenv, useDef);
	trhs = typeOf(rhs, tenv, useDef);
	if(tlhs == trhs){
		return tbool();
	}
	
	return tunknown();
}

Type typeOf(AExpr e, TEnv tenv, UseDef useDef) {
  switch (e) {
    case ref(id(_, src = loc u)):  
      if (<u, loc d> <- useDef, <d, x, _, Type t> <- tenv) {
        return t;
      }
    case string(str _):
      return tstr();
    case integer(int _):
      return tint();
    case boolean(bool _):
      return tbool();
    case brackets(AExpr exp):
      return typeOf(exp, tenv, useDef);
    case not(AExpr exp):
      return typeOf(exp, tenv, useDef);
  }
  if(	mul(AExpr lhs, AExpr rhs) := e ||
		div(AExpr lhs, AExpr rhs) := e ||  		
		sum(AExpr lhs, AExpr rhs) := e ||  		
		min(AExpr lhs, AExpr rhs) := e ||  		
		less(AExpr lhs, AExpr rhs) := e ||  		
		leq(AExpr lhs, AExpr rhs) := e ||  		
		greater(AExpr lhs, AExpr rhs) := e ||  		
		geq(AExpr lhs, AExpr rhs) := e	
  	){
	return tint();
  }
  if(	eq(AExpr lhs, AExpr rhs) := e ||
		neq(AExpr lhs, AExpr rhs) := e ||
		and(AExpr lhs, AExpr rhs) := e ||
  		or(AExpr lhs, AExpr rhs) := e
  	){
	return tbool();
  }
  return tunknown(); 
}

Type typeOf(AType t){
	switch (t) {
		case integer():
			return tint();
		case boolean():
			return tbool();
		case string():
			return tstr();
	}
	return tunknown();
}

str type2str(Type t){
	switch(t) {
		case tint():
			return "int";
		case tbool():
			return "boolean";
		case tstr():
			return "string";
	}
	return "unknown";
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
 
 

