module IDE

import Syntax;
import AST;
import CST2AST;
import Resolve;
import Check;
import Compile;
import Transform;

import IO;
import util::IDE;
import Message;
import ParseTree;


private str MyQL ="MyQL";

anno rel[loc, loc] Tree@hyperlinks;

void main() {
  registerLanguage(MyQL, "myql", Tree(str src, loc l) {
    return parse(#start[Form], src, l);
  });
  
  contribs = {
    annotator(Tree(Tree t) {
      if (start[Form] pt := t) {
        AForm ast = cst2ast(pt);
        <_,_,useDef> = resolve(ast);
        set[Message] msgs = check(ast, collect(ast), useDef);
        return t[@messages=msgs][@hyperlinks=useDef];
      }
      return t[@messages={error("Not a form", t@\loc)}];
    }),
    
    builder(set[Message] (Tree t) {
      if (start[Form] pt := t) {
        AForm ast = cst2ast(pt);
        <_,_,useDef> = resolve(ast);
        set[Message] msgs = check(ast, collect(ast), useDef);
        if (msgs == {}) {
          compile(ast);
        }
        return msgs;
      }
      return {error("Not a form", t@\loc)};
    })
  };
  
  registerContributions(MyQL, contribs);
}

AForm astQL(loc file){
	return cst2ast(parse(#Form, file));
}

set[Message] checkQL(loc file){
	ast = cst2ast(parse(#Form, file));
  check(ast);
}

set[Message] checkQL(AForm ast){
  <_,_,usedef> = resolve(ast);
  tenv = collect(ast);
  return check(ast, tenv, usedef);
}

void compileQL(loc file){
  ast = astQL(file);
  compile(ast);
}

void compileQL(AForm ast){
  compile(ast);
}

/*
use : def
b@2 : b@1
b@4 : b@1



*/

AForm flattenQL(loc file){
  ast = astQL(file);
  return flatten(ast);
}

start[Form] renameQL(loc file, str pre, str post){
  sf = parse(#start[Form], file);
	ast = cst2ast(sf);
	refs = resolve(ast);
	tenv = collect(ast);
	return rename(sf,|project://QL/examples/tax.myql|(796,12,<31,46>,<31,58>), "nuds", refs);
}