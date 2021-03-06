parser grammar BNGGrammar_ReactionRules;

options {
  language = Java;
  output = template;
 
}
@members{
 public void getParentTemplate(){
 
  this.setTemplateLib(gParent.getTemplateLib());
 }
}

reaction_rules_block[List reactionRules]
scope{
  int reactionCounter;
  
 
}
@init{
getParentTemplate();
  $reaction_rules_block::reactionCounter = 1;
  gParent.paraphrases.push("in reaction rules block"); 
}
@after{
  gParent.paraphrases.pop();
}
        : BEGIN REACTION RULES (reaction_rule_def[$reaction_rules_block::reactionCounter] 
                  {
                  reactionRules.add($reaction_rule_def.st);
                  StringTemplate sInvert = null;
                  if($reaction_rule_def.numReactions == 2)
                    sInvert = InvertBidirectional.invert($reaction_rule_def.st.toString(),$reaction_rules_block::reactionCounter+1);
                  reactionRules.add(sInvert);
                  $reaction_rules_block::reactionCounter+= $reaction_rule_def.numReactions;
                  
                  })* END REACTION RULES
        ;



reactionLabel returns [String label]
@init{
  $label = "";
  }
:
(STRING {$label += $STRING.text + " ";}
          |INT{$label += $INT.text + " ";})+
        COLON 

;
reaction_rule_def[int reactionCounter] returns [int numReactions, double secondRate]
scope{
List patternsReactants;
List patternsProducts;
List<Double> rateList;
ReactionAction reactionAction;
String name;
 String text;
}
@init{
  $reaction_rule_def::patternsReactants = new ArrayList();
  $reaction_rule_def::patternsProducts = new ArrayList();
  $reaction_rule_def::rateList = new ArrayList<Double>();
  $reaction_rule_def::reactionAction = new ReactionAction();
  $reaction_rule_def::name = "Rule" + reactionCounter;
  $reaction_rule_def::text = "";
}
        :  ((match_attribute)? (
          
	        l1=reactionLabel{$reaction_rule_def::text += $l1.label + ":"; 
	                         $reaction_rule_def::name = $l1.label;
	                  })?)
        
        
      
        reaction_def[$reaction_rule_def::patternsReactants,$reaction_rule_def::patternsProducts,"RR" + reactionCounter]{
          $reaction_rule_def::reactionAction.execute();
          if($reaction_def.bidirectional)
              $numReactions = 2;
           else
              $numReactions = 1;
           
          $reaction_rule_def::text += $reaction_def.text;
        
        }
        {
        //Whitespaces are normally skipped but they are still in the stream. In this case if this rule is valid
        //a valid WS would be located on the previous token
        ((ChangeableChannelTokenStream)input).seek(((ChangeableChannelTokenStream)input).index()-1)  ;
        } 
        WS
        bi=rate_list[$reaction_rule_def::rateList] {$secondRate=$reaction_rule_def::rateList.get(1);$reaction_rule_def::text += " " + $rate_list.text;}
        (modif_command)* (DELETEMOLECULES)? (MOVECONNECTED)?
        
        {
          $reaction_rule_def::text = $reaction_rule_def::text.replaceAll("<","&lt;");
          $reaction_rule_def::text = $reaction_rule_def::text.replaceAll(">","&gt;");
        }

        -> reaction_block(id={"RR" + reactionCounter},reactant={$reaction_rule_def::patternsReactants},
        product={$reaction_rule_def::patternsProducts},name={$reaction_rule_def::name},
        rate={$reaction_rule_def::rateList.get(0)},bidirectional={bi},leftMap={$reaction_rule_def::reactionAction.getLeft()},
        rightMap={$reaction_rule_def::reactionAction.getRight()},operations={$reaction_rule_def::reactionAction.getOperations()},
        operator1={$reaction_rule_def::reactionAction.getOperator1()},operator2={$reaction_rule_def::reactionAction.getOperator2()},expression={$reaction_rule_def::text})
        ;
match_attribute
        : LBRACKET MATCHONCE RBRACKET
        ;
        
reaction_def  [List patternsReactants,List patternsProducts,String upperID] returns [boolean bidirectional,Map<String,List<ReactionRegister>> reactionStack,
Map<String,List<ReactionRegister>> productStack]
scope{
int reactantPatternCounter;
//Map<String,List<ReactionRegister>> reactionStack;
//Map<String,List<ReactionRegister>> productStack;

}
@init{
  $reaction_def::reactantPatternCounter =1;
  $reactionStack = new HashMap<String,List<ReactionRegister>>();
  $productStack = new HashMap<String,List<ReactionRegister>>();
  
}

