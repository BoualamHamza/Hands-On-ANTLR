grammar Calculette;

//helper function 
@parser::members {
	private int _cur_label = 0;
    private String newLabel( ) { return "Label"+(_cur_label++); };
    private TablesSymboles tablesSymboles = new TablesSymboles();
	private String evalOp(String op) {
		if ( op.equals("*") ){
			return "MUL\n";
		} else if ( op.equals("/") ){
			return "DIV\n";
		} else if ( op.equals("%") ){
			return "MOD\n";
		}else if ( op.equals("+") ){
			return "ADD\n";
		} else if ( op.equals("-") ){
			return "SUB\n";
		} else if ( op.equals("==") ){
			return "EQUAL\n";
		} else if ( op.equals("<>") ){
			return " NEQ \n";
		} else if ( op.equals(">") ){
			return "SUP \n";
		} else if ( op.equals("<") ){
			return "INF \n";
		} else if ( op.equals(">=") ){
			return "SUPEQ \n";
		} else if ( op.equals("<=") ){
			return "INFEQ \n";
		} else {
		 System.err.println("Opérateur arithmétique incorrect : '"+op+"'");
		 throw new IllegalArgumentException("Opérateur arithmétique incorrect : '"+op+"'");
		}
	}
}

start: calcul EOF;

calcul
	returns[ String code ]
	@init { $code = new String(); } // On initialise une variable pour accumuler le code 
	@after { System.out.println($code); }: (
		decl { $code += $decl.code; }
	)* { $code += "  JUMP Main\n"; } NEWLINE* (
		fonction { $code += $fonction.code; }
	)* NEWLINE* { $code += "LABEL Main\n"; } (
		instruction { $code += $instruction.code; }
	)* { $code += "  HALT\n"; };

// la regle instruction contient exrp et fin in struction 
instruction
	returns[ String code ]:
	expression finInstruction { $code = $expression.code;}
	| assignation finInstruction { $code=$assignation.code; }
	| 'println' '(' expression ')' finInstruction {

			$code=$expression.code + "WRITE\n POP\n"; 
		}
	| 'readln' '(' IDENTIFIANT ')' finInstruction {
			VariableInfo vi = tablesSymboles.getVar($IDENTIFIANT.text);
			String loug = (vi.scope == VariableInfo.Scope.GLOBAL) ? "G " : "L ";
			$code="READ\nSTORE"+loug+vi.address+"\n"; 
		}
	| 'while' '(' condition ')' alorsinstruction {
			String label1 = newLabel();
			String label2 = newLabel();
			$code="LABEL "+ label1 +"\n" + $condition.code + "JUMPF "+ label2+ "\n"+$alorsinstruction.code +" JUMP "+label1 + "\nLABEL "+label2 +"\n"; 
		}
	| 'if' '(' condition ')' alorsinstruction {
			String l1 = newLabel();
			String l2 = newLabel(); 
			$code = $condition.code + "  JUMPF " + l1 + "\n" + $alorsinstruction.code + "  JUMP " + l2 + "\nLABEL " + l1 + "\n";
		} ('else' i2 = instruction { $code += $i2.code; })? (
		'else' '{' (instruction)* '}' { $code += $instruction.code; }
	)? { $code += "LABEL " + l2 + "\n"; }
	| 'for' '(' ass1 = assignation ';' condition ';' ass2 = assignation ')' alorsinstruction {
			String label1 = newLabel();
			String label2 = newLabel(); 
			String label3 = newLabel(); 
			$code= $ass1.code + "LABEL " + label1 + "\n" + $condition.code + "  JUMPF " + label3 + "\n" + $alorsinstruction.code + "LABEL " + label2 + "\n" + $ass2.code + "  JUMP " + label1 + "\nLABEL " + label3 + "\n";
		}
	| finInstruction { $code=""; }
	| RETURN expression finInstruction {
			VariableInfo vi = tablesSymboles.getReturn();
			String loug = (vi.scope == VariableInfo.Scope.GLOBAL) ? "G " : "L ";
			$code = $expression.code + " STORE"+loug+" " + vi.address + "\n  RETURN\n";
		};

/*
 expression doit retourner un string code qui va contenir le code mvap 5+1 --> PUSHI 5 THEN PUSHI 1
 THEN ADD $code = "PUSHI 5 PUSHI 1 ADD"
 */
expression
	returns[String code, String type]:
	'-' a = expression {$code="PUSHI 0\n"+ $a.code + "SUB\n";}
	| '(' a = expression ')' {$code = $a.code;}
	| a = expression op = ('*' | '/' | '%') b = expression {$code = $a.code + $b.code+ evalOp($op.text);
		}
	| a = expression op = ('+' | '-') b = expression {$code = $a.code + $b.code+ evalOp($op.text);}
	| IDENTIFIANT {
			VariableInfo vi = tablesSymboles.getVar($IDENTIFIANT.text);
			String loug = (vi.scope == VariableInfo.Scope.GLOBAL) ? "G " : "L ";		
			$code = "PUSH"+loug +" "+vi.address + "\n"; 
			}
	| IDENTIFIANT '(' args ')' {
		
			$code ="PUSHI 0\n" + $args.code + "  CALL " + $IDENTIFIANT.text+ "\n";
			for(int i = 0; i < $args.size; i++) { $code += "  POP \n"; }	
		}
	| ENTIER {$code = "PUSHI " + $ENTIER.int + "\n";};

