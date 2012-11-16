globalvars = {}       # We will store the calculator's variables here
def lookup(map, name):
    #print "lookup", map, name
    for x, v in map:
        if x == name: return v
    if not globalvars.has_key(name):
        #print 'Undefined (defaulting to 0):', name
        pass
    return globalvars.get(name, 0)

%%
parser Calculator:
    ignore:    "[ \r\t\n]+"
    ignore:    "\\/\\/.*?\r?\n"
    token BEGIN: "begin"
    token END: "end"
    token FUNCTION: "function"
    token ENDTOKEN: "$"
    token NUM: "[0-9]+[\\'dhb]*[a-fA-F0-9]*"
    token VAR: "[a-zA-Z_][a-zA-Z0-9_]*"
    token STR:   r'"([^\\"]+|\\.)*"'
    token LPAREN: "\\(" token RPAREN: "\\)"
    token LBRACKET: "\\[" token RBRACKET: "\\]"
    token LBRACE: "{" token RBRACE: "}"
    token HASH: "#"
    token DOT: r"[\\.]"
    token COMMA: ','
    token COMMA2: ","
    token AMPER: '&' token AMPERAMPER: "&&"
    token COLON: ':' token COLONCOLON: "::" token SEMICOLON: ';'
    token QUESTION: "\\?"
    token CARET: "\\^"
    token LESS: "<" token LESSLESS: "<<" token LEQ: "<=" token LARROW: "<-"
    token GEQ: ">="
    token EQUAL: "=" token EQEQ: "=="
    token STAR: "[*]"

    # Each line can either be an expression or an assignment statement
    rule gggoal:   expr<<[]>> ENDTOKEN            {{ return expr }}
               | "set" VAR expr<<[]>> ENDTOKEN  {{ globalvars[VAR] = expr }}
                                           {{ return expr }}

    # An expression is the sum and difference of factors
    rule expr<<V>>:   factor<<V>>         {{ n = factor }}
                     ( "[+]" factor<<V>>  {{ n = n+factor }}
                     |  "-"  factor<<V>>  {{ n = n-factor }}
                     )*                   {{ return n }}

    # A factor is the product and division of terms
    rule factor<<V>>: nterm<<V>>           {{ v = nterm }}
                     ( STAR nterm<<V>>    {{ v = v*nterm }}
                     |  "/"  nterm<<V>>
#    {{ v = v/nterm }}
                     |  CARET  nterm<<V>>
                     |  LESS  nterm<<V>>
                     |  ">"  nterm<<V>>
                     |  GEQ  nterm<<V>>
                     |  LESSLESS  nterm<<V>>
                     |  LEQ  nterm<<V>>
                     |  ">>"  nterm<<V>>
                     |  EQEQ  nterm<<V>>
                     |  "!="  nterm<<V>>
                     |  AMPER  nterm<<V>>
                     |  AMPERAMPER  nterm<<V>>
                     |  "||"  nterm<<V>>
                     |  "%"  nterm<<V>>
                     |  QUESTION nterm<<V>> COLON  nterm<<V>>
                     )*                   {{ return v }}

    rule fieldname: VAR

    rule typefieldname: VAR

    rule nterm<<V>>:
        [ ("!" | "~" | "-" ) ] term<<V>> {{ return term }}

    rule call_params<<V>>:
        LPAREN [ expr<<V>> [VAR]( COMMA expr<<V>> [VAR])* ] RPAREN

    # A term is a number, variable, or an expression surrounded by parentheses
    rule term_partial<<V>>:
               NUM       {{ return int(10) }}
               | "tagged" ("Valid" VAR | "Invalid")
               | VAR ( COLONCOLON VAR )*
                    ( call_params<<V>>
                    | LBRACE typefieldname COLON expr<<V>> ( COMMA typefieldname COLON expr<<V>> )* RBRACE
                    | HASH
                    )*
                    {{ return lookup(V, VAR) }}
               | Type_item
               | STR
               | LPAREN expr<<V>> RPAREN 