:
 s1=rule_species_def[upperID+"_RP" + $reaction_def::reactantPatternCounter,$reaction_rule_def::reactionAction] 
           //Add as many chemicals as the stoichiometry tells us. We also have to modify some of the internal tags
           //(more specifically all the RP's and PP's
           {
            int counter = $reaction_def::reactantPatternCounter;
            for(int i=0;i<s1.stoichiometry;i++){
               StringTemplate correctedString = GenericMethods.replace(s1.st,"RP" + counter,"RP" + $reaction_def::reactantPatternCounter);
               patternsReactants.add(correctedString);
               ReactionRegister.mergeMaps($s1.map,$reactionStack);
              $reaction_def::reactantPatternCounter++;
            } 
           } 
  (PLUS s2=rule_species_def[upperID+"_RP"+ $reaction_def::reactantPatternCounter,$reaction_rule_def::reactionAction]
            {
            counter = $reaction_def::reactantPatternCounter;
            for(int i=0;i<s2.stoichiometry;i++){ 
              StringTemplate correctedString = GenericMethods.replace(s2.st,"RP" + counter,"RP" + $reaction_def::reactantPatternCounter);
               patternsReactants.add(correctedString);
               ReactionRegister.mergeMaps($s2.map,$reactionStack);
              $reaction_def::reactantPatternCounter++;
            }
            })* 
        (UNI_REACTION_SIGN {$bidirectional = false;}| BI_REACTION_SIGN {$bidirectional = true;}) 
  (s3=rule_species_def[upperID+"_PP"+ 1,$reaction_rule_def::reactionAction] 
        {
        $reaction_def::reactantPatternCounter =1;
          counter = $reaction_def::reactantPatternCounter;
          for(int i=0;i<s3.stoichiometry;i++){ 
            StringTemplate correctedString = GenericMethods.replace(s3.st,"PP" + counter,"PP" + $reaction_def::reactantPatternCounter);
            patternsProducts.add(correctedString);
            ReactionRegister.mergeMaps($s3.map,$productStack);
            $reaction_def::reactantPatternCounter++;
        }
        }) 
        (PLUS s4=rule_species_def[upperID+"_PP"+ $reaction_def::reactantPatternCounter,$reaction_rule_def::reactionAction] 
        {
            counter = $reaction_def::reactantPatternCounter;
           for(int i=0;i<s4.stoichiometry;i++){ 
               StringTemplate correctedString = GenericMethods.replace(s4.st,"PP" + counter,"PP" + $reaction_def::reactantPatternCounter);
               patternsProducts.add(correctedString);
              $reaction_def::reactantPatternCounter++;
              ReactionRegister.mergeMaps($s4.map,$productStack);
           }
        })* 
        
 ;
        
rule_species_def[String upperID,ReactionAction reactionAction] returns [int stoichiometry,Map <String,List<ReactionRegister>> map]
scope{
List reactants;
BondList bonds;
}
@init{
  $rule_species_def::reactants = new ArrayList();
  $rule_species_def::bonds = new BondList();
  $stoichiometry = 1;
}
: 
(
(i1=INT {$stoichiometry = Integer.parseInt($i1.text);} TIMES)? 
 (s1=(species_def[$rule_species_def::reactants,$rule_species_def::bonds,upperID] {
       reactionAction.addMolecule(upperID,$species_def.text,$rule_species_def::bonds);
       $map = $species_def.listOfMolecules;
  })) 
  | i2=INT {
        $map  = new HashMap<String,List<ReactionRegister>>();
        if(!$i2.text.equals("0")){
        throw new RecognitionException();
        }
      }
    )
    ->rule_seed_species_block(id={upperID},molecules={$rule_species_def::reactants},firstBonds={$rule_species_def::bonds.getLeft()},
      secondBonds={$rule_species_def::bonds.getRight()})
    ;


rate_list[List<Double> rateList]
        : e1=expression[gParent.memory] {rateList.add(e1.value);rateList.add(0.0);}(COMMA e2=expression[gParent.memory] {rateList.set(1,e2.value);})?
        ;
modif_command
        : include_command
        | exclude_command
        ;
//are the patterns same in include and exclude?
include_command
        :  (INCLUDE_REACTANTS
          | INCLUDE_PRODUCTS)
          LPAREN INT COMMA pattern (COMMA pattern)* RPAREN
        ;
exclude_command
        : (EXCLUDE_REACTANTS
        | EXCLUDE_PRODUCTS)
        LPAREN INT COMMA pattern (COMMA pattern)* RPAREN
        ;



pattern :       ;






 