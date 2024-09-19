grammar myCompiler;

options {
    language = Java;
}

@header {
    // import packages here.
    import java.util.HashMap;
    import java.util.ArrayList;
}

@members {
    boolean TRACEON = false;

    // Type information.
    public enum Type{
        ERR, BOOL, INT, FLOAT, CHAR, CONST_INT, CONST_FLOAT, STRING;
    }

    // This structure is used to record the information of a variable or a constant.
    class tVar {
	    int    varIndex; // temporary variable's index. Ex: t1, t2, ..., etc.
	    int    iValue;   // value of constant integer. Ex: 123.
	    float  fValue;   // value of constant floating point. Ex: 2.314.
        String sValue;   // value of string. Ex: abc.
    };

    class Info {
        Type theType;  // type information.
        tVar theVar;
	   
	    Info() {
            theType = Type.ERR;
		    theVar = new tVar();
	    }
    };

    class Print {
        int    varCnt;
        String printStr;

        Print() {
            varCnt = 0;
            printStr = new String();
        }
    }

	
    // ============================================
    // Create a symbol table.
	// ArrayList is easy to extend to add more info. into symbol table.
	//
	// The structure of symbol table:
	// <variable ID, [Type, [varIndex or iValue, or fValue]]>
	//    - type: the variable type   (please check "enum Type")
	//    - varIndex: the variable's index, ex: t1, t2, ...
	//    - iValue: value of integer constant.
	//    - fValue: value of floating-point constant.
    // ============================================

    HashMap<String, Info> symtab = new HashMap<String, Info>();

    // labelCount is used to represent temporary label.
    // The first index is 0.
    int labelCount = 0;
	
    // varCount is used to represent temporary variables.
    // The first index is 0.
    int varCount = 0;

    // Record all assembly instructions.
    List<String> TextCode = new ArrayList<String>();


    /*
     * Output prologue.
     */
    void prologue()
    {
        TextCode.add("; === prologue ====");
        TextCode.add("declare dso_local i32 @printf(i8*, ...)\n");
	    TextCode.add("define dso_local i32 @main()");
	    TextCode.add("{");
    }
    
	
    /*
     * Output epilogue.
     */
    void epilogue()
    {
        /* handle epilogue */
        TextCode.add("\n; === epilogue ===");
	    TextCode.add("ret i32 0");
        TextCode.add("}");
    }
    
    
    /* Generate a new label */
    String newLabel()
    {
        labelCount ++;
        return (new String("L")) + Integer.toString(labelCount);
    } 
    
    
    public List<String> getTextCode()
    {
        return TextCode;
    }
}

program
    : VOID MAIN '(' ')' {
        /* Output function prologue */
        prologue();
      }
      '{' 
        declarations
        statements
      '}' {
	    if (TRACEON)
	        System.out.println("VOID MAIN () {declarations statements}");

            /* output function epilogue */	  
            epilogue();
      };

declarations
    : type Identifier ';' declarations {
        if (TRACEON)
            System.out.println("declarations: type Identifier : declarations");

        if (symtab.containsKey($Identifier.text)) {
            // variable re-declared.
            System.out.println("Type Error: " + $Identifier.getLine() + ": Redeclared identifier.");
            System.exit(0);
        }
                 
        /* Add ID and its info into the symbol table. */
        Info the_entry = new Info();
        the_entry.theType = $type.attr_type;
        the_entry.theVar.varIndex = varCount;
        varCount ++;
        symtab.put($Identifier.text, the_entry);

        // issue the instruction.
        // Ex: \%a = alloca i32, align 4
        if ($type.attr_type == Type.INT) { 
            TextCode.add("\%t" + the_entry.theVar.varIndex + " = alloca i32, align 4");
        }
        else if ($type.attr_type == Type.FLOAT) {
			TextCode.add("\%t" + the_entry.theVar.varIndex + " = alloca float, align 4");
		}
      }
    | {
        if (TRACEON)
            System.out.println("declarations: ");
      };

type returns [Type attr_type]
    : INT { if (TRACEON) System.out.println("type: INT"); $attr_type=Type.INT; }
    | CHAR { if (TRACEON) System.out.println("type: CHAR"); $attr_type=Type.CHAR; }
    | FLOAT { if (TRACEON) System.out.println("type: FLOAT"); $attr_type=Type.FLOAT; };

statements
    : statement statements
    | ;

statement
    : assign_stmt ';'
    | if_stmt
    | func_no_return_stmt ';'
    | for_stmt;

for_stmt
    : FOR '(' assign_stmt ';'
              cond_expression ';'
              assign_stmt
          ')' block_stmt;		 
		 
if_stmt returns [String label] @init {label = new String();}
    : a=if_then_stmt {
        String L_then = $a.label;
        String L_end = newLabel();
        $label = L_end;

        TextCode.add("br label \%" + L_end);
        TextCode.add(L_then + ":");
      }
      (ELSE b=if_then_stmt {
        String L_next = $b.label;
        
        TextCode.add("br label \%" + $label);
        TextCode.add(L_next + ":");
      }
      )* if_else_stmt[label] {
        TextCode.add("br label \%" + $label);
        TextCode.add($label + ":");
      };

if_then_stmt returns [String label] @init {label = new String();}
    : IF '(' cond_expression ')' {
        String L_true = newLabel();
        String L_false = newLabel();
        label = L_false;

        TextCode.add("br i1 \%t" + $cond_expression.theInfo.theVar.varIndex + ", label \%" + L_true + ", label \%" + L_false);
        TextCode.add(L_true + ":");
      }
      block_stmt;

if_else_stmt[String label]
    : ELSE block_stmt
    | ;

block_stmt
    : '{' statements '}';

