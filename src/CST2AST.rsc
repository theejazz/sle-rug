module CST2AST

import Syntax;
import AST;

import ParseTree;
import String;

/*
 * Implement a mapping from concrete syntax trees (CSTs) to abstract syntax trees (ASTs)
 *
 * - Use switch to do case distinction with concrete patterns (like in Hack your JS) 
 * - Map regular CST arguments (e.g., *, +, ?) to lists 
 *   (NB: you can iterate over * / + arguments using `<-` in comprehensions or for-loops).
 * - Map lexical nodes to Rascal primitive types (bool, int, str)
 * - See the ref example on how to obtain and propagate source locations.
 */

AForm cst2ast(start[Form] sf) {
  /*Form f = sf.top;
  switch (f) {
    case (Form) `form <Id i> { <Question* qs> }`:
      return form(id("<i>"), [cst2ast(q) | Question q <- qs], src=f@\loc);
    default:
      throw "Unhandled question <q>";
  }*/
  return cst2ast(sf.top);
}

AForm cst2ast(f: (Form) `form <Id i> { <Question* qs> }`) {
  return form(id("<i>"), [cst2ast(q) | Question q <- qs], src=f@\loc);
}

AQuestion cst2ast(Question q) {
  switch (q) {
    case (Question) `if ( <Expr e> ) { <Question* if_qs> } else { <Question* else_qs> }`:
      return if_then(cst2ast(e), [cst2ast(q) | Question q <- if_qs], [cst2ast(q) | Question q <- else_qs], src=q@\loc);
    case (Question) `if ( <Expr e> ) { <Question* if_qs> }`:
      return if_then_else(cst2ast(e), [cst2ast(q) | Question q <- if_qs], src=q@\loc);
    case (Question) `<Str s> <Id i>: <Type t> = <Expr e>`:
      return computed_question(string("<s>"), id("<i>"), cst2ast(t), cst2ast(e), src=q@\loc);
    case (Question) `<Str s> <Id i>: <Type t>`:
      return question(string("<s>"), id("<i>"), cst2ast(t), src=q@\loc);
    case (Question) `{ <Question* qs> }`:
      return block([cst2ast(q) | Question q <- qs], src=q@\loc);
    default:
      throw "Unhandled question <q>";
  }
}

AExpr cst2ast(Expr e) {
  switch (e) {
    case (Expr) `<Id x>`: 
      return ref(id("<x>", src=e@\loc));
    case (Expr) `<Str x>`: 
      return string("<x>", src=e@\loc);
    case (Expr) `<Int x>`: 
      return integer(toInt("<x>"), src=e@\loc);
    case (Expr) `<Bool x>`: 
      return boolean(fromString("<x>"), src=e@\loc);
    case (Expr) `(<Expr expr>)`: 
      return brackets(cst2ast(expr), src=e@\loc);
    case (Expr) `! <Expr expr>`: 
      return not(cst2ast(expr), src=e@\loc);
    case (Expr) `<Expr e1> * <Expr e2>`: 
      return mul(cst2ast(e1), cst2ast(e2), src=e@\loc);
    case (Expr) `<Expr e1> / <Expr e2>`: 
      return div(cst2ast(e1), cst2ast(e2), src=e@\loc);
    case (Expr) `<Expr e1> + <Expr e2>`: 
      return sum(cst2ast(e1), cst2ast(e2), src=e@\loc);
    case (Expr) `<Expr e1> - <Expr e2>`: 
      return min(cst2ast(e1), cst2ast(e2), src=e@\loc);
    case (Expr) `<Expr e1> \< <Expr e2>`: 
      return les(cst2ast(e1), cst2ast(e2), src=e@\loc);
    case (Expr) `<Expr e1> \<= <Expr e2>`: 
      return leq(cst2ast(e1), cst2ast(e2), src=e@\loc);
    case (Expr) `<Expr e1> \> <Expr e2>`: 
      return greater(cst2ast(e1), cst2ast(e2), src=e@\loc);
    case (Expr) `<Expr e1> \>= <Expr e2>`: 
      return geq(cst2ast(e1), cst2ast(e2), src=e@\loc);
    case (Expr) `<Expr e1> == <Expr e2>`: 
      return eq(cst2ast(e1), cst2ast(e2), src=e@\loc);
    case (Expr) `<Expr e1> != <Expr e2>`: 
      return neq(cst2ast(e1), cst2ast(e2), src=e@\loc);
    case (Expr) `<Expr e1> && <Expr e2>`: 
      return and(cst2ast(e1), cst2ast(e2), src=e@\loc);
    case (Expr) `<Expr e1> || <Expr e2>`: 
      return or(cst2ast(e1), cst2ast(e2), src=e@\loc);
    default: 
      throw "Unhandled expression: <e>";
  }
}

AType cst2ast(Type t) {
  switch (t) {
    case (Type) `boolean`: return boolean(src=t@\loc);
    case (Type) `string`: return string(src=t@\loc);
    case (Type) `integer`: return integer(src=t@\loc);
    default: throw "Unhandled type: <t>";
  }
}
