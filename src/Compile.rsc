module Compile

import AST;
import Resolve;
import Eval;
import IO;
import Set;
import String;
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

HTML5Attr vmodel(value val) = html5attr("v-model", val);
HTML5Attr vif(value val) = html5attr("v-if", val);

void compile(AForm f) {
  writeFile(f.src[extension="js"].top, form2js(f));
  writeFile(f.src[extension="html"].top, toString(form2html(f)));
}

HTML5Node form2html(AForm f) {
  return 
  html(
    head(
      meta(charset("UTF-8")),
      script(src("https://cdn.jsdelivr.net/vue/0.12.16/vue.min.js")),
      link(\rel("stylesheet"), href("https://stackpath.bootstrapcdn.com/bootstrap/4.4.1/css/bootstrap.min.css")),
      link(\rel("stylesheet"), href("styles.css"))
    ),
    body(
      div(
        class("container"),
        h1(class("title"), "<f.src[extension=""].file>"),
        hr(),
        questions2html(table(id("form")), f.questions, resolve(f)[1])
      ),
      script(src(f.src[extension="js"].file))
    )
  );
/*
            "<!DOCTYPE html>
            '<html>
            '  <head>
            '    <meta charset="UTF-8">
            '    <script src="https://cdn.jsdelivr.net/vue/0.12.16/vue.min.js"></script>
            '  </head>
            '  <body>
            '    <div id="form">
            '    </div>
            '    <script src="mtax.js"></script>
            '  </body>
            '</html>i
            ";
*/
}

HTML5Node questions2html(HTML5Node parent, list[AQuestion] questions, Def defs){
  
  for(question <- questions){
    parent = question2html(parent, question, defs);
  }

  return parent;
}

HTML5Node question2html(HTML5Node parent, AQuestion question, Def defs){
  switch(question){
    case question(label,id,t):
      parent.kids += [tr(class("question"),
               td(div(class("label"),strong(replaceAll(label.label, "\"", "")))),
               td(div(class("input"),question2html("<id.name><id.src.begin.line>", t)))
             )];
    case computed_question(label, id,_,_):
      parent.kids += [tr(class("computed"),
               td(div(class("label"),strong(replaceAll(label.label, "\"", "")))),
               td(div(class("output"),strong("{{<id.name><id.src.begin.line>}}")))
             )];
    case block(list [AQuestion] questions):
      parent.kids += [
        tr(class("block"),
          td(colspan("2"), 
            questions2html(table(), questions, defs)
            )
          )];
    case if_then(AExpr exp, list [AQuestion] if_qs):
      parent.kids += [
        tr(class("if"), vif(eq2html(exp, defs)), 
          td(colspan("2"),
            questions2html(table(), if_qs, defs)
            )
          )];
    case if_then_else(AExpr exp, list [AQuestion] if_qs, list[AQuestion] else_qs): {
      parent.kids += [
        tr(class("if"), vif(eq2html(exp, defs)), 
          td(colspan("2"),
            questions2html(table(class("subtable")), if_qs, defs)
            )
          ),
        tr(class("else"), vif("!(<eq2html(exp,defs)>)"),
          td(colspan("2"),
            questions2html(table(class("subtable")),else_qs,defs)
            )
          )];
    }
    default:
      throw("Unsupported question: <question>");
  }
  return parent;
}

HTML5Node question2html(str var, AType t){
  switch(t){
    case string():
      return input(vmodel(var));
    case integer():
      return input(\type("number"), vmodel(var));
    case boolean():
      return input(\type("checkbox"), vmodel(var));
    default:
      throw("Unsuported type: <t>");
  }
}

str form2js(AForm f) {
  //<qs, cqs> = getQuestions(f.questions);
  qs = {<id.name, id.src.begin.line, t> | /question(_, id, t) := f};
  cqs = {<id.name, id.src.begin.line, e> | /computed_question(_, id, _, e) := f};
  
  <_,def,_> = resolve(f);
  
  str js = 
          "var form = new Vue({
          '  el: \'#form\',
          '  data: {\n";
  
  for(q <- qs){
    js += "    <q[0]><q[1]>: <(q[2] == boolean() ? "false" : "null")>,\n";
  }
  
  js +=   "  },
          '  computed: {\n";
  
  for(q <- cqs){
    js += "    <q[0]><q[1]>: function() {\n";
    js += "      return <eq2js(q[2], def)>;\n"; 
    js += "    },\n";
  }
          
  js +=   "  },
          '});
          ";
  return js;
}

tuple[list [AQuestion], list [AQuestion]] getQuestions(AQuestion q){
  list[AQuestion] qs = [];
  list[AQuestion] cqs = [];
  switch(q){
    case if_then_else(_, list[AQuestion] if_qs, list[AQuestion] else_qs): {
      <qqs, qcqs> = getQuestions(if_qs);
      qs += qqs;
      cqs += qcqs;
      <qqs, qcqs> = getQuestions(else_qs);
      qs += qqs;
      cqs += qcqs;
    }  
    case if_then(_, list[AQuestion] if_qs): {
      <qqs, qcqs> = getQuestions(if_qs);
      qs += qqs;
      cqs += qcqs;
    }
    case computed_question(_, AId id, AType t, AExpr e):
      cqs += [q];
    case question(_, AId id, AType t): 
      qs += [q];
    case block(list[AQuestion] block_qs): {
      <qqs, qcqs> = getQuestions(block_qs);
      qs += qqs;
      cqs += qcqs;
    }
  }
  return <qs,cqs>;
}