assign_stmt
    : Identifier '=' arith_expression {
        Info theRHS = $arith_expression.theInfo;
        Info theLHS = symtab.get($Identifier.text); 
    
        if ((theLHS.theType == Type.INT) && (theRHS.theType == Type.INT)) {		   
            // issue store insruction.
            // Ex: store i32 \%tx, i32* \%ty
            TextCode.add("store i32 \%t" + theRHS.theVar.varIndex + ", i32* \%t" + theLHS.theVar.varIndex);
        }
        else if ((theLHS.theType == Type.INT) && (theRHS.theType == Type.CONST_INT)) {
            // issue store insruction.
            // Ex: store i32 value, i32* \%ty
            TextCode.add("store i32 " + theRHS.theVar.iValue + ", i32* \%t" + theLHS.theVar.varIndex);				
        }

        if ((theLHS.theType == Type.FLOAT) && (theRHS.theType == Type.FLOAT)) {		   
            // issue store insruction.
            // Ex: store float \%tx, float* \%ty
            TextCode.add("store float \%t" + theRHS.theVar.varIndex + ", float* \%t" + theLHS.theVar.varIndex);
        }
        else if ((theLHS.theType == Type.FLOAT) && (theRHS.theType == Type.CONST_FLOAT)) {
            // issue store insruction.
            // Ex: store float value, float* \%ty
            String f_str = String.format("\%e", theRHS.theVar.fValue); 
            TextCode.add("store float " + f_str + ", float* \%t" + theLHS.theVar.varIndex);				
        }
      };
	   
func_no_return_stmt
    : Identifier '(' argument[0] ')'
    | 'printf' '(' argument[1] ')';

argument[int arg_case] returns [Print parameter] @init {parameter = new Print();}
    : a=arg {
        if (arg_case == 1) {
            int len = $a.theInfo.theVar.sValue.length() + 1;
            String s = $a.theInfo.theVar.sValue;
            if (s.endsWith("\\n")) len--;
            s = s.replace("\\n", "\\0A");

            TextCode.add(1 , "@t" + varCount + " = constant [" + len + " x i8] c\"" + s + "\\00\"");
            $parameter.varCnt = varCount;
            varCount ++;
        }
      }
      (',' b=arg {
        String ins = ", i32 \%t" + $b.theInfo.theVar.varIndex;
        parameter.printStr += ins;
      }
      )* {
        if (arg_case == 1) {
            int len = $a.theInfo.theVar.sValue.length() + 1;
            String s = $a.theInfo.theVar.sValue;
            if (s.endsWith("\\n")) len--;

            TextCode.add("call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([" + len + " x i8], [" + len +" x i8]* @t" + $parameter.varCnt + ", i32 0, i32 0)" + $parameter.printStr + ")");
            varCount ++;
        }
      };

arg returns [Info theInfo] @init {theInfo = new Info();}
    : arith_expression {$theInfo = $arith_expression.theInfo; }
    | STRING_LITERAL {
        String s = $STRING_LITERAL.text;
        $theInfo.theType = Type.STRING;
        $theInfo.theVar.sValue = s.substring(1, s.length() - 1);
    };
		   
