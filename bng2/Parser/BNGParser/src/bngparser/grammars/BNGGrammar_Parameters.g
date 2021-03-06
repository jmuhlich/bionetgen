parser grammar BNGGrammar_Parameters;

options {
  language = Java;
  output = template;
 
}
@members{
 public void getParentTemplate(){
 
  this.setTemplateLib(gParent.getTemplateLib());
 }
}

parameters_block [ Map<String,Register> memory, List parameters]
scope{
  Map<String,Register> lmemory;
}
@init{
  getParentTemplate();
  $parameters_block::lmemory = $memory;
 // System.out.println(gParent.netGrammar);
}

: BEGIN PARAMETERS 
(parameter_def[$memory] {$parameters.add($parameter_def.st);})*  

END PARAMETERS;


parameter_def[Map<String,Register> lmemory]
:
({gParent.netGrammar}? INT |  ) STRING (BECOMES)? expression[lmemory]  {
        lmemory.put($STRING.text,new Register($expression.value,"parameter"));
        }   -> parameter_def(id={$STRING.text},value={$expression.text})
;