#( DOT fieldname )*
                    #[ LBRACKET expr<<V>> [ COLON expr<<V>> ] RBRACKET ]
                    {{ return expr }}
               | LBRACE expr<<V>> ( COMMA expr<<V>> )* RBRACE
               | QUESTION

    rule term<<V>>:
        term_partial<<V>>
        ( LBRACKET expr<<V>> [ COLON expr<<V>> ] RBRACKET
        | DOT fieldname [ call_params<<V>> ]
        )*
        {{ return term_partial }}

               #| "let" VAR EQUAL expr<<V>>  {{ V = [(VAR, expr)] + V }}
               #  "in" expr<<V>>           {{ return expr }}

###########jca

    rule interface_method: VAR

    rule Package_name: VAR

    rule rule_names: VAR

    rule list_rule_names: "LRN"

    rule Return_type: VAR

    rule Type: VAR

    rule action_name: VAR

    rule c_function_name: VAR

    rule clock_name: VAR

    rule enable: VAR

    rule enable_port: VAR

    rule expression: expr<<[]>>

    rule function_name: VAR
        | '\\\\\\+'
        | '\\\\\\-'
        | '\\\\\\*'

    rule ifc_name: VAR

    rule importBVI_statements: "IMPBVI"

    rule input_ports: VAR

    rule interface_method_definitions: "IFCMETHDEF"

    rule module_instantiations: "MODINSTANC"

    rule module_name: VAR

    rule module_statements: "MODSTA"

    rule port_name1: VAR

    rule port_name2: VAR

    rule provisos:
        [ "provisos" LPAREN expression (COMMA expression )* RPAREN ]
        SEMICOLON

    rule ready_port: VAR

    rule return_statement:
        "return" expression SEMICOLON

    rule rule_name: VAR

    rule rules_name: VAR

    rule verilog_module_name: VAR

    rule attribute:
        "synthesize"
        | "RST_N"  EQUAL STR
        | "CLK"  EQUAL STR
        | "always_ready" [ EQUAL interface_method ]
        | "always_enabled" [ EQUAL interface_method ]
        | "descending" "urgency" EQUAL LBRACE rule_names RBRACE
        | "preempts" [ EQUAL ] LBRACE rule_names COMMA  LPAREN list_rule_names RPAREN RBRACE
        | "doc" EQUAL STR
        | "ready" EQUAL STR
        | "enable" EQUAL STR
        | "result" EQUAL STR
        | "prefix" EQUAL STR
        | "port"  EQUAL STR
        | "noinline"
        | "fire_when_enabled"
        | "no_implicit_conditions"

    rule attribute_statement:
         "\\([*]" attribute [ EQUAL expression ] "[*]\\)"

    rule Type_named_sub:
        VAR [ HASH LPAREN expression (COMMA expression )* RPAREN ]

    rule Type_item_or_name:
        Type_item
        | Type_named_sub

    rule Ifc_type: Type_item_or_name

    rule import_statements:
        "import"
        ( "BDPI" [ c_function_name  EQUAL ] FUNCTION Return_type
            function_name argument_list provisos
        | "BVI" [verilog_module_name]  EQUAL
            "module" [ Type ] module_name [ HASH  argument_list ]
            LPAREN Ifc_type ifc_name RPAREN  provisos
            module_statements
            importBVI_statements
            "endmodule" [ COLON  module_name ]
        | Package_name  COLONCOLON  STAR SEMICOLON
        )

    rule variable_assignment:
        term<<[]>>
        ( EQUAL | LEQ ) expression
        #VAR [ LBRACKET expression [ COLON expression ] RBRACKET ]
        #(EQUAL | LEQ) expression

    rule variable_declaration:
        Type_item_or_name VAR [ ( EQUAL | LARROW ) expression ] SEMICOLON

    rule assign_value:
        ( case_statement
        | seq_statement
        | expression
        )

    rule declared_item:
        term<<[]>> [ ( EQUAL | LARROW ) assign_value ]

    rule variable_declaration_or_call:
        ( Type_item declared_item ( COMMA declared_item )*
        | term<<[]>> [   ( declared_item ( COMMA declared_item )*
                         | ( EQUAL | LEQ ) assign_value
                         )
                     ]
        ) SEMICOLON

    rule for_decl_item:
        Type_item_or_name [ VAR ] ( EQUAL | LEQ ) expression

    rule for_statement:
        "for" LPAREN
            for_decl_item (COMMA for_decl_item)* SEMICOLON
            expression SEMICOLON
            variable_assignment ( COMMA variable_assignment )* RPAREN
        ( group_statements
        | seq_statement
        | variable_declaration_or_call
        )

    rule helper_statements:
        ( "\\$display" | "\\$write" | "\\$fopen" | "\\$fdisplay"
        | "\\$fwrite" | "\\$fgetc" | "\\$fflush" | "\\$fclose" | "\\$ungetc"
        | "\\$finish" | "\\$stop" | "\\$dumpon" | "\\$dumpoff" | "\\$dumpvars"
        | "\\$test\\$plusargs" | "\\$time" | "\\$stime"
        )
        [ LPAREN expression (COMMA expression)* RPAREN ]
        SEMICOLON

    rule method_body_statements:
        ( let_statement
        | for_statement
        | return_statement
        | function_statement
        | if_statement
        | case_statement
        | helper_statements
        | seq_statement
        | group_statements
        | variable_declaration_or_call
        )+

    rule group_statements:
        BEGIN
        method_body_statements
        END

    rule seq_statement:
        "seq"
        method_body_statements
        "endseq"

    rule method_name: VAR

    rule method_predicate: expression

    rule output_port: "OUTPUTPORRRT"

    rule method_declarations:
        "method" 
        ( "Action" method_name  argument_list
            [ "if"  LPAREN method_predicate RPAREN ] SEMICOLON
            [ method_body_statements
              "endmethod" [ COLON method_name]
            ]
        | "ActionValue"
            [ HASH LPAREN expression RPAREN ]
            method_name argument_list
            [ "if"  LPAREN method_predicate RPAREN ] SEMICOLON
            [ method_body_statements
              #return_statement
              "endmethod" [ COLON method_name]
            ]
        | ("Type" | Type_item_basic | Type_named_sub) method_name  [ argument_list ]
            [ "if"  LPAREN method_predicate RPAREN ] SEMICOLON
            [ method_body_statements
              "endmethod" [ COLON method_name]
            ]
        | [ output_port ] method_name
            LPAREN LBRACE input_ports RBRACE RPAREN
            [ enable enable_port ]
            [ "ready" ready_port ] [ "clocked_by" clock_name ]
            [ "reset_by" clock_name] SEMICOLON
        )

    rule subinterface_declarations:
        "interface" ifc_name VAR EQUAL expression SEMICOLON

    rule interface_arg:
        ["numeric"] "type" Type_name

    rule interface_declarations:
        "interface" ifc_name [VAR]
        ( SEMICOLON
            ( method_declarations
            | attribute_statement
            | subinterface_declarations
            )*
            "endinterface" [ COLON ifc_name ]
        | HASH LPAREN interface_arg ( COMMA interface_arg)* RPAREN SEMICOLON
            ( method_declarations
            | attribute_statement
            | subinterface_declarations
            )*
            "endinterface" [ COLON ifc_name ]
        )

    rule match_arg:
        DOT term<<[]>>

    rule match_statement:
        "match"
        LBRACE match_arg (COMMA match_arg)* RBRACE EQUAL expression SEMICOLON

    rule module_declarations:
        "module" [ LBRACKET "Module" RBRACKET ] module_name [ HASH  argument_list ]
        LPAREN [ Ifc_type ] [ ifc_name ] [ STAR ] RPAREN provisos
        ( module_instantiations
        | rule_statements
        | interface_declarations
        | interface_method_definitions
        | match_statement
        | return_statement
        | function_statement
        | rule_statement
        | method_declarations
        | for_statement
        | let_statement
        | variable_declaration_or_call
        )*
        "endmodule" [ COLON module_name]

    rule package_statement:
        "package" Package_name SEMICOLON
        ( typedef_statements
        | import_statements
        | interface_declarations
        | module_declarations
        )*
        "endpackage" [ COLON  Package_name]