cond_expression returns [Info theInfo] @init {theInfo = new Info();}
    : a=arith_expression (GT_OP b=arith_expression {
        // We need to do type checking first.
        // ...
        
        // code generation.
        if (($a.theInfo.theType == Type.INT) && ($b.theInfo.theType == Type.INT)) {
            TextCode.add("\%t" + varCount + " = icmp sgt i32 \%t" + $a.theInfo.theVar.varIndex + ", \%t" + $b.theInfo.theVar.varIndex);
            
            // Update cond_expression's theInfo.
            $theInfo.theType = Type.BOOL;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
        else if (($a.theInfo.theType == Type.INT) && ($b.theInfo.theType == Type.CONST_INT)) {
            TextCode.add("\%t" + varCount + " = icmp sgt i32 \%t" + $a.theInfo.theVar.varIndex + ", " + $b.theInfo.theVar.iValue);
           
            // Update cond_expression's theInfo.
            $theInfo.theType = Type.BOOL;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
        else if (($a.theInfo.theType == Type.CONST_INT) && ($b.theInfo.theType == Type.INT)) {
            TextCode.add("\%t" + varCount + " = icmp sgt i32 " + $a.theInfo.theVar.iValue + ", \%t" + $b.theInfo.theVar.varIndex);
            
            // Update cond_expression's theInfo.
            $theInfo.theType = Type.BOOL;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
        else if (($a.theInfo.theType == Type.CONST_INT) && ($b.theInfo.theType == Type.CONST_INT)) {
            TextCode.add("\%t" + varCount + " = icmp sgt i32 " + $a.theInfo.theVar.iValue + ", " + $b.theInfo.theVar.iValue);
            
            // Update cond_expression's theInfo.
            $theInfo.theType = Type.BOOL;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }

        if (($a.theInfo.theType == Type.FLOAT) && ($b.theInfo.theType == Type.FLOAT)) {
            TextCode.add("\%t" + varCount + " = fcmp ogt float \%t" + $a.theInfo.theVar.varIndex + ", \%t" + $b.theInfo.theVar.varIndex);
            
            // Update cond_expression's theInfo.
            $theInfo.theType = Type.BOOL;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
        else if (($a.theInfo.theType == Type.FLOAT) && ($b.theInfo.theType == Type.CONST_FLOAT)) {
            String f_str = String.format("\%e", $b.theInfo.theVar.fValue);
            TextCode.add("\%t" + varCount + " = fcmp ogt float \%t" + $a.theInfo.theVar.varIndex + ", " + f_str);
           
            // Update cond_expression's theInfo.
            $theInfo.theType = Type.BOOL;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
        else if (($a.theInfo.theType == Type.CONST_FLOAT) && ($b.theInfo.theType == Type.FLOAT)) {
            String f_str = String.format("\%e", $a.theInfo.theVar.fValue);
            TextCode.add("\%t" + varCount + " = fcmp ogt float " + f_str + ", \%t" + $b.theInfo.theVar.varIndex);
            
            // Update cond_expression's theInfo.
            $theInfo.theType = Type.BOOL;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
        else if (($a.theInfo.theType == Type.CONST_FLOAT) && ($b.theInfo.theType == Type.CONST_FLOAT)) {
            String f_str1 = String.format("\%e", $a.theInfo.theVar.fValue);
            String f_str2 = String.format("\%e", $b.theInfo.theVar.fValue);
            TextCode.add("\%t" + varCount + " = fcmp ogt float " + f_str1 + ", " + f_str2);
            
            // Update cond_expression's theInfo.
            $theInfo.theType = Type.BOOL;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
      }
      | GE_OP c=arith_expression {
        // We need to do type checking first.
        // ...
        
        // code generation.
        if (($a.theInfo.theType == Type.INT) && ($c.theInfo.theType == Type.INT)) {
            TextCode.add("\%t" + varCount + " = icmp sge i32 \%t" + $a.theInfo.theVar.varIndex + ", \%t" + $c.theInfo.theVar.varIndex);
            
            // Update cond_expression's theInfo.
            $theInfo.theType = Type.BOOL;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
        else if (($a.theInfo.theType == Type.INT) && ($c.theInfo.theType == Type.CONST_INT)) {
            TextCode.add("\%t" + varCount + " = icmp sge i32 \%t" + $a.theInfo.theVar.varIndex + ", " + $c.theInfo.theVar.iValue);
           
            // Update cond_expression's theInfo.
            $theInfo.theType = Type.BOOL;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
        else if (($a.theInfo.theType == Type.CONST_INT) && ($c.theInfo.theType == Type.INT)) {
            TextCode.add("\%t" + varCount + " = icmp sge i32 " + $a.theInfo.theVar.iValue + ", \%t" + $c.theInfo.theVar.varIndex);
            
            // Update cond_expression's theInfo.
            $theInfo.theType = Type.BOOL;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
        else if (($a.theInfo.theType == Type.CONST_INT) && ($c.theInfo.theType == Type.CONST_INT)) {
            TextCode.add("\%t" + varCount + " = icmp sge i32 " + $a.theInfo.theVar.iValue + ", " + $c.theInfo.theVar.iValue);
            
            // Update cond_expression's theInfo.
            $theInfo.theType = Type.BOOL;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }

        if (($a.theInfo.theType == Type.FLOAT) && ($c.theInfo.theType == Type.FLOAT)) {
            TextCode.add("\%t" + varCount + " = fcmp oge float \%t" + $a.theInfo.theVar.varIndex + ", \%t" + $c.theInfo.theVar.varIndex);
            
            // Update cond_expression's theInfo.
            $theInfo.theType = Type.BOOL;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
        else if (($a.theInfo.theType == Type.FLOAT) && ($c.theInfo.theType == Type.CONST_FLOAT)) {
            String f_str = String.format("\%e", $c.theInfo.theVar.fValue);
            TextCode.add("\%t" + varCount + " = fcmp oge float \%t" + $a.theInfo.theVar.varIndex + ", " + f_str);
           
            // Update cond_expression's theInfo.
            $theInfo.theType = Type.BOOL;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
        else if (($a.theInfo.theType == Type.CONST_FLOAT) && ($c.theInfo.theType == Type.FLOAT)) {
            String f_str = String.format("\%e", $a.theInfo.theVar.fValue);
            TextCode.add("\%t" + varCount + " = fcmp oge float " + f_str + ", \%t" + $c.theInfo.theVar.varIndex);
            
            // Update cond_expression's theInfo.
            $theInfo.theType = Type.BOOL;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
        else if (($a.theInfo.theType == Type.CONST_FLOAT) && ($c.theInfo.theType == Type.CONST_FLOAT)) {
            String f_str1 = String.format("\%e", $a.theInfo.theVar.fValue);
            String f_str2 = String.format("\%e", $c.theInfo.theVar.fValue);
            TextCode.add("\%t" + varCount + " = fcmp oge float " + f_str1 + ", " + f_str2);
            
            // Update cond_expression's theInfo.
            $theInfo.theType = Type.BOOL;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
      }
      | LT_OP d=arith_expression {
        // We need to do type checking first.
        // ...
        
        // code generation.
        if (($a.theInfo.theType == Type.INT) && ($d.theInfo.theType == Type.INT)) {
            TextCode.add("\%t" + varCount + " = icmp slt i32 \%t" + $a.theInfo.theVar.varIndex + ", \%t" + $d.theInfo.theVar.varIndex);
            
            // Update cond_expression's theInfo.
            $theInfo.theType = Type.BOOL;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
        else if (($a.theInfo.theType == Type.INT) && ($d.theInfo.theType == Type.CONST_INT)) {
            TextCode.add("\%t" + varCount + " = icmp slt i32 \%t" + $a.theInfo.theVar.varIndex + ", " + $d.theInfo.theVar.iValue);
           
            // Update cond_expression's theInfo.
            $theInfo.theType = Type.BOOL;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
        else if (($a.theInfo.theType == Type.CONST_INT) && ($d.theInfo.theType == Type.INT)) {
            TextCode.add("\%t" + varCount + " = icmp slt i32 " + $a.theInfo.theVar.iValue + ", \%t" + $d.theInfo.theVar.varIndex);
            
            // Update cond_expression's theInfo.
            $theInfo.theType = Type.BOOL;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
        else if (($a.theInfo.theType == Type.CONST_INT) && ($d.theInfo.theType == Type.CONST_INT)) {
            TextCode.add("\%t" + varCount + " = icmp slt i32 " + $a.theInfo.theVar.iValue + ", " + $d.theInfo.theVar.iValue);
            
            // Update cond_expression's theInfo.
            $theInfo.theType = Type.BOOL;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }

        if (($a.theInfo.theType == Type.FLOAT) && ($d.theInfo.theType == Type.FLOAT)) {
            TextCode.add("\%t" + varCount + " = fcmp olt float \%t" + $a.theInfo.theVar.varIndex + ", \%t" + $d.theInfo.theVar.varIndex);
            
            // Update cond_expression's theInfo.
            $theInfo.theType = Type.BOOL;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
        else if (($a.theInfo.theType == Type.FLOAT) && ($d.theInfo.theType == Type.CONST_FLOAT)) {
            String f_str = String.format("\%e", $d.theInfo.theVar.fValue);
            TextCode.add("\%t" + varCount + " = fcmp olt float \%t" + $a.theInfo.theVar.varIndex + ", " + f_str);
           
            // Update cond_expression's theInfo.
            $theInfo.theType = Type.BOOL;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
        else if (($a.theInfo.theType == Type.CONST_FLOAT) && ($d.theInfo.theType == Type.FLOAT)) {
            String f_str = String.format("\%e", $a.theInfo.theVar.fValue);
            TextCode.add("\%t" + varCount + " = fcmp olt float " + f_str + ", \%t" + $d.theInfo.theVar.varIndex);
            
            // Update cond_expression's theInfo.
            $theInfo.theType = Type.BOOL;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
        else if (($a.theInfo.theType == Type.CONST_FLOAT) && ($d.theInfo.theType == Type.CONST_FLOAT)) {
            String f_str1 = String.format("\%e", $a.theInfo.theVar.fValue);
            String f_str2 = String.format("\%e", $d.theInfo.theVar.fValue);
            TextCode.add("\%t" + varCount + " = fcmp olt float " + f_str1 + ", " + f_str2);
            
            // Update cond_expression's theInfo.
            $theInfo.theType = Type.BOOL;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
      }
      | LE_OP e=arith_expression {
        // We need to do type checking first.
        // ...
        
        // code generation.
        if (($a.theInfo.theType == Type.INT) && ($e.theInfo.theType == Type.INT)) {
            TextCode.add("\%t" + varCount + " = icmp sle i32 \%t" + $a.theInfo.theVar.varIndex + ", \%t" + $e.theInfo.theVar.varIndex);
            
            // Update cond_expression's theInfo.
            $theInfo.theType = Type.BOOL;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
        else if (($a.theInfo.theType == Type.INT) && ($e.theInfo.theType == Type.CONST_INT)) {
            TextCode.add("\%t" + varCount + " = icmp sle i32 \%t" + $a.theInfo.theVar.varIndex + ", " + $e.theInfo.theVar.iValue);
           
            // Update cond_expression's theInfo.
            $theInfo.theType = Type.BOOL;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
        else if (($a.theInfo.theType == Type.CONST_INT) && ($e.theInfo.theType == Type.INT)) {
            TextCode.add("\%t" + varCount + " = icmp sle i32 " + $a.theInfo.theVar.iValue + ", \%t" + $e.theInfo.theVar.varIndex);
            
            // Update cond_expression's theInfo.
            $theInfo.theType = Type.BOOL;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
        else if (($a.theInfo.theType == Type.CONST_INT) && ($e.theInfo.theType == Type.CONST_INT)) {
            TextCode.add("\%t" + varCount + " = icmp sle i32 " + $a.theInfo.theVar.iValue + ", " + $e.theInfo.theVar.iValue);
            
            // Update cond_expression's theInfo.
            $theInfo.theType = Type.BOOL;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }

        if (($a.theInfo.theType == Type.FLOAT) && ($e.theInfo.theType == Type.FLOAT)) {
            TextCode.add("\%t" + varCount + " = fcmp ole float \%t" + $a.theInfo.theVar.varIndex + ", \%t" + $e.theInfo.theVar.varIndex);
            
            // Update cond_expression's theInfo.
            $theInfo.theType = Type.BOOL;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
        else if (($a.theInfo.theType == Type.FLOAT) && ($e.theInfo.theType == Type.CONST_FLOAT)) {
            String f_str = String.format("\%e", $e.theInfo.theVar.fValue);
            TextCode.add("\%t" + varCount + " = fcmp ole float \%t" + $a.theInfo.theVar.varIndex + ", " + f_str);
           
            // Update cond_expression's theInfo.
            $theInfo.theType = Type.BOOL;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
        else if (($a.theInfo.theType == Type.CONST_FLOAT) && ($e.theInfo.theType == Type.FLOAT)) {
            String f_str = String.format("\%e", $a.theInfo.theVar.fValue);
            TextCode.add("\%t" + varCount + " = fcmp ole float " + f_str + ", \%t" + $e.theInfo.theVar.varIndex);
            
            // Update cond_expression's theInfo.
            $theInfo.theType = Type.BOOL;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
        else if (($a.theInfo.theType == Type.CONST_FLOAT) && ($e.theInfo.theType == Type.CONST_FLOAT)) {
            String f_str1 = String.format("\%e", $a.theInfo.theVar.fValue);
            String f_str2 = String.format("\%e", $e.theInfo.theVar.fValue);
            TextCode.add("\%t" + varCount + " = fcmp ole float " + f_str1 + ", " + f_str2);
            
            // Update cond_expression's theInfo.
            $theInfo.theType = Type.BOOL;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
      }
      | EQ_OP f=arith_expression {
        // We need to do type checking first.
        // ...
        
        // code generation.
        if (($a.theInfo.theType == Type.INT) && ($f.theInfo.theType == Type.INT)) {
            TextCode.add("\%t" + varCount + " = icmp eq i32 \%t" + $a.theInfo.theVar.varIndex + ", \%t" + $f.theInfo.theVar.varIndex);
            
            // Update cond_expression's theInfo.
            $theInfo.theType = Type.BOOL;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
        else if (($a.theInfo.theType == Type.INT) && ($f.theInfo.theType == Type.CONST_INT)) {
            TextCode.add("\%t" + varCount + " = icmp eq i32 \%t" + $a.theInfo.theVar.varIndex + ", " + $f.theInfo.theVar.iValue);
           
            // Update cond_expression's theInfo.
            $theInfo.theType = Type.BOOL;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
        else if (($a.theInfo.theType == Type.CONST_INT) && ($f.theInfo.theType == Type.INT)) {
            TextCode.add("\%t" + varCount + " = icmp eq i32 " + $a.theInfo.theVar.iValue + ", \%t" + $f.theInfo.theVar.varIndex);
            
            // Update cond_expression's theInfo.
            $theInfo.theType = Type.BOOL;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
        else if (($a.theInfo.theType == Type.CONST_INT) && ($f.theInfo.theType == Type.CONST_INT)) {
            TextCode.add("\%t" + varCount + " = icmp eq i32 " + $a.theInfo.theVar.iValue + ", " + $f.theInfo.theVar.iValue);
            
            // Update cond_expression's theInfo.
            $theInfo.theType = Type.BOOL;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }

        if (($a.theInfo.theType == Type.FLOAT) && ($f.theInfo.theType == Type.FLOAT)) {
            TextCode.add("\%t" + varCount + " = fcmp oeq float \%t" + $a.theInfo.theVar.varIndex + ", \%t" + $f.theInfo.theVar.varIndex);
            
            // Update cond_expression's theInfo.
            $theInfo.theType = Type.BOOL;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
        else if (($a.theInfo.theType == Type.FLOAT) && ($f.theInfo.theType == Type.CONST_FLOAT)) {
            String f_str = String.format("\%e", $f.theInfo.theVar.fValue);
            TextCode.add("\%t" + varCount + " = fcmp oeq float \%t" + $a.theInfo.theVar.varIndex + ", " + f_str);
           
            // Update cond_expression's theInfo.
            $theInfo.theType = Type.BOOL;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
        else if (($a.theInfo.theType == Type.CONST_FLOAT) && ($f.theInfo.theType == Type.FLOAT)) {
            String f_str = String.format("\%e", $a.theInfo.theVar.fValue);
            TextCode.add("\%t" + varCount + " = fcmp oeq float " + f_str + ", \%t" + $f.theInfo.theVar.varIndex);
            
            // Update cond_expression's theInfo.
            $theInfo.theType = Type.BOOL;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
        else if (($a.theInfo.theType == Type.CONST_FLOAT) && ($f.theInfo.theType == Type.CONST_FLOAT)) {
            String f_str1 = String.format("\%e", $a.theInfo.theVar.fValue);
            String f_str2 = String.format("\%e", $f.theInfo.theVar.fValue);
            TextCode.add("\%t" + varCount + " = fcmp oeq float " + f_str1 + ", " + f_str2);
            
            // Update cond_expression's theInfo.
            $theInfo.theType = Type.BOOL;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
      }
      | NE_OP g=arith_expression {
        // We need to do type checking first.
        // ...
        
        // code generation.
        if (($a.theInfo.theType == Type.INT) && ($g.theInfo.theType == Type.INT)) {
            TextCode.add("\%t" + varCount + " = icmp ne i32 \%t" + $a.theInfo.theVar.varIndex + ", \%t" + $g.theInfo.theVar.varIndex);
            
            // Update cond_expression's theInfo.
            $theInfo.theType = Type.BOOL;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
        else if (($a.theInfo.theType == Type.INT) && ($g.theInfo.theType == Type.CONST_INT)) {
            TextCode.add("\%t" + varCount + " = icmp ne i32 \%t" + $a.theInfo.theVar.varIndex + ", " + $g.theInfo.theVar.iValue);
           
            // Update cond_expression's theInfo.
            $theInfo.theType = Type.BOOL;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
        else if (($a.theInfo.theType == Type.CONST_INT) && ($g.theInfo.theType == Type.INT)) {
            TextCode.add("\%t" + varCount + " = icmp ne i32 " + $a.theInfo.theVar.iValue + ", \%t" + $g.theInfo.theVar.varIndex);
            
            // Update cond_expression's theInfo.
            $theInfo.theType = Type.BOOL;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
        else if (($a.theInfo.theType == Type.CONST_INT) && ($g.theInfo.theType == Type.CONST_INT)) {
            TextCode.add("\%t" + varCount + " = icmp ne i32 " + $a.theInfo.theVar.iValue + ", " + $g.theInfo.theVar.iValue);
            
            // Update cond_expression's theInfo.
            $theInfo.theType = Type.BOOL;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }

        if (($a.theInfo.theType == Type.FLOAT) && ($g.theInfo.theType == Type.FLOAT)) {
            TextCode.add("\%t" + varCount + " = fcmp one float \%t" + $a.theInfo.theVar.varIndex + ", \%t" + $g.theInfo.theVar.varIndex);
            
            // Update cond_expression's theInfo.
            $theInfo.theType = Type.BOOL;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
        else if (($a.theInfo.theType == Type.FLOAT) && ($g.theInfo.theType == Type.CONST_FLOAT)) {
            String f_str = String.format("\%e", $g.theInfo.theVar.fValue);
            TextCode.add("\%t" + varCount + " = fcmp one float \%t" + $a.theInfo.theVar.varIndex + ", " + f_str);
           
            // Update cond_expression's theInfo.
            $theInfo.theType = Type.BOOL;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
        else if (($a.theInfo.theType == Type.CONST_FLOAT) && ($g.theInfo.theType == Type.FLOAT)) {
            String f_str = String.format("\%e", $a.theInfo.theVar.fValue);
            TextCode.add("\%t" + varCount + " = fcmp one float " + f_str + ", \%t" + $g.theInfo.theVar.varIndex);
            
            // Update cond_expression's theInfo.
            $theInfo.theType = Type.BOOL;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
        else if (($a.theInfo.theType == Type.CONST_FLOAT) && ($g.theInfo.theType == Type.CONST_FLOAT)) {
            String f_str1 = String.format("\%e", $a.theInfo.theVar.fValue);
            String f_str2 = String.format("\%e", $g.theInfo.theVar.fValue);
            TextCode.add("\%t" + varCount + " = fcmp one float " + f_str1 + ", " + f_str2);
            
            // Update cond_expression's theInfo.
            $theInfo.theType = Type.BOOL;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
      }
      )*;
	   
arith_expression returns [Info theInfo] @init {theInfo = new Info();}
    : a=multExpr { $theInfo=$a.theInfo; }
      ( '+' b=multExpr {
        // We need to do type checking first.
        // ...
        
        // code generation.					   
        if (($a.theInfo.theType == Type.INT) && ($b.theInfo.theType == Type.INT)) {
            TextCode.add("\%t" + varCount + " = add nsw i32 \%t" + $a.theInfo.theVar.varIndex + ", \%t" + $b.theInfo.theVar.varIndex);
        
            // Update arith_expression's theInfo.
            $theInfo.theType = Type.INT;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
        else if (($a.theInfo.theType == Type.INT) && ($b.theInfo.theType == Type.CONST_INT)) {
            TextCode.add("\%t" + varCount + " = add nsw i32 \%t" + $a.theInfo.theVar.varIndex + ", " + $b.theInfo.theVar.iValue);
        
            // Update arith_expression's theInfo.
            $theInfo.theType = Type.INT;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
        else if (($a.theInfo.theType == Type.CONST_INT) && ($b.theInfo.theType == Type.INT)) {
            TextCode.add("\%t" + varCount + " = add nsw i32 " + $a.theInfo.theVar.iValue + ", \%t" + $b.theInfo.theVar.varIndex);
        
            // Update arith_expression's theInfo.
            $theInfo.theType = Type.INT;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
        else if (($a.theInfo.theType == Type.CONST_INT) && ($b.theInfo.theType == Type.CONST_INT)) {
            TextCode.add("\%t" + varCount + " = add nsw i32 " + $a.theInfo.theVar.iValue + ", " + $b.theInfo.theVar.iValue);
        
            // Update arith_expression's theInfo.
            $theInfo.theType = Type.INT;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }

        if (($a.theInfo.theType == Type.FLOAT) && ($b.theInfo.theType == Type.FLOAT)) {
            TextCode.add("\%t" + varCount + " = fadd float \%t" + $a.theInfo.theVar.varIndex + ", \%t" + $b.theInfo.theVar.varIndex);

            // Update arith_expression's theInfo.
            $theInfo.theType = Type.FLOAT;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
        else if (($a.theInfo.theType == Type.FLOAT) && ($b.theInfo.theType == Type.CONST_FLOAT)) {
            String f_str = String.format("\%e", $b.theInfo.theVar.fValue); 
            TextCode.add("\%t" + varCount + " = fadd float \%t" + $a.theInfo.theVar.varIndex + ", " + f_str);

            // Update arith_expression's theInfo.
            $theInfo.theType = Type.FLOAT;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
        else if (($a.theInfo.theType == Type.CONST_FLOAT) && ($b.theInfo.theType == Type.FLOAT)) {
            String f_str = String.format("\%e", $a.theInfo.theVar.fValue); 
            TextCode.add("\%t" + varCount + " = fadd float " + f_str + ", \%t" + $b.theInfo.theVar.varIndex);

            // Update arith_expression's theInfo.
            $theInfo.theType = Type.FLOAT;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
        else if (($a.theInfo.theType == Type.CONST_FLOAT) && ($b.theInfo.theType == Type.CONST_FLOAT)) {
            String f_str1 = String.format("\%e", $a.theInfo.theVar.fValue); 
            String f_str2 = String.format("\%e", $b.theInfo.theVar.fValue); 
            TextCode.add("\%t" + varCount + " = fadd float " + f_str1 + ", " + f_str2);

            // Update arith_expression's theInfo.
            $theInfo.theType = Type.FLOAT;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
      }
      | '-' c=multExpr {
        // We need to do type checking first.
        // ...
        
        // code generation.					   
        if (($a.theInfo.theType == Type.INT) && ($c.theInfo.theType == Type.INT)) {
            TextCode.add("\%t" + varCount + " = sub nsw i32 \%t" + $a.theInfo.theVar.varIndex + ", \%t" + $c.theInfo.theVar.varIndex);
        
            // Update arith_expression's theInfo.
            $theInfo.theType = Type.INT;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
        else if (($a.theInfo.theType == Type.INT) && ($c.theInfo.theType == Type.CONST_INT)) {
            TextCode.add("\%t" + varCount + " = sub nsw i32 \%t" + $a.theInfo.theVar.varIndex + ", " + $c.theInfo.theVar.iValue);
        
            // Update arith_expression's theInfo.
            $theInfo.theType = Type.INT;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
        else if (($a.theInfo.theType == Type.CONST_INT) && ($c.theInfo.theType == Type.INT)) {
            TextCode.add("\%t" + varCount + " = sub nsw i32 " + $a.theInfo.theVar.iValue + ", \%t" + $c.theInfo.theVar.varIndex);
        
            // Update arith_expression's theInfo.
            $theInfo.theType = Type.INT;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
        else if (($a.theInfo.theType == Type.CONST_INT) && ($c.theInfo.theType == Type.CONST_INT)) {
            TextCode.add("\%t" + varCount + " = sub nsw i32 " + $a.theInfo.theVar.iValue + ", " + $c.theInfo.theVar.iValue);
        
            // Update arith_expression's theInfo.
            $theInfo.theType = Type.INT;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }

        if (($a.theInfo.theType == Type.FLOAT) && ($c.theInfo.theType == Type.FLOAT)) {
            TextCode.add("\%t" + varCount + " = fsub float \%t" + $a.theInfo.theVar.varIndex + ", \%t" + $c.theInfo.theVar.varIndex);

            // Update arith_expression's theInfo.
            $theInfo.theType = Type.FLOAT;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
        else if (($a.theInfo.theType == Type.FLOAT) && ($c.theInfo.theType == Type.CONST_FLOAT)) {
            String f_str = String.format("\%e", $c.theInfo.theVar.fValue); 
            TextCode.add("\%t" + varCount + " = fsub float \%t" + $a.theInfo.theVar.varIndex + ", " + f_str);

            // Update arith_expression's theInfo.
            $theInfo.theType = Type.FLOAT;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
        else if (($a.theInfo.theType == Type.CONST_FLOAT) && ($c.theInfo.theType == Type.FLOAT)) {
            String f_str = String.format("\%e", $a.theInfo.theVar.fValue); 
            TextCode.add("\%t" + varCount + " = fsub float " + f_str + ", \%t" + $c.theInfo.theVar.varIndex);

            // Update arith_expression's theInfo.
            $theInfo.theType = Type.FLOAT;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
        else if (($a.theInfo.theType == Type.CONST_FLOAT) && ($c.theInfo.theType == Type.CONST_FLOAT)) {
            String f_str1 = String.format("\%e", $a.theInfo.theVar.fValue); 
            String f_str2 = String.format("\%e", $c.theInfo.theVar.fValue); 
            TextCode.add("\%t" + varCount + " = fsub float " + f_str1 + ", " + f_str2);

            // Update arith_expression's theInfo.
            $theInfo.theType = Type.FLOAT;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
      }
      )*;

multExpr returns [Info theInfo] @init {theInfo = new Info();}
    : a=signExpr { $theInfo=$a.theInfo; }
      ( '*' b=signExpr {
        // We need to do type checking first.
        // ...
        
        // code generation.					   
        if (($a.theInfo.theType == Type.INT) && ($b.theInfo.theType == Type.INT)) {
            TextCode.add("\%t" + varCount + " = mul nsw i32 \%t" + $a.theInfo.theVar.varIndex + ", \%t" + $b.theInfo.theVar.varIndex);
        
            // Update mult_expression's theInfo.
            $theInfo.theType = Type.INT;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
        else if (($a.theInfo.theType == Type.INT) && ($b.theInfo.theType == Type.CONST_INT)) {
            TextCode.add("\%t" + varCount + " = mul nsw i32 \%t" + $a.theInfo.theVar.varIndex + ", " + $b.theInfo.theVar.iValue);
        
            // Update mult_expression's theInfo.
            $theInfo.theType = Type.INT;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
        else if (($a.theInfo.theType == Type.CONST_INT) && ($b.theInfo.theType == Type.INT)) {
            TextCode.add("\%t" + varCount + " = mul nsw i32 " + $a.theInfo.theVar.iValue + ", \%t" + $b.theInfo.theVar.varIndex);
        
            // Update mult_expression's theInfo.
            $theInfo.theType = Type.INT;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
        else if (($a.theInfo.theType == Type.CONST_INT) && ($b.theInfo.theType == Type.CONST_INT)) {
            TextCode.add("\%t" + varCount + " = mul nsw i32 " + $a.theInfo.theVar.iValue + ", " + $b.theInfo.theVar.iValue);
        
            // Update mult_expression's theInfo.
            $theInfo.theType = Type.INT;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }

        if (($a.theInfo.theType == Type.FLOAT) && ($b.theInfo.theType == Type.FLOAT)) {
            TextCode.add("\%t" + varCount + " = fmul float \%t" + $a.theInfo.theVar.varIndex + ", \%t" + $b.theInfo.theVar.varIndex);

            // Update mult_expression's theInfo.
            $theInfo.theType = Type.FLOAT;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
        else if (($a.theInfo.theType == Type.FLOAT) && ($b.theInfo.theType == Type.CONST_FLOAT)) {
            String f_str = String.format("\%e", $b.theInfo.theVar.fValue);
            TextCode.add("\%t" + varCount + " = fmul float \%t" + $a.theInfo.theVar.varIndex + ", " + f_str);

            // Update mult_expression's theInfo.
            $theInfo.theType = Type.FLOAT;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
        else if (($a.theInfo.theType == Type.CONST_FLOAT) && ($b.theInfo.theType == Type.FLOAT)) {
            String f_str = String.format("\%e", $a.theInfo.theVar.fValue); 
            TextCode.add("\%t" + varCount + " = fmul float " + f_str + ", \%t" + $b.theInfo.theVar.varIndex);

            // Update mult_expression's theInfo.
            $theInfo.theType = Type.FLOAT;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
        else if (($a.theInfo.theType == Type.CONST_FLOAT) && ($b.theInfo.theType == Type.CONST_FLOAT)) {
            String f_str1 = String.format("\%e", $a.theInfo.theVar.fValue); 
            String f_str2 = String.format("\%e", $b.theInfo.theVar.fValue);
            TextCode.add("\%t" + varCount + " = fmul float " + f_str1 + ", " + f_str2);

            // Update mult_expression's theInfo.
            $theInfo.theType = Type.FLOAT;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
      }
      | '/' c=signExpr {
        // We need to do type checking first.
        // ...
        
        // code generation.					   
        if (($a.theInfo.theType == Type.INT) && ($c.theInfo.theType == Type.INT)) {
            TextCode.add("\%t" + varCount + " = sdiv i32 \%t" + $a.theInfo.theVar.varIndex + ", \%t" + $c.theInfo.theVar.varIndex);
        
            // Update mult_expression's theInfo.
            $theInfo.theType = Type.INT;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
        else if (($a.theInfo.theType == Type.INT) && ($c.theInfo.theType == Type.CONST_INT)) {
            TextCode.add("\%t" + varCount + " = sdiv i32 \%t" + $a.theInfo.theVar.varIndex + ", " + $c.theInfo.theVar.iValue);
        
            // Update mult_expression's theInfo.
            $theInfo.theType = Type.INT;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
        else if (($a.theInfo.theType == Type.CONST_INT) && ($c.theInfo.theType == Type.INT)) {
            TextCode.add("\%t" + varCount + " = sdiv i32 " + $a.theInfo.theVar.iValue + ", \%t" + $c.theInfo.theVar.varIndex);
        
            // Update mult_expression's theInfo.
            $theInfo.theType = Type.INT;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
        else if (($a.theInfo.theType == Type.CONST_INT) && ($c.theInfo.theType == Type.CONST_INT)) {
            TextCode.add("\%t" + varCount + " = sdiv i32 " + $a.theInfo.theVar.iValue + ", " + $c.theInfo.theVar.iValue);
        
            // Update mult_expression's theInfo.
            $theInfo.theType = Type.INT;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }

        if (($a.theInfo.theType == Type.FLOAT) && ($c.theInfo.theType == Type.FLOAT)) {
            TextCode.add("\%t" + varCount + " = fdiv float \%t" + $a.theInfo.theVar.varIndex + ", \%t" + $c.theInfo.theVar.varIndex);

            // Update mult_expression's theInfo.
            $theInfo.theType = Type.FLOAT;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
        else if (($a.theInfo.theType == Type.FLOAT) && ($c.theInfo.theType == Type.CONST_FLOAT)) {
            String f_str = String.format("\%e", $c.theInfo.theVar.fValue);
            TextCode.add("\%t" + varCount + " = fdiv float \%t" + $a.theInfo.theVar.varIndex + ", " + f_str);

            // Update mult_expression's theInfo.
            $theInfo.theType = Type.FLOAT;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
        else if (($a.theInfo.theType == Type.CONST_FLOAT) && ($c.theInfo.theType == Type.FLOAT)) {
            String f_str = String.format("\%e", $a.theInfo.theVar.fValue); 
            TextCode.add("\%t" + varCount + " = fdiv float " + f_str + ", \%t" + $c.theInfo.theVar.varIndex);

            // Update mult_expression's theInfo.
            $theInfo.theType = Type.FLOAT;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
        else if (($a.theInfo.theType == Type.CONST_FLOAT) && ($c.theInfo.theType == Type.CONST_FLOAT)) {
            String f_str1 = String.format("\%e", $a.theInfo.theVar.fValue); 
            String f_str2 = String.format("\%e", $c.theInfo.theVar.fValue);
            TextCode.add("\%t" + varCount + " = fdiv float " + f_str1 + ", " + f_str2);

            // Update mult_expression's theInfo.
            $theInfo.theType = Type.FLOAT;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
      }
      )*;

signExpr returns [Info theInfo] @init {theInfo = new Info();}
    : a=primaryExpr { $theInfo=$a.theInfo; } 
    | '-' b=primaryExpr {
        // We need to do type checking first.
        // ...
        
        // code generation.
        if ($b.theInfo.theType == Type.INT) {
            TextCode.add("\%t" + varCount + " = sub nsw i32 " + 0 + ", \%t" + $b.theInfo.theVar.varIndex);
            
            // Update sign_expression's theInfo.
            $theInfo.theType = Type.INT;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
        else if ($b.theInfo.theType == Type.CONST_INT) {
            TextCode.add("\%t" + varCount + " = sub nsw i32 " + 0 + ", " + $b.theInfo.theVar.iValue);
            
            // Update sign_expression's theInfo.
            $theInfo.theType = Type.INT;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }

        if ($b.theInfo.theType == Type.FLOAT) {
            TextCode.add("\%t" + varCount + " = fsub float " + 0.0 + ", \%t" + $b.theInfo.theVar.varIndex);
            
            // Update sign_expression's theInfo.
            $theInfo.theType = Type.FLOAT;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
        else if ($b.theInfo.theType == Type.CONST_FLOAT) {
            String f_str = String.format("\%e", $b.theInfo.theVar.fValue);
            TextCode.add("\%t" + varCount + " = fsub float " + 0.0 + ", " + f_str);
            
            // Update sign_expression's theInfo.
            $theInfo.theType = Type.FLOAT;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
      };
		  
primaryExpr returns [Info theInfo] @init {theInfo = new Info();}
    : Integer_constant {
        $theInfo.theType = Type.CONST_INT;
        $theInfo.theVar.iValue = Integer.parseInt($Integer_constant.text);
      }
    | Floating_point_constant {
        $theInfo.theType = Type.CONST_FLOAT;
        $theInfo.theVar.fValue = Float.parseFloat($Floating_point_constant.text);
      }
    | Identifier {
        // get type information from symtab.
        Type the_type = symtab.get($Identifier.text).theType;
        $theInfo.theType = the_type;

        // get variable index from symtab.
        int vIndex = symtab.get($Identifier.text).theVar.varIndex;
        
        switch (the_type) {
            case INT: 
                // get a new temporary variable and
                // load the variable into the temporary variable.
                
                // Ex: \%tx = load i32, i32* \%ty.
                TextCode.add("\%t" + varCount + " = load i32, i32* \%t" + vIndex);
                
                // Now, Identifier's value is at the temporary variable \%t[varCount].
                // Therefore, update it.
                $theInfo.theVar.varIndex = varCount;
                varCount ++;
                break;
            case FLOAT:
                // get a new temporary variable and
                // load the variable into the temporary variable.
                
                // Ex: \%tx = load float, float* \%ty.
                TextCode.add("\%t" + varCount + " = load float, float* \%t" + vIndex + ", align 4");
                
                // Now, Identifier's value is at the temporary variable \%t[varCount].
                // Therefore, update it.
                $theInfo.theVar.varIndex = varCount;
                varCount ++;
                break;
            case CHAR:
                break;
        }
      }
    | '&' Identifier
    | '(' arith_expression {$theInfo = $arith_expression.theInfo; } ')';

		   
/* description of the tokens */
FLOAT: 'float';
INT: 'int';
CHAR: 'char';
BOOL: 'boolean';

MAIN: 'main';
VOID: 'void';
IF: 'if';
ELSE: 'else';
FOR: 'for';

GT_OP : '>';
GE_OP : '>=';
LT_OP : '<';
LE_OP : '<=';
EQ_OP : '==';
NE_OP : '!=';

Identifier:('a'..'z'|'A'..'Z'|'_') ('a'..'z'|'A'..'Z'|'0'..'9'|'_')*;
Integer_constant:'0'..'9'+;
Floating_point_constant:'0'..'9'+ '.' '0'..'9'+;

STRING_LITERAL
    :  '"' ( EscapeSequence | ~('\\'|'"') )* '"'
    ;

WS:( ' ' | '\t' | '\r' | '\n' ) {$channel=HIDDEN;};
COMMENT:'/*' .* '*/' {$channel=HIDDEN;};


fragment
EscapeSequence
    :   '\\' ('b'|'t'|'n'|'f'|'r'|'\"'|'\''|'\\')
    ;
