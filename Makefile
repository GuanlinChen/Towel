OBJS = common.cmo parser.cmo scanner.cmo traverse.cmo

traverse : $(OBJS)
	ocamlc -o traverse str.cma $(OBJS)

scanner.ml : scanner.mll
	ocamllex scanner.mll

parser.ml parser.mli : parser.mly
	menhir parser.mly

%.cmo : %.ml
	ocamlc -c $<

%.cmi : %.mli
	ocamlc -c $<

.PHONY : clean
clean :
	rm -f traverse parser.ml parser.mli scanner.ml *.cmo *.cmi *.automaton *.conflicts

# Generated by ocamldep *.ml *.mli
common.cmo : ast.cmi
common.cmx : ast.cmi
parser.cmo : common.cmo ast.cmi parser.cmi
parser.cmx : common.cmx ast.cmi parser.cmi
scanner.cmo : parser.cmi common.cmo ast.cmi
scanner.cmx : parser.cmx common.cmx ast.cmi
traverse.cmo : scanner.cmo parser.cmi common.cmo ast.cmi
traverse.cmx : scanner.cmx parser.cmx common.cmx ast.cmi
ast.cmi :
parser.cmi : ast.cmi