args
	returns[String code, int size]
	@init { $code = new String(); $size = 0; }: (
		expression { 
			$code = $expression.code; 
			$size = 1;
		} (
			',' expression { 
			$code += $expression.code; 
			$size += 1;
		}
		)*
	)?;
finInstruction: ( NEWLINE | ';')+;

// TYPE:int, double ... declaration type : int x - > PUSHI 0, or int x = 2 -> PUSHI 0 + STOREG + var
// adrr,
decl
	returns[String code]:
	TYPE IDENTIFIANT finInstruction {
			tablesSymboles.addVarDecl($IDENTIFIANT.text,$TYPE.text);
			$code = "PUSHI 0\n";
		}
	| TYPE IDENTIFIANT '=' expression finInstruction {
			tablesSymboles.addVarDecl($IDENTIFIANT.text,$TYPE.text);
			$code = "PUSHI 0\n"+ $expression.code + "STOREG " +tablesSymboles.getVar($IDENTIFIANT.text).address + "\n";
		};

// @assignation permet assigner une valeur à notre variable 'identifiant' qui est un string (combinaison de lettres) cette derniere peut etre sous la forme x=2 ou x2 avec une operation aka expression
assignation
	returns[ String code]:
	IDENTIFIANT '=' expression {
			VariableInfo vi = tablesSymboles.getVar($IDENTIFIANT.text);
			String loug = (vi.scope == VariableInfo.Scope.GLOBAL) ? "G " : "L ";
			$code= $expression.code + "STORE"+loug+" "+vi.address + "\n";
	
		}
	| IDENTIFIANT '+=' expression {
			VariableInfo vi = tablesSymboles.getVar($IDENTIFIANT.text);
			String loug = (vi.scope == VariableInfo.Scope.GLOBAL) ? "G " : "L ";			
			$code = "PUSH"+loug+" "+vi.address + "\n" + $expression.code + "ADD \n" + "STORE"+loug+" " + vi.address + "\n"; 
		};

//Un bloc est une suite d'instructions
bloc
	returns[ String code ]
	@init { $code = new String(); }:
	'{' (instruction {$code += $instruction.code; })* '}' NEWLINE*;

//conditions
condition
	returns[String code]:
	a = expression operator = (
		'=='
		| '<>'
		| '>'
		| '<'
		| '>='
		| '<='
	) b = expression {$code=$a.code+$b.code+evalOp($operator.text);}
	| 'True' { $code = "  PUSHI 1\n"; }
	| 'False' { $code = "  PUSHI 0\n"; }
	| '!' condition { $code = "  PUSHI 1 \n" + $condition.code + "  SUB\n"; }
	| con1 = condition '&&' con2 = condition { $code = $con1.code + $con2.code + "  MUL\n"; }
	| con1 = condition '||' con2 = condition { $code = $con1.code + $con2.code + "  ADD\n  PUSHI 0\n  SUB\n"; 
		};
//besoin d'ajouter alors  de la boucle {}/  while (True) {i += 1; println(i);} => while True bloc ou while instruction pour while (True) i = i + 2; 
alorsinstruction
	returns[String code]:
	instruction {$code = $instruction.code;}
	| bloc {$code = $bloc.code;};

// k- fonctions
fonction
	returns[ String code ]
	@init { tablesSymboles.enterFunction(); }
	@after { tablesSymboles.exitFunction(); }:
	'fun' IDENTIFIANT '(' params? ')' '->' TYPE {
			tablesSymboles.addFunction($IDENTIFIANT.text, $TYPE.text);
			$code = "LABEL " + $IDENTIFIANT.text + "\n";
		} '{' NEWLINE? (decl { $code += $decl.code; })* NEWLINE* (
		instruction { $code += $instruction.code; }
	)* '}' NEWLINE* {$code += "RETURN\n";};

params:
	TYPE IDENTIFIANT {
			tablesSymboles.addParam($IDENTIFIANT.text,$TYPE.text);
		} (
		',' TYPE IDENTIFIANT {
				tablesSymboles.addParam($IDENTIFIANT.text,$TYPE.text);
			}
	)*;

// lexer
TYPE: 'int' | 'double';
IDENTIFIANT: ('a' ..'z' | 'A' ..'Z' | '_') (
		'a' ..'z'
		| 'A' ..'Z'
		| '_'
		| '0' ..'9'
	)*;
RETURN: 'return';
NEWLINE: '\r'? '\n';
WS: (' ' | '\t')+ -> skip;
ENTIER: ('0' ..'9')+;
COMMENTAIRE: ('//' ~('\n')* | '/*' .*? '*/') -> skip;
UNMATCH: . -> skip;