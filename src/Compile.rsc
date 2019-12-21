module Compile

import AST;
import Resolve;
import Eval;
import IO;
import Set;
import lang::html5::DOM; // see standard library

/*
 * Implement a compiler for QL to HTML and Javascript
 *
 * - assume the form is type- and name-correct
 * - separate the compiler in two parts form2html and form2js producing 2 files
 * - use string templates to generate Javascript
 * - use the HTML5Node type and the `str toString(HTML5Node x)` function to format to string
 * - use any client web framework (e.g. Vue, React, jQuery, whatever) you like for event handling
 * - map booleans to checkboxes, strings to textfields, ints to numeric text fields
 * - be sure to generate uneditable widgets for computed questions!
 * - if needed, use the name analysis to link uses to definitions
 */

void compile(AForm f) {
  writeFile(f.src[extension="js"].top, form2js(f));
  writeFile(f.src[extension="html"].top, toString(form2html(f)));
}

HTML5Node form2html(AForm f) {
  return html();
}

str form2js(AForm f)
  = "var form = new Vue({
    '  el: \'form\',
    '  data:{<for(question(_, AId id, AType t) <- f.questions){>
    '    <id.name>: <t == boolean() ? "false" : "null">,
    '  <}>},
    '  computed:{
    '  }
    '})";

list [AQuestion] getQuestions(AQuestion q){
  list[AQuestion] qs = [];
  switch(q){
    case question(_, AId id, AType t): 
      qs += [q];
    case if_then(_, list[AQuestion] if_qs):
      qs += getQuestions(if_qs);
    case if_then_else(_, list[AQuestion] if_qs, list[AQuestion] else_qs):
      qs += getQuestions(if_qs)
          + getQuestions(else_qs);
    case block(list[AQuestion] block_qs):
      qs += getQuestions(block_qs);
  }
  return qs;
}

list [AQuestion] getQuestions(list [AQuestion] qs){
  list [AQuestion] questions = [];
  for(qq <- qs){
    for(q <- getQuestions(qq)){
      questions += [q];
    }
  }
  return questions;   
}