tuple[list [AQuestion], list [AQuestion]] getQuestions(list [AQuestion] questions){
  list [AQuestion] qs = [];
  list [AQuestion] cqs = [];
  for(q <- questions){
    <qqs, qcqs> = getQuestions(q);
    qs += qqs;
    cqs += qcqs;
  }
  return <qs, cqs>;   
}
str eq2html(AExpr e, Def defs){
  switch(e){
    case ref(AId id):
      return "<id.name><getDef(id.name, id.src, defs).begin.line>";
    case string(str s):
      return "<s>";
    case integer(int i):
      return "<i>";
    case boolean(bool b):
      return (b ? "true" : "false");
    case brackets(AExpr expr):
      return "(<eq2js(expr, defs)>)";
    case not(AExpr expr):
      return "!<eq2js(expr, defs)>";
    case mul(AExpr lhs, AExpr rhs):
      return "<eq2js(lhs, defs)> * <eq2js(rhs, defs)>";
    case div(AExpr lhs, AExpr rhs):
      return "<eq2js(lhs, defs)> / <eq2js(rhs, defs)>";
    case sum(AExpr lhs, AExpr rhs):
      return "<eq2js(lhs, defs)> + <eq2js(rhs, defs)>";
    case min(AExpr lhs, AExpr rhs):
      return "<eq2js(lhs, defs)> - <eq2js(rhs, defs)>";
    case less(AExpr lhs, AExpr rhs):
      return "<eq2js(lhs, defs)> \< <eq2js(rhs, defs)>";
    case leq(AExpr lhs, AExpr rhs):
      return "<eq2js(lhs, defs)> \<= <eq2js(rhs, defs)>";
    case greater(AExpr lhs, AExpr rhs):
      return "<eq2js(lhs, defs)> \> <eq2js(rhs, defs)>";
    case geq(AExpr lhs, AExpr rhs):
      return "<eq2js(lhs, defs)> \>= <eq2js(rhs, defs)>";
    case eql(AExpr lhs, AExpr rhs):
      return "<eq2js(lhs, defs)> == <eq2js(rhs, defs)>";
    case neq(AExpr lhs, AExpr rhs):
      return "<eq2js(lhs, defs)> != <eq2js(rhs, defs)>";
    case and(AExpr lhs, AExpr rhs):
      return "<eq2js(lhs, defs)> && <eq2js(rhs, defs)>";
    case or(AExpr lhs, AExpr rhs):
      return "<eq2js(lhs, defs)> || <eq2js(rhs, defs)>";
  }
  return "\"\"";
}

str eq2js(AExpr e, Def defs){
  switch(e){
    case ref(AId id):
      return "this.<id.name><getDef(id.name, id.src, defs).begin.line>";
    case string(str s):
      return "<s>";
    case integer(int i):
      return "<i>";
    case boolean(bool b):
      return (b ? "true" : "false");
    case brackets(AExpr expr):
      return "(<eq2js(expr, defs)>)";
    case not(AExpr expr):
      return "!<eq2js(expr, defs)>";
    case mul(AExpr lhs, AExpr rhs):
      return "parseInt(<eq2js(lhs, defs)>,10) * parseInt(<eq2js(rhs, defs)>,10)";
    case div(AExpr lhs, AExpr rhs):
      return "parseInt(<eq2js(lhs, defs)>,10) / parseInt(<eq2js(rhs, defs)>,10)";
    case sum(AExpr lhs, AExpr rhs):
      return "parseInt(<eq2js(lhs, defs)>,10) + parseInt(<eq2js(rhs, defs)>,10)";
    case min(AExpr lhs, AExpr rhs):
      return "parseInt(<eq2js(lhs, defs)>,10) - parseInt(<eq2js(rhs, defs)>,10)";
    case less(AExpr lhs, AExpr rhs):
      return "parseInt(<eq2js(lhs, defs)>,10) \< parseInt(<eq2js(rhs, defs)>,10)";
    case leq(AExpr lhs, AExpr rhs):
      return "parseInt(<eq2js(lhs, defs)>,10) \<= parseInt(<eq2js(rhs, defs)>,10)";
    case greater(AExpr lhs, AExpr rhs):
      return "parseInt(<eq2js(lhs, defs)>,10) \> parseInt(<eq2js(rhs, defs)>,10)";
    case geq(AExpr lhs, AExpr rhs):
      return "parseInt(<eq2js(lhs, defs)>,10) \>= parseInt(<eq2js(rhs, defs)>,10)";
    case eql(AExpr lhs, AExpr rhs):
      return "<eq2js(lhs, defs)> == <eq2js(rhs, defs)>";
    case neq(AExpr lhs, AExpr rhs):
      return "<eq2js(lhs, defs)> != <eq2js(rhs, defs)>";
    case and(AExpr lhs, AExpr rhs):
      return "<eq2js(lhs, defs)> && <eq2js(rhs, defs)>";
    case or(AExpr lhs, AExpr rhs):
      return "<eq2js(lhs, defs)> || <eq2js(rhs, defs)>";
  }
  return "\"\"";
}

loc getDef(str name, loc src, Def defs){
  loc dl = src;
  for(<n, l> <- defs){
    if(n == name && l.begin.line < src.begin.line && (dl.begin.line < l.begin.line || dl == src)){
      dl = l;
    }
  }
  return dl;
}