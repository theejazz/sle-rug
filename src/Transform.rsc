module Transform

extend lang::std::Id;

import Syntax;
import Resolve;
import AST;


/* 
 * Transforming QL forms
 */
 
 
/* Normalization:
 *  wrt to the semantics of QL the following
 *     q0: "" int; 
 *     if (a) { 
 *        if (b) { 
 *          q1: "" int; 
 *        } 
 *        q2: "" int; 
 *      }
 *
 *  is equivalent to
 *     if (true) q0: "" int;
 *     if (true && a && b) q1: "" int;
 *     if (true && a) q2: "" int;
 *
 * Write a transformation that performs this flattening transformation.
 *
 */
 
AForm flatten(AForm f) {
  
  list [AQuestion] questions = [];
  
   for( q <- f.questions) {
    questions += flatten(q, []);
   }
   
  f.questions = questions;
  
  return f; 
}

list [AQuestion] flatten(AQuestion q, list [AExpr] exprs) {
  list[AQuestion] qs = [];
  switch(q){
    case if_then(expr, if_qs):
      for(if_q <- if_qs){
        qs += flatten(if_q, exprs + [expr]);
      }
    case if_then_else(expr, if_qs, else_qs): {
      for(if_q <- if_qs){
        qs += flatten(if_q, exprs + [expr]);
      }
      for(else_q <- else_qs){
        qs += flatten(else_q, exprs + [not(expr)]);
      }
    }
    case block(block_qs):
      for(block_q <- block_qs){
        qs += flatten(block_q, exprs);
      }
    default:
      qs += [if_then(appendExprs(exprs), [q])];
  }
  
  return qs;
}

AExpr appendExprs(list [AExpr] exprs){
  AExpr expr = boolean(true);
  
  for(e <- exprs){
    expr = and(expr, brackets(e));
  }
  
  return expr;
}

/* Rename refactoring:
 *
 * Write a refactoring transformation that consistently renames all occurrences of the same name.
 * Use the results of name resolution to find the equivalence class of a name.
 *
 */
 

start[Form] rename(start[Form] sf, loc useOrDef, str newName,  RefGraph refs) {
  set [loc] tr = {useOrDef};
  solve(tr) {
    tr = singlePass(tr, refs[2]);
  }
   
  Id new = [Id]newName;
  
  return visit (sf) {
    case (Question) `<Str s> <Id i>: <Type t>` 
      => (Question) `<Str s> <Id new>: <Type t>`
    when i@\loc in tr
    case (Question) `<Str s> <Id i>: <Type t> = <Expr e>` 
      => (Question) `<Str s> <Id new>: <Type t> = <Expr e>`
    when i@\loc in tr
    case (Expr) `<Id i>` => (Expr) `<Id new>`
    when i@\loc in tr
  }; 
 } 
  
 set [loc] singlePass(set [loc] uds, UseDef useDef){
  set [loc] nuds = {};
  for(l <- uds){
    nuds += l;
    for(<use, def> <- useDef){
      if(l == use){
        nuds += def;
      }
      if(l == def){
        nuds += use;
      }
    } 
  }
  return nuds;
 }
 
 