#    Ifc_type ifc_name LARROW module_name argument_list SEMICOLON
#    Ifc_type ifc_name LARROW module_name argument_list COMMA2
#        "clocked_by" clock_name COMMA2
#        "reset_by" reset_name ] RPAREN SEMICOLON

    rule rule_statements: "RULEST"

    rule tagged_match_arg:
        VAR COLON DOT VAR
#term<<[]>>

    rule rule_predicate:
        LPAREN
        expression
        [ "matches" "tagged" VAR
            ( LBRACE tagged_match_arg (COMMA tagged_match_arg)* RBRACE
            | DOT VAR
            )
        ]
        RPAREN

    rule rule_statement:
        "rule" rule_name [rule_predicate] SEMICOLON
        action_statements
        "endrule" [ COLON  rule_name ]

    rule rules_statement:
        "rules" [ COLON  rules_name]
        rule_statements
        (variable_declaration_or_call SEMICOLON)*
        "endrules" [ COLON  rules_name]

    rule action_statement:
        "action" [ COLON  action_name] [ SEMICOLON ]
        action_statements
        "endaction" [ COLON action_name]

    rule Type_name: VAR

    rule Type_item_basic:
        ( "Bit#" | "Int#" | "Uint#" | "ComplexF#" | "Reg#" | "FIFO#" | "Maybe#" )
           LPAREN expression RPAREN
        | ("Vector#" | "Tuple2#" | "FixedPoint#")
           LPAREN expression (COMMA expression)* RPAREN
        | "Integer" | "Bool" | "String"
        | "Nat"

    rule Type_item:
        Type_item_basic
        | "Action" | "ActionValue#" LPAREN VAR RPAREN

#    "type identifier LARROW expression SEMICOLON
#    identifier LARROW expression SEMICOLON

    rule case_statement:
        "case" LPAREN expression RPAREN
        ((VAR | NUM) COLON 
            ( return_statement
            | case_statement
            | group_statements
            | expression SEMICOLON
            )
        )*
        "endcase"

    rule let_statement:
        "let"
        ( VAR
        | LBRACE VAR (COMMA VAR)* RBRACE
        )
        ( EQUAL | LARROW )
        ( case_statement
        | expression
        ) SEMICOLON

#    register_name LEQ expression SEMICOLON

    rule Typeclass: VAR

    rule type_variable: VAR

    rule Elements: term<<[]>> [EQUAL expression]

    rule Member: VAR

    rule TypeClass:
        "Eq" | "Bits"

    rule deriving_clause:
        "deriving"  LPAREN Typeclass ( COMMA TypeClass )* RPAREN

    rule struct_arg:
        [ "numeric" ] "type" type_variable

    rule typedef_statements:
        "typedef" 
        ( ( "type" | Type_item_or_name | NUM ) Type_name
            [ HASH LPAREN struct_arg (COMMA struct_arg)* RPAREN ] SEMICOLON
        | "enum" LBRACE Elements ( COMMA Elements )* RBRACE Type_name
            [ deriving_clause ] SEMICOLON
        | "struct" LBRACE
            ( Type_item_or_name VAR SEMICOLON )* RBRACE
            Type_name [ HASH LPAREN struct_arg (COMMA struct_arg)* RPAREN ]
                [ deriving_clause ] SEMICOLON
        | "union" "tagged"
            LBRACE "type" Member SEMICOLON RBRACE
            Type_name [ HASH [ "numeric" ] "type" type_variable ] SEMICOLON
        )

#    "Type" variable_name  EQUAL "Type" LBRACE member COLON expression RBRACE
#        "Coord" c1  EQUAL Coord{x COLON 1 COMMA2 y COLON foo}SEMICOLON

#    "Type" variable_name  EQUAL Member expression SEMICOLON
#    "tagged" "Member" [ pattern ]
#    "tagged" "Type" [ member COLON pattern ]
#    "tagged" { pattern COMMA2 pattern }
#    "case"  LPAREN f LPAREN a RPAREN RPAREN  matches
#        "tagged" "Valid" .x  COLON  return x SEMICOLON
#        "tagged" "Invalid"  COLON  return 0 SEMICOLON
#    "endcase"
#    if  LPAREN x matches tagged Valid .n &&& n > 5 ... RPAREN
#    "match" pattern  EQUAL expression SEMICOLON

    rule argument_item:
        ( FUNCTION 
            ( "Action" VAR
            | VAR [VAR]
            )
            LPAREN argument_item (COMMA argument_item)* RPAREN
        | Type_item_or_name [ VAR ]
        )

    rule argument_list:
        LPAREN [ argument_item ( COMMA argument_item)* ] RPAREN

    rule variable_assignment_or_call:
        term<<[]>>
        ( EQUAL expression SEMICOLON
        | LEQ expression SEMICOLON
        | SEMICOLON
        )

    rule if_item:
        ( group_statements
        | if_statement
        | seq_statement
        | variable_assignment_or_call
        )

    rule if_statement:
        "if" LPAREN expression RPAREN
           if_item [ "else" if_item ]

    rule action_statements:
        ( let_statement
        | for_statement
        | if_statement
        | variable_declaration_or_call
        | group_statements
        )*

    rule function_body_statements:
        let_statement
        | function_statement
        | action_statement
        | for_statement
        | match_statement
        | case_statement
        | variable_declaration_or_call

    rule function_statement:
        FUNCTION Type_item_or_name [function_name]  argument_list
        ( EQUAL expression SEMICOLON
        | provisos
            ( return_statement
            | function_body_statements
            )*
            "endfunction" [ COLON  function_name]
        )


#    "parameter" parameter_name  EQUAL expression SEMICOLON
#    "port" port_name  EQUAL expression SEMICOLON
#    "default_clock" clock_name
#        [ LPAREN port_name COMMA2 port_name RPAREN ] [ EQUAL expression ] SEMICOLON
#    "input_clock" clock_name [ LPAREN port_name COMMA2
#        port_name RPAREN ]  EQUAL expression SEMICOLON
#    "output_clock" clock_name
#         LPAREN port_name [ COMMA2 port_name ] RPAREN SEMICOLON
#    "no_reset" SEMICOLON
#    "default_reset" clock_name  LPAREN [ port_name ] RPAREN  [ EQUAL expression] SEMICOLON
#    "input_reset" clock_name  LPAREN [ port_name ] RPAREN   EQUAL expression SEMICOLON
#    "output_reset" clock_name  LPAREN port_name RPAREN SEMICOLON
#    "ancestor"  LPAREN clock1 COMMA2 clock2 RPAREN SEMICOLON
#    "same_family"  LPAREN clock1 COMMA2 clock2 RPAREN SEMICOLON

    rule schedule_statement:
         "schedule"  LPAREN ( method_name ) RPAREN  ( "CF" | "SB" | "SBR" | "C" )
         LPAREN ( method_name ) RPAREN SEMICOLON

    rule path_statement:
        "path" LPAREN port_name1 COMMA2 port_name2 RPAREN  SEMICOLON

    rule instance_arg:
        Type_item_or_name

    rule instance_statement:
        "instance" Type_name HASH LPAREN instance_arg ( COMMA instance_arg )* RPAREN
            provisos
        (function_statement)*
        "endinstance"

    rule top_level_statements:
        typedef_statements
        | function_statement
        | instance_statement
        | import_statements
        | interface_declarations
        | attribute_statement
        | method_declarations
        | module_declarations
        | let_statement
        | package_statement

    rule goal:
        (top_level_statements)* ENDTOKEN

%%
############jca

if __name__=='__main__':
    #print 'args', sys.argv
    #print 'args1', sys.argv[1]
    s = open(sys.argv[1]).read()
    s1 = parse('goal', s)
    #print 'Output:', s1
    #print 'Bye.